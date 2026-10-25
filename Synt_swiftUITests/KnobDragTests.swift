//
//  KnobDragTests.swift
//  Knob drag is linear from the grab point; no acceleration.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct KnobDragTests {
    @Test func dragIsLinearFromTheStartValue() {
        let r: ClosedRange<Float> = 0...1
        // Many small events of a cumulative translation land where one event would.
        var v: Float = 0.2
        for y in stride(from: 0.0, through: -30.0, by: -1.0) {
            v = knobDragValue(start: 0.2, translationY: CGFloat(y), range: r)
        }
        #expect(abs(v - 0.4) < 1e-5)
        #expect(abs(knobDragValue(start: 0.2, translationY: -30, range: r) - 0.4) < 1e-5)
    }

    @Test func dragClampsToRange() {
        #expect(knobDragValue(start: 0.9, translationY: -300, range: 0...1) == 1)
        #expect(knobDragValue(start: 100, translationY: 1000, range: 20...20000) == 20)
    }
}
