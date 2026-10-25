//
//  Stage13MPETests.swift
//  Synt_swiftUITests
//
//  Stage 4 tests for GROK_BUILD_TASKS_SYNT_13:
//  - Parameter address 163 (mpeEnabled) metadata and preset roundtrip
//  - MIDI command parsing: legacy vs MPE member channels (1..15) and master channel (0)
//  - Per-note independent pitch bend on member channels
//  - Per-voice pressure and CC74 timbre storage on member channels
//  - Golden hash bit-exactness when mpeEnabled = false
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage13MPETests: XCTestCase {

    func testMpeParameterAddressMetadataAndPresetDefaults() {
        let addr = SynthParameterAddress.mpeEnabled
        XCTAssertEqual(addr.rawValue, 163)
        XCTAssertEqual(addr.identifier, "mpeEnabled")
        XCTAssertEqual(addr.displayName, "MPE Enabled")
        XCTAssertEqual(addr.min, 0.0)
        XCTAssertEqual(addr.max, 1.0)

        var preset = SynthPreset.defaultPreset
        XCTAssertFalse(preset.mpeEnabled)

        // ParameterValues roundtrip
        preset.setParameterValue(1.0, for: .mpeEnabled)
        XCTAssertTrue(preset.mpeEnabled)
        XCTAssertEqual(preset.parameterValue(for: .mpeEnabled), 1.0)

        preset.setParameterValue(0.0, for: .mpeEnabled)
        XCTAssertFalse(preset.mpeEnabled)
        XCTAssertEqual(preset.parameterValue(for: .mpeEnabled), 0.0)
    }

    func testMIDICommandParsingLegacyVsMPE() {
        // When MPE is disabled: all channels route to standard commands
        let noteOnMsg = MIDIMessage.noteOn(note: 60, velocity: 0.8, channel: 1)
        let noteOffMsg = MIDIMessage.noteOff(note: 60, channel: 1)
        let bendMsg = MIDIMessage.pitchBend(0.5, channel: 1)
        let pressureMsg = MIDIMessage.channelPressure(0.7, channel: 1)
        let cc74Msg = MIDIMessage.controlChange(controller: 74, value: 64, channel: 1)

        XCTAssertEqual(AudioEngine.command(for: noteOnMsg, mpeEnabled: false), .keyDown(midiNote: 60, velocity: 0.8))
        XCTAssertEqual(AudioEngine.command(for: noteOffMsg, mpeEnabled: false), .keyUp(midiNote: 60))
        XCTAssertEqual(AudioEngine.command(for: bendMsg, mpeEnabled: false), .setPitchBend(0.5))
        XCTAssertEqual(AudioEngine.command(for: pressureMsg, mpeEnabled: false), .setAftertouch(0.7))
        XCTAssertEqual(AudioEngine.command(for: cc74Msg, mpeEnabled: false), .controlChange(cc: 74, value: 64))

        // When MPE is enabled: member channel 1 routes to MPE commands
        XCTAssertEqual(AudioEngine.command(for: noteOnMsg, mpeEnabled: true), .mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 1))
        XCTAssertEqual(AudioEngine.command(for: noteOffMsg, mpeEnabled: true), .mpeKeyUp(midiNote: 60, channel: 1))
        XCTAssertEqual(AudioEngine.command(for: bendMsg, mpeEnabled: true), .mpePitchBend(channel: 1, value: 0.5))
        XCTAssertEqual(AudioEngine.command(for: pressureMsg, mpeEnabled: true), .mpePressure(channel: 1, value: 0.7))
        let expectedTimbre = Float(64) / 127.0
        XCTAssertEqual(AudioEngine.command(for: cc74Msg, mpeEnabled: true), .mpeTimbre(channel: 1, value: expectedTimbre))

        // When MPE is enabled: master channel 0 routes to global commands
        let masterBendMsg = MIDIMessage.pitchBend(0.3, channel: 0)
        let masterPressureMsg = MIDIMessage.channelPressure(0.4, channel: 0)
        XCTAssertEqual(AudioEngine.command(for: masterBendMsg, mpeEnabled: true), .setPitchBend(0.3))
        XCTAssertEqual(AudioEngine.command(for: masterPressureMsg, mpeEnabled: true), .setAftertouch(0.4))
    }

    func testIndependentPerNotePitchBend() {
        let engine = AudioEngine()
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly
        engine.preset.unisonVoices = 1
        engine.applyPreset()
        engine.cachedMpeEnabled = true // Ensure cached flag is set

        // Note A on channel 1 (MIDI ch 2), Note B on channel 2 (MIDI ch 3)
        engine.handleCommand(.mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 1))
        engine.handleCommand(.mpeKeyDown(midiNote: 64, velocity: 0.8, channel: 2))

        var voiceAIdx: Int?
        var voiceBIdx: Int?
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 && engine.voices[i].midiChannel == 1 {
                voiceAIdx = i
            }
            if engine.voices[i].isActive && engine.voices[i].midiNote == 64 && engine.voices[i].midiChannel == 2 {
                voiceBIdx = i
            }
        }

        guard let idxA = voiceAIdx, let idxB = voiceBIdx else {
            XCTFail("Voices A and B were not created with expected channel tags")
            return
        }

        XCTAssertEqual(engine.voices[idxA].mpePitchBendMultiplier, 1.0)
        XCTAssertEqual(engine.voices[idxB].mpePitchBendMultiplier, 1.0)

        // Apply pitch bend +1.0 (full bend up) on channel 1 only
        engine.handleCommand(.mpePitchBend(channel: 1, value: 1.0))

        // Bend range is 48 semitones -> exp2(1.0 * 48 / 12) = exp2(4) = 16.0
        let expectedMulA = exp2(Double(1.0) * Double(engine.cachedMpePitchBendRange) / 12.0)
        XCTAssertEqual(engine.voices[idxA].mpePitchBendMultiplier, expectedMulA, accuracy: 1e-6)
        // Voice B on channel 2 must be completely unchanged!
        XCTAssertEqual(engine.voices[idxB].mpePitchBendMultiplier, 1.0)

        // Now bend channel 2 down (-0.5)
        engine.handleCommand(.mpePitchBend(channel: 2, value: -0.5))
        let expectedMulB = exp2(Double(-0.5) * Double(engine.cachedMpePitchBendRange) / 12.0)
        XCTAssertEqual(engine.voices[idxB].mpePitchBendMultiplier, expectedMulB, accuracy: 1e-6)
        // Voice A remains at expectedMulA
        XCTAssertEqual(engine.voices[idxA].mpePitchBendMultiplier, expectedMulA, accuracy: 1e-6)

        // Note off for note A on channel 1 only releases note A
        engine.handleCommand(.mpeKeyUp(midiNote: 60, channel: 1))
        XCTAssertTrue(engine.voices[idxA].isReleasing)
        XCTAssertFalse(engine.voices[idxB].isReleasing)
    }

    func testPerVoicePressureAndTimbreStorage() {
        let engine = AudioEngine()
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly
        engine.preset.unisonVoices = 1
        engine.applyPreset()
        engine.cachedMpeEnabled = true

        engine.handleCommand(.mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 1))
        engine.handleCommand(.mpeKeyDown(midiNote: 64, velocity: 0.8, channel: 2))

        var idxA: Int = -1
        var idxB: Int = -1
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 { idxA = i }
            if engine.voices[i].isActive && engine.voices[i].midiNote == 64 { idxB = i }
        }

        XCTAssertTrue(idxA >= 0 && idxB >= 0)

        engine.handleCommand(.mpePressure(channel: 1, value: 0.75))
        engine.handleCommand(.mpeTimbre(channel: 1, value: 0.6))

        XCTAssertEqual(engine.voices[idxA].mpePressure, 0.75)
        XCTAssertEqual(engine.voices[idxA].mpeTimbre, 0.6)
        XCTAssertEqual(engine.voices[idxB].mpePressure, 0.0)
        XCTAssertEqual(engine.voices[idxB].mpeTimbre, 0.0)
    }

    @MainActor func testGoldenHarnessBitExactness() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        XCTAssertEqual(hash, 0xd1b3635203a4799e, "Golden FNV-1a hash must match 0xd1b3635203a4799e bit-identically")
    }
}
