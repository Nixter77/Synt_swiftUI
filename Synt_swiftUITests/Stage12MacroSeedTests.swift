//
//  Stage12MacroSeedTests.swift
//  Synt_swiftUITests
//
//  Unit tests covering Stage 2:
//  - randomSeed in preset (decodeIfPresent, reproducible note-to-note random phase & S&H on load).
//  - Performance macros 5-8 (AU addresses 154-157, mod matrix, UI, parameter store).
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage12MacroSeedTests {
    @Test func randomSeedJSONDecoding() throws {
        // Missing randomSeed in legacy JSON
        let legacyJSON = """
        {
            "name": "LegacyPatch",
            "category": "Lead"
        }
        """.data(using: .utf8)!

        let decodedLegacy = try JSONDecoder().decode(SynthPreset.self, from: legacyJSON)
        #expect(decodedLegacy.randomSeed == nil)
        #expect(decodedLegacy.macro5 == 0.0)
        #expect(decodedLegacy.macro6 == 0.0)
        #expect(decodedLegacy.macro7 == 0.0)
        #expect(decodedLegacy.macro8 == 0.0)

        // Present randomSeed and macros 5-8
        var preset = SynthPreset.defaultPreset
        preset.name = "SeededPatch"
        preset.randomSeed = 0xABCD1234
        preset.macro5 = 0.5
        preset.macro6 = -0.75
        preset.macro7 = 0.25
        preset.macro8 = -0.1

        let data = try JSONEncoder().encode(preset)
        let roundtrip = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(roundtrip.randomSeed == 0xABCD1234)
        #expect(roundtrip.macro5 == 0.5)
        #expect(roundtrip.macro6 == -0.75)
        #expect(roundtrip.macro7 == 0.25)
        #expect(roundtrip.macro8 == -0.1)
    }

    @Test func randomSeedProvidesReproducibleOscPhaseAndRandVal() {
        let engine1 = AudioEngine(coreOnly: true)
        engine1.prepare(sampleRate: 44100, maxFrames: 256)
        var p = SynthPreset.defaultPreset
        p.oscPhaseMode = .randomPerNote
        p.randomSeed = 0x54321
        engine1.preset = p

        let engine2 = AudioEngine(coreOnly: true)
        engine2.prepare(sampleRate: 44100, maxFrames: 256)
        engine2.preset = p

        // Note 1: both engines must select identical random phase and voice random values
        engine1.handleNoteOn(midiNote: 60, velocity: 1.0)
        engine2.handleNoteOn(midiNote: 60, velocity: 1.0)

        #expect(engine1.voices[0].phase == engine2.voices[0].phase)
        #expect(engine1.voices[0].randomValue == engine2.voices[0].randomValue)

        for _ in 0..<200 {
            let (l1, r1) = engine1.renderOneSample()
            let (l2, r2) = engine2.renderOneSample()
            #expect(l1 == l2)
            #expect(r1 == r2)
        }

        // Note 2: next note in sequence also matches identically
        engine1.handleNoteOn(midiNote: 64, velocity: 0.8)
        engine2.handleNoteOn(midiNote: 64, velocity: 0.8)

        #expect(engine1.voices[1].phase == engine2.voices[1].phase)
        #expect(engine1.voices[1].randomValue == engine2.voices[1].randomValue)

        for _ in 0..<200 {
            let (l1, r1) = engine1.renderOneSample()
            let (l2, r2) = engine2.renderOneSample()
            #expect(l1 == l2)
            #expect(r1 == r2)
        }
    }

    @Test func randomSeedProvidesReproducibleLFOSampleAndHold() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)

        var p = SynthPreset.defaultPreset
        p.lfoEnabled = true
        p.lfoWaveform = .noise // Sample & Hold
        p.lfoRate = 20.0 // Fast cycles to trigger S&H updates
        p.randomSeed = 0x998877
        engine.preset = p

        var run1: [Float] = []
        for _ in 0..<500 {
            let (l, _) = engine.renderOneSample()
            run1.append(l)
        }

        // Reload preset
        engine.preset = p
        var run2: [Float] = []
        for _ in 0..<500 {
            let (l, _) = engine.renderOneSample()
            run2.append(l)
        }

        #expect(run1 == run2)
    }

    @Test func macroAddressesAndRanges() {
        #expect(SynthParameterAddress.macro5.rawValue == 154)
        #expect(SynthParameterAddress.macro6.rawValue == 155)
        #expect(SynthParameterAddress.macro7.rawValue == 156)
        #expect(SynthParameterAddress.macro8.rawValue == 157)

        for addr in [SynthParameterAddress.macro5, .macro6, .macro7, .macro8] {
            #expect(addr.min == -1)
            #expect(addr.max == 1)
            #expect(addr.clamped(0.0) == 0.0)
        }
    }

    @Test func macroAutomationAndModMatrixRouting() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)

        var p = SynthPreset.defaultPreset
        p.filterCutoff = 2000
        p.filterResonance = 0.0
        // Route Macro 5 to Cutoff
        p.modMatrix = [
            ModMatrixEntry(source: .macro5, destination: .cutoff, amount: 0.5)
        ]
        p.macro5 = 0.0
        engine.preset = p

        #expect(engine.cachedMacro5 == 0.0)

        // Automate Macro 5 via RT address
        engine.applyAddressedParameterRT(id: SynthParameterAddress.macro5.rawValue, value: 0.8)
        #expect(engine.cachedMacro5 == 0.8)
        #expect(engine.addressedParameterValue(.macro5) == 0.8)

        // Adopt on main thread
        engine.adoptAddressedParameterOnMain(id: SynthParameterAddress.macro5.rawValue, value: 0.8)
        #expect(engine.preset.macro5 == 0.8)

        // Verify Macros 6, 7, 8 apply similarly
        engine.applyAddressedParameterRT(id: SynthParameterAddress.macro6.rawValue, value: -0.6)
        #expect(engine.cachedMacro6 == -0.6)

        engine.applyAddressedParameterRT(id: SynthParameterAddress.macro7.rawValue, value: 0.4)
        #expect(engine.cachedMacro7 == 0.4)

        engine.applyAddressedParameterRT(id: SynthParameterAddress.macro8.rawValue, value: -0.2)
        #expect(engine.cachedMacro8 == -0.2)
    }

    @Test func modSourceEnumIncludesAllMacrosAtEnd() {
        let sources = ModSource.allCases
        #expect(sources.contains(.macro5))
        #expect(sources.contains(.macro6))
        #expect(sources.contains(.macro7))
        #expect(sources.contains(.macro8))

        // New enum cases must be at the end
        let count = sources.count
        #expect(sources[count - 4] == .macro5)
        #expect(sources[count - 3] == .macro6)
        #expect(sources[count - 2] == .macro7)
        #expect(sources[count - 1] == .macro8)
    }
}
