//
//  LFOView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

struct LFOView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    @State private var selectedLFO: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppleSectionHeader(title: "LFO", accent: theme.aLFO, icon: "waveform.path")
                Spacer()
                ThemeSegmented(
                    options: [(1, "1"), (2, "2")],
                    selection: $selectedLFO,
                    accent: theme.aLFO
                )
                .frame(width: 52)
                ThemeToggle(isOn: selectedLFO == 1 ? $preset.lfoEnabled : $preset.lfo2Enabled)
            }

            let isEnabled = selectedLFO == 1 ? preset.lfoEnabled : preset.lfo2Enabled
            if isEnabled {
                VStack(spacing: 6) {
                    HStack {
                        Text("Wave")
                            .themeCaption(theme, size: 10)
                            .foregroundColor(theme.textDim)
                        Spacer()
                    }
                    if selectedLFO == 1 {
                        WaveformPicker(selected: $preset.lfoWaveform, accent: theme.aLFO)
                    } else {
                        WaveformPicker(selected: $preset.lfo2Waveform, accent: theme.aLFO)
                    }

                    HStack {
                        Text("Target")
                            .themeCaption(theme, size: 10)
                            .foregroundColor(theme.textDim)
                        Spacer()
                        Button {
                            if selectedLFO == 1 {
                                preset.lfoTempoSync.toggle()
                            } else {
                                preset.lfo2TempoSync.toggle()
                            }
                        } label: {
                            let synced = selectedLFO == 1 ? preset.lfoTempoSync : preset.lfo2TempoSync
                            Text("SYNC")
                                .font(.system(size: 8, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(synced ? theme.aLFO : Color.clear)
                                .foregroundColor(synced ? .black : theme.textDim)
                                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aLFO.opacity(0.6), lineWidth: 1))
                                .cornerRadius(3)
                        }
                        .buttonStyle(.plain)
                    }
                    if selectedLFO == 1 {
                        ThemeSegmented(
                            options: LFOTarget.allCases.map { (value: $0, title: $0.rawValue) },
                            selection: $preset.lfoTarget,
                            accent: theme.aLFO
                        )
                    } else {
                        ThemeSegmented(
                            options: LFOTarget.allCases.map { (value: $0, title: $0.rawValue) },
                            selection: $preset.lfo2Target,
                            accent: theme.aLFO
                        )
                    }

                    HStack(spacing: 8) {
                        if selectedLFO == 1 {
                            if preset.lfoTempoSync {
                                VStack(spacing: 2) {
                                    Menu {
                                        ForEach(TimeDivision.allCases, id: \.self) { div in
                                            Button(div.rawValue) { preset.lfoSyncDivision = div }
                                        }
                                    } label: {
                                        Text(preset.lfoSyncDivision.rawValue)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(theme.aLFO)
                                            .frame(width: 50, height: 26)
                                            .background(theme.card)
                                            .cornerRadius(4)
                                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.aLFO.opacity(0.5), lineWidth: 1))
                                    }
                                    .menuStyle(.borderlessButton)
                                    Text("Sync")
                                        .themeCaption(theme, size: 9)
                                        .foregroundColor(theme.textDim)
                                }
                                .frame(width: 50, height: 50)
                            } else {
                                KnobView(
                                    value: $preset.lfoRate,
                                    range: 0.1...20,
                                    label: "Rate",
                                    format: "%.1f Hz",
                                    modulated: modSources(.lfoRate, in: preset.modMatrix)
                                )
                            }
                            KnobView(
                                value: $preset.lfoDepth,
                                range: 0...1,
                                label: "Depth",
                                modulated: modSources(.lfoDepth, in: preset.modMatrix)
                            )
                        } else {
                            if preset.lfo2TempoSync {
                                VStack(spacing: 2) {
                                    Menu {
                                        ForEach(TimeDivision.allCases, id: \.self) { div in
                                            Button(div.rawValue) { preset.lfo2SyncDivision = div }
                                        }
                                    } label: {
                                        Text(preset.lfo2SyncDivision.rawValue)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(theme.aLFO)
                                            .frame(width: 50, height: 26)
                                            .background(theme.card)
                                            .cornerRadius(4)
                                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.aLFO.opacity(0.5), lineWidth: 1))
                                    }
                                    .menuStyle(.borderlessButton)
                                    Text("Sync")
                                        .themeCaption(theme, size: 9)
                                        .foregroundColor(theme.textDim)
                                }
                                .frame(width: 50, height: 50)
                            } else {
                                KnobView(
                                    value: $preset.lfo2Rate,
                                    range: 0.1...20,
                                    label: "Rate",
                                    format: "%.1f Hz"
                                )
                            }
                            KnobView(
                                value: $preset.lfo2Depth,
                                range: 0...1,
                                label: "Depth"
                            )
                        }
                    }
                }
            }
        }
        .padding(8)
        .appleCard(accent: theme.aLFO)
    }
}

#Preview {
    LFOView(preset: .constant(.defaultPreset))
        .frame(width: 250).padding()
        .background(Theme.baseline.bg)
}
