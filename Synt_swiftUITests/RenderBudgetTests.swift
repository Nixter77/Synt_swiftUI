//
//  RenderBudgetTests.swift
//  Offline render budget: 512-frame buffers must stay under half a realtime slice.
//

import Foundation
import Darwin
import Testing
@testable import Synt_swiftUI

/// CPU budget gate. Thread time under the parallel runner still crosses the
/// 50% line on a loaded machine (measured about 51.7%). The limit stays 50.
/// Opt in with SYNT_RUN_PERF=1, same as the other render benchmark.
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SYNT_RUN_PERF"] == "1"))
struct RenderBudgetTests {

    private static let framesPerBuffer = 512
    private static let bufferCount = 200
    private static let sampleRate = 44_100.0
    private static let sevenNotes = [48, 52, 55, 60, 64, 67, 71]

    /// Percent of one 512-frame buffer at 44.1 kHz. The app target compiles Debug
    /// with -O, so the half-buffer gate applies. The test bundle itself stays
    /// -Onone; if that ever pulls unoptimized DSP into the measurement, raise
    /// this under `#if DEBUG` — the log line must stay either way.
    private static let budgetLimitPercent: Double = 50

    @Test func renderBudgetForInitChordAndHeaviestFactory() {
        let initPercent = Self.measure(
            preset: .defaultPreset,
            notes: Self.sevenNotes,
            label: "Init×7"
        )

        let heavy = Self.heaviestUnisonPhaserFactory()
        // One held key keeps unison partials; a second key collapses them.
        let heavyPercent = Self.measure(
            preset: heavy.preset,
            notes: [60],
            label: "heavy \(heavy.preset.name) unison+phaser"
        )

        let limit = Self.budgetLimitPercent
        Self.logBudget(String(
            format: "RenderBudget Init×7 %.2f%% of 512-frame buffer (limit %.0f%%)",
            initPercent, limit
        ))
        Self.logBudget(String(
            format: "RenderBudget %@ unison+phaser %.2f%% of 512-frame buffer (limit %.0f%%)",
            heavy.preset.name, heavyPercent, limit
        ))

        #expect(initPercent < limit)
        #expect(heavyPercent < limit)
        #expect(initPercent > 0)
        #expect(heavyPercent > 0)
    }

    /// Factory with the most unison partials. Phaser is forced on for the
    /// measurement only — the library itself is not edited (Glass Horizon ships
    /// with phaser off).
    private static func heaviestUnisonPhaserFactory() -> (preset: SynthPreset, changedPhaser: Bool) {
        let factories = SynthPreset.factoryPresets
        let ranked = factories.max { lhs, rhs in
            cost(lhs) < cost(rhs)
        }
        var preset = ranked ?? .defaultPreset
        let changedPhaser = !preset.phaserEnabled
        if changedPhaser {
            preset.phaserEnabled = true
            if preset.phaserMix < 0.12 { preset.phaserMix = 0.35 }
            if preset.phaserDepth < 0.1 { preset.phaserDepth = 0.4 }
            if preset.phaserRate < 0.05 { preset.phaserRate = 0.3 }
        }
        if preset.unisonVoices < 2 {
            preset.unisonVoices = 2
            preset.unisonDetune = 8
            preset.unisonSpread = 0.4
        }
        return (preset, changedPhaser)
    }

    private static func cost(_ preset: SynthPreset) -> Int {
        var score = preset.unisonVoices * 4
        if preset.phaserEnabled { score += 8 }
        if preset.osc1Waveform == .wavetable || preset.osc2Waveform == .wavetable { score += 3 }
        if preset.osc2Enabled { score += 2 }
        if preset.lfoEnabled { score += 1 }
        if preset.distortionEnabled { score += 1 }
        if preset.eqEnabled { score += 1 }
        if preset.chorusMix > 0 { score += 1 }
        return score
    }

    private static func measure(preset: SynthPreset, notes: [Int], label: String) -> Double {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        for midi in notes {
            engine.noteOn(midiNote: midi, velocity: 1.0)
        }
        engine.processCommandsForTesting()

        _ = engine.renderFramesMetricsForTesting(framesPerBuffer * 4)

        // Thread CPU time, not wall clock. Swift Testing runs suites in parallel,
        // and a preempted buffer would otherwise look like a DSP regression.
        var elapsedNs: UInt64 = 0
        for _ in 0..<bufferCount {
            let t0 = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            _ = engine.renderFramesMetricsForTesting(framesPerBuffer)
            let t1 = clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)
            elapsedNs += t1 &- t0
        }

        let averageSeconds = Double(elapsedNs) / Double(bufferCount) / 1_000_000_000.0
        let budgetSeconds = Double(framesPerBuffer) / sampleRate
        let percent = averageSeconds / budgetSeconds * 100.0
        Self.logBudget(String(
            format: "RenderBudget detail %@ avg %.3f ms = %.2f%% of %.3f ms",
            label,
            averageSeconds * 1000.0,
            percent,
            budgetSeconds * 1000.0
        ))
        return percent
    }

    private static func logBudget(_ line: String) {
        // stderr is what `xcodebuild test` surfaces; also leave a copy for the run log.
        fputs(line + "\n", stderr)
        fflush(stderr)
        print(line)
    }
}
