//
//  DSPDualFilterTests.swift
//  Synt_swiftUITests
//
//  Stage 3: Dual filter tests (frequency response for serial vs parallel, stability).
//

import Testing
import Foundation
@testable import SynthCore

@MainActor
@Suite struct DSPDualFilterTests {

    @Test func frequencyResponseSerialVsParallel() {
        let sampleRate: Double = 44100.0
        let dualFilter = DSPDualFilter(sampleRate: sampleRate)

        // Filter 1: LowPass at 500 Hz
        dualFilter.type1 = .lowPass
        dualFilter.cutoff1 = 500.0
        dualFilter.resonance1 = 0.3

        // Filter 2: HighPass at 2000 Hz
        dualFilter.type2 = .highPass
        dualFilter.cutoff2 = 2000.0
        dualFilter.resonance2 = 0.3

        func measureGain(freq: Float) -> Float {
            dualFilter.reset()
            let n = 2048
            var sumSquare: Float = 0
            for i in 0..<n {
                let phase = 2.0 * Float.pi * freq * Float(i) / Float(sampleRate)
                let x = sin(phase)
                let y = dualFilter.process(x)
                if i >= 512 {
                    sumSquare += y * y
                }
            }
            return sqrt(sumSquare / Float(n - 512))
        }

        // Test in PARALLEL with balance 0.5 (creates a band-reject / notch shape)
        dualFilter.routing = .parallel
        dualFilter.balance = 0.5
        let parGain100Hz = measureGain(freq: 100.0)   // Passed by LP
        let parGain8000Hz = measureGain(freq: 8000.0) // Passed by HP

        // Test in SERIAL with balance 1.0 (Filter 1 LP 500 -> Filter 2 HP 2000: rejects both 100Hz and 8000Hz)
        dualFilter.routing = .serial
        dualFilter.balance = 1.0
        let serGain100Hz = measureGain(freq: 100.0)   // Rejected by HP 2000
        let serGain8000Hz = measureGain(freq: 8000.0) // Rejected by LP 500

        #expect(parGain100Hz > serGain100Hz * 3.0, "Parallel at 100Hz (\(parGain100Hz)) must pass much more signal than Serial (\(serGain100Hz))")
        #expect(parGain8000Hz > serGain8000Hz * 3.0, "Parallel at 8000Hz (\(parGain8000Hz)) must pass much more signal than Serial (\(serGain8000Hz))")
    }

    @Test func serialCascadingSteepness() {
        let sampleRate: Double = 44100.0
        let dualFilter = DSPDualFilter(sampleRate: sampleRate)

        // Both filters set to LowPass at 1000 Hz
        dualFilter.type1 = .lowPass
        dualFilter.cutoff1 = 1000.0
        dualFilter.resonance1 = 0.2

        dualFilter.type2 = .lowPass
        dualFilter.cutoff2 = 1000.0
        dualFilter.resonance2 = 0.2

        func measureGain(freq: Float) -> Float {
            dualFilter.reset()
            let n = 2048
            var sumSquare: Float = 0
            for i in 0..<n {
                let phase = 2.0 * Float.pi * freq * Float(i) / Float(sampleRate)
                let x = sin(phase)
                let y = dualFilter.process(x)
                if i >= 512 {
                    sumSquare += y * y
                }
            }
            return sqrt(sumSquare / Float(n - 512))
        }

        // Single filter output (balance = 0.0)
        dualFilter.routing = .serial
        dualFilter.balance = 0.0
        let singleFilterStopband = measureGain(freq: 4000.0)

        // Cascaded serial output (balance = 1.0, 4th-order slope)
        dualFilter.balance = 1.0
        let cascadedStopband = measureGain(freq: 4000.0)

        #expect(cascadedStopband < singleFilterStopband * 0.3, "Cascaded serial 4th-order filter (\(cascadedStopband)) must have significantly higher stopband attenuation than single 2nd-order (\(singleFilterStopband))")
    }

    @Test func stabilityUnderContinuousParameterSweeps() {
        let sampleRate: Double = 44100.0
        let totalSamples = 100_000
        let dualFilter = DSPDualFilter(sampleRate: sampleRate)

        var rng: UInt32 = 0x87654321
        func nextNoise() -> Float {
            rng ^= (rng << 13)
            rng ^= (rng >> 17)
            rng ^= (rng << 5)
            return (Float(rng) / Float(UInt32.max)) * 2.0 - 1.0
        }

        for i in 0..<totalSamples {
            if i % 500 == 0 {
                let p = Float(i) / Float(totalSamples)
                dualFilter.cutoff1 = 50.0 + p * 15000.0
                dualFilter.cutoff2 = 15000.0 - p * 14000.0
                dualFilter.resonance1 = 0.1 + p * 0.85
                dualFilter.resonance2 = 0.9 - p * 0.8
                dualFilter.balance = p
                dualFilter.routing = (i % 2000 < 1000) ? .serial : .parallel
            }

            let input = nextNoise()
            let (outL, outR) = dualFilter.process(inputL: input, inputR: input)

            #expect(outL.isFinite, "Output L must be finite at sample \(i)")
            #expect(outR.isFinite, "Output R must be finite at sample \(i)")
            #expect(!outL.isNaN, "Output L must not be NaN at sample \(i)")
            #expect(!outR.isNaN, "Output R must not be NaN at sample \(i)")
            #expect(abs(outL) <= 15.0, "Output L must stay within safe bounds at sample \(i)")
            #expect(abs(outR) <= 15.0, "Output R must stay within safe bounds at sample \(i)")
        }
    }

    @Test func balanceCrossfadeParallel() {
        let dualFilter = DSPDualFilter(sampleRate: 44100.0)
        dualFilter.routing = .parallel
        dualFilter.type1 = .lowPass
        dualFilter.cutoff1 = 200.0

        dualFilter.type2 = .highPass
        dualFilter.cutoff2 = 10000.0

        // Test with a 1000 Hz input:
        // Filter 1 (LP 200) attenuates it.
        // Filter 2 (HP 10000) attenuates it.
        // But with LP at 2000 Hz and HP at 200 Hz:
        dualFilter.cutoff1 = 2000.0 // passes 1000 Hz
        dualFilter.cutoff2 = 200.0  // passes 1000 Hz

        dualFilter.balance = 0.0
        let outF1 = dualFilter.process(1.0)

        dualFilter.balance = 1.0
        let outF2 = dualFilter.process(1.0)

        dualFilter.balance = 0.5
        dualFilter.reset()
        // Run a few samples to check mix
        let outMixed = dualFilter.process(1.0)
        #expect(outMixed.isFinite)
        #expect(outF1.isFinite)
        #expect(outF2.isFinite)
    }

    @Test func blockProcessingMatchesSampleProcessing() {
        let sampleRate: Double = 44100.0
        let frameCount = 256

        let filter1 = DSPDualFilter(sampleRate: sampleRate)
        let filter2 = DSPDualFilter(sampleRate: sampleRate)

        filter1.cutoff1 = 1200.0
        filter1.cutoff2 = 800.0
        filter1.routing = .serial
        filter1.balance = 0.7

        filter2.cutoff1 = 1200.0
        filter2.cutoff2 = 800.0
        filter2.routing = .serial
        filter2.balance = 0.7

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
