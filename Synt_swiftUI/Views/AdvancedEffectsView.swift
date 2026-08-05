//
//  AdvancedEffectsView.swift
//  Synt_swiftUI
//
//  UI for Stage 4 advanced FX (Distortion, Parametric EQ, Phaser).
//  All controls write through `AudioEngine.updatePreset` so `preset` stays the
//  single source of truth and later applyPreset calls cannot clobber live FX.
//

import SwiftUI

struct AdvancedEffectsView: View {
    @ObservedObject var audioEngine: AudioEngine

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
            selectedEQPreset = audioEngine.preset.eqPreset
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

            if audioEngine.preset.distortionEnabled {
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

            if audioEngine.preset.eqEnabled {
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

    private func applyEQPreset(_ curve: EQPreset) {
        audioEngine.updatePreset { p in
            p.eqEnabled = true
            p.applyEQCurve(curve)
        }
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

            if audioEngine.preset.phaserEnabled {
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

    // MARK: - Bindings (preset ↔ engine via updatePreset)

    private func binding<T>(
        get: @escaping (SynthPreset) -> T,
        set: @escaping (inout SynthPreset, T) -> Void
    ) -> Binding<T> {
        Binding(
            get: { get(audioEngine.preset) },
            set: { newValue in
                audioEngine.updatePreset { set(&$0, newValue) }
            }
        )
    }

    private var distortionEnabled: Binding<Bool> {
        binding(get: { $0.distortionEnabled }, set: { $0.distortionEnabled = $1 })
    }

    private var distortionType: Binding<DistortionType> {
        binding(get: { $0.distortionType }, set: { $0.distortionType = $1 })
    }

    private var distortionDrive: Binding<Float> {
        binding(get: { $0.distortionDrive }, set: { $0.distortionDrive = $1 })
    }

    private var distortionTone: Binding<Float> {
        binding(get: { $0.distortionTone }, set: { $0.distortionTone = $1 })
    }

    private var distortionMix: Binding<Float> {
        binding(get: { $0.distortionMix }, set: { $0.distortionMix = $1 })
    }

    private var eqEnabled: Binding<Bool> {
        Binding(
            get: { audioEngine.preset.eqEnabled },
            set: { enabled in
                audioEngine.updatePreset { p in
                    p.eqEnabled = enabled
                    if enabled {
                        p.applyEQCurve(selectedEQPreset)
                    }
                }
            }
        )
    }

    private var eqLowGain: Binding<Float> {
        binding(get: { $0.eqLowGain }, set: { $0.eqLowGain = $1 })
    }

    private var eqMidGain: Binding<Float> {
        binding(get: { $0.eqMidGain }, set: { $0.eqMidGain = $1 })
    }

    private var eqHighGain: Binding<Float> {
        binding(get: { $0.eqHighGain }, set: { $0.eqHighGain = $1 })
    }

    private var eqLowFreq: Binding<Float> {
        binding(get: { $0.eqLowFreq }, set: { $0.eqLowFreq = $1 })
    }

    private var eqMidFreq: Binding<Float> {
        binding(get: { $0.eqMidFreq }, set: { $0.eqMidFreq = $1 })
    }

    private var eqHighFreq: Binding<Float> {
        binding(get: { $0.eqHighFreq }, set: { $0.eqHighFreq = $1 })
    }

    private var phaserEnabled: Binding<Bool> {
        binding(get: { $0.phaserEnabled }, set: { $0.phaserEnabled = $1 })
    }

    private var phaserMode: Binding<PhaserMode> {
        binding(get: { $0.phaserMode }, set: { $0.phaserMode = $1 })
    }

    private var phaserRate: Binding<Float> {
        binding(get: { $0.phaserRate }, set: { $0.phaserRate = $1 })
    }

    private var phaserDepth: Binding<Float> {
        binding(get: { $0.phaserDepth }, set: { $0.phaserDepth = $1 })
    }

    private var phaserMix: Binding<Float> {
        binding(get: { $0.phaserMix }, set: { $0.phaserMix = $1 })
    }

    private var phaserFeedback: Binding<Float> {
        binding(get: { $0.phaserFeedback }, set: { $0.phaserFeedback = $1 })
    }

    private var phaserCenter: Binding<Float> {
        binding(get: { $0.phaserCenterFrequency }, set: { $0.phaserCenterFrequency = $1 })
    }

    private var phaserSpread: Binding<Float> {
        binding(get: { $0.phaserStereoSpread }, set: { $0.phaserStereoSpread = $1 })
    }
}

#Preview {
    AdvancedEffectsView(audioEngine: AudioEngine())
        .frame(width: 280)
        .padding()
        .background(AppleTheme.windowBackground)
}
