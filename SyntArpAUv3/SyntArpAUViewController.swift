//
//  SyntArpAUViewController.swift
//  SyntArpAUv3
//
//  Principal class for the MIDI FX AUv3. Hosts a compact SwiftUI control panel
//  bound bidirectionally to SyntArpAudioUnit.parameterTree.
//

import AppKit
import AudioToolbox
import CoreAudioKit
import Foundation
import SwiftUI

@objc(SyntArpAUViewController)
public final class SyntArpAUViewController: AUViewController, AUAudioUnitFactory {
    private static let panelSize = NSSize(width: 460, height: 124)

    private var parameterModel: ArpParameterModel?
    private var hostingView: NSView?

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        requestPreferredSize()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        requestPreferredSize()
    }

    deinit {
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                parameterModel?.detach()
            }
        } else {
            let model = parameterModel
            DispatchQueue.main.async {
                model?.detach()
            }
        }
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try SyntArpAudioUnit(componentDescription: componentDescription, options: [])
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                attach(audioUnit: unit)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.attach(audioUnit: unit)
            }
        }
        return unit
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = Self.panelSize
        ensureHostingView()
    }

    public override func viewWillAppear() {
        super.viewWillAppear()
        preferredContentSize = Self.panelSize
    }

    private func requestPreferredSize() {
        if Thread.isMainThread {
            preferredContentSize = Self.panelSize
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.preferredContentSize = Self.panelSize
            }
        }
    }

    @MainActor
    private func ensureModel() -> ArpParameterModel {
        if let parameterModel {
            return parameterModel
        }
        let model = ArpParameterModel()
        parameterModel = model
        return model
    }

    @MainActor
    private func attach(audioUnit: SyntArpAudioUnit) {
        let model = ensureModel()
        model.bind(to: audioUnit)
        ensureHostingView()
        preferredContentSize = Self.panelSize
    }

    @MainActor
    private func ensureHostingView() {
        guard isViewLoaded, hostingView == nil else { return }
        let model = ensureModel()
        let hosted = NSHostingView(rootView: SyntArpPanelView(model: model))
        hosted.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosted)
        NSLayoutConstraint.activate([
            hosted.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosted.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hosted.topAnchor.constraint(equalTo: view.topAnchor),
            hosted.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hostingView = hosted
    }
}

@MainActor
private final class ArpParameterModel: ObservableObject {
    @Published private(set) var mode: Int = 0
    @Published private(set) var rate: Int = 2
    @Published private(set) var gate: Double = 0.8
    @Published private(set) var octaves: Int = 1
    @Published private(set) var hold: Bool = false

    private var audioUnit: SyntArpAudioUnit?
    private nonisolated(unsafe) var parameterTree: AUParameterTree?
    private nonisolated(unsafe) var observerToken: AUParameterObserverToken?

    deinit {
        if let observerToken, let parameterTree {
            parameterTree.removeParameterObserver(observerToken)
        }
    }

    func detach() {
        if let observerToken, let parameterTree {
            parameterTree.removeParameterObserver(observerToken)
        }
        observerToken = nil
        parameterTree = nil
        audioUnit = nil
    }

    func bind(to unit: SyntArpAudioUnit) {
        detach()
        audioUnit = unit
        guard let tree = unit.parameterTree else { return }
        parameterTree = tree
        syncFromTree(tree)
        observerToken = tree.token(byAddingParameterObserver: { [weak self] address, value in
            let apply: () -> Void = {
                self?.applyHostParameter(address: address, value: value)
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        })
    }

    func setMode(_ value: Int) {
        let clamped = max(0, min(3, value))
        mode = clamped
        pushParameter(address: 0, value: AUValue(clamped))
    }

    func setRate(_ value: Int) {
        let clamped = max(0, min(3, value))
        rate = clamped
        pushParameter(address: 1, value: AUValue(clamped))
    }

    func setGate(_ value: Double) {
        let clamped = max(0.05, min(1.0, value))
        gate = clamped
        pushParameter(address: 2, value: AUValue(clamped))
    }

    func setOctaves(_ value: Int) {
        let clamped = max(1, min(4, value))
        octaves = clamped
        pushParameter(address: 3, value: AUValue(clamped))
    }

    func setHold(_ value: Bool) {
        hold = value
        pushParameter(address: 4, value: value ? 1 : 0)
    }

    private func pushParameter(address: AUParameterAddress, value: AUValue) {
        guard let tree = parameterTree, let observerToken else { return }
        tree.parameter(withAddress: address)?.setValue(value, originator: observerToken)
    }

    private func syncFromTree(_ tree: AUParameterTree) {
        for address: AUParameterAddress in 0...4 {
            if let param = tree.parameter(withAddress: address) {
                applyHostParameter(address: address, value: param.value)
            }
        }
    }

    private func applyHostParameter(address: AUParameterAddress, value: AUValue) {
        guard value.isFinite else { return }
        switch address {
        case 0: mode = max(0, min(3, Int(value.rounded())))
        case 1: rate = max(0, min(3, Int(value.rounded())))
        case 2: gate = max(0.05, min(1.0, Double(value)))
        case 3: octaves = max(1, min(4, Int(value.rounded())))
        case 4: hold = value >= 0.5
        default: break
        }
    }
}

private struct SyntArpPanelView: View {
    @ObservedObject var model: ArpParameterModel

    private static let modeLabels = ["Up", "Down", "Up-Down", "Random"]
    private static let rateLabels = ["1/4", "1/8", "1/16", "1/32"]
    private static let bg = Color(red: 0.09, green: 0.10, blue: 0.13)
    private static let surface = Color(red: 0.15, green: 0.17, blue: 0.22)
    private static let accent = Color(red: 0.22, green: 0.78, blue: 0.90)
    private static let holdAmber = Color(red: 0.96, green: 0.65, blue: 0.18)

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("SYNT ARP")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(Self.accent)
                    .tracking(1.1)

                Spacer(minLength: 4)

                HStack(spacing: 6) {
                    Text("GATE")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { model.gate },
                            set: { model.setGate($0) }
                        ),
                        in: 0.05...1.0
                    )
                    .frame(width: 120)
                    .tint(Self.accent)
                    Text("\(Int((model.gate * 100).rounded()))%")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                        .frame(width: 34, alignment: .trailing)
                }

                Toggle(
                    "Hold",
                    isOn: Binding(
                        get: { model.hold },
                        set: { model.setHold($0) }
                    )
                )
                .toggleStyle(.button)
                .buttonStyle(.borderedProminent)
                .tint(model.hold ? Self.holdAmber : Self.surface)
                .controlSize(.small)
                .font(.system(size: 11, weight: .semibold))
            }

            HStack(spacing: 8) {
                sectionLabel("MODE")
                segmentedRow(
                    labels: Self.modeLabels,
                    selectedIndex: model.mode,
                    onSelect: model.setMode
                )
            }

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    sectionLabel("RATE")
                    segmentedRow(
                        labels: Self.rateLabels,
                        selectedIndex: model.rate,
                        onSelect: model.setRate
                    )
                }
                HStack(spacing: 8) {
                    sectionLabel("OCT")
                    segmentedRow(
                        labels: ["1", "2", "3", "4"],
                        selectedIndex: model.octaves - 1,
                        onSelect: { model.setOctaves($0 + 1) }
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(width: 460, height: 124)
        .background(Self.bg)
        .preferredColorScheme(.dark)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: 34, alignment: .leading)
    }

    private func segmentedRow(
        labels: [String],
        selectedIndex: Int,
        onSelect: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 3) {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                let isSelected = index == selectedIndex
                Button {
                    onSelect(index)
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? .black : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isSelected ? Self.accent : Self.surface)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
