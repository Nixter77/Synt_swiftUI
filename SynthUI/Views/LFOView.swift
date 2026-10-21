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
    /// Collapsed so the mod column keeps its height. The editor writes preset fields only.
    @State private var showsMSEG = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppleSectionHeader(title: "LFO", accent: theme.aLFO, icon: "waveform.path")
                Button {
                    showsMSEG.toggle()
                } label: {
                    Text("MSEG")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(showsMSEG ? theme.aLFO : Color.clear)
                        .foregroundColor(showsMSEG ? .black : theme.textDim)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aLFO.opacity(0.6), lineWidth: 1))
                        .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("msegEditor")
                .help("MSEG 1")
                Spacer()
                ThemeSegmented(
                    options: [(1, "1"), (2, "2")],
                    selection: $selectedLFO,
                    accent: theme.aLFO
                )
                .frame(width: 52)
                ThemeToggle(isOn: selectedLFO == 1 ? $preset.lfoEnabled : $preset.lfo2Enabled)
            }

            if showsMSEG {
                MSEGPointEditor(preset: $preset)
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
                                    modulated: modSources(.lfoRate, in: preset.modMatrix),
                                    modulationAmount: modAmount(.lfoRate, in: preset.modMatrix)
                                )
                            }
                            KnobView(
                                value: $preset.lfoDepth,
                                range: 0...1,
                                label: "Depth",
                                modulated: modSources(.lfoDepth, in: preset.modMatrix),
                                modulationAmount: modAmount(.lfoDepth, in: preset.modMatrix)
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

/// Writes `preset.mseg` only. The engine publishes that struct off the render thread.
private struct MSEGPointEditor: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    @State private var selected = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                chip("ADD", id: "msegAdd", action: addPoint)
                chip("DEL", id: "msegDelete", action: deletePoint)
                chip(preset.mseg.syncMode == .beats ? "BEAT" : "HZ", id: "msegSync", action: toggleSync)
                chip(preset.mseg.sustainIndex == nil ? "SUS" : "SUS*", id: "msegSustain", action: toggleSustain)
                chip(preset.mseg.loopStartIndex == nil ? "LOOP" : "LOOP*", id: "msegLoop", action: toggleLoop)
            }
            if preset.mseg.points.isEmpty {
                Text("No points")
                    .themeCaption(theme, size: 9)
                    .foregroundColor(theme.textDim)
            } else {
                Text("\(min(selected, preset.mseg.points.count - 1) + 1)/\(preset.mseg.points.count)")
                    .themeCaption(theme, size: 9)
                    .foregroundColor(theme.textDim)
                HStack(spacing: 4) {
                    if preset.mseg.syncMode == .beats {
                        KnobView(
                            value: $preset.mseg.syncBeats,
                            range: 0.0625...32,
                            label: "Beats",
                            format: "%.2f"
                        )
                    } else {
                        KnobView(
                            value: $preset.mseg.rateHz,
                            range: 0.05...20,
                            label: "Hz",
                            format: "%.2f"
                        )
                    }
                    KnobView(value: pointField(\.time), range: 0...1, label: "T", format: "%.2f")
                    KnobView(value: pointField(\.value), range: -1...1, label: "V", format: "%.2f")
                    KnobView(value: pointField(\.curve), range: -1...1, label: "C", format: "%.2f")
                }
            }
        }
    }

    private func chip(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .foregroundColor(theme.textDim)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aLFO.opacity(0.6), lineWidth: 1))
                .cornerRadius(3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private func pointField(_ keyPath: WritableKeyPath<DSPMSEGPoint, Float>) -> Binding<Float> {
        Binding(
            get: {
                let points = preset.mseg.points
                guard !points.isEmpty else { return 0 }
                return points[min(selected, points.count - 1)][keyPath: keyPath]
            },
            set: { newValue in
                guard !preset.mseg.points.isEmpty else { return }
                let index = min(selected, preset.mseg.points.count - 1)
                if keyPath == \DSPMSEGPoint.time {
                    commitTime(index, newValue)
                } else {
                    preset.mseg.points[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func commitTime(_ index: Int, _ time: Float) {
        var spec = preset.mseg
        guard spec.points.indices.contains(index) else { return }
        spec.points[index].time = max(0, min(1, time))
        let order = spec.points.indices.sorted { spec.points[$0].time < spec.points[$1].time }
        spec.points = order.map { spec.points[$0] }
        spec.loopStartIndex = remap(spec.loopStartIndex, order: order)
        spec.loopEndIndex = remap(spec.loopEndIndex, order: order)
        spec.sustainIndex = remap(spec.sustainIndex, order: order)
        preset.mseg = spec
        if let newIndex = order.firstIndex(of: index) {
            selected = newIndex
        }
    }

    private func remap(_ index: Int?, order: [Int]) -> Int? {
        guard let index, let mapped = order.firstIndex(of: index) else { return nil }
        return mapped
    }

    private func addPoint() {
        var spec = preset.mseg
        guard spec.points.count < DSPMSEGModel.maxPoints else { return }
        if spec.points.isEmpty {
            spec.points = [
                DSPMSEGPoint(time: 0, value: 0),
                DSPMSEGPoint(time: 1, value: 0)
            ]
            selected = 0
        } else {
            let time = min(1, (spec.points.last?.time ?? 0) + 0.1)
            spec.points.append(DSPMSEGPoint(time: time, value: 0))
            spec.points.sort { $0.time < $1.time }
            selected = spec.points.count - 1
        }
        preset.mseg = spec
    }

    private func deletePoint() {
        var spec = preset.mseg
        guard !spec.points.isEmpty else { return }
        let index = min(selected, spec.points.count - 1)
        spec.points.remove(at: index)
        spec.loopStartIndex = shift(spec.loopStartIndex, deleted: index)
        spec.loopEndIndex = shift(spec.loopEndIndex, deleted: index)
        spec.sustainIndex = shift(spec.sustainIndex, deleted: index)
        if spec.points.isEmpty {
            spec.loopStartIndex = nil
            spec.loopEndIndex = nil
            spec.sustainIndex = nil
        }
        preset.mseg = spec
        selected = min(selected, max(0, spec.points.count - 1))
    }

    private func shift(_ index: Int?, deleted: Int) -> Int? {
        guard let index else { return nil }
        if index == deleted { return nil }
        return index > deleted ? index - 1 : index
    }

    private func toggleSync() {
        preset.mseg.syncMode = preset.mseg.syncMode == .hz ? .beats : .hz
    }

    private func toggleSustain() {
        var spec = preset.mseg
        if spec.sustainIndex == nil, spec.points.count >= 2 {
            spec.sustainIndex = spec.points.count / 2
        } else {
            spec.sustainIndex = nil
        }
        preset.mseg = spec
    }

    private func toggleLoop() {
        var spec = preset.mseg
        if spec.loopStartIndex == nil, spec.points.count >= 2 {
            spec.loopStartIndex = 0
            spec.loopEndIndex = spec.points.count - 1
        } else {
            spec.loopStartIndex = nil
            spec.loopEndIndex = nil
        }
        preset.mseg = spec
    }
}

#Preview {
    LFOView(preset: .constant(.defaultPreset))
        .frame(width: 250).padding()
        .background(Theme.baseline.bg)
}
