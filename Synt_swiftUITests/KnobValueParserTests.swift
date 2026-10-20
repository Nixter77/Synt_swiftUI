//
//  KnobValueParserTests.swift
//

import AppKit
import Foundation
import Testing
@testable import Synt_swiftUI

struct KnobValueParserTests {

    @Test func parsesNumbersUnitsAndClamps() {
        let hz: ClosedRange<Float> = 0...20000
        #expect(parsed("440", "%.0f", hz) == 440)
        #expect(parsed("440 Hz", "%.0fHz", hz) == 440)
        #expect(parsed("1.2k", "%.0f", hz) == 1200)
        #expect(parsed("1,5 kHz", "%.0fHz", hz) == 1500)
        #expect(parsed("250ms", "%.2fs", 0...2) == 0.25)
        #expect(parsed("-6 dB", "%.0fdB", -12...12) == -6)
        #expect(parsed("50%", "%.0f%%", 0...1) == 0.5)
        // Sustain / Swing show 0…100 without a % in the field: "50" is 50 %, not max.
        #expect(parsed("50", "%.0f%%", 0...1) == 0.5)
        #expect(parsed("0", "%.0f%%", 0...1) == 0)
        #expect(parsed("100", "%.0f%%", 0...1) == 1)
        #expect(parsed("0.5", "%.2f", 0...1) == 0.5)
        #expect(parsed("12ct", "%.0f ct", -50...50) == 12)
        #expect(parsed("-7 ct", "%.0f ct", -50...50) == -7)
        #expect(parsed("3st", "%.0f st", -24...24) == 3)
        #expect(KnobValueParser.editingText(value: 12, format: "%.0f ct", valueText: nil, range: -50...50) == "12 ct")
        #expect(parsed("999", "%.2f", 0...1) == 1)
        #expect(parsed("abc", "%.2f", 0...1) == nil)
        #expect(parsed("", "%.2f", 0...1) == nil)
        #expect(parsed("+0.5 oct", "%+.2f", -1...1) == 0.5)
    }

    @Test func escapeOnAKnobLeavesTheValueUnchanged() {
        let kept = KnobTyping.resolved(
            draft: "999",
            current: 0.4,
            format: "%.2f",
            range: 0...1,
            cancelled: true
        )
        #expect(kept.value == 0.4)
        #expect(kept.invalid == false)

        let garbage = KnobTyping.resolved(
            draft: "abc",
            current: 0.4,
            format: "%.2f",
            range: 0...1,
            cancelled: false
        )
        #expect(garbage.value == 0.4)
        #expect(garbage.invalid)
    }

    @Test @MainActor func keyboardHandlerIgnoresKeysWhileATextFieldIsFirstResponder() {
        #expect(KeyboardHandler.ignoresTyping(firstResponder: nil) == false)
        #expect(KeyboardHandler.ignoresTyping(firstResponder: NSView()) == false)
        #expect(KeyboardHandler.ignoresTyping(firstResponder: NSTextView()) == true)
        #expect(KeyboardHandler.ignoresTyping(firstResponder: NSTextField()) == true)
    }

    @Test func percentLabelRoundTripsAUnitKnob() {
        let shown = KnobValueParser.display(value: 0.7, format: "%.0f%%", valueText: nil, range: 0...1)
        #expect(shown == "70%")
        let draft = KnobValueParser.editingText(value: 0.7, format: "%.0f%%", valueText: nil, range: 0...1)
        #expect(parsed(draft, "%.0f%%", 0...1) == 0.7)
    }

    private func parsed(_ text: String, _ format: String, _ range: ClosedRange<Float>) -> Float? {
        KnobValueParser.parse(text, format: format, range: range)
    }
}
