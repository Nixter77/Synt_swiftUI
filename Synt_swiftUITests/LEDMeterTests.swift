//
//  LEDMeterTests.swift
//  The LED bar follows the level; the peak is one held segment above it.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct LEDMeterTests {
    @Test func barFollowsLevelNotPeak() {
        let s = ledSegments(level: 0.1, peak: 1.0, count: 12)
        // 0.1 = −20 dB → 12 − 6.67 → 5 segments; peak 0 dB → top segment only.
        #expect(s.filled == 5)
        #expect(s.peakIndex == 11)
    }

    @Test func silenceAndFullScale() {
        #expect(ledSegments(level: 0, peak: 0, count: 12).filled == 0)
        #expect(ledSegments(level: 0, peak: 0, count: 12).peakIndex == nil)
        #expect(ledSegments(level: .nan, peak: .nan, count: 12).filled == 0)
        #expect(ledSegments(level: 1, peak: 1, count: 12).filled == 12)
        #expect(ledSegments(level: 1, peak: 1, count: 12).peakIndex == nil)
    }

    @Test func eachSegmentIsThreeDecibels() {
        let a = ledSegments(level: pow(10, -6.0 / 20), peak: 0, count: 12).filled
        let b = ledSegments(level: pow(10, -12.0 / 20), peak: 0, count: 12).filled
        #expect(a - b == 2)
    }
}
