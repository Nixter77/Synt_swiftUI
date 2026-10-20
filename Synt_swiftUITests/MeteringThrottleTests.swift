//
//  MeteringThrottleTests.swift
//  Level publishes stay at or under 31 in one simulated second.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct MeteringThrottleTests {

    @Test func levelPublishesStayAtOrUnderThirtyOnePerSecond() {
        let meters = AudioMeterModel()
        var publishes = 0
        for step in 0..<1_000 {
            let now = Double(step) * 0.001
            let level = Float(step) / 100
            if meters.ingest(output: level, peak: level, now: now) {
                publishes += 1
            }
        }
        #expect(publishes <= 31)
        #expect(publishes >= 29)
        #expect(meters.publishCount == publishes)
    }

    @Test func unchangedLevelsDoNotRepublish() {
        let meters = AudioMeterModel()
        #expect(meters.ingest(output: 0.4, peak: 0.4, now: 0))
        for step in 1..<50 {
            let published = meters.ingest(output: 0.40, peak: 0.405, now: Double(step) * 0.1)
            #expect(!published)
        }
        #expect(meters.publishCount == 1)
    }
}
