//
//  UnisonView.swift
//  Synt_swiftUI
//

import SwiftUI

struct UnisonView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                AppleSectionHeader(title: "UNISON / MASTER", accent: theme.aFilter, icon: "person.3.fill")
                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Voices")
                        .themeCaption(theme, size: 10)
                        .foregroundColor(theme.textDim)
                        .lineLimit(1)

                    StepperField(value: $preset.unisonVoices, range: 1...7)
                }

                KnobView(value: $preset.unisonDetune, range: 0...50, label: "Detune", format: "%.1f")
                KnobView(value: $preset.unisonSpread, range: 0...1, label: "Spread")
                KnobView(value: $preset.portamento, range: 0...1.0, label: "Glide", format: "%.2fs")
            }
            .padding(4)
            .appleInset(cornerRadius: 10)
        }
        .padding(6)
        .appleCard(cornerRadius: theme.rCard, accent: theme.aFilter)
    }
}
