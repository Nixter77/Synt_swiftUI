//
//  FilterView.swift
//  Synt_swiftUI
//

import SwiftUI

struct FilterView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppleSectionHeader(title: "FILTER", accent: theme.aFilter, icon: "line.3.horizontal.decrease")

            ThemeSegmented(
                options: FilterType.allCases.map { (value: $0, title: $0.rawValue) },
                selection: $preset.filterType,
                accent: theme.aFilter
            )

            HStack(spacing: 20) {
                LargeKnobView(value: $preset.filterCutoff, range: 20...20000, label: "Cutoff", format: "%.0f Hz")
                KnobView(value: $preset.filterResonance, range: 0...1, label: "Resonance")
                KnobView(value: $preset.filterEnvelopeAmount, range: 0...1, label: "Env Amt")
            }
        }
        .padding()
        .appleCard(accent: theme.aFilter)
    }
}

#Preview {
    FilterView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(Theme.baseline.bg)
}
