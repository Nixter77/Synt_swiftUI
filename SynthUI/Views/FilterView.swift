//
//  FilterView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

struct FilterView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    /// Default off so the panel keeps the Filter 1 height. LayoutTests measure that state.
    @State private var showsFilter2 = false

    private static let filter2Routes: [(value: DualFilterRouting, title: String)] = [
        (.off, "Off"),
        (.serial, "Serial"),
        (.parallel, "Parallel"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                AppleSectionHeader(title: "FILTER", accent: theme.aFilter, icon: "line.3.horizontal.decrease")
                Button {
                    showsFilter2.toggle()
                } label: {
                    Text(showsFilter2 ? "F1" : "F2")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(showsFilter2 ? theme.aFilter : Color.clear)
                        .foregroundColor(showsFilter2 ? .black : theme.textDim)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFilter.opacity(0.6), lineWidth: 1))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter2Tab")
                .help("Filter 2")
                Spacer()
                Menu {
                    Menu("Velocity -> Env (\(Int((preset.velocityToEnvAmount * 100).rounded()))%)") {
                        Button("Off (0%)") { preset.velocityToEnvAmount = 0.0 }
                        Button("25%") { preset.velocityToEnvAmount = 0.25 }
                        Button("50%") { preset.velocityToEnvAmount = 0.50 }
                        Button("75%") { preset.velocityToEnvAmount = 0.75 }
                        Button("100% (Full)") { preset.velocityToEnvAmount = 1.00 }
                        Divider()
                        Button("-50% (Inverted)") { preset.velocityToEnvAmount = -0.50 }
                        Button("-100% (Inverted Full)") { preset.velocityToEnvAmount = -1.00 }
                    }
                } label: {
                    if abs(preset.velocityToEnvAmount) > 0.01 {
                        Text("V→E \(Int((preset.velocityToEnvAmount * 100).rounded()))%")
                            .font(theme.monoFont(size: 9, weight: .bold))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(theme.accent.opacity(0.18)))
                    } else {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textDim)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Velocity to Envelope Amount Routing")
            }

            if showsFilter2 {
                ThemeSegmented(
                    options: Self.filter2Routes,
                    selection: $preset.filter2Routing,
                    accent: theme.aFilter
                )
                ThemeSegmented(
                    options: FilterType.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: $preset.filter2Type,
                    accent: theme.aFilter
                )
                HStack(spacing: 5) {
                    LargeKnobView(
                        value: $preset.filter2Cutoff,
                        range: 20...20000,
                        label: "Cutoff",
                        format: "%.0f Hz"
                    )
                    KnobView(value: $preset.filter2Resonance, range: 0...1, label: "Resonance")
                    KnobView(value: $preset.filter2Balance, range: 0...1, label: "Balance")
                    if preset.filter2Type == .formant {
                        KnobView(
                            value: $preset.filterVowel,
                            range: 0...4,
                            label: "Vowel",
                            modulated: modSources(.vowel, in: preset.modMatrix),
                            modulationAmount: modAmount(.vowel, in: preset.modMatrix)
                        )
                    }
                    Spacer(minLength: 0)
                }
            } else {
                ThemeSegmented(
                    options: FilterType.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: $preset.filterType,
                    accent: theme.aFilter
                )

                HStack(spacing: 5) {
                    LargeKnobView(
                        value: $preset.filterCutoff,
                        range: 20...20000,
                        label: "Cutoff",
                        format: "%.0f Hz",
                        modulated: modSources(.cutoff, in: preset.modMatrix),
                        modulationAmount: modAmount(.cutoff, in: preset.modMatrix)
                    )
                    KnobView(
                        value: $preset.filterResonance,
                        range: 0...1,
                        label: "Resonance",
                        modulated: modSources(.resonance, in: preset.modMatrix),
                        modulationAmount: modAmount(.resonance, in: preset.modMatrix)
                    )
                    KnobView(value: $preset.filterEnvelopeAmount, range: -1...1, label: "Env")
                    KnobView(value: $preset.velocityToCutoff, range: 0...1, label: "Vel", format: "%.0f%%")
                    KnobView(value: $preset.filterKeyTracking, range: 0...1, label: "Key Trk")
                    KnobView(value: $preset.filterDrive, range: 0...1, label: "Drive")
                }
                HStack(spacing: 5) {
                    KnobView(value: $preset.filterFeedback, range: -1...1, label: "Feedback")
                    if preset.filterType == .formant {
                        KnobView(
                            value: $preset.filterVowel,
                            range: 0...4,
                            label: "Vowel",
                            modulated: modSources(.vowel, in: preset.modMatrix),
                            modulationAmount: modAmount(.vowel, in: preset.modMatrix)
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(6)
        .appleCard(accent: theme.aFilter)
    }
}

#Preview {
    FilterView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(Theme.baseline.bg)
}
