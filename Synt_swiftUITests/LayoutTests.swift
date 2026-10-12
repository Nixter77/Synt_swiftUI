//
//  LayoutTests.swift
//  Init control grid at the width it has inside a 1000 pt window.
//

import AppKit
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
            AdvancedEffectsView(audioEngine: engine)
            EffectsView(preset: $engine.preset)
        }
    }
}
