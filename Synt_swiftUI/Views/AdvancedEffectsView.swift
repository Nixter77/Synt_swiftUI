//
//  AdvancedEffectsView.swift
//  Synt_swiftUI
//
//  Distortion, parametric EQ, and phaser. Every control writes through
//  `AudioEngine.updatePreset` so `preset` stays the source of truth.
//

import SwiftUI

struct AdvancedEffectsView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var audioEngine: AudioEngine

    var body: some View {
        VStack(spacing: 10) {
            distortionCard
            eqCard
            phaserCard
        }
    }

    private var presetBinding: Binding<SynthPreset> {
        Binding(
            get: { audioEngine.preset },
            set: { audioEngine.preset = $0 }
        )
    }

    private var distortionCard: some View {
        FXSlotCard(
            title: "Distortion",
            enabled: distortionEnabled,
            accent: theme.aFx,
            storageName: "distortion",
            startsExpanded: audioEngine.preset.distortionEnabled,
            menu: { FXPresetMenu(kind: .distortion, preset: presetBinding) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Type", selection: distortionType) {
                        ForEach(DistortionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 11, design: .rounded))

                    Spacer()

                    Button {
                        audioEngine.preset.distortionOversampling.toggle()
                    } label: {
                        Text("2X HQ")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(audioEngine.preset.distortionOversampling ? theme.aFx : Color.clear)
                            .foregroundColor(audioEngine.preset.distortionOversampling ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    KnobView(value: distortionDrive, range: 0...1, label: "Drive")
                    KnobView(value: distortionTone, range: 0...1, label: "Tone")
                    KnobView(value: distortionMix, range: 0...1, label: "Mix", target: .distortionMix)
                }
            }
        }
    }

    private var eqCard: some View {
        FXSlotCard(
            title: "EQ",
            enabled: eqEnabled,
            accent: theme.aFx,
            storageName: "eq",
            startsExpanded: audioEngine.preset.eqEnabled,
            menu: { FXPresetMenu(kind: .eq, preset: presetBinding) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    KnobView(value: eqLowGain, range: -12...12, label: "Low", format: "%.0fdB")
                    KnobView(value: eqMidGain, range: -12...12, label: "Mid", format: "%.0fdB")
                    KnobView(value: eqHighGain, range: -12...12, label: "High", format: "%.0fdB")
                }
                HStack(spacing: 8) {
                    KnobView(value: eqLowFreq, range: 40...400, label: "Lo F", format: "%.0fHz")
                    KnobView(value: eqMidFreq, range: 200...5000, label: "Mid F", format: "%.0fHz")
                    KnobView(value: eqHighFreq, range: 2000...16000, label: "Hi F", format: "%.0fHz")
                }
            }
        }
    }

    private var phaserCard: some View {
        FXSlotCard(
            title: "Phaser",
            enabled: phaserEnabled,
            accent: theme.aFx,
            storageName: "phaser",
            startsExpanded: audioEngine.preset.phaserEnabled,
            menu: { FXPresetMenu(kind: .phaser, preset: presetBinding) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: phaserMode) {
                    ForEach(PhaserMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11, design: .rounded))

                HStack(spacing: 8) {
                    KnobView(value: phaserRate, range: 0.05...5, label: "Rate", format: "%.2fHz")
                    KnobView(value: phaserDepth, range: 0...1, label: "Depth")
                    KnobView(value: phaserMix, range: 0...1, label: "Mix", target: .phaserMix)
                }
                HStack(spacing: 8) {
                    KnobView(value: phaserFeedback, range: -0.9...0.9, label: "Fdbk")
                    KnobView(value: phaserCenter, range: 200...4000, label: "Center", format: "%.0fHz")
                    KnobView(value: phaserSpread, range: 0...1, label: "Spread")
                }
            }
        }
    }

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
        binding(get: { $0.eqEnabled }, set: { $0.eqEnabled = $1 })
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
        .frame(width: 240)
        .padding()
        .background(Theme.baseline.bg)
}
