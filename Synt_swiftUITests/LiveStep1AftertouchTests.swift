//
//  LiveStep1AftertouchTests.swift
//  Synt_swiftUITests
//
//  Tests for Step 1: Channel Pressure (0xD0) and Polyphonic Key Pressure (0xA0)
//

import Testing
@testable import SynthCore
import Foundation
@testable import Synt_swiftUI

@MainActor
struct LiveStep1AftertouchTests {

    @Test func channelPressureAndPolyPressureByteParsing() {
        var parser = MIDIByteParser()

        // 0xD0: Channel Pressure on channel 2 with value 64
        let d0Bytes: [UInt8] = [0xD2, 64]
        let d0Messages = parser.parse(d0Bytes)
        #expect(d0Messages.count == 1)
        if case let .channelPressure(pressure, channel) = d0Messages[0] {
            #expect(channel == 2)
            #expect(abs(pressure - Float(64) / 127.0) < 0.001)
        } else {
            Issue.record("Expected channelPressure message")
        }

        // 0xA0: Polyphonic Pressure on channel 1 for note 60 with pressure 100
        let a0Bytes: [UInt8] = [0xA1, 60, 100]
        let a0Messages = parser.parse(a0Bytes)
        #expect(a0Messages.count == 1)
        if case let .polyPressure(note, pressure, channel) = a0Messages[0] {
            #expect(channel == 1)
            #expect(note == 60)
            #expect(abs(pressure - Float(100) / 127.0) < 0.001)
        } else {
            Issue.record("Expected polyPressure message")
        }
    }

    @Test func channelPressureAndPolyPressureUMPParsing() {
        // UMP MIDI 1.0 Channel Voice (Type 0x2):
        // [Message Type 4b: 0x2][Group 4b: 0x0][Status 8b: 0xD3][Data1 8b: 80][Data2 8b: 0]
        let d0Word: UInt32 = (0x2 << 28) | (0xD3 << 16) | (80 << 8) | 0
        let d0Msg = MIDIDecode.ump(d0Word)
        if case let .channelPressure(pressure, channel) = d0Msg {
            #expect(channel == 3)
            #expect(abs(pressure - Float(80) / 127.0) < 0.001)
        } else {
            Issue.record("Expected channelPressure from UMP word")
        }

        // UMP 0xA0: [0x2][0x0][0xA4][Note: 72][Pressure: 120]
        let a0Word: UInt32 = (0x2 << 28) | (0xA4 << 16) | (72 << 8) | 120
        let a0Msg = MIDIDecode.ump(a0Word)
        if case let .polyPressure(note, pressure, channel) = a0Msg {
            #expect(channel == 4)
            #expect(note == 72)
            #expect(abs(pressure - Float(120) / 127.0) < 0.001)
        } else {
            Issue.record("Expected polyPressure from UMP word")
        }
    }

    @Test func aftertouchModulatesFilterCutoffSmoothly() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.filterCutoff = 1000.0
        // Route Aftertouch -> Filter Cutoff (+1.0 = +4 octaves)
        preset.modMatrix = [
            ModMatrixEntry(source: .aftertouch, destination: .cutoff, amount: 1.0)
        ]
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.resetPatchStateRT()

        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()

        // Render initially with 0 aftertouch
        _ = engine.renderFramesForTesting(500)
        let initialCutoff = engine.filterL.cutoff
        #expect(abs(initialCutoff - 1000.0) < 50.0)

        // Now send full channel pressure aftertouch
        engine.aftertouch(1.0)
        engine.processCommandsForTesting()

        // Render 2000 samples for one-pole smoothing to advance
        _ = engine.renderFramesForTesting(2000)
        let modulatedCutoff = engine.filterL.cutoff
        // 1000 Hz * 2^(1.0 * 4) = 16000 Hz
        #expect(modulatedCutoff > 10000.0)

        // Release aftertouch
        engine.aftertouch(0.0)
        engine.processCommandsForTesting()
        _ = engine.renderFramesForTesting(3000)
        let restoredCutoff = engine.filterL.cutoff
        #expect(abs(restoredCutoff - 1000.0) < 100.0)
    }

    @Test func polyAftertouchAffectsTargetNoteVoice() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.modMatrix = [
            ModMatrixEntry(source: .aftertouch, destination: .amp, amount: -0.5)
        ]
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        // Apply poly pressure to note 60
        engine.polyAftertouch(midiNote: 60, pressure: 0.9)
        engine.processCommandsForTesting()

        var foundPoly = false
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 {
                #expect(abs(engine.voices[i].polyAftertouch - 0.9) < 0.001)
                foundPoly = true
            }
        }
        #expect(foundPoly)
    }

    @Test func initGoldenHashPreserved() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        #expect(hash == InitGoldenTests.golden["Init"], "Init golden hash changed: 0x\(String(hash, radix: 16))")
    }
}
