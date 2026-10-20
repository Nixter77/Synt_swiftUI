//
//  PhaseV2VelocityTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.9: Velocity Sensitivity (Velocity to Cutoff & Envelope).
//

import Foundation
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2VelocityTests {

    @Test func defaultsAndLegacyDecoding() throws {
        let p = SynthPreset.defaultPreset
        #expect(p.velocityToCutoff == 0.0)
        #expect(p.velocityToEnvAmount == 0.0)

        // Legacy JSON decoding
        let minimalJSON = """
        {"name":"Vintage Velocity"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(decoded.velocityToCutoff == 0.0)
        #expect(decoded.velocityToEnvAmount == 0.0)

        // Sanitization clamps
        var dirty = SynthPreset.defaultPreset
        dirty.velocityToCutoff = 2.0
        dirty.velocityToEnvAmount = 3.0
        let sanitized = dirty.sanitized()
        #expect(sanitized.velocityToCutoff == 1.0)
        #expect(sanitized.velocityToEnvAmount == 1.0)

        var dirtyLow = SynthPreset.defaultPreset
        dirtyLow.velocityToCutoff = -1.5
        dirtyLow.velocityToEnvAmount = -2.5
        let sanitizedLow = dirtyLow.sanitized()
        #expect(sanitizedLow.velocityToCutoff == 0.0)
        #expect(sanitizedLow.velocityToEnvAmount == -1.0)
    }

    @Test func velocityScalesFilterCutoff() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.filterCutoff = 6000.0
        p.filterEnvelopeAmount = 0.0
        p.filterKeyTracking = 0.0
        p.velocityToCutoff = 1.0 // 100% velocity sensitivity
        p.velocityToEnvAmount = 0.0
        p.osc1Waveform = .sawtooth
        p.osc2Enabled = false
        p.attack = 0.001
        p.decay = 0.5
        p.sustain = 1.0
        p.release = 0.5
        engine.preset = p
        engine.applyPresetForTesting()

        // 1. Soft note (velocity = 0.2)
        engine.noteOn(midiNote: 60, velocity: 0.2)
        engine.processCommandsForTesting()

        // Warm up and sample
        var softEnergy: Float = 0.0
        for _ in 0..<1024 {
            let (l, _) = engine.renderOneSample()
            softEnergy += abs(l)
        }
        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()

        // Silence / reset voices
        for _ in 0..<44100 {
            _ = engine.renderOneSample()
        }

        // 2. Hard note (velocity = 1.0)
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var hardEnergy: Float = 0.0
        for _ in 0..<1024 {
            let (l, _) = engine.renderOneSample()
            hardEnergy += abs(l)
        }
        engine.noteOff(midiNote: 60)

        // With sawtooth waveform, a wide open filter (velocity 1.0) passes far more high-frequency harmonics
        // than an attenuated cutoff filter (velocity 0.2), producing higher integrated amplitude/energy.
        #expect(hardEnergy > softEnergy * 1.05, "Hard hit energy (\(hardEnergy)) must exceed soft hit energy (\(softEnergy))")
    }

    @Test func velocityScalesFilterEnvelope() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.filterCutoff = 500.0
        p.filterEnvelopeAmount = 0.8
        p.velocityToCutoff = 0.0
        p.velocityToEnvAmount = 1.0 // Velocity strongly scales envelope amount
        p.attack = 0.001
        p.decay = 0.1
        p.sustain = 0.0
        p.release = 0.1
        p.osc1Waveform = .sawtooth
        p.osc2Enabled = false
        engine.preset = p
        engine.applyPresetForTesting()

        // 1. Render soft hit
        engine.noteOn(midiNote: 60, velocity: 0.2)
        engine.processCommandsForTesting()
        var softMax: Float = 0.0
        for _ in 0..<1000 {
            let (l, _) = engine.renderOneSample()
            softMax = max(softMax, abs(l))
        }
        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()

        for _ in 0..<22050 {
            _ = engine.renderOneSample()
        }

        // 2. Render hard hit
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()
        var hardMax: Float = 0.0
        for _ in 0..<1000 {
            let (l, _) = engine.renderOneSample()
            hardMax = max(hardMax, abs(l))
        }
        engine.noteOff(midiNote: 60)

        // Hard hit envelope opens filter significantly more than soft hit
        #expect(hardMax > softMax * 1.05, "Hard envelope peak (\(hardMax)) must exceed soft envelope peak (\(softMax))")
    }

    @Test func initGoldenHashPreserved() {
        let p = SynthPreset.defaultPreset
        let hash = InitGoldenTests.renderHash(p)
        #expect(hash == InitGoldenTests.golden["Init"], "Init golden hash changed: 0x\(String(hash, radix: 16))")
    }
}
