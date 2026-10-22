//
//  UnisonView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

struct UnisonView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    @State private var macroBank: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                AppleSectionHeader(title: "UNISON", accent: theme.aFilter, icon: "person.3.fill")
                Spacer(minLength: 4)

                Menu {
                    Picker("Voice Mode", selection: $preset.voiceMode) {
                        ForEach(VoiceMode.allCases, id: \.self) { v in
                            Text(v.rawValue).tag(v)
                        }
                    }
                } label: {
                    Text(preset.voiceMode.rawValue.uppercased())
                        .font(theme.monoFont(size: 9, weight: .bold))
                        .foregroundColor(preset.voiceMode == .poly ? theme.textFaint : theme.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(preset.voiceMode == .poly ? theme.tile : theme.accent.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(preset.voiceMode == .poly ? theme.border : theme.accent, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Voice Mode: Poly, Mono, Legato")

                Menu {
                    Picker("Chord Mode", selection: $preset.chordMode) {
                        ForEach(ChordMode.allCases, id: \.self) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                } label: {
                    Text(preset.chordMode == .off ? "CHORD" : preset.chordMode.rawValue.uppercased())
                        .font(theme.monoFont(size: 9, weight: .bold))
                        .foregroundColor(preset.chordMode == .off ? theme.textFaint : theme.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(preset.chordMode == .off ? theme.tile : theme.accent.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(preset.chordMode == .off ? theme.border : theme.accent, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Chord Memory Mode: Octave, Fifth, Minor, Major, Sus4")

                Menu {
                    Picker("Arp Mode", selection: $preset.arpMode) {
                        ForEach(ArpeggiatorMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    Picker("Arp Rate", selection: $preset.arpRate) {
                        ForEach(TimeDivision.allCases, id: \.self) { d in
                            Text(d.rawValue).tag(d)
                        }
                    }
                    Picker("Octaves", selection: $preset.arpOctaves) {
                        ForEach(1...3, id: \.self) { o in
                            Text("\(o) Oct").tag(o)
                        }
                    }
                    Divider()
                    Menu("Gate (\(Int((preset.arpGateLength * 100).rounded()))%)") {
                        Button("25% (Staccato)") { preset.arpGateLength = 0.25 }
                        Button("50% (Short)") { preset.arpGateLength = 0.50 }
                        Button("75% (Medium)") { preset.arpGateLength = 0.75 }
                        Button("80% (Default)") { preset.arpGateLength = 0.80 }
                        Button("90% (Long)") { preset.arpGateLength = 0.90 }
                        Button("100% (Legato)") { preset.arpGateLength = 1.00 }
                    }
                    Menu("Swing (\(Int((preset.arpSwing * 100).rounded()))%)") {
                        Button("0% (Straight)") { preset.arpSwing = 0.0 }
                        Button("15% (Light)") { preset.arpSwing = 0.15 }
                        Button("30% (Medium)") { preset.arpSwing = 0.30 }
                        Button("50% (Groove)") { preset.arpSwing = 0.50 }
                        Button("66% (Triplet)") { preset.arpSwing = 0.66 }
                        Button("75% (Hard)") { preset.arpSwing = 0.75 }
                    }
                } label: {
                    let swingTag = preset.arpSwing > 0.01 ? " S:\(Int((preset.arpSwing * 100).rounded()))%" : ""
                    let gateTag = abs(preset.arpGateLength - 0.8) > 0.01 ? " G:\(Int((preset.arpGateLength * 100).rounded()))%" : ""
                    Text(preset.arpMode == .off ? "ARP OFF" : "ARP \(preset.arpMode.rawValue.uppercased()) \(preset.arpRate.rawValue) \(preset.arpOctaves)x\(gateTag)\(swingTag)")
                        .font(theme.monoFont(size: 9, weight: .bold))
                        .foregroundColor(preset.arpMode == .off ? theme.textFaint : theme.accent)
                        .lineLimit(1)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(preset.arpMode == .off ? theme.tile : theme.accent.opacity(0.18)))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(preset.arpMode == .off ? theme.border : theme.accent, lineWidth: 0.5))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Arpeggiator Mode, Rate, Octaves, Gate Length & Swing Groove")
            }
            .padding(.horizontal, 4)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    VStack(spacing: 4) {
                        Text("Voices")
                            .themeCaption(theme, size: 9)
                            .foregroundColor(theme.textDim)
                            .lineLimit(1)

                        StepperField(value: $preset.unisonVoices, range: 1...7)
                    }

                    KnobView(value: $preset.unisonDetune, range: 0...50, label: "Detune", format: "%.1f")
                    KnobView(value: $preset.unisonSpread, range: 0...1, label: "Spread")
                    KnobView(value: $preset.analogDrift, range: 0...1, label: "Drift", format: "%.0f%%")
                    KnobView(value: $preset.portamento, range: 0...1.0, label: "Glide", format: "%.2fs")
                }
                HStack(spacing: 6) {
                    Text("Poly")
                        .themeCaption(theme, size: 9)
                        .foregroundColor(theme.textDim)
                        .lineLimit(1)
                    StepperField(value: $preset.polyphonyLimit, range: 1...AudioEngine.maxVoices)
                        .accessibilityIdentifier("polyphonyLimit")
                    Spacer(minLength: 4)
                    Picker("Macro Bank", selection: $macroBank) {
                        Text("1-2").tag(0)
                        Text("3-4").tag(1)
                        Text("5-6").tag(2)
                        Text("7-8").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 130)
                    .accessibilityIdentifier("macroBankPicker")
                }
                switch macroBank {
                case 1:
                    MacroXYPad(macro1: $preset.macro3, macro2: $preset.macro4, labelX: "M3", labelY: "M4")
                case 2:
                    MacroXYPad(macro1: $preset.macro5, macro2: $preset.macro6, labelX: "M5", labelY: "M6")
                case 3:
                    MacroXYPad(macro1: $preset.macro7, macro2: $preset.macro8, labelX: "M7", labelY: "M8")
                default:
                    MacroXYPad(macro1: $preset.macro1, macro2: $preset.macro2, labelX: "M1", labelY: "M2")
                }
            }
            .padding(4)
            .appleInset(cornerRadius: 10)
        }
        .padding(6)
        .appleCard(cornerRadius: theme.rCard, accent: theme.aFilter)
    }
}
