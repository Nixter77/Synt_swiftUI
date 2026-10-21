//
//  LiveStep4BlockRenderTests.swift
//  Synt_swiftUITests
//
//  Unit tests and performance benchmark for Step 4:
//  Zero-ARC render callback and block render optimization.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct LiveStep4BlockRenderTests {

    @Test func blockRenderMatchesSingleSampleOutput() {
        let engine1 = AudioEngine()
        let engine2 = AudioEngine()

        // Configure both with identical preset and notes
        var preset = SynthPreset.defaultPreset
        preset.osc1Volume = 0.6
        preset.osc2Enabled = true
        preset.osc2Volume = 0.5
        preset.filterCutoff = 3500.0
        preset.filterResonance = 0.4
        preset.chorusMix = 0.3

        engine1.preset = preset
        engine1.applyPresetForTesting()
        engine2.preset = preset
        engine2.applyPresetForTesting()

        // Play 3 notes on both engines
        for note in [60, 64, 67] {
            engine1.noteOn(midiNote: note, velocity: 0.8)
            engine2.noteOn(midiNote: note, velocity: 0.8)
        }
        engine1.processCommandsForTesting()
        engine2.processCommandsForTesting()

        let frameCount = 2048
        let bufL1 = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR1 = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufL2 = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        let bufR2 = UnsafeMutablePointer<Float>.allocate(capacity: frameCount)
        defer {
            bufL1.deallocate()
            bufR1.deallocate()
            bufL2.deallocate()
            bufR2.deallocate()
        }

        // Engine 1 renders sample-by-sample
        for frame in 0..<frameCount {
            let (l, r) = engine1.renderOneSample()
            bufL1[frame] = l
            bufR1[frame] = r
        }

        // Engine 2 renders block
        engine2.renderBlock(intoL: bufL2, intoR: bufR2, frameCount: frameCount)

        // Compare sample-by-sample difference
        var maxDiff: Float = 0
        for frame in 0..<frameCount {
            let diffL = abs(bufL1[frame] - bufL2[frame])
            let diffR = abs(bufR1[frame] - bufR2[frame])
            maxDiff = max(maxDiff, max(diffL, diffR))
        }

        #expect(maxDiff <= 1e-6,
                "Block render output must match renderOneSample within 1e-6 (actual max diff: \(maxDiff))")
    }

    @Test func initGoldenHashPreservedInStep4() {
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == InitGoldenTests.golden["Init"],
                "Init golden hash must remain 100% bit-identical (0xd1b3635203a4799e)")
    }
}

/// CPU benchmark — not a unit test. Wall/CPU time in a Debug build under the
/// parallel test runner is not a stable pass/fail signal, and both variants
/// run the same per-sample loop. Opt in with SYNT_RUN_PERF=1.
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SYNT_RUN_PERF"] == "1"))
struct LiveStep4PerfBenchmarks {

    @Test func benchmark32VoicesCPU() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.osc1Volume = 0.7
        preset.osc2Enabled = true
        preset.osc2Volume = 0.7
        preset.unisonVoices = 5
        preset.unisonDetune = 15.0
        preset.filterCutoff = 4000.0
        preset.filterResonance = 0.5
        preset.chorusMix = 0.25
        preset.delayMix = 0.2
        engine.preset = preset
        engine.applyPresetForTesting()

        // Trigger notes to fill up to 32 active voices
        for n in 36...67 {
            engine.noteOn(midiNote: n, velocity: 0.7)
        }
        engine.processCommandsForTesting()

        let bufferSize = 512
        let bufferCount = 200
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer {
            bufL.deallocate()
            bufR.deallocate()
        }

        // Warmup 10 buffers
        for _ in 0..<10 {
            engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: bufferSize)
        }

        // Benchmark per-sample (before optimization)
        let startPerSample = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        for _ in 0..<bufferCount {
            for frame in 0..<bufferSize {
                let (l, r) = engine.renderOneSample()
                bufL[frame] = l
                bufR[frame] = r
            }
        }
        let endPerSample = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        let elapsedPerSampleMs = Double(endPerSample - startPerSample) / 1_000_000.0

        // Benchmark renderBlock (optimized zero-ARC block render)
        let startBlock = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        for _ in 0..<bufferCount {
            engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: bufferSize)
        }
        let endBlock = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
        let elapsedBlockMs = Double(endBlock - startBlock) / 1_000_000.0

        let realTimeBudgetMs = (Double(bufferSize * bufferCount) / 44100.0) * 1000.0
        let percentPerSample = (elapsedPerSampleMs / realTimeBudgetMs) * 100.0
        let percentBlock = (elapsedBlockMs / realTimeBudgetMs) * 100.0

        let report = """
        Per-sample render (before): \(String(format: "%.2f", elapsedPerSampleMs)) ms (\(String(format: "%.2f", percentPerSample))% of RT budget)
        Block render (after): \(String(format: "%.2f", elapsedBlockMs)) ms (\(String(format: "%.2f", percentBlock))% of RT budget)
        Total 200-buffer audio duration: \(String(format: "%.2f", realTimeBudgetMs)) ms
        """
        print(report)

        #expect(percentBlock < 85.0,
                "32 active voices should render within real-time budget")
    }
}
