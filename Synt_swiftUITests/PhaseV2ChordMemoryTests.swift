//
//  PhaseV2ChordMemoryTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.10: Chord Memory Unison (Octave, Fifth, Minor, Major, Sus4).
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2ChordMemoryTests {

    @Test func defaultsAndLegacyDecoding() throws {
        let p = SynthPreset.defaultPreset
        #expect(p.chordMode == .off)

        // Legacy JSON decoding
        let minimalJSON = """
        {"name":"Vintage Patch"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(decoded.chordMode == .off)

        // Sanitization
        var dirty = SynthPreset.defaultPreset
        dirty.chordMode = .minor
        let sanitized = dirty.sanitized()
        #expect(sanitized.chordMode == .minor)
    }

    @Test func chordModeIntervalOffsets() {
        // Octave: [0, 12, -12, 24, -24]
        #expect(ChordMode.octave.semitoneOffset(for: 0, totalPartials: 3) == 0)
        #expect(ChordMode.octave.semitoneOffset(for: 1, totalPartials: 3) == 12)
        #expect(ChordMode.octave.semitoneOffset(for: 2, totalPartials: 3) == -12)

        // Fifth: [0, 7, 12, 19, -12]
        #expect(ChordMode.fifth.semitoneOffset(for: 0, totalPartials: 3) == 0)
        #expect(ChordMode.fifth.semitoneOffset(for: 1, totalPartials: 3) == 7)
        #expect(ChordMode.fifth.semitoneOffset(for: 2, totalPartials: 3) == 12)

        // Minor: [0, 3, 7, 10, 12]
        #expect(ChordMode.minor.semitoneOffset(for: 0, totalPartials: 3) == 0)
        #expect(ChordMode.minor.semitoneOffset(for: 1, totalPartials: 3) == 3)
        #expect(ChordMode.minor.semitoneOffset(for: 2, totalPartials: 3) == 7)

        // Major: [0, 4, 7, 11, 12]
        #expect(ChordMode.major.semitoneOffset(for: 0, totalPartials: 3) == 0)
        #expect(ChordMode.major.semitoneOffset(for: 1, totalPartials: 3) == 4)
        #expect(ChordMode.major.semitoneOffset(for: 2, totalPartials: 3) == 7)

        // Sus4: [0, 5, 7, 12, 17]
        #expect(ChordMode.sus4.semitoneOffset(for: 0, totalPartials: 3) == 0)
        #expect(ChordMode.sus4.semitoneOffset(for: 1, totalPartials: 3) == 5)
        #expect(ChordMode.sus4.semitoneOffset(for: 2, totalPartials: 3) == 7)
    }

    @Test func voiceFrequenciesTransposedInRender() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.chordMode = .minor
        p.unisonVoices = 3
        p.unisonDetune = 0.0 // no detune jitter, pure chord frequencies
        p.portamento = 0.0
        engine.preset = p
        engine.applyPresetForTesting()

        let baseFreq = AudioMath.midiToFrequency(60) // C4 ~261.63 Hz
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var freqs: [Double] = []
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 {
                freqs.append(engine.voices[i].targetFrequency)
            }
        }
        freqs.sort()

        #expect(freqs.count == 3, "Expected 3 unison partial voices, got \(freqs.count)")
        if freqs.count == 3 {
            let expectedRoot = baseFreq
            let expectedThird = baseFreq * pow(2.0, 3.0 / 12.0)
            let expectedFifth = baseFreq * pow(2.0, 7.0 / 12.0)

            #expect(abs(freqs[0] - expectedRoot) < 0.01, "Root mismatch: \(freqs[0]) vs \(expectedRoot)")
            #expect(abs(freqs[1] - expectedThird) < 0.01, "Minor 3rd mismatch: \(freqs[1]) vs \(expectedThird)")
            #expect(abs(freqs[2] - expectedFifth) < 0.01, "Fifth mismatch: \(freqs[2]) vs \(expectedFifth)")
        }
    }

    @Test func initGoldenHashPreserved() {
        let p = SynthPreset.defaultPreset
        let hash = InitGoldenTests.renderHash(p)
        #expect(hash == InitGoldenTests.golden["Init"], "Init golden hash changed: 0x\(String(hash, radix: 16))")
    }
}
