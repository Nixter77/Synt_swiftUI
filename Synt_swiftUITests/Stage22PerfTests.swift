//
//  Stage22PerfTests.swift
//  SYNT_22 Stage 2: wavetable 32×5 budget gate (≤90% RT, thread CPU time) + 24×5 guidance figure.
//  Opt in with SYNT_RUN_PERF=1. Run serially, on its own.
//

import Testing
import Foundation
@testable import SynthCore

@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SYNT_RUN_PERF"] == "1"))
struct Stage22WavetablePerfBudget {

    static func wavetablePreset() -> SynthPreset {
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
        return preset
    }

    /// Budget gate: 32 wavetable voices × 5 unison × 2 osc must stay ≤ 90% of real time.
    /// (115.8% before the SYNT_22 Oscillator copy/pow hoist.)
    @Test func wavetable32x5WithinNinetyPercentBudget() {
        let pct = Stage18WavetablePerfBenchmarks.measure(Self.wavetablePreset(), label: "SYNT22 wavetable budget")
        #expect(pct <= 90.0, "wavetable 32×5 = \(pct)% of RT (budget 90%)")
    }

    /// Guidance figure for the 24-voice recommendation (logged, sanity ceiling only).
    @Test func wavetable24x5Guidance() {
        let pct = Stage18WavetablePerfBenchmarks.measure(Self.wavetablePreset(), label: "SYNT22 wavetable", voices: 24)
        #expect(pct < 200.0)
    }
}
