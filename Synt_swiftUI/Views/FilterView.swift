//
//  FilterView.swift
//  Synt_swiftUI
//

import SwiftUI

struct FilterView: View {
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppleSectionHeader(title: "FILTER", accent: AppleTheme.accentFilter, icon: "line.3.horizontal.decrease")

            Picker("Type", selection: $preset.filterType) {
                ForEach(FilterType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 20) {
                LargeKnobView(value: $preset.filterCutoff, range: 20...20000, label: "Cutoff", format: "%.0f Hz")
                KnobView(value: $preset.filterResonance, range: 0...1, label: "Resonance")
                KnobView(value: $preset.filterEnvelopeAmount, range: 0...1, label: "Env Amt")
            }
        }
        .padding()
        .appleCard(accent: AppleTheme.accentFilter)
    }
}

#Preview {
    FilterView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(AppleTheme.windowBackground)
}
