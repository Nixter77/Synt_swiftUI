//
//  LayoutTests.swift
//  Init control grid at the width it has inside a 1000 pt window.
//

import AppKit
@testable import SynthCore
import SwiftUI
import Testing
@testable import Synt_swiftUI

@MainActor
struct LayoutTests {

    private static let collapseKeys = [
        "fx.collapsed.distortion",
        "fx.collapsed.eq",
        "fx.collapsed.phaser",
        "fx.collapsed.chorus",
        "fx.collapsed.delay",
        "fx.collapsed.reverb",
    ]

    /// Width of the grid inside a 1000 pt window: 16 pt scroll padding on each side.
    private static let contentWidth: CGFloat = 968

    @Test func controlsSectionFitsInitInEveryTheme() {
        clearCollapse()
        defer { clearCollapse() }

        let engine = AudioEngine()
        var report: [String] = []
        for id in ThemeID.allCases {
            let theme = Theme.all[id]
            let size = measure(
                SynthControlGrid(audioEngine: engine).frame(width: Self.contentWidth),
                theme: theme,
                width: Self.contentWidth
            )
            let sources = measure(SourceColumnProbe(engine: engine), theme: theme, width: 280).height
            let shape = measure(ShapeColumnProbe(engine: engine), theme: theme, width: 280).height
            let mod = measure(ModColumnProbe(engine: engine), theme: theme, width: 200).height
            let fx = measure(FXColumnProbe(engine: engine), theme: theme, width: 200).height
            report.append("\(id.rawValue) \(size.width)x\(size.height) src \(sources) shape \(shape) mod \(mod) fx \(fx)")
            #expect(size.height <= 520, "\(id.rawValue) controlsSection \(size.height) pt, was 893")
            #expect(size.height > 80, "\(id.rawValue) controlsSection \(size.height) pt did not lay out")
            #expect(size.width <= Self.contentWidth + 1, "\(id.rawValue) grid width \(size.width) overflows \(Self.contentWidth)")
        }
        let line = "LAYOUT_AFTER " + report.joined(separator: " ") + "\n"
        try? line.write(toFile: "/tmp/layout-after.txt", atomically: true, encoding: .utf8)
    }

    /// Many rows scroll inside a bounded box instead of growing the column.
    @Test func longModMatrixScrollsWithinItsBudget() {
        var preset = SynthPreset.defaultPreset
        preset.modMatrix = (0..<8).map { _ in
            ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.3)
        }
        for id in ThemeID.allCases {
            let height = measure(
                ModMatrixView(preset: .constant(preset)),
                theme: Theme.all[id],
                width: 200
            ).height
            #expect(height <= modMatrixScrollMaxHeight + 80, "\(id.rawValue) matrix \(height) pt")
        }
        #expect(modMatrixScrollMaxHeight < 470)
    }

    /// The pickers own the first line and the knob the second, so in the
    /// 140 pt column the knob line alone must fit; the menus can flex.
    @Test func matrixRowKnobLineFitsTheNarrowColumn() {
        var preset = SynthPreset.defaultPreset
        preset.modMatrix = [ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.3)]
        let one = measure(ModMatrixView(preset: .constant(preset)), theme: .baseline, width: 140)
        preset.modMatrix = []
        let none = measure(ModMatrixView(preset: .constant(preset)), theme: .baseline, width: 140)
        // Two lines (menus ~22 pt + knob ≥ 50 pt) per row.
        #expect(one.height - none.height >= 72, "row adds \(one.height - none.height) pt")
        let knobLine = measure(
            HStack(spacing: 6) {
                KnobView(value: .constant(0.3), range: -1...1, label: "Amt", valueText: "+30 %")
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                Image(systemName: "trash").font(.system(size: 10))
            },
            theme: .baseline,
            width: 140
        )
        #expect(knobLine.width + 12 <= 140, "knob line \(knobLine.width) pt")
    }

    @Test func knobStaysAtLeast50Points() {
        let size = measure(
            KnobView(value: .constant(0.4), range: 0...1, label: "Vol"),
            theme: .baseline,
            width: 120
        )
        #expect(size.width >= 50, "knob width \(size.width)")
        #expect(size.height >= 50, "knob height \(size.height)")
    }

    private func measure<V: View>(_ view: V, theme: Theme, width: CGFloat) -> CGSize {
        let host = NSHostingView(rootView: view.environment(\.theme, theme))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 2400)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    private func clearCollapse() {
        for key in Self.collapseKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

private struct SourceColumnProbe: View {
    @ObservedObject var engine: AudioEngine
    var body: some View {
        VStack(spacing: 10) {
            OscillatorView(preset: $engine.preset, oscillatorNumber: 1, audioEngine: engine)
            OscillatorView(preset: $engine.preset, oscillatorNumber: 2, audioEngine: engine)
        }
    }
}

private struct ShapeColumnProbe: View {
    @ObservedObject var engine: AudioEngine
    var body: some View {
        VStack(spacing: 10) {
            ADSRView(preset: $engine.preset)
            FilterView(preset: $engine.preset)
            UnisonView(preset: $engine.preset)
        }
    }
}

private struct ModColumnProbe: View {
    @ObservedObject var engine: AudioEngine
    var body: some View {
        VStack(spacing: 10) {
            LFOView(preset: $engine.preset)
            ModMatrixView(preset: $engine.preset)
        }
    }
}

private struct FXColumnProbe: View {
    @ObservedObject var engine: AudioEngine
    var body: some View {
        VStack(spacing: 10) {
            AdvancedEffectsView(preset: $engine.preset)
            EffectsView(preset: $engine.preset)
        }
    }
}
