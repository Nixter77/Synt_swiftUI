//
//  OscillatorView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore
import UniformTypeIdentifiers

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
                if oscillatorNumber == 1 {
                    HStack(spacing: 4) {
                        Button {
                            preset.subOscOctave = preset.subOscOctave == -2 ? -1 : -2
                        } label: {
                            Text(preset.subOscOctave == -2 ? "-2 oct" : "-1 oct")
                                .themeCaption(theme, size: 9, weight: .semibold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(theme.inset))
                                .foregroundColor(theme.textDim)
                        }
                        .buttonStyle(.plain)
                        .help("Sub-oscillator octave (-1 or -2)")

                        Menu {
                            Button("Sine") { preset.subOscWaveform = .sine }
                            Button("Triangle") { preset.subOscWaveform = .triangle }
                            Button("Square") { preset.subOscWaveform = .square }
                        } label: {
                            Text(preset.subOscWaveform == .sine ? "Sub Sin" : (preset.subOscWaveform == .triangle ? "Sub Tri" : "Sub Sqr"))
                                .themeCaption(theme, size: 9, weight: .semibold)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(theme.inset))
                                .foregroundColor(theme.textDim)
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("Sub-oscillator waveform")
                    }
                }
                if oscillatorNumber == 2 {
                    Button {
                        preset.oscSyncEnabled.toggle()
                    } label: {
                        Text("SYNC")
                            .themeCaption(theme, size: 9, weight: .bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(preset.oscSyncEnabled ? theme.aOsc : theme.inset)
                            )
                            .foregroundColor(preset.oscSyncEnabled ? theme.bg : theme.textDim)
                    }
                    .buttonStyle(.plain)
                    .help("Hard Sync: OSC 1 forces OSC 2 phase reset")

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
                    HStack(spacing: oscillatorNumber == 2 ? 6 : 10) {
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
                        if oscillatorNumber == 1 {
                            KnobView(
                                value: $preset.subOscVolume,
                                range: 0...1,
                                label: "Sub",
                                format: "%.0f %%"
                            )
                        }
                        if oscillatorNumber == 2 {
                            KnobView(
                                value: $preset.fmAmount,
                                range: 0...1,
                                label: "FM",
                                format: "%.0f %%"
                            )
                            KnobView(
                                value: $preset.ringModAmount,
                                range: 0...1,
                                label: "Ring",
                                format: "%.0f %%"
                            )
                        }
                    }
                    if (oscillatorNumber == 1 && preset.osc1Waveform == .noise) ||
                       (oscillatorNumber == 2 && preset.osc2Waveform == .noise) {
                        HStack {
                            Text("Color")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            ThemeSegmented(
                                options: [
                                    (value: NoiseColor.white, title: "White"),
                                    (value: NoiseColor.pink, title: "Pink"),
                                    (value: NoiseColor.brown, title: "Brown")
                                ],
                                selection: $preset.noiseColor,
                                accent: theme.aOsc
                            )
                        }
                        .padding(.top, 4)
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
                        HStack(spacing: 4) {
                            ThemeSegmented(
                                options: [
                                    (value: 0, title: "Basic"),
                                    (value: 1, title: "Analog"),
                                    (value: 2, title: "Digital"),
                                    (value: 3, title: "PWM"),
                                    (value: 4, title: "Formant"),
                                    (value: 5, title: "User")
                                ],
                                selection: wavetableIndex,
                                accent: theme.aOsc
                            )
                            Button {
                                openUserWavetable()
                            } label: {
                                Image(systemName: "folder")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(theme.textDim)
                                    .frame(width: 22, height: 22)
                                    .background(theme.inset)
                                    .clipShape(RoundedRectangle(cornerRadius: max(theme.rSmall - 1, 2)))
                            }
                            .buttonStyle(.plain)
                            .help("Load custom 2048-sample WAV wavetable")
                        }
                        .padding(.top, 4)

                        HStack {
                            Text("Morph")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            if !modSources(oscillatorNumber == 1 ? .wtMorph1 : .wtMorph2, in: preset.modMatrix).isEmpty {
                                Circle()
                                    .fill(theme.aMod)
                                    .frame(width: 5, height: 5)
                                    .help("Modulated by matrix")
                            }
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

    private var wavetableIndex: Binding<Int> {
        Binding(
            get: {
                oscillatorNumber == 1
                    ? preset.osc1WavetableIndex
                    : preset.osc2WavetableIndex
            },
            set: { value in
                let clamped = max(0, min(5, value))
                if clamped == 5 && WavetableOscillator.userWavetable == nil {
                    openUserWavetable()
                }
                if let engine = audioEngine {
                    engine.updatePreset { p in
                        if oscillatorNumber == 1 {
                            p.osc1WavetableIndex = clamped
                        } else {
                            p.osc2WavetableIndex = clamped
                        }
                    }
                } else {
                    if oscillatorNumber == 1 {
                        preset.osc1WavetableIndex = clamped
                    } else {
                        preset.osc2WavetableIndex = clamped
                    }
                }
            }
        )
    }

    private func openUserWavetable() {
        let panel = NSOpenPanel()
        panel.title = "Select Wavetable (.wav)"
        panel.allowedContentTypes = [UTType.audio, UTType.wav]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try audioEngine?.loadUserWavetable(url: url, forOscillator: oscillatorNumber)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn't load wavetable"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
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
