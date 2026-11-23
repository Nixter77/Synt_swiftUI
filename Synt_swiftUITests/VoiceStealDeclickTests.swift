//
//  VoiceStealDeclickTests.swift
//  A hard voice steal (pool full) must not step the mix to zero. The stolen
//  voice's last sample decays through `stealDeclick*` instead (≈ −60 dB in 5 ms).
//  Init / factory goldens never steal, so they stay bit-identical.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct VoiceStealDeclickTests {
    /// Sine, open filter, no FX tails: a held chord whose only discontinuity can be the steal.
    static func sinePad(polyphony: Int) -> SynthPreset {
        var p = SynthPreset.defaultPreset
        p.osc1Waveform = .sine
        p.osc2Enabled = false
        p.attack = 0.002
        p.sustain = 1.0
        p.release = 0.5
        p.filterCutoff = 18_000
        p.reverbMix = 0
        p.chorusMix = 0
        p.delayMix = 0
        p.unisonVoices = 1
        p.polyphonyLimit = polyphony
        return p
    }

    /// Max |x[n] − 2x[n−1] + x[n−2]| over `samples`.
    static func maxSecondDifference(_ samples: [Float]) -> Float {
        guard samples.count > 2 else { return 0 }
        var m: Float = 0
        for n in 2..<samples.count {
            m = max(m, abs(samples[n] - 2 * samples[n - 1] + samples[n - 2]))
        }
        return m
    }

    @Test func hardStealDecaysInsteadOfSteppingToZero() {
        let engine = AudioEngine()
        engine.preset = Self.sinePad(polyphony: 8)
        engine.applyPresetForTesting()
        #expect(engine.cachedPolyphonyLimit == 8)

        // Fill the 8-voice pool with held notes and let them reach sustain.
        for k in 0..<8 {
            engine.noteOn(midiNote: 48 + k * 3, velocity: 0.9)
        }
        engine.processCommandsForTesting()
        var history: [Float] = []
        for _ in 0..<4_096 {
            history.append(engine.renderOneSample().0)
        }
        let steady = Self.maxSecondDifference(Array(history.suffix(1_024)))
        var victimLevel: Float = 0
        for i in 0..<AudioEngine.maxVoices where engine.voices[i].isActive {
            victimLevel = max(victimLevel, abs(engine.voices[i].lastOutL))
        }
        #expect(victimLevel > 0.01, "voices should be audible before the steal, got \(victimLevel)")

        // Ninth key: pool is full and nothing is releasing → hard steal.
        let stealsBefore = engine.stealCountRT
        engine.noteOn(midiNote: 84, velocity: 0.9)
        engine.processCommandsForTesting()
        #expect(engine.stealCountRT == stealsBefore + 1)

        var window: [Float] = Array(history.suffix(2))
        // CleanBus delays the mix by `CleanBus.lookahead`, so look past it.
        for _ in 0..<(CleanBus.lookahead + 512) {
            window.append(engine.renderOneSample().0)
        }
        let atSteal = Self.maxSecondDifference(window)
        // A hard kill would jump by roughly one voice's output (≈ victimLevel · master · headroom).
        // The de-click keeps the transition near the steady-state curvature.
        #expect(atSteal < steady * 3 + victimLevel * 0.1,
                "steal step \(atSteal) vs steady \(steady), victim \(victimLevel)")
        #expect(window.allSatisfy { $0.isFinite })

        // The residual dies out within a few ms and leaves no DC behind.
        for _ in 0..<2_048 { _ = engine.renderOneSample() }
        #expect(engine.stealDeclickL == 0 && engine.stealDeclickR == 0)
    }

    @Test func noStealLeavesResidualUntouched() {
        let engine = AudioEngine()
        engine.preset = Self.sinePad(polyphony: 8)
        engine.applyPresetForTesting()
        for k in 0..<4 {
            engine.noteOn(midiNote: 60 + k * 4, velocity: 0.8)
        }
        engine.processCommandsForTesting()
        for _ in 0..<2_048 { _ = engine.renderOneSample() }
        #expect(engine.stealCountRT == 0)
        #expect(engine.stealDeclickL == 0 && engine.stealDeclickR == 0)
    }

    @Test func clearAllVoicesDropsResidual() {
        let engine = AudioEngine()
        engine.stealDeclickL = 0.3
        engine.stealDeclickR = -0.2
        engine.clearAllVoices()
        #expect(engine.stealDeclickL == 0 && engine.stealDeclickR == 0)
    }

    @Test func declickCoefficientTracksSampleRate() {
        let c44 = AudioEngine.stealDeclickCoef(sampleRate: 44_100)
        let c96 = AudioEngine.stealDeclickCoef(sampleRate: 96_000)
        #expect(c44 > 0.9 && c44 < 1)
        #expect(c96 > c44 && c96 < 1)
        // ≈ −60 dB after 5 ms at either rate.
        #expect(pow(c44, Float(0.005 * 44_100)) < 0.002)
        #expect(pow(c96, Float(0.005 * 96_000)) < 0.002)
    }
}
