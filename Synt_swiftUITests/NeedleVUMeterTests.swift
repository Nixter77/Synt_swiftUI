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

    @Test func levelsAboveZeroDecibelsSitInTheRedZone() {
        #expect(!needleIsInRedZone(level: 0))
        #expect(!needleIsInRedZone(level: 1))
        #expect(needleAngle(level: 1) == needleZeroDB)
        #expect(needleIsInRedZone(level: 1.05))
        #expect(needleAngle(level: 1.2) > needleZeroDB)
        #expect(needleAngle(level: 4) == needleRightStop)
    }
}
