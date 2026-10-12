//
//  NeedleVUMeterTests.swift
//  The retro needle is a pure function of the mono level.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct NeedleVUMeterTests {

    @Test func angleParksAtSilenceAndRises() {
        #expect(needleAngle(level: 0) == needleLeftStop)
        #expect(needleAngle(level: .nan) == needleLeftStop)
        #expect(needleAngle(level: -.infinity) == needleLeftStop)
        #expect(needleAngle(level: -1) == needleLeftStop)

        var previous = needleAngle(level: 0)
        for step in 1...20 {
            let angle = needleAngle(level: Float(step) / 10)
            #expect(angle >= previous)
            previous = angle
        }
    }

    /// The engine level is 0…1, so the red zone must be inside that range.
    @Test func redZoneIsReachableWithinTheRealLevelRange() {
        #expect(!needleIsInRedZone(level: 0))
        #expect(!needleIsInRedZone(level: 0.4))
        #expect(abs(needleAngle(level: needleReferenceLevel) - needleZeroDB) < 1e-9)
        #expect(needleIsInRedZone(level: 0.6))
        #expect(needleIsInRedZone(level: 1))
        #expect(needleAngle(level: 1) == needleRightStop)
    }

    @Test func scaleIsDecibelNotLinear() {
        // −20 VU (level 0.05) is the left stop; −10 VU sits well up the arc.
        #expect(abs(needleAngle(level: 0.05) - needleLeftStop) < 1e-6)
        let minus10 = needleAngle(level: 0.5 * pow(10, -10.0 / 20.0))
        #expect(abs(minus10 - angleForVU(-10)) < 1e-6)
        #expect(minus10 > needleLeftStop + 30)
    }

    @Test func peakLampTracksTheCeiling() {
        #expect(!needlePeakLampLit(peak: 0.9))
        #expect(needlePeakLampLit(peak: 0.99))
        #expect(!needlePeakLampLit(peak: .nan))
    }
}
