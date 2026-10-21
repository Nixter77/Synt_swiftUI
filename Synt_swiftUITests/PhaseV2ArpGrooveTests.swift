//
//  PhaseV2ArpGrooveTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.8: Arpeggiator Pro Groove — Gate Length & Swing.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2ArpGrooveTests {

    @Test func defaultsAndLegacyDecoding() throws {
        let p = SynthPreset.defaultPreset
        #expect(p.arpGateLength == 0.8)
        #expect(p.arpSwing == 0.0)

        // Legacy JSON decoding
        let minimalJSON = """
        {"name":"Vintage Arp"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(decoded.arpGateLength == 0.8)
        #expect(decoded.arpSwing == 0.0)

        // Sanitization clamps
        var dirty = SynthPreset.defaultPreset
        dirty.arpGateLength = 2.5
        dirty.arpSwing = 1.5
        let sanitized = dirty.sanitized()
        #expect(sanitized.arpGateLength == 1.0)
        #expect(sanitized.arpSwing == 0.75)

        var dirtyLow = SynthPreset.defaultPreset
        dirtyLow.arpGateLength = -0.5
        dirtyLow.arpSwing = -0.2
        let sanitizedLow = dirtyLow.sanitized()
        #expect(sanitizedLow.arpGateLength == 0.1)
        #expect(sanitizedLow.arpSwing == 0.0)
    }

    @Test func swingStepDurationAlternatesEvenAndOdd() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.bpm = 120.0
        p.arpSwing = 0.5 // 50% swing
        engine.preset = p
        engine.applyPresetForTesting()
        _ = engine.renderOneSample()

        // 44100 * 60 / 120 / 4 = 5512.5 samples per tick
        let base = engine.samplesPerTick
        #expect(base == 5512.5)

        // Step 0 (even): base + 0.5 * base * 0.5 = 1.25 * base
        engine.arpStepIndex = 0
        let evenDuration = engine.currentArpStepDuration()
        #expect(abs(evenDuration - (base * 1.25)) < 1e-4)

        // Step 1 (odd): base - 0.5 * base * 0.5 = 0.75 * base
        engine.arpStepIndex = 1
        let oddDuration = engine.currentArpStepDuration()
        #expect(abs(oddDuration - (base * 0.75)) < 1e-4)

        // Total duration of two steps is preserved
        #expect(abs((evenDuration + oddDuration) - (2.0 * base)) < 1e-4)
    }

    @Test func gateCutoffReleasesNoteEarlyOnStaccato() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.arpMode = .up
        p.arpRate = .sixteenth
        p.bpm = 120.0
        p.arpGateLength = 0.25 // 25% gate (staccato)
        p.arpSwing = 0.0
        engine.preset = p
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()

        // Fast-forward until the first arp tick fires (at sample 5513)
        var fired = false
        var activeMidi: Int? = nil
        for _ in 0...5600 {
            _ = engine.renderOneSample()
            if let note = engine.arp.currentNote {
                fired = true
                activeMidi = note
                break
            }
        }
        #expect(fired)
        #expect(activeMidi == 60)

        let stepDuration = engine.samplesPerTick // 5512.5
        let gateSamples = Int((stepDuration * 0.25).rounded(.down)) // ~1378 samples

        // Check voice state right after note start: should not be releasing
        var isReleasingImmediately = false
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 {
                isReleasingImmediately = engine.voices[i].isReleasing
            }
        }
        #expect(!isReleasingImmediately)

        // Render past the 25% gate threshold
        for _ in 0..<(gateSamples + 10) {
            _ = engine.renderOneSample()
        }

        // Voice must now have entered release phase and arp.currentNote should be nil
        #expect(engine.arp.currentNote == nil)
        var hasEnteredRelease = false
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 {
                hasEnteredRelease = engine.voices[i].isReleasing
            }
        }
        #expect(hasEnteredRelease)
    }

    @Test func initGoldenHashPreserved() {
        var p = SynthPreset.defaultPreset
        let hash = InitGoldenTests.renderHash(p)
        #expect(hash == InitGoldenTests.golden["Init"], "Init golden hash changed: 0x\(String(hash, radix: 16))")
    }
}
