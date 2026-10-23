//
//  Stage18PerfTests.swift
//  SYNT_18 Stage 1: R15-2 perf margin for wavetable voices (the path generateSample serves).
//  Opt in with SYNT_RUN_PERF=1. Run serially, on its own.
//

import Testing
import Foundation
@testable import SynthCore

@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SYNT_RUN_PERF"] == "1"))
struct Stage18WavetablePerfBenchmarks {

    /// Same load as LiveStep4PerfBenchmarks (classic oscillators), logged to /tmp/synt18_perf.txt.
    @Test func benchmark32ClassicVoicesCPULogged() {
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
        let pct = Self.measure(preset, label: "classic (LiveStep4 load)")
        #expect(pct < 200.0)
    }

    @Test func benchmark32WavetableVoicesCPU() {
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .wavetable
        preset.osc1WavetableIndex = 1
        preset.osc1WavetableMorph = 0.37
        preset.osc1Volume = 0.7
        preset.osc2Enabled = true
        preset.osc2Waveform = .wavetable
        preset.osc2WavetableIndex = 3
        preset.osc2WavetableMorph = 0.61
        preset.osc2Volume = 0.7
        preset.unisonVoices = 5
        preset.unisonDetune = 15.0
        preset.filterCutoff = 4000.0
        preset.filterResonance = 0.5
        let pct = Self.measure(preset, label: "wavetable")
        // Measurement for the R15-2 margin; 32 wavetable voices × 5 unison × 2 osc.
        // On the Intel Mac mini this load was over budget before SYNT_18 (see SYNT_18_REPORT.md), so the
        // gate here is a sanity ceiling, not the 85% real-time line.
        #expect(pct < 200.0)
    }

    static func measure(_ preset: SynthPreset, label: String) -> Double {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        for n in 36...67 { engine.noteOn(midiNote: n, velocity: 0.7) }
        engine.processCommandsForTesting()

        let bufferSize = 512
        let bufferCount = 200
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { bufL.deallocate(); bufR.deallocate() }
        for _ in 0..<10 { engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: bufferSize) }

        var best = Double.greatestFiniteMagnitude
        for _ in 0..<3 {
            let t0 = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            for _ in 0..<bufferCount { engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: bufferSize) }
            let t1 = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            best = min(best, Double(t1 - t0) / 1_000_000.0)
        }
        let budgetMs = Double(bufferSize * bufferCount) / 44100.0 * 1000.0
        let pct = best / budgetMs * 100.0
        let line = String(format: "SYNT18-PERF %@ 32 voices x5 unison: best of 3 = %.2f ms = %.2f%% of RT budget\n", label, best, pct)
        print(line)
        if let h = FileHandle(forWritingAtPath: "/tmp/synt18_perf.txt") ?? {
            FileManager.default.createFile(atPath: "/tmp/synt18_perf.txt", contents: nil)
            return FileHandle(forWritingAtPath: "/tmp/synt18_perf.txt")
        }() {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        }
        return pct
    }
}
