//
//  DSPFormantFilterTests.swift
//  Synt_swiftUITests
//
//  Stage 1: Formant filter tests (peaks in spectrum, stability at all morph values, 10s white noise).
//

import Testing
import Foundation
@testable import SynthCore

@MainActor
@Suite struct DSPFormantFilterTests {

    @Test func formantPeakInSpectrum() {
        let sampleRate: Double = 44100.0
        let filter = DSPFormantFilter(sampleRate: sampleRate)
        filter.vowel = 0.0 // 'A', F1 ~ 800 Hz
        filter.q = 8.0
        filter.resonance = 0.6
        filter.mix = 1.0

        // Test frequency response at 800 Hz (F1 peak) vs 200 Hz (deep dip before F1)
        func measureGain(freq: Float) -> Float {
            filter.reset()
            let n = 2048
            var sumSquare: Float = 0
            for i in 0..<n {
                let phase = 2.0 * Float.pi * freq * Float(i) / Float(sampleRate)
                let x = sin(phase)
                let y = filter.process(x)
                if i >= 512 { // steady-state
                    sumSquare += y * y
                }
            }
            return sqrt(sumSquare / Float(n - 512))
        }

        let gainAtPeak = measureGain(freq: 800.0)
        let gainAtDip = measureGain(freq: 200.0)

        #expect(gainAtPeak > gainAtDip * 3.0, "Formant peak at 800Hz (\(gainAtPeak)) must be noticeably stronger than at 200Hz dip (\(gainAtDip))")
    }

    @Test func stableAtAllMorphValues() {
        let sampleRate: Double = 44100.0
        let filter = DSPFormantFilter(sampleRate: sampleRate)
        filter.resonance = 0.95
        filter.q = 15.0

        // Sweep morph from -0.5 to 4.5 in fine increments
        var morph: Float = -0.5
        while morph <= 4.5 {
            filter.vowel = morph
            for _ in 0..<100 {
                let x: Float = Float.random(in: -1.0...1.0)
                let y = filter.process(x)
                #expect(y.isFinite, "Output must be finite for morph \(morph)")
                #expect(abs(y) <= 12.0, "Output must be bounded within rails")
            }
            morph += 0.1
        }
    }

    @Test func finiteOutputWithWhiteNoiseFor10Seconds() {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * 10.0) // 10 seconds = 441,000 samples
        let filter = DSPFormantFilter(sampleRate: sampleRate)

        // Pseudo-random xorshift32 for deterministic fast noise
        var rng: UInt32 = 0x12345678
        func nextNoise() -> Float {
            rng ^= (rng << 13)
            rng ^= (rng >> 17)
            rng ^= (rng << 5)
            return (Float(rng) / Float(UInt32.max)) * 2.0 - 1.0
        }

        filter.resonance = 0.9
        filter.q = 10.0

        var hasNonZero = false
        for i in 0..<totalSamples {
            // Continuously modulate morph across the 10 seconds
            if i % 1000 == 0 {
                let progress = Float(i) / Float(totalSamples)
                filter.vowel = progress * 4.0
            }

            let input = nextNoise()
            let output = filter.process(input)

            #expect(output.isFinite, "Output must be finite at sample \(i)")
            #expect(!output.isNaN, "Output must not be NaN at sample \(i)")
            #expect(abs(output) <= 12.0, "Output must remain within safe rails at sample \(i)")

            if abs(output) > 1.0e-4 {
                hasNonZero = true
            }
        }

        #expect(hasNonZero, "Filter must produce non-silent output with white noise")
    }

    @Test func stereoProcessingAndReset() {
        let filter = DSPFormantFilter(sampleRate: 44100.0)
        filter.vowel = 1.0 // 'E'
        let (outL, outR) = filter.process(inputL: 0.5, inputR: -0.5)
        #expect(outL.isFinite)
        #expect(outR.isFinite)
        #expect(outL > 0)
        #expect(outR < 0)

        filter.reset()
        let (zeroL, zeroR) = filter.process(inputL: 0.0, inputR: 0.0)
        #expect(abs(zeroL) < 1.0e-5)
        #expect(abs(zeroR) < 1.0e-5)
    }

    @Test func blockProcessingMatchesSampleProcessing() {
        let sampleRate: Double = 44100.0
        let frameCount = 256

        let filter1 = DSPFormantFilter(sampleRate: sampleRate)
        let filter2 = DSPFormantFilter(sampleRate: sampleRate)
        filter1.vowel = 2.3
        filter2.vowel = 2.3

        var inL = (0..<frameCount).map { sin(Float($0) * 0.1) }
        var inR = (0..<frameCount).map { cos(Float($0) * 0.1) }

        var expectedL = [Float](repeating: 0, count: frameCount)
        var expectedR = [Float](repeating: 0, count: frameCount)

        for i in 0..<frameCount {
            let (l, r) = filter1.process(inputL: inL[i], inputR: inR[i])
            expectedL[i] = l
            expectedR[i] = r
        }

        inL.withUnsafeMutableBufferPointer { bufL in
            inR.withUnsafeMutableBufferPointer { bufR in
                filter2.process(bufferL: bufL.baseAddress!, bufferR: bufR.baseAddress!, frameCount: frameCount)
            }
        }

        for i in 0..<frameCount {
            #expect(abs(inL[i] - expectedL[i]) < 1.0e-5, "Block and sample L mismatch at \(i)")
            #expect(abs(inR[i] - expectedR[i]) < 1.0e-5, "Block and sample R mismatch at \(i)")
        }
    }
}
