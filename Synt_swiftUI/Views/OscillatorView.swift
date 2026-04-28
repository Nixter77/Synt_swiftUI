//
//  OscillatorView.swift
//  Synt_swiftUI
//

import SwiftUI

struct OscillatorView: View {
    @Binding var preset: SynthPreset
    let oscillatorNumber: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppleSectionHeader(title: "OSC \(oscillatorNumber)", accent: AppleTheme.accentOscillator, icon: "waveform")
                Spacer()
                if oscillatorNumber == 2 {
                    Toggle("", isOn: $preset.osc2Enabled)
                        .toggleStyle(.switch)
                        .scaleEffect(0.7)
                        .tint(AppleTheme.accentOscillator)
                }
            }

            if oscillatorNumber == 1 || preset.osc2Enabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("Wave")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(AppleTheme.textSecondary)
                        Spacer()
                    }
                    WaveformPicker(selected: oscillatorNumber == 1 ? $preset.osc1Waveform : $preset.osc2Waveform)
                    HStack(spacing: 16) {
                        KnobView(
                            value: oscillatorNumber == 1 ? $preset.osc1Volume : $preset.osc2Volume,
                            range: 0...1,
                            label: "Volume"
                        )
                        VStack(spacing: 4) {
                            Text("Octave")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(AppleTheme.textSecondary)
                            HStack(spacing: 8) {
                                Button("-") {
                                    if oscillatorNumber == 1 { preset.osc1Octave = max(-2, preset.osc1Octave - 1) }
                                    else { preset.osc2Octave = max(-2, preset.osc2Octave - 1) }
                                }
                                .buttonStyle(.plain).foregroundColor(AppleTheme.textPrimary)
                                Text("\(oscillatorNumber == 1 ? preset.osc1Octave : preset.osc2Octave)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppleTheme.textPrimary).frame(width: 30)
                                Button("+") {
                                    if oscillatorNumber == 1 { preset.osc1Octave = min(2, preset.osc1Octave + 1) }
                                    else { preset.osc2Octave = min(2, preset.osc2Octave + 1) }
                                }
                                .buttonStyle(.plain).foregroundColor(AppleTheme.textPrimary)
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
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundColor(AppleTheme.textSecondary)
                                .frame(width: 40, alignment: .trailing)
                            Slider(value: oscillatorNumber == 1 ? $preset.osc1PulseWidth : $preset.osc2PulseWidth, in: 0.05...0.95)
                                .tint(AppleTheme.accentOscillator)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding()
        .appleCard(accent: AppleTheme.accentOscillator)
    }
}

#Preview {
    HStack {
        OscillatorView(preset: .constant(.defaultPreset), oscillatorNumber: 1)
        OscillatorView(preset: .constant(.defaultPreset), oscillatorNumber: 2)
    }
    .padding()
    .background(AppleTheme.windowBackground)
}
