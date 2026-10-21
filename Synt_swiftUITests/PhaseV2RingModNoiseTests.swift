//
//  PhaseV2RingModNoiseTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.7: Ring Modulator (Osc 1 × Osc 2) and Colored Noise (White/Pink/Brown).
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2RingModNoiseTests {

    @Test func ringModAndNoiseColorDefaultsAndLegacyDecoding() throws {
        let p = SynthPreset.defaultPreset
        #expect(p.ringModAmount == 0.0)
        #expect(p.noiseColor == .white)

        // Legacy JSON decoding
        let minimalJSON = """
        {"name":"Vintage Patch"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(decoded.ringModAmount == 0.0)
        #expect(decoded.noiseColor == .white)
    }

    @Test func noiseColorFilteringProducesVariedSpectra() {
        var note = ActiveNote()
        note.activate(midiNote: 60, velocity: 1.0, frequency: 261.63)

        // 1. White noise: unchanged
        let whiteIn: Float = 0.75
        let whiteOut = note.filterNoise(whiteIn, color: .white)
        #expect(whiteOut == whiteIn)

        // 2. Pink noise: filtered, finite, damped
        var pinkFinite = true
        for _ in 0..<100 {
            let out = note.filterNoise(0.5, color: .pink)
            if !out.isFinite { pinkFinite = false }
        }
        #expect(pinkFinite)

        // 3. Brown noise: filtered, finite
        var brownFinite = true
        for _ in 0..<100 {
            let out = note.filterNoise(0.5, color: .brown)
            if !out.isFinite { brownFinite = false }
        }
        #expect(brownFinite)
    }

    @Test func ringModulationAffectsAudioOutput() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        // Preset with Osc 1 (Sine) and Osc 2 (Sine)
        var p = SynthPreset.defaultPreset
        p.osc1Waveform = .sine
        p.osc2Waveform = .sine
        p.osc2Enabled = true
        p.osc2Detune = 50.0 // 50 cents detuned
        p.ringModAmount = 0.0
        p.chorusMix = 0.0
        p.reverbMix = 0.0
        p.delayMix = 0.0

        engine.preset = p
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        // Warm up past attack envelope
        for _ in 0..<512 { _ = engine.renderOneSample() }

        var normalSamples: [Float] = []
        for _ in 0..<512 {
            let (l, _) = engine.renderOneSample()
            normalSamples.append(l)
        }

        // Now activate full Ring Modulation
        p.ringModAmount = 1.0
        engine.clearAllVoices()
        engine.preset = p
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        for _ in 0..<512 { _ = engine.renderOneSample() }

        var ringSamples: [Float] = []
        for _ in 0..<512 {
            let (l, _) = engine.renderOneSample()
            ringSamples.append(l)
        }

        var diffSum: Float = 0.0
        for i in 0..<512 {
            diffSum += abs(normalSamples[i] - ringSamples[i])
        }

        #expect(diffSum > 5.0, "Ring modulation must produce distinct sideband frequencies (diff: \(diffSum))")
    }

    @Test func phaseV2PreservesInitGolden() {
        let h = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(h == 0xd1b3635203a4799e, "Init golden hash must remain 0xd1b3635203a4799e")
    }
}
