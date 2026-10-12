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
                Toggle("", isOn: $preset.lfoEnabled)
                    .toggleStyle(.switch)
                    .scaleEffect(0.7)
                    .tint(theme.aLFO)
            }

            if preset.lfoEnabled {
                VStack(spacing: 12) {
                    HStack {
                        Text("Wave")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textDim)
                        Spacer()
                    }
                    WaveformPicker(selected: $preset.lfoWaveform)
                    HStack {
                        Text("Target")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(theme.textDim)
                        Spacer()
                    }
                    Picker("Target", selection: $preset.lfoTarget) {
                        ForEach(LFOTarget.allCases, id: \.self) { target in
                            Text(target.rawValue).tag(target)
                        }
                    }
                    .pickerStyle(.segmented)
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
