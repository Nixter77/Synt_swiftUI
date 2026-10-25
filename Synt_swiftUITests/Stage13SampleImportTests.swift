//
//  Stage13SampleImportTests.swift
//  Synt_swiftUITests
//
//  Stage 3: Sample import robustness, send tail smooth fade,
//  wide seed space (no 256 collapse), no seed leakage, and preset table compression.
//

import Testing
import Foundation
@testable import SynthCore

@MainActor
@Suite struct Stage13SampleImportTests {

    // MARK: - 1. Sample Import Robustness

    @Test func testDCRemovalAndLoopSeamSmoothing() throws {
        // Create 2048 samples with a heavy DC offset (e.g. +5.0) and a step discontinuity at the seam:
        // sample 0 = 0.8, sample 2047 = -0.7.
        var rawSamples = [Float](repeating: 5.0, count: 2048)
        for i in 0..<2048 {
            rawSamples[i] += sin(Float(i) * 0.05)
        }
        rawSamples[0] = 5.8
        rawSamples[2047] = 4.3

        let table = try WavetableOscillator.importAudioBuffer(samples: rawSamples, samplesPerFrame: 2048, maxFrames: 1)
        #expect(table.frames.count == 1)
        let frame = table.frames[0]
        #expect(frame.count == 2048)

        // Verify DC is removed (mean is ~0)
        let mean = frame.reduce(0, +) / Float(frame.count)
        #expect(abs(mean) < 1e-4)

        // Verify seamless loop connection (first sample matches last sample)
        let seamDelta = abs(frame[0] - frame[frame.count - 1])
        #expect(seamDelta < 1e-4)

        // Peak normalized to <= 1.0
        let maxPeak = frame.map { abs($0) }.max() ?? 0
        #expect(maxPeak <= 1.0001)
        #expect(maxPeak >= 0.99)
    }

    @Test func testNaNAndInfinityCleaning() throws {
        var dirtySamples = [Float](repeating: 0.1, count: 2048)
        dirtySamples[10] = Float.nan
        dirtySamples[20] = Float.infinity
        dirtySamples[30] = -Float.infinity

        let table = try WavetableOscillator.importAudioBuffer(samples: dirtySamples, samplesPerFrame: 2048, maxFrames: 1)
        let frame = table.frames[0]
        for s in frame {
            #expect(!s.isNaN)
            #expect(!s.isInfinite)
        }
    }

    // MARK: - 2. R9-2 Send Tail Smooth Fade and Incremental Clearing

    @Test func testSendTailSmoothFadeAndIncrementalClear() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        engine.cachedSendA = 0.5
        engine.sendFadeA = 0.5

        // Process a sample with non-zero send
        _ = engine.renderOneSample()
        #expect(engine.sendFadeA > 0.4)
        #expect(!engine.sendReverb.isClearing)

        // User turns send to zero
        engine.cachedSendA = 0.0

        // Next sample should NOT immediately cut to 0 or synchronously reset
        _ = engine.renderOneSample()
        #expect(engine.sendFadeA > 0.0) // fading out smoothly!

        // Simulate fading out across remaining ~15 ms and clearing
        for _ in 0..<1500 {
            _ = engine.renderOneSample()
        }

        // Once fade finishes, sendFadeA is 0 and buffer is cleared
        #expect(engine.sendFadeA == 0)
        #expect(!engine.sendReverb.isClearing)

        // Turning send back up starts fresh with no old tail
        engine.cachedSendA = 0.8
        _ = engine.renderOneSample()
        #expect(!engine.sendReverb.isClearing)
        #expect(engine.sendFadeA > 0)
    }

    // MARK: - 3. R10-5 Widen Seed Space (No 256-Collapse) and Prevent Seed Leakage

    @Test func testWideSeedSpaceNo256Collapse() {
        let sr = SmoothRandom()

        // Three seeds with identical lower 8 bits (0x01) but different upper bits
        let seedA: UInt32 = 0x0000_0001
        let seedB: UInt32 = 0x1000_0001
        let seedC: UInt32 = 0x8000_0001

        sr.reset(seed: seedA)
        let valA = sr.advance(hz: 1.0, sampleRate: 44100)

        sr.reset(seed: seedB)
        let valB = sr.advance(hz: 1.0, sampleRate: 44100)

        sr.reset(seed: seedC)
        let valC = sr.advance(hz: 1.0, sampleRate: 44100)

        // In ROUND10 with wide seed space, these must NOT collapse to identical values
        #expect(valA != valB)
        #expect(valA != valC)
        #expect(valB != valC)
    }

    @Test func testSeedDoesNotLeakIntoNextPatch() {
        let engine = AudioEngine(coreOnly: true)

        // Patch 1 has a custom seed
        var patch1 = SynthPreset(name: "Patch1", category: .bass)
        patch1.randomSeed = 0x98765432
        engine.preset = patch1
        engine.resetPatchStateRT()
        #expect(engine.randomSeed == 0x98765432)

        // Patch 2 has NO seed (nil)
        let patch2 = SynthPreset(name: "Patch2", category: .lead)
        #expect(patch2.randomSeed == nil)
        engine.preset = patch2
        engine.resetPatchStateRT()

        // Seed MUST NOT leak from Patch 1; must be restored to default
        #expect(engine.randomSeed == 0x12345678)
    }

    // MARK: - 4. R10-9 Cap and Compress Wavetable Data in Presets

    @Test func testWavetableCompressionAndLimits() throws {
        // Generate a 4-frame wavetable
        var frames: [[Float]] = []
        for f in 0..<4 {
            var frame = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 {
                frame[i] = sin(Float(i + f * 50) * 0.02)
            }
            frames.append(frame)
        }
        let wt = Wavetable(name: "TestCompress", frames: frames)

        let raw = wt.serializedData()
        let compressed = wt.compressedSerializedData()

        #expect(compressed.count < raw.count) // compressed is significantly smaller

        // Test round-trip deserialization from compressed data
        let deserialized = Wavetable.deserialize(from: compressed, name: "TestCompress")
        #expect(deserialized != nil)
        #expect(deserialized?.frameCount == 4)
        #expect(deserialized?.samplesPerFrame == 2048)

        // Verify frame sample bit-exactness
        for f in 0..<4 {
            let origFrame = wt.frames[f]
            let decFrame = deserialized!.frames[f]
            #expect(origFrame == decFrame)
        }

        // Test oversized data rejection
        let oversizedData = Data(repeating: 0, count: Wavetable.maxSerializedBytes + 100)
        #expect(Wavetable.deserialize(from: oversizedData) == nil)
    }
}
