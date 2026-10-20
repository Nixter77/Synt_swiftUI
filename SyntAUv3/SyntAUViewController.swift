//
//  SyntAUViewController.swift
//  SyntAUv3
//
//  Principal class. Hosts the control grid and talks to the parameter tree.
//

import AudioToolbox
import CoreAudioKit
import SwiftUI
import SynthCore

@objc(SyntAUViewController)
public final class SyntAUViewController: AUViewController, AUAudioUnitFactory {
    private var surface: AUParameterSurface?
    private var hostingView: NSView?
    private weak var hostedSurface: AUParameterSurface?

    /// Main thread only (NSViewController asserts off main). Use `requestPreferredSize()` elsewhere.
    private func applyPreferredSize() {
        dispatchPrecondition(condition: .onQueue(.main))
        let layout = surface?.layout ?? .compact
        let zoom = surface?.zoom ?? .p100
        let size = AUPluginMetrics.preferredSize(layout: layout, zoom: zoom)
        preferredContentSize = NSSize(width: size.width, height: size.height)
    }

    private func requestPreferredSize() {
        PluginMainThread.perform { [weak self] in self?.applyPreferredSize() }
    }

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        requestPreferredSize()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        requestPreferredSize()
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try SyntAudioUnit(componentDescription: componentDescription, options: [])
        let surface = AUParameterSurface(audioUnit: unit)
        surface.onChromeChange = { [weak self] in self?.requestPreferredSize() }
        self.surface = surface
        // The host calls this from the extension XPC queue. Every AppKit/SwiftUI
        // touch (size, hosting view) must happen on main.
        PluginMainThread.perform { [weak self] in
            self?.applyPreferredSize()
            self?.installHostingView(for: surface)
        }
        return unit
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        applyPreferredSize()
        guard let surface else { return }
        if Thread.isMainThread {
            installHostingView(for: surface)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.installHostingView(for: surface)
            }
        }
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        applyPreferredSize()
    }

    private func installHostingView(for surface: AUParameterSurface) {
        guard isViewLoaded else { return }
        // createAudioUnit and viewDidLoad both land here; build the view once per surface.
        if hostingView != nil && hostedSurface === surface { return }
        hostingView?.removeFromSuperview()
        let root = PluginScreen(surface: surface)
            .environment(\.theme, Theme.baseline)
        let hosted = NSHostingView(rootView: root)
        hosted.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: view.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingView = hosted
        hostedSurface = surface
        applyPreferredSize()
    }
}

/// Knob edits call `setValue(_:originator:)`. Host automation arrives through the observer token.
@MainActor
final class AUParameterSurface: ObservableObject {
    @Published private(set) var preset: SynthPreset
    @Published private(set) var zoom: PluginZoom
    @Published private(set) var layout: PluginLayout
    private let audioUnit: SyntAudioUnit
    private var observerToken: AUParameterObserverToken?
    private var stateObserver: NSObjectProtocol?
    private var chromeObserver: NSObjectProtocol?
    private var applyingFromHost = false
    var onChromeChange: (() -> Void)?

    var respondsToProgramChange: Bool {
        get { audioUnit.respondsToProgramChange }
        set {
            audioUnit.respondsToProgramChange = newValue
            objectWillChange.send()
        }
    }

    init(audioUnit: SyntAudioUnit) {
        self.audioUnit = audioUnit
        self.preset = audioUnit.uiPreset
        self.zoom = audioUnit.uiZoom
        self.layout = audioUnit.uiLayout
        PatchHistoryManager.shared.registerPresetProvider { [weak self] in
            self?.preset ?? .defaultPreset
        }
        // Host loaded a whole state: re-read everything, not just addressed knobs.
        stateObserver = NotificationCenter.default.addObserver(
            forName: SyntAudioUnit.stateDidChangeNotification,
            object: audioUnit,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.preset = self.audioUnit.uiPreset
                self.zoom = self.audioUnit.uiZoom
                self.layout = self.audioUnit.uiLayout
                self.onChromeChange?()
            }
        }
        chromeObserver = NotificationCenter.default.addObserver(
            forName: SyntAudioUnit.chromeDidChangeNotification,
            object: audioUnit,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.zoom = self.audioUnit.uiZoom
                self.layout = self.audioUnit.uiLayout
                self.onChromeChange?()
            }
        }
        guard let tree = audioUnit.parameterTree else { return }
        observerToken = tree.token(byAddingParameterObserver: { [weak self] address, value in
            let apply: () -> Void = {
                self?.hostSet(address: address, value: value)
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        })
    }

    deinit {
        if let stateObserver {
            NotificationCenter.default.removeObserver(stateObserver)
        }
        if let chromeObserver {
            NotificationCenter.default.removeObserver(chromeObserver)
        }
        if let observerToken, let tree = audioUnit.parameterTree {
            tree.removeParameterObserver(observerToken)
        }
    }

    func userSetPreset(_ newValue: SynthPreset) {
        let old = preset
        preset = newValue
        PatchHistoryManager.shared.recordChange(from: old, to: newValue)
        guard !applyingFromHost, let tree = audioUnit.parameterTree, let observerToken else { return }
        for address in SynthParameterAddress.allCases {
            let before = old.parameterValue(for: address)
            let after = newValue.parameterValue(for: address)
            if before != after {
                tree.parameter(withAddress: address.rawValue)?.setValue(after, originator: observerToken)
            }
        }
        if old.withAddressedKnobsParked() != newValue.withAddressedKnobsParked() {
            audioUnit.adoptNonAddressedFields(of: newValue)
        }
    }

    private func hostSet(address: AUParameterAddress, value: AUValue) {
        guard let parameter = SynthParameterAddress(rawValue: address) else { return }
        applyingFromHost = true
        var next = preset
        next.setParameterValue(value, for: parameter)
        preset = next
        applyingFromHost = false
    }

    func setZoom(_ zoom: PluginZoom) {
        audioUnit.uiZoom = zoom
        self.zoom = zoom
        onChromeChange?()
    }
}

private struct PluginScreen: View {
    @ObservedObject var surface: AUParameterSurface

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                Theme.baseline.bg.ignoresSafeArea()
                SynthControlGrid(
                    preset: Binding(
                        get: { surface.preset },
                        set: { surface.userSetPreset($0) }
                    ),
                    layout: surface.layout
                )
                .frame(width: max(geo.size.width, 1), height: max(geo.size.height, 1), alignment: .top)

                HStack(spacing: 4) {
                    Menu {
                        ForEach(PluginZoom.allCases, id: \.self) { zoom in
                            Button("\(zoom.rawValue)%") { surface.setZoom(zoom) }
                        }
                    } label: {
                        Text("\(surface.zoom.rawValue)%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.baseline.textDim)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Zoom")
                    .accessibilityIdentifier("pluginZoomMenu")

                    Menu {
                        Toggle("Program Change", isOn: Binding(
                            get: { surface.respondsToProgramChange },
                            set: { surface.respondsToProgramChange = $0 }
                        ))
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13))
                            .foregroundColor(Theme.baseline.textDim)
                            .padding(6)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("Settings")
                }
                .padding(6)
            }
        }
    }
}
