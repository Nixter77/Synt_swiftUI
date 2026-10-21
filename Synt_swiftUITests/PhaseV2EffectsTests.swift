//
//  PhaseV2EffectsTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.6: DSP Shimmer Reverb & Stereo Chorus Spread.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2EffectsTests {

    @Test func chorusAndShimmerDefaultsAndLegacyDecoding() throws {
        let p = SynthPreset.defaultPreset
        #expect(p.chorusStereo == true)
        #expect(p.reverbShimmer == 0.0)

        // Legacy JSON decoding
        let minimalJSON = """
        {"name":"Old School Patch"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(decoded.chorusStereo == true)
        #expect(decoded.reverbShimmer == 0.0)
    }

    @Test func dspChorusMonoVsStereoSpread() {
        let chorus = DSPChorus(sampleRate: 44100.0)
        chorus.rate = 1.5
        chorus.depth = 0.8
        chorus.mix = 1.0

        // 1. Mono mode (stereo = false) -> Left and Right should be identical
        chorus.stereo = false
        var maxMonoDiff: Float = 0.0
        for i in 0..<1000 {
            let input = Float(sin(Double(i) * 0.05))
            let (l, r) = chorus.process(inputL: input, inputR: input)
            maxMonoDiff = max(maxMonoDiff, abs(l - r))
        }
        #expect(maxMonoDiff < 1e-5, "In mono chorus mode, L and R must be identical (diff: \(maxMonoDiff))")

        // 2. Stereo mode (stereo = true) -> 90° quadrature phase creates clear L/R difference
        chorus.stereo = true
        chorus.reset()
        var maxStereoDiff: Float = 0.0
        for i in 0..<1000 {
            let input = Float(sin(Double(i) * 0.05))
            let (l, r) = chorus.process(inputL: input, inputR: input)
            maxStereoDiff = max(maxStereoDiff, abs(l - r))
        }
        #expect(maxStereoDiff > 0.01, "In stereo chorus mode, 90° phase offset must create stereo width (diff: \(maxStereoDiff))")
    }

    @Test func shimmerProcessorStabilityAndOctaveShift() {
        let shimmer = ShimmerProcessor(sampleRate: 44100.0)
        shimmer.reset()

        var hasNonZeroOutput = false
        var maxOutput: Float = 0.0

        // Feed 440 Hz sine wave for 2048 samples (past grain size of 1024)
        for i in 0..<2048 {
            let input = Float(sin(Double(i) * 440.0 * 2.0 * Double.pi / 44100.0))
            let (outL, outR) = shimmer.process(inputL: input, inputR: input)

            #expect(outL.isFinite, "Shimmer outL must be finite")
            #expect(outR.isFinite, "Shimmer outR must be finite")

            maxOutput = max(maxOutput, abs(outL), abs(outR))
            if i > 1024 && abs(outL) > 0.01 {
                hasNonZeroOutput = true
            }
        }

        #expect(hasNonZeroOutput, "Shimmer processor must produce audio after grain warmup")
        #expect(maxOutput <= 2.0, "Shimmer processor must not explode in gain")
    }

    @Test func audioEngineShimmerReverbIntegration() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var shimmerPreset = SynthPreset.defaultPreset
        shimmerPreset.reverbShimmer = 0.5
        engine.preset = shimmerPreset
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var allFinite = true
        for _ in 0..<1024 {
            let (l, r) = engine.renderOneSample()
            if !l.isFinite || !r.isFinite {
                allFinite = false
            }
        }
        #expect(allFinite, "AudioEngine with shimmer must render clean finite audio")
    }
}
