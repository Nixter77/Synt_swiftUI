//
//  LadderFilterTests.swift
//  Notch depth, ladder slope, and stability at full resonance.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct LadderFilterTests {
    private func sineRMS(
        frequency: Float,
        sampleRate: Float = 44_100,
        seconds: Float = 0.5,
        skip: Float = 0.1,
        amplitude: Float = 0.05,
        body: (Float) -> Float
    ) -> Float {
        let total = Int(sampleRate * seconds)
        let warm = Int(sampleRate * skip)
        var sum: Float = 0
        var n = 0
        let step = 2 * Float.pi * frequency / sampleRate
        for i in 0..<total {
            let y = body(sin(step * Float(i)) * amplitude)
            if i >= warm {
                sum += y * y
                n += 1
            }
        }
        return (sum / Float(max(1, n))).squareRoot()
    }

    @Test func notchRemovesTheCutoffFrequency() {
        let coeffs = CachedBiquadFilter.coefficients(
            type: .notch,
            cutoff: 1_000,
            resonance: 0.85,
            sampleRate: 44_100
        )
        var memory = BiquadMemory()
        let atCutoff = sineRMS(frequency: 1_000) { memory.process($0, coeffs: coeffs) }
        memory.reset()
        let far = sineRMS(frequency: 4_000) { memory.process($0, coeffs: coeffs) }
        #expect(far > 0.01)
        #expect(atCutoff < far * 0.1, "notch rms \(atCutoff) vs \(far)")
    }

    @Test func ladderFallsAboutTwentyFourDecibelsPerOctave() {
        var ladder = LadderFilter()
        let low = sineRMS(frequency: 4_000) {
            ladder.process($0, cutoff: 1_000, resonance: 0, drive: 0, sampleRate: 44_100)
        }
        ladder.reset()
        let high = sineRMS(frequency: 8_000) {
            ladder.process($0, cutoff: 1_000, resonance: 0, drive: 0, sampleRate: 44_100)
        }
        let db = 20 * log10(Double(high) / Double(low))
        #expect(abs(db - (-24)) < 3, "slope \(db) dB/oct")
    }

    @Test func ladderStaysFiniteAtFullResonanceWhileCutoffMoves() {
        var ladder = LadderFilter()
        var worst: Float = 0
        for i in 0..<22_050 {
            let cutoff = 80 + Float(i % 1_500) * 6
            let x = sin(Float(i) * 0.37)
            let y = ladder.process(x, cutoff: cutoff, resonance: 1, drive: 1, sampleRate: 44_100)
            #expect(y.isFinite)
            if abs(y) > worst { worst = abs(y) }
        }
        #expect(worst < 8)

        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.name = "Ladder Stab"
        preset.filterType = .ladder
        preset.filterCutoff = 1_200
        preset.filterResonance = 1
        preset.filterDrive = 0.4
        preset.attack = 0.001
        preset.decay = 0.2
        preset.sustain = 0.4
        preset.release = 0.1
        engine.preset = preset
        engine.applyPresetForTesting()
        for note in 0..<32 {
            engine.noteOn(midiNote: 36 + note, velocity: 0.7)
        }
        engine.processCommandsForTesting()
        let metrics = engine.renderFramesMetricsForTesting(2_048)
        #expect(metrics.nanCount == 0)
        #expect(metrics.peak < 1.5)
    }
}
