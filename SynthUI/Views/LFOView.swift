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

enum MSEGSnapMode: String, CaseIterable, Sendable {
    case off = "OFF"
    case div16 = "1/16"
    case div8 = "1/8"
    case div4 = "1/4"
    case step10 = "0.1"

    var step: Float? {
        switch self {
        case .off: return nil
        case .div16: return 0.0625
        case .div8: return 0.125
        case .div4: return 0.25
        case .step10: return 0.1
        }
    }
}

/// Writes `preset.mseg` and `preset.mseg2`. The engine publishes those off the render thread.
private struct MSEGPointEditor: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    @State private var selectedMSEG = 1
    @State private var selectedPoint = 0
    @State private var snapMode: MSEGSnapMode = .off

    private func getSpec() -> MSEGPreset {
        selectedMSEG == 1 ? preset.mseg : preset.mseg2
    }

    private func updateSpec(_ transform: (inout MSEGPreset) -> Void) {
        var spec = getSpec()
        transform(&spec)
        if selectedMSEG == 1 {
            preset.mseg = spec
        } else {
            preset.mseg2 = spec
        }
    }

    var body: some View {
        let spec = getSpec()
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                chip(selectedMSEG == 1 ? "[1]" : " 1 ", id: "msegSelect1") { selectedMSEG = 1 }
                chip(selectedMSEG == 2 ? "[2]" : " 2 ", id: "msegSelect2") { selectedMSEG = 2 }
                chip(selectedMSEG == 1 ? "1→2" : "2→1", id: "msegCopy") { copyMSEG() }
                chip("SNAP:\(snapMode.rawValue)", id: "msegSnap") { cycleSnap() }
            }
            HStack(spacing: 3) {
                chip("ADD", id: "msegAdd", action: addPoint)
                chip("DEL", id: "msegDelete", action: deletePoint)
                chip(spec.syncMode == .beats ? "BEAT" : "HZ", id: "msegSync", action: toggleSync)
                chip(spec.sustainIndex == nil ? "SUS" : "SUS*", id: "msegSustain", action: toggleSustain)
                chip(spec.loopStartIndex == nil ? "LOOP" : "LOOP*", id: "msegLoop", action: toggleLoop)
            }
            miniCurve(spec: spec)
            if spec.points.isEmpty {
                Text("No points")
                    .themeCaption(theme, size: 9)
                    .foregroundColor(theme.textDim)
            } else {
                Text("\(min(selectedPoint, spec.points.count - 1) + 1)/\(spec.points.count)")
                    .themeCaption(theme, size: 9)
                    .foregroundColor(theme.textDim)
                HStack(spacing: 4) {
                    if spec.syncMode == .beats {
                        KnobView(
                            value: syncBeatsBinding(),
                            range: 0.0625...32,
                            label: "Beats",
                            format: "%.2f"
                        )
                    } else {
                        KnobView(
                            value: rateHzBinding(),
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

    private func syncBeatsBinding() -> Binding<Float> {
        Binding(
            get: { getSpec().syncBeats },
            set: { val in updateSpec { $0.syncBeats = val } }
        )
    }

    private func rateHzBinding() -> Binding<Float> {
        Binding(
            get: { getSpec().rateHz },
            set: { val in updateSpec { $0.rateHz = val } }
        )
    }

    private func miniCurve(spec: MSEGPreset) -> some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(theme.scopeBg))

            let step = snapMode.step ?? 0.25
            var t: Float = step
            while t < 0.999 {
                let x = CGFloat(t) * size.width
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(theme.border.opacity(0.3)), lineWidth: 0.5)
                t += step
            }

            let pts = spec.points
            guard pts.count >= 2 else { return }
            let midY = size.height / 2.0
            var path = Path()
            let first = pts[0]
            let startY = midY - CGFloat(first.value) * (midY - 2)
            path.move(to: CGPoint(x: CGFloat(first.time) * size.width, y: startY))
            for i in 1..<pts.count {
                let pt = pts[i]
                let px = CGFloat(pt.time) * size.width
                let py = midY - CGFloat(pt.value) * (midY - 2)
                path.addLine(to: CGPoint(x: px, y: py))
            }
            context.stroke(path, with: .color(theme.aLFO), lineWidth: 1.5)

            for (idx, pt) in pts.enumerated() {
                let px = CGFloat(pt.time) * size.width
                let py = midY - CGFloat(pt.value) * (midY - 2)
                let rect = CGRect(x: px - 2, y: py - 2, width: 4, height: 4)
                let color = idx == selectedPoint ? Color.white : theme.aLFO
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }
        .frame(height: 24)
        .cornerRadius(3)
        .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.border, lineWidth: 0.5))
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

    private func copyMSEG() {
        if selectedMSEG == 1 {
            preset.mseg2 = preset.mseg
        } else {
            preset.mseg = preset.mseg2
        }
    }

    private func cycleSnap() {
        let all = MSEGSnapMode.allCases
        if let idx = all.firstIndex(of: snapMode) {
            snapMode = all[(idx + 1) % all.count]
        }
    }

    private func snappedTime(_ time: Float) -> Float {
        guard let step = snapMode.step else { return max(0, min(1, time)) }
        let snapped = (time / step).rounded() * step
        return max(0, min(1, snapped))
    }

    private func pointField(_ keyPath: WritableKeyPath<DSPMSEGPoint, Float>) -> Binding<Float> {
        Binding(
            get: {
                let points = getSpec().points
                guard !points.isEmpty else { return 0 }
                return points[min(selectedPoint, points.count - 1)][keyPath: keyPath]
            },
            set: { newValue in
                guard !getSpec().points.isEmpty else { return }
                let index = min(selectedPoint, getSpec().points.count - 1)
                if keyPath == \DSPMSEGPoint.time {
                    commitTime(index, newValue)
                } else {
                    updateSpec { $0.points[index][keyPath: keyPath] = newValue }
                }
            }
        )
    }

    private func commitTime(_ index: Int, _ time: Float) {
        let t = snappedTime(time)
        updateSpec { spec in
            guard spec.points.indices.contains(index) else { return }
            spec.points[index].time = t
            let order = spec.points.indices.sorted { spec.points[$0].time < spec.points[$1].time }
            spec.points = order.map { spec.points[$0] }
            spec.loopStartIndex = remap(spec.loopStartIndex, order: order)
            spec.loopEndIndex = remap(spec.loopEndIndex, order: order)
            spec.sustainIndex = remap(spec.sustainIndex, order: order)
            if let newIndex = order.firstIndex(of: index) {
                selectedPoint = newIndex
            }
        }
    }

    private func remap(_ index: Int?, order: [Int]) -> Int? {
        guard let index, let mapped = order.firstIndex(of: index) else { return nil }
        return mapped
    }

    private func addPoint() {
        updateSpec { spec in
            guard spec.points.count < DSPMSEGModel.maxPoints else { return }
            if spec.points.isEmpty {
                spec.points = [
                    DSPMSEGPoint(time: 0, value: 0),
                    DSPMSEGPoint(time: 1, value: 0)
                ]
                selectedPoint = 0
            } else {
                let lastTime = spec.points.last?.time ?? 0
                let rawTime = min(1, lastTime + 0.1)
                let time = snappedTime(rawTime)
                spec.points.append(DSPMSEGPoint(time: time, value: 0))
                spec.points.sort { $0.time < $1.time }
                selectedPoint = spec.points.count - 1
            }
        }
    }

    private func deletePoint() {
        updateSpec { spec in
            guard !spec.points.isEmpty else { return }
            let index = min(selectedPoint, spec.points.count - 1)
            spec.points.remove(at: index)
            spec.loopStartIndex = shift(spec.loopStartIndex, deleted: index)
            spec.loopEndIndex = shift(spec.loopEndIndex, deleted: index)
            spec.sustainIndex = shift(spec.sustainIndex, deleted: index)
            if spec.points.isEmpty {
                spec.loopStartIndex = nil
                spec.loopEndIndex = nil
                spec.sustainIndex = nil
            }
            selectedPoint = min(selectedPoint, max(0, spec.points.count - 1))
        }
    }

    private func shift(_ index: Int?, deleted: Int) -> Int? {
        guard let index else { return nil }
        if index == deleted { return nil }
        return index > deleted ? index - 1 : index
    }

    private func toggleSync() {
        updateSpec { spec in
            spec.syncMode = spec.syncMode == .hz ? .beats : .hz
        }
    }

    private func toggleSustain() {
        updateSpec { spec in
            if spec.sustainIndex == nil, spec.points.count >= 2 {
                spec.sustainIndex = spec.points.count / 2
            } else {
                spec.sustainIndex = nil
            }
        }
    }

    private func toggleLoop() {
        updateSpec { spec in
            if spec.loopStartIndex == nil, spec.points.count >= 2 {
                spec.loopStartIndex = 0
                spec.loopEndIndex = spec.points.count - 1
            } else {
                spec.loopStartIndex = nil
                spec.loopEndIndex = nil
            }
        }
    }
}

#Preview {
    LFOView(preset: .constant(.defaultPreset))
        .frame(width: 250).padding()
        .background(Theme.baseline.bg)
}
