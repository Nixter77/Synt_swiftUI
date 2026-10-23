//
//  SynthControlGrid.swift
//  The main-screen columns. Each panel owns a rectangle. Rectangles do not overlap.
//

import SwiftUI
import SynthCore

/// Filled by layout. Tests read the rectangles the grid actually placed.
final class PanelFrameRecorder {
    var frames: [String: CGRect] = [:]
}

/// Four columns. Standalone passes the engine. The plugin passes a preset binding.
struct SynthControlGrid: View {
    private var preset: Binding<SynthPreset>
    private var audioEngine: AudioEngine?
    var layout: PluginLayout
    var recorder: PanelFrameRecorder?

    init(audioEngine: AudioEngine, layout: PluginLayout = .compact, recorder: PanelFrameRecorder? = nil) {
        self.audioEngine = audioEngine
        self.preset = Binding(
            get: { audioEngine.preset },
            set: { audioEngine.preset = $0 }
        )
        self.layout = layout
        self.recorder = recorder
    }

    init(preset: Binding<SynthPreset>, layout: PluginLayout = .compact, recorder: PanelFrameRecorder? = nil) {
        self.preset = preset
        self.audioEngine = nil
        self.layout = layout
        self.recorder = recorder
    }

    var body: some View {
        injected(gridColumns)
    }

    private var gridColumns: some View {
        PluginColumnLayout(layout: layout, recorder: recorder) {
            panel("osc1") {
                OscillatorView(preset: preset, oscillatorNumber: 1, audioEngine: audioEngine)
            }
            panel("osc2") {
                OscillatorView(preset: preset, oscillatorNumber: 2, audioEngine: audioEngine)
            }
            panel("adsr") {
                ADSRView(preset: preset)
            }
            panel("filter") {
                FilterView(preset: preset)
            }
            panel("unison") {
                UnisonView(preset: preset, controllerMasterBendRange: audioEngine?.controllerMasterPitchBendRange)
            }
            panel("lfo") {
                LFOView(preset: preset)
            }
            panel("matrix") {
                ModMatrixView(preset: preset)
            }
            panel("fx") {
                FXChainView(preset: preset, audioEngine: audioEngine)
            }
        }
        .accessibilityIdentifier("controlsSection")
    }

    @ViewBuilder
    private func injected<V: View>(_ grid: V) -> some View {
        if let snapshot = audioEngine?.liveModulation {
            grid.environment(\.liveModulation, snapshot)
        } else {
            grid
        }
    }

    private func panel<V: View>(_ id: String, @ViewBuilder content: () -> V) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
            .accessibilityIdentifier("panel.\(id)")
    }
}

/// Places the eight panels in four columns. Column widths sum to the bounds.
struct PluginColumnLayout: Layout {
    var layout: PluginLayout
    var recorder: PanelFrameRecorder?

    private static let ids = AUPluginMetrics.panelIDs
    private static let columns: [[Int]] = [[0, 1], [2, 3, 4], [5, 6], [7]]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? AUPluginMetrics.compactWidth
        let natural = naturalHeight(width: width, subviews: subviews)
        let cap = layout == .compact ? AUPluginMetrics.compactHeight : AUPluginMetrics.extendedHeight
        let height: CGFloat
        if let proposed = proposal.height, proposed.isFinite, proposed < natural {
            height = proposed
        } else {
            height = min(natural, cap)
        }
        return CGSize(width: width, height: max(1, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let widths = AUPluginMetrics.columnWidths(total: bounds.width, layout: layout)
        let spacing = AUPluginMetrics.panelSpacing
        var x = bounds.minX
        var recorded: [String: CGRect] = [:]
        for (column, group) in Self.columns.enumerated() {
            let columnWidth = widths[column]
            var ideals: [CGFloat] = []
            for index in group where index < subviews.count {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
                ideals.append(max(0, size.height))
            }
            let gaps = spacing * CGFloat(max(0, ideals.count - 1))
            let idealSum = ideals.reduce(0, +) + gaps
            let compress = idealSum > bounds.height + 0.5
            let innerH = max(0, bounds.height - gaps)
            let weight = ideals.reduce(0, +)
            var y = bounds.minY
            var used: CGFloat = 0
            for (row, index) in group.enumerated() where index < subviews.count {
                let height: CGFloat
                if !compress {
                    height = ideals[row]
                } else if row == ideals.count - 1 {
                    height = max(0, innerH - used)
                } else if weight > 0 {
                    height = floor(innerH * ideals[row] / weight)
                    used += height
                } else {
                    height = floor(innerH / CGFloat(ideals.count))
                    used += height
                }
                let origin = CGPoint(x: x, y: y)
                subviews[index].place(
                    at: origin,
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: columnWidth, height: height)
                )
                recorded[Self.ids[index]] = CGRect(
                    x: x - bounds.minX,
                    y: y - bounds.minY,
                    width: columnWidth,
                    height: height
                )
                y += height + spacing
            }
            x += columnWidth + spacing
        }
        recorder?.frames = recorded
    }

    private func naturalHeight(width: CGFloat, subviews: Subviews) -> CGFloat {
        let widths = AUPluginMetrics.columnWidths(total: width, layout: layout)
        let spacing = AUPluginMetrics.panelSpacing
        var tallest: CGFloat = 0
        for (column, group) in Self.columns.enumerated() {
            var height: CGFloat = 0
            var counted = 0
            for index in group where index < subviews.count {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: widths[column], height: nil))
                height += max(0, size.height)
                counted += 1
            }
            if counted > 1 { height += spacing * CGFloat(counted - 1) }
            tallest = max(tallest, height)
        }
        return tallest
    }
}
