//
//  LFOView.swift
//  Synt_swiftUI
//

import SwiftUI

struct LFOView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppleSectionHeader(title: "LFO", accent: theme.aLFO, icon: "waveform.path")
                Spacer()
                ThemeToggle(isOn: $preset.lfoEnabled)
            }

            if preset.lfoEnabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("Wave")
                            .themeCaption(theme, size: 11)
                            .foregroundColor(theme.textDim)
                        Spacer()
                    }
                    WaveformPicker(selected: $preset.lfoWaveform, accent: theme.aLFO)
                    HStack {
                        Text("Target")
                            .themeCaption(theme, size: 11)
                            .foregroundColor(theme.textDim)
                        Spacer()
                    }
                    ThemeSegmented(
                        options: LFOTarget.allCases.map { (value: $0, title: $0.rawValue) },
                        selection: $preset.lfoTarget,
                        accent: theme.aLFO
                    )
                    HStack(spacing: 16) {
                        KnobView(value: $preset.lfoRate, range: 0.1...20, label: "Rate", format: "%.1f Hz")
                        KnobView(value: $preset.lfoDepth, range: 0...1, label: "Depth")
                    }
                }
            }
        }
        .padding()
        .appleCard(accent: theme.aLFO)
    }
}

#Preview {
    LFOView(preset: .constant(.defaultPreset))
        .frame(width: 250).padding()
        .background(Theme.baseline.bg)
}
