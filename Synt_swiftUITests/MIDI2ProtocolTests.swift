//
//  MIDI2ProtocolTests.swift
//  SYNT_68 S4: setting-gated audioUnitMIDIProtocol, default OFF. UMP fixtures.
//  Logic manual check = KEEP ME IN (nixter).
//

import AudioToolbox
import CoreMIDI
import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct MIDI2ProtocolTests {
    private func makeUnit() throws -> SyntAudioUnit {
        // aumu / Synt / Nixr — same codes as SyntAudioUnitStateTests.
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return try SyntAudioUnit(componentDescription: desc)
    }

    @Test func defaultProtocolIsMIDI1() throws {
        let unit = try makeUnit()
        #expect(!unit.midi2ProtocolEnabled)
        #expect(unit.audioUnitMIDIProtocol == ._1_0)
        #expect(!PerformanceSettings.storedMIDI2Protocol())
    }

    @Test func enablingFlagAdvertisesMIDI2() throws {
        let unit = try makeUnit()
        unit.midi2ProtocolEnabled = true
        #expect(unit.audioUnitMIDIProtocol == ._2_0)
        unit.midi2ProtocolEnabled = false
        #expect(unit.audioUnitMIDIProtocol == ._1_0)
    }

    @Test func fullStateRoundTripsMIDI2FlagWithoutStickyDefaults() throws {
        let unit = try makeUnit()
        unit.midi2ProtocolEnabled = true
        let saved = unit.fullState
        #expect(saved?[PerformanceSettings.midi2StateKey] as? Bool == true)

        let unit2 = try makeUnit()
        #expect(!unit2.midi2ProtocolEnabled)
        unit2.fullState = saved
        #expect(unit2.midi2ProtocolEnabled)
        #expect(unit2.audioUnitMIDIProtocol == ._2_0)
        // Unit-test host must not write UserDefaults.
        #expect(!PerformanceSettings.storedMIDI2Protocol())
    }

    @Test func umpMidi2NoteOnFixtureKeepsSixteenBitVelocity() {
        // UMP type 4, note-on ch0 note 60, velocity 0x8000 (≈0.5)
        let message = SyntRenderContext.midi2NoteMessage(0x4090_3C00, 0x8000_0000)
        guard case let .noteOn(note, velocity, channel)? = message else {
            Issue.record("expected MIDI 2.0 note-on from UMP fixture")
            return
        }
        #expect(note == 60)
        #expect(channel == 0)
        #expect(abs(velocity - 0.5) < 1e-4)
        #expect(AudioEngine.command(for: message!) == .keyDown(midiNote: 60, velocity: velocity))
    }

    @Test func umpMidi2NoteOffFixtureKeepsReleaseVelocity() {
        let message = SyntRenderContext.midi2NoteMessage(0x4080_3C00, 0x4000_0000)
        let expected = Float(0x4000) / 65535
        #expect(message == .noteOff(note: 60, velocity: expected, channel: 0))
    }

    @Test func umpMidi1ChannelVoiceStillParsesWhenProtocolFlagOff() throws {
        let unit = try makeUnit()
        #expect(unit.audioUnitMIDIProtocol == ._1_0)
        // Existing MIDI 1.0 UMP type 2 note-on must still schedule.
        let engine = unit.engine
        var on: [UInt8] = [0x90, 60, 100]
        engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        let l = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { l.deallocate(); r.deallocate() }
        engine.render(frames: 64, intoL: l, intoR: r)
        #expect(engine.voices.contains { $0.isActive && $0.midiNote == 60 })
    }
}
