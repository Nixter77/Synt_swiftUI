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

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        preferredContentSize = NSSize(width: AUPluginMetrics.contentWidth, height: AUPluginMetrics.contentHeight)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        preferredContentSize = NSSize(width: AUPluginMetrics.contentWidth, height: AUPluginMetrics.contentHeight)
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try SyntAudioUnit(componentDescription: componentDescription, options: [])
        let surface = AUParameterSurface(audioUnit: unit)
        self.surface = surface
        // The host calls this from the extension XPC queue. SwiftUI views load on main.
        if Thread.isMainThread {
            installHostingView(for: surface)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.installHostingView(for: surface)
            }
        }
        return unit
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: AUPluginMetrics.contentWidth, height: AUPluginMetrics.contentHeight)
        guard let surface else { return }
        if Thread.isMainThread {
            installHostingView(for: surface)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.installHostingView(for: surface)
            }
        }
    }

    private func installHostingView(for surface: AUParameterSurface) {
        guard isViewLoaded else { return }
        hostingView?.removeFromSuperview()
        let root = PluginScreen(surface: surface)
            .environment(\.theme, Theme.baseline)
            .frame(width: AUPluginMetrics.contentWidth, height: AUPluginMetrics.contentHeight, alignment: .top)
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
        preferredContentSize = NSSize(width: AUPluginMetrics.contentWidth, height: AUPluginMetrics.contentHeight)
    }
}

/// Knob edits call `setValue(_:originator:)`. Host automation arrives through the observer token.
@MainActor
final class AUParameterSurface: ObservableObject {
    @Published private(set) var preset: SynthPreset
    private let audioUnit: SyntAudioUnit
    private var observerToken: AUParameterObserverToken?
    private var stateObserver: NSObjectProtocol?
    private var applyingFromHost = false

    init(audioUnit: SyntAudioUnit) {
        self.audioUnit = audioUnit
        self.preset = audioUnit.uiPreset
        // Host loaded a whole state: re-read everything, not just addressed knobs.
        stateObserver = NotificationCenter.default.addObserver(
            forName: SyntAudioUnit.stateDidChangeNotification,
            object: audioUnit,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.preset = self.audioUnit.uiPreset
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
        if let observerToken, let tree = audioUnit.parameterTree {
            tree.removeParameterObserver(observerToken)
        }
    }

    func userSetPreset(_ newValue: SynthPreset) {
        let old = preset
        preset = newValue
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
}

private struct PluginScreen: View {
    @ObservedObject var surface: AUParameterSurface

    var body: some View {
        SynthControlGrid(preset: Binding(
            get: { surface.preset },
            set: { surface.userSetPreset($0) }
        ))
    }
}
