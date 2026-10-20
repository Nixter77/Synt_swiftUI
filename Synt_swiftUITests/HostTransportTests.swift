//
//  HostTransportTests.swift
//  Plugin transport gates the arp. Standalone leaves the flag off.
//

import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct HostTransportTests {
    @Test func stoppedHostTransportDoesNotAdvanceTheArpClock() {
        let engine = AudioEngine()
        engine.usesHostTransport = true
        engine.hostTransportMoving = false
        engine.cachedArpMode = .up
        _ = engine.renderFramesForTesting(64)
        #expect(engine.clockPhase == 0)

        engine.hostTransportMoving = true
        _ = engine.renderFramesForTesting(64)
        #expect(engine.clockPhase == 64)
    }

    @Test func hostTempoReachesTheArpCacheWithoutWritingThePreset() {
        let engine = AudioEngine()
        let presetBPM = engine.preset.bpm
        engine.cachedLfoTempoSync = true
        engine.cachedLfoSyncDivision = .quarter
        engine.adoptHostContext(tempo: 140, transportMoving: true)
        #expect(engine.cachedBPM == 140)
        #expect(engine.preset.bpm == presetBPM)
        #expect(abs(engine.lfo.rate - TimeDivision.quarter.frequency(bpm: 140)) < 0.0001)
    }
}
