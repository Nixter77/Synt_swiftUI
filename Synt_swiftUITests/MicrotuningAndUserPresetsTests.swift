//
//  MicrotuningAndUserPresetsTests.swift
//  Synt_swiftUITests
//
//  Stage 4: Microtuning (.scl) parser, AU user presets and parameter tree grouping.
//

import Testing
import Foundation
import AudioToolbox
@testable import SynthCore

@Suite struct MicrotuningAndUserPresetsTests {

    @Test func scalaParserParsesCommentsDescriptionAndPitches() throws {
        let sclContent = """
        ! 12-EDO.scl
        ! An equal-tempered scale with 12 notes per octave
        Equal Temperament 12
        12
        ! Pitch entries
        100.0
        200.0
        300.0
        400.0
        500.0
        600.0
        700.0
        800.0
        900.0
        1000.0
        1100.0
        2/1
        """

        let scale = try ScalaParser.parse(sclContent)
        #expect(scale.description == "Equal Temperament 12")
        #expect(scale.noteCount == 12)
        #expect(scale.ratios.count == 12)
        #expect(abs(scale.ratios[0] - pow(2.0, 100.0 / 1200.0)) < 1e-6)
        #expect(abs(scale.ratios[11] - 2.0) < 1e-6)
    }

    @Test func scalaParserParsesJustRatiosAndCents() throws {
        let scl = """
        ! 5-limit just intonation
        Just Intonation Pentatonic
        5
        9/8
        5/4
        3/2
        5/3
        2/1
        """

        let scale = try ScalaParser.parse(scl)
        #expect(scale.noteCount == 5)
        #expect(abs(scale.ratios[0] - 1.125) < 1e-6)
        #expect(abs(scale.ratios[1] - 1.250) < 1e-6)
        #expect(abs(scale.ratios[2] - 1.500) < 1e-6)
        #expect(abs(scale.ratios[4] - 2.000) < 1e-6)
    }

    @Test func scalaParserThrowsExpectedErrorsOnCorruptInputs() {
        #expect(throws: ScalaParseError.emptyFile) {
            _ = try ScalaParser.parse("")
        }

        #expect(throws: ScalaParseError.missingNoteCount) {
            _ = try ScalaParser.parse("! only description\nScale Description Only")
        }

        #expect(throws: ScalaParseError.invalidNoteCount("not_a_number")) {
            _ = try ScalaParser.parse("Description\nnot_a_number\n100.0")
        }

        #expect(throws: ScalaParseError.insufficientPitches(expected: 3, found: 1)) {
            _ = try ScalaParser.parse("Description\n3\n100.0")
        }

        #expect(throws: ScalaParseError.invalidPitch("invalid_pitch")) {
            _ = try ScalaParser.parse("Description\n1\ninvalid_pitch")
        }
    }

    @Test func frequencyTableMatches12TETAndAltersPitchWhenApplied() throws {
        let scl12TET = """
        ! 12-TET
        12-TET Standard
        12
        100.0
        200.0
        300.0
        400.0
        500.0
        600.0
        700.0
        800.0
        900.0
        1000.0
        1100.0
        1200.0
        """
        let scale = try ScalaParser.parse(scl12TET)
        let table = ScalaParser.makeFrequencyTable(scale: scale)

        // Middle C (note 60) and A4 (note 69) should match standard frequencies within 0.01 Hz
        let middleC = table[60]
        let a4 = table[69]
        #expect(abs(middleC - 261.625) < 0.05)
        #expect(abs(a4 - 440.0) < 0.05)

        // Apply custom microtuning to engine
        let engine = AudioEngine()
        var custom = table
        // Detune MIDI note 60 by +50 Hz
        custom[60] = 311.625
        engine.customTuningTable = custom

        #expect(engine.noteToFrequency(60) == 311.625)
        #expect(abs(engine.noteToFrequency(69) - 440.0) < 0.05)

        // Reset custom tuning
        engine.customTuningTable = nil
        #expect(abs(engine.noteToFrequency(60) - 261.625) < 0.05)
    }

    @Test func auAudioUnitUserPresetsRoundTrip() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x53796e74, // 'Synt'
            componentManufacturer: 0x4e697872, // 'Nixr'
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: desc, options: [])
        #expect(unit.supportsUserPresets)

        let testPresetName = "TestUserPatch_\(UUID().uuidString.prefix(6))"
        let auPreset = AUAudioUnitPreset()
        auPreset.name = testPresetName

        unit.engine.preset.filterCutoff = 1337.0
        try unit.saveUserPreset(auPreset)

        let userList = unit.userPresets
        #expect(userList.contains(where: { $0.name == testPresetName }))

        let state = try unit.presetState(for: auPreset)
        let data = try #require(state[SyntAudioUnit.statePresetKey] as? Data)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(decoded.name == testPresetName)
        #expect(decoded.filterCutoff == 1337.0)

        // Delete user preset
        try unit.deleteUserPreset(auPreset)
        #expect(!unit.userPresets.contains(where: { $0.name == testPresetName }))
    }

    @Test func parameterTreeHasLogarithmicFlagsOnFrequencies() throws {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x53796e74,
            componentManufacturer: 0x4e697872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: desc, options: [])
        let tree = try #require(unit.parameterTree)

        let cutoff = try #require(tree.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue))
        #expect(cutoff.flags.contains(.flag_DisplayLogarithmic))

        let eqLow = try #require(tree.parameter(withAddress: SynthParameterAddress.eqLowFreq.rawValue))
        #expect(eqLow.flags.contains(.flag_DisplayLogarithmic))

        let eqMid = try #require(tree.parameter(withAddress: SynthParameterAddress.eqMidFreq.rawValue))
        #expect(eqMid.flags.contains(.flag_DisplayLogarithmic))

        let eqHigh = try #require(tree.parameter(withAddress: SynthParameterAddress.eqHighFreq.rawValue))
        #expect(eqHigh.flags.contains(.flag_DisplayLogarithmic))

        let phaserCenter = try #require(tree.parameter(withAddress: SynthParameterAddress.phaserCenterFrequency.rawValue))
        #expect(phaserCenter.flags.contains(.flag_DisplayLogarithmic))
    }
}
