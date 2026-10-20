//
//  StepperFieldTests.swift
//

import AppKit
@testable import SynthCore
import SwiftUI
import Testing
@testable import Synt_swiftUI

struct StepperFieldTests {

    @Test func clampsToOneThroughSeven() {
        #expect(StepperMath.stepped(1, by: -1, in: 1...7) == 1)
        #expect(StepperMath.stepped(7, by: 1, in: 1...7) == 7)
        #expect(StepperMath.stepped(3, by: 1, in: 1...7) == 4)
        #expect(StepperMath.stepped(3, by: -1, in: 1...7) == 2)
        #expect(StepperMath.clamped(0, to: 1...7) == 1)
        #expect(StepperMath.clamped(9, to: 1...7) == 7)
        #expect(StepperMath.parse("4") == 4)
        #expect(StepperMath.parse(" 6 ") == 6)
        #expect(StepperMath.parse("") == nil)
        #expect(StepperMath.parse("abc") == nil)
    }

    @Test @MainActor func voiceCountIsNotClippedAtColumnWidth() {
        for id in ThemeID.allCases {
            var preset = SynthPreset.defaultPreset
            preset.unisonVoices = 7
            let theme = Theme.all[id]
            let glyph = measure(
                Text("7").font(theme.valueFont(size: 13)).fixedSize(),
                theme: theme,
                width: 80
            ).width
            let box = WidthBox()
            let host = NSHostingView(
                rootView: UnisonWidthProbe(preset: preset, theme: theme, box: box)
            )
            host.frame = NSRect(x: 0, y: 0, width: 220, height: 320)
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            let width = box.width
            #expect(width + 0.5 >= glyph, "\(id.rawValue) voices width \(width) < glyph \(glyph)")
            #expect(width >= 28, "\(id.rawValue) voices field \(width) pt")
        }
    }

    @MainActor
    private func measure<V: View>(_ view: V, theme: Theme, width: CGFloat) -> CGSize {
        let host = NSHostingView(rootView: view.environment(\.theme, theme))
        host.frame = NSRect(x: 0, y: 0, width: width, height: 80)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }
}

private final class WidthBox {
    var width: CGFloat = 0
}

private struct UnisonWidthProbe: View {
    var preset: SynthPreset
    var theme: Theme
    var box: WidthBox

    var body: some View {
        UnisonView(preset: .constant(preset))
            .environment(\.theme, theme)
            .frame(width: 220)
            .onPreferenceChange(StepperValueWidthKey.self) { box.width = $0 }
    }
}
