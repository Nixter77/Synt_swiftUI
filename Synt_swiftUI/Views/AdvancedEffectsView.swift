//
//  AdvancedEffectsView.swift
//  Synt_swiftUI
//
//  UI for Stage 4 advanced FX (Distortion, Parametric EQ, Phaser).
//  Modules stay disabled by default — enabling is opt-in from this panel.
//

import SwiftUI

struct AdvancedEffectsView: View {
    @ObservedObject var audioEngine: AudioEngine

    @State private var showDistortion = false
    @State private var showEQ = false
    @State private var showPhaser = false
    @State private var selectedEQPreset: EQPreset = .flat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppleSectionHeader(
                title: "ADVANCED FX",
                accent: AppleTheme.accentModulation,
                icon: "slider.horizontal.3"
            )

            distortionSection
            Divider()
            eqSection
            Divider()
            phaserSection
        }
        .padding()
        .appleCard(accent: AppleTheme.accentModulation)
        .onAppear {
            showDistortion = audioEngine.distortion.enabled
            showEQ = audioEngine.parametricEQL.enabled
            showPhaser = !audioEngine.phaser.bypass
        }
    }

    // MARK: - Distortion

    private var distortionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Distortion")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppleTheme.textPrimary)
                Spacer()
                Toggle("", isOn: distortionEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .tint(AppleTheme.accentModulation)
            }

            if audioEngine.distortion.enabled {
                Picker("Type", selection: distortionType) {
                    ForEach(DistortionType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11, design: .rounded))

                HStack(spacing: 12) {
                    KnobView(value: distortionDrive, range: 0...1, label: "Drive")
                    KnobView(value: distortionTone, range: 0...1, label: "Tone")
                    KnobView(value: distortionMix, range: 0...1, label: "Mix")
                }
            }
        }
    }

    // MARK: - Parametric EQ

    private var eqSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Parametric EQ")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppleTheme.textPrimary)
                Spacer()
                Toggle("", isOn: eqEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .tint(AppleTheme.accentModulation)
            }

            if audioEngine.parametricEQL.enabled {
                HStack {
                    Text("Preset")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(AppleTheme.textSecondary)
                    Spacer()
                    Picker("EQ Preset", selection: $selectedEQPreset) {
                        ForEach(EQPreset.allCases) { preset in
                            Text(preset.rawValue).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 11, design: .rounded))
                    .onChange(of: selectedEQPreset) { _, newValue in
                        applyEQPreset(newValue)
                    }
                }

                HStack(spacing: 10) {
                    KnobView(value: eqLowGain, range: -12...12, label: "Low", format: "%.0fdB")
                    KnobView(value: eqMidGain, range: -12...12, label: "Mid", format: "%.0fdB")
                    KnobView(value: eqHighGain, range: -12...12, label: "High", format: "%.0fdB")
                }
                HStack(spacing: 10) {
                    KnobView(value: eqLowFreq, range: 40...400, label: "Lo F", format: "%.0fHz")
                    KnobView(value: eqMidFreq, range: 200...5000, label: "Mid F", format: "%.0fHz")
                    KnobView(value: eqHighFreq, range: 2000...16000, label: "Hi F", format: "%.0fHz")
                }
            }
        }
    }

    private func applyEQPreset(_ preset: EQPreset) {
        audioEngine.parametricEQL.applyPreset(preset)
        audioEngine.parametricEQR.applyPreset(preset)
        audioEngine.objectWillChange.send()
    }

    // MARK: - Phaser

    private var phaserSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Phaser")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppleTheme.textPrimary)
                Spacer()
                Toggle("", isOn: phaserEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .tint(AppleTheme.accentModulation)
            }

            if !audioEngine.phaser.bypass {
                Picker("Mode", selection: phaserMode) {
                    ForEach(PhaserMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11, design: .rounded))

                HStack(spacing: 10) {
                    KnobView(value: phaserRate, range: 0.05...5, label: "Rate", format: "%.2fHz")
                    KnobView(value: phaserDepth, range: 0...1, label: "Depth")
                    KnobView(value: phaserMix, range: 0...1, label: "Mix")
                }
                HStack(spacing: 10) {
                    KnobView(value: phaserFeedback, range: -0.9...0.9, label: "Fdbk")
                    KnobView(value: phaserCenter, range: 200...4000, label: "Center", format: "%.0fHz")
                    KnobView(value: phaserSpread, range: 0...1, label: "Spread")
                }
            }
        }
    }

    // MARK: - Bindings (mutate engine FX; notify SwiftUI)

    private var distortionEnabled: Binding<Bool> {
        Binding(
            get: { audioEngine.distortion.enabled },
            set: {
                audioEngine.distortion.enabled = $0
                showDistortion = $0
                audioEngine.objectWillChange.send()
            }
        )
    }

    private var distortionType: Binding<DistortionType> {
        Binding(
            get: { audioEngine.distortion.type },
            set: {
                audioEngine.distortion.type = $0
                audioEngine.objectWillChange.send()
            }
        )
    }

    private var distortionDrive: Binding<Float> {
        Binding(
            get: { audioEngine.distortion.drive },
            set: { audioEngine.distortion.drive = $0 }
        )
    }

    private var distortionTone: Binding<Float> {
        Binding(
            get: { audioEngine.distortion.tone },
            set: { audioEngine.distortion.tone = $0 }
        )
    }

    private var distortionMix: Binding<Float> {
        Binding(
            get: { audioEngine.distortion.mix },
            set: { audioEngine.distortion.mix = $0 }
        )
    }

    private var eqEnabled: Binding<Bool> {
        Binding(
            get: { audioEngine.parametricEQL.enabled },
            set: {
                audioEngine.parametricEQL.enabled = $0
                audioEngine.parametricEQR.enabled = $0
                showEQ = $0
                if $0 {
                    // Apply current preset when turning EQ on
                    applyEQPreset(selectedEQPreset)
                }
                audioEngine.objectWillChange.send()
            }
        )
    }

    private func syncEQ(_ body: (ParametricEQ) -> Void) {
        body(audioEngine.parametricEQL)
        body(audioEngine.parametricEQR)
    }

    private var eqLowGain: Binding<Float> {
        Binding(
            get: { audioEngine.parametricEQL.lowGain },
            set: { v in syncEQ { $0.lowGain = v } }
        )
    }

    private var eqMidGain: Binding<Float> {
        Binding(
            get: { audioEngine.parametricEQL.midGain },
            set: { v in syncEQ { $0.midGain = v } }
        )
    }

    private var eqHighGain: Binding<Float> {
        Binding(
            get: { audioEngine.parametricEQL.highGain },
            set: { v in syncEQ { $0.highGain = v } }
        )
    }

    private var eqLowFreq: Binding<Float> {
        Binding(
            get: { audioEngine.parametricEQL.lowFreq },
            set: { v in syncEQ { $0.lowFreq = v } }
        )
    }

    private var eqMidFreq: Binding<Float> {
        Binding(
            get: { audioEngine.parametricEQL.midFreq },
            set: { v in syncEQ { $0.midFreq = v } }
        )
    }

    private var eqHighFreq: Binding<Float> {
        Binding(
            get: { audioEngine.parametricEQL.highFreq },
            set: { v in syncEQ { $0.highFreq = v } }
        )
    }

    private var phaserEnabled: Binding<Bool> {
        Binding(
            get: { !audioEngine.phaser.bypass },
            set: {
                audioEngine.phaser.bypass = !$0
                showPhaser = $0
                audioEngine.objectWillChange.send()
            }
        )
    }

    private var phaserMode: Binding<PhaserMode> {
        Binding(
            get: { audioEngine.phaser.mode },
            set: {
                audioEngine.phaser.mode = $0
                audioEngine.objectWillChange.send()
            }
        )
    }

    private var phaserRate: Binding<Float> {
        Binding(
            get: { audioEngine.phaser.rate },
            set: { audioEngine.phaser.rate = $0 }
        )
    }

    private var phaserDepth: Binding<Float> {
        Binding(
            get: { audioEngine.phaser.depth },
            set: { audioEngine.phaser.depth = $0 }
        )
    }

    private var phaserMix: Binding<Float> {
        Binding(
            get: { audioEngine.phaser.mix },
            set: { audioEngine.phaser.mix = $0 }
        )
    }

    private var phaserFeedback: Binding<Float> {
        Binding(
            get: { audioEngine.phaser.feedback },
            set: { audioEngine.phaser.feedback = $0 }
        )
    }

    private var phaserCenter: Binding<Float> {
        Binding(
            get: { audioEngine.phaser.centerFrequency },
            set: { audioEngine.phaser.centerFrequency = $0 }
        )
    }

    private var phaserSpread: Binding<Float> {
        Binding(
            get: { audioEngine.phaser.stereoSpread },
            set: { audioEngine.phaser.stereoSpread = $0 }
        )
    }
}

#Preview {
    AdvancedEffectsView(audioEngine: AudioEngine())
        .frame(width: 280)
        .padding()
        .background(AppleTheme.windowBackground)
}
