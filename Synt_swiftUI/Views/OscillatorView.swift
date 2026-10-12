//
//  OscillatorView.swift
//  Synt_swiftUI
//

import SwiftUI

struct OscillatorView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    let oscillatorNumber: Int
    /// Optional: needed for wavetable morph (lives on AudioEngine, not preset).
    var audioEngine: AudioEngine? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppleSectionHeader(title: "OSC \(oscillatorNumber)", accent: theme.aOsc, icon: "waveform")
                Spacer()
                if oscillatorNumber == 2 {
                    ThemeToggle(isOn: $preset.osc2Enabled)
                }
            }

            if oscillatorNumber == 1 || preset.osc2Enabled {
                VStack(spacing: 8) {
                    HStack {
                        Text("Wave")
                            .themeCaption(theme, size: 11)
                            .foregroundColor(theme.textDim)
                            .lineLimit(1)
                        Spacer()
                    }
                    WaveformPicker(
                        selected: oscillatorNumber == 1 ? $preset.osc1Waveform : $preset.osc2Waveform,
                        accent: theme.aOsc
                    )
                    HStack(spacing: 16) {
                        KnobView(
                            value: oscillatorNumber == 1 ? $preset.osc1Volume : $preset.osc2Volume,
                            range: 0...1,
                            label: "Volume",
                            modulated: modSources(.mix, in: preset.modMatrix)
                        )
                        VStack(spacing: 4) {
                            Text("Octave")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Button("-") {
                                    if oscillatorNumber == 1 { preset.osc1Octave = max(-2, preset.osc1Octave - 1) }
                                    else { preset.osc2Octave = max(-2, preset.osc2Octave - 1) }
                                }
                                .buttonStyle(.plain).foregroundColor(theme.text)
                                Text("\(oscillatorNumber == 1 ? preset.osc1Octave : preset.osc2Octave)")
                                    .font(theme.monoFont(size: 12))
                                    .foregroundColor(theme.text).frame(width: 30)
                                Button("+") {
                                    if oscillatorNumber == 1 { preset.osc1Octave = min(2, preset.osc1Octave + 1) }
                                    else { preset.osc2Octave = min(2, preset.osc2Octave + 1) }
                                }
                                .buttonStyle(.plain).foregroundColor(theme.text)
                            }
                        }
                        KnobView(
                            value: oscillatorNumber == 1 ? $preset.osc1Detune : $preset.osc2Detune,
                            range: -50...50,
                            label: "Detune",
                            format: "%.0f ct"
                        )
                    }
                    if (oscillatorNumber == 1 && preset.osc1Waveform == .square) ||
                       (oscillatorNumber == 2 && preset.osc2Waveform == .square) {
                        HStack {
                            Text("PWM")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            if !modSources(oscillatorNumber == 1 ? .pwm1 : .pwm2, in: preset.modMatrix).isEmpty {
                                Circle()
                                    .fill(theme.aMod)
                                    .frame(width: 5, height: 5)
                                    .help("Acts only on Pulse")
                            }
                            ThemeSlider(
                                value: oscillatorNumber == 1 ? $preset.osc1PulseWidth : $preset.osc2PulseWidth,
                                range: 0.05...0.95
                            )
                        }
                        .padding(.top, 4)
                    }
                    if isWavetableSelected, audioEngine != nil {
                        HStack {
                            Text("Morph")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            ThemeSlider(value: wavetableMorph, range: 0...1)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(8)
        .appleCard(accent: theme.aOsc)
    }

    private var isWavetableSelected: Bool {
        if oscillatorNumber == 1 {
            return preset.osc1Waveform == .wavetable
        }
        return preset.osc2Waveform == .wavetable
    }

    /// Morph is stored on `preset` so later `applyPreset` (filter/ADSR edits) cannot reset it.
    private var wavetableMorph: Binding<Float> {
        Binding(
            get: {
                oscillatorNumber == 1
                    ? preset.osc1WavetableMorph
                    : preset.osc2WavetableMorph
            },
            set: { value in
                let clamped = max(0, min(1, value))
                if let engine = audioEngine {
                    // Write through engine so didSet → applyPreset keeps oscillators in sync.
                    engine.updatePreset { p in
                        if oscillatorNumber == 1 {
                            p.osc1WavetableMorph = clamped
                        } else {
                            p.osc2WavetableMorph = clamped
                        }
                    }
                } else {
                    if oscillatorNumber == 1 {
                        preset.osc1WavetableMorph = clamped
                    } else {
                        preset.osc2WavetableMorph = clamped
                    }
                }
            }
        )
    }
}

#Preview {
    HStack {
        OscillatorView(preset: .constant(.defaultPreset), oscillatorNumber: 1)
        OscillatorView(preset: .constant(.defaultPreset), oscillatorNumber: 2)
    }
    .padding()
    .background(Theme.baseline.bg)
}
