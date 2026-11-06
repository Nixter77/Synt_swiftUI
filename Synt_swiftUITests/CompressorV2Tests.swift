//
//  CompressorV2Tests.swift
//  SYNT_68: bus-glue compressor v2 — GR curve, no NaN, RT budget, flag-off invariance.
//

import Foundation
@testable import SynthCore
import Darwin
import Testing
@testable import Synt_swiftUI

@MainActor
struct CompressorV2Tests {
    @Test func busGlueProfileProducesGainReductionWithoutNaN() {
        let c = Compressor(sampleRate: 44_100)
        c.configureBusGlueProfile()
        #expect(c.enabled)
        #expect(abs(c.ratio - 2) < 0.001)
        #expect(c.attack >= 0.010 && c.attack <= 0.030)

        var maxGR: Float = 0
        var sawFinite = true
        // Hot tone above threshold
        for i in 0..<4_410 {
            let x = 0.8 * sin(2 * Float.pi * 440 * Float(i) / 44_100)
            let y = c.process(x)
            if !y.isFinite { sawFinite = false }
            maxGR = max(maxGR, c.currentGainReduction)
        }
        #expect(sawFinite)
        #expect(maxGR > 0.5, "expected measurable GR on a hot tone, got \(maxGR)")
        #expect(maxGR.isFinite)
    }

    @Test func softSignalBelowThresholdIsNearUnity() {
        let c = Compressor(sampleRate: 44_100)
        c.configureBusGlueProfile()
        var maxDiff: Float = 0
        for i in 0..<2_000 {
            let x = 0.02 * sin(2 * Float.pi * 220 * Float(i) / 44_100)
            let y = c.process(x)
            maxDiff = max(maxDiff, abs(y - x))
        }
        #expect(maxDiff < 0.002, "soft signal should pass near-unity, diff \(maxDiff)")
        #expect(c.currentGainReduction < 0.25)
    }

    @Test func limiterModeStillClampsFirstTransient() {
        let limiter = Compressor(sampleRate: 48_000)
        limiter.enabled = true
        limiter.limiterMode = true
        limiter.kneeWidth = 0.0
        limiter.setAttack(0.001)
        limiter.setRelease(0.080)
        let (left, right) = limiter.processStereo(inputL: 4.0, inputR: -4.0)
        #expect(abs(left) <= 1.0)
        #expect(abs(right) <= 1.0)
    }

    @Test func busGlueDisabledKeepsInitGoldenBitIdentical() {
        #expect(!SynthPreset.defaultPreset.busGlueEnabled)
        #expect(InitGoldenTests.renderHash(.defaultPreset) == 0xd1b3635203a4799e)
    }

    @Test func busGlueFlagWiresIntoRenderPath() {
        var loud = SynthPreset.factoryPresets.first { $0.name == "Wavetable Growl" }!
        loud.masterVolume = 1.0
        loud.busGlueEnabled = true
        let engine = AudioEngine()
        engine.preset = loud
        engine.applyPresetForTesting()
        #expect(engine.cachedBusGlueEnabled)
        #expect(engine.busGlueCompressor.enabled)
        engine.noteOn(midiNote: 60, velocity: 1)
        engine.processCommandsForTesting()
        var peak: Float = 0
        var maxGR: Float = 0
        for _ in 0..<8_820 {
            let (l, r) = engine.renderOneSample()
            peak = max(peak, max(abs(l), abs(r)))
            maxGR = max(maxGR, engine.busGlueCompressor.currentGainReduction)
        }
        #expect(peak.isFinite && peak > 0.01)
        #expect(maxGR > 0.1, "expected GR on hot Growl, got \(maxGR) peak \(peak)")
    }

    @Test func processStereoRTBudgetUnderOneRealtimeSlice() {
        let c = Compressor(sampleRate: 44_100)
        c.configureBusGlueProfile()
        let frames = 512
        let loops = 400
        // Warmup
        for i in 0..<frames {
            let x = 0.5 * sin(2 * Float.pi * Float(i) / Float(frames))
            _ = c.processStereo(inputL: x, inputR: -x)
        }
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let t0 = mach_absolute_time()
        for _ in 0..<loops {
            for i in 0..<frames {
                let x = 0.5 * sin(2 * Float.pi * Float(i) / Float(frames))
                _ = c.processStereo(inputL: x, inputR: -x)
            }
        }
        let t1 = mach_absolute_time()
        let nanos = Double(t1 - t0) * Double(info.numer) / Double(info.denom)
        let seconds = nanos / 1e9
        let realtime = Double(frames * loops) / 44_100.0
        let pct = 100.0 * seconds / realtime
        // Compressor alone must be trivial vs a 512-frame slice.
        #expect(pct < 10.0, "Compressor stereo RT \(pct)% of realtime")
        #expect(c.currentGainReduction.isFinite)
    }
}
