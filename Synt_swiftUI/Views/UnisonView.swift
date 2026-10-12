//
//  UnisonView.swift
//  Synt_swiftUI
//

import SwiftUI

struct UnisonView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                AppleSectionHeader(title: "UNISON / MASTER", accent: theme.aFilter, icon: "person.3.fill")
                Spacer()
            }
            .padding(.horizontal, 4)

            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Text("Voices")
                        .themeCaption(theme, size: 10)
                        .foregroundColor(theme.textDim)
                    
                    Picker("Voices", selection: $preset.unisonVoices) {
                        ForEach(1...7, id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 50)
                    .background(theme.panel)
                    .cornerRadius(6)
                }

                KnobView(value: $preset.unisonDetune, range: 0...50, label: "Detune", format: "%.1f")
                KnobView(value: $preset.unisonSpread, range: 0...1, label: "Spread")
                KnobView(value: $preset.portamento, range: 0...1.0, label: "Glide", format: "%.2fs")
            }
            .padding(12)
            .appleInset(cornerRadius: 10)
        }
        .padding(8)
        .appleCard(cornerRadius: theme.rCard, accent: theme.aFilter)
    }
}
