//
//  MIDIMessageParserTests.swift
//  Pure MIDI decoding (bytes + UMP), CC123/CC120 routing, and a live
//  CoreMIDI virtual source → MIDIHandler → engine round trip.
//

import Foundation
import CoreMIDI
import Testing
@testable import Synt_swiftUI

struct MIDIMessageParserTests {

    // MARK: - Byte stream

    @Test func noteOnOffAndVelocityZeroIsOff() {
        var p = MIDIByteParser()
        #expect(p.parse([0x90, 60, 127]) == [.noteOn(note: 60, velocity: 1, channel: 0)])
        #expect(p.parse([0x93, 64, 0]) == [.noteOff(note: 64, channel: 3)])
        #expect(p.parse([0x8F, 72, 40]) == [.noteOff(note: 72, channel: 15)])
    }

    @Test func velocityMapsLinearlyToAmplitude() {
        var p = MIDIByteParser()
        guard case let .noteOn(_, v, _)? = p.parse([0x90, 60, 64]).first else {
            Issue.record("no note on"); return
        }
        #expect(abs(v - 64.0 / 127.0) < 1e-6)
    }

    @Test func pitchBendCenterAndExtremes() {
        #expect(MIDIDecode.normalizedPitchBend(lsb: 0x00, msb: 0x40) == 0)
        #expect(MIDIDecode.normalizedPitchBend(lsb: 0x7F, msb: 0x7F) == 1)
        #expect(MIDIDecode.normalizedPitchBend(lsb: 0x00, msb: 0x00) == -1)
        var p = MIDIByteParser()
        #expect(p.parse([0xE1, 0x00, 0x40]) == [.pitchBend(0, channel: 1)])
    }

    @Test func controllersWheelPedalAndModeMessages() {
        var p = MIDIByteParser()
        #expect(p.parse([0xB0, 1, 127]) == [.modWheel(1, channel: 0)])
        #expect(p.parse([0xB0, 64, 63]) == [.sustain(down: false, channel: 0)])
        #expect(p.parse([0xB0, 64, 64]) == [.sustain(down: true, channel: 0)])
        #expect(p.parse([0xB0, 123, 0]) == [.allNotesOff(channel: 0)])
        #expect(p.parse([0xB0, 120, 0]) == [.allSoundOff(channel: 0)])
        #expect(p.parse([0xB0, 7, 100]) == [.controlChange(controller: 7, value: 100, channel: 0)])
    }

    @Test func runningStatusRealtimeAndSysEx() {
        var p = MIDIByteParser()
        let out = p.parse([0xF0, 0x7E, 0x01, 0xF7,       // SysEx dropped
                           0x90, 60, 100, 0xF8, 64, 100,  // clock mid-message
                           67, 0])                        // running status, vel 0
        #expect(out == [
            .noteOn(note: 60, velocity: Float(100) / 127, channel: 0),
            .noteOn(note: 64, velocity: Float(100) / 127, channel: 0),
            .noteOff(note: 67, channel: 0),
        ])
        // Data bytes with no status are ignored; program change is 1 data byte.
        var q = MIDIByteParser()
        #expect(q.parse([60, 100, 0xC0, 5, 0x90, 61, 1]).count == 2)
    }

    // MARK: - UMP (MIDI 1.0 channel voice, what CoreMIDI delivers)

    @Test func umpChannelVoiceWords() {
        #expect(MIDIDecode.ump(0x2090_3C7F) == .noteOn(note: 60, velocity: 1, channel: 0))
        #expect(MIDIDecode.ump(0x2095_3C00) == .noteOff(note: 60, channel: 5))
        #expect(MIDIDecode.ump(0x2080_3C40) == .noteOff(note: 60, channel: 0))
        #expect(MIDIDecode.ump(0x20E0_0040) == .pitchBend(0, channel: 0))
        #expect(MIDIDecode.ump(0x20B0_4000 | 127) == .sustain(down: true, channel: 0))
        #expect(MIDIDecode.ump(0x20B0_7B00) == .allNotesOff(channel: 0))
        // Group nibble is ignored; non-MIDI-1.0 types are ignored.
        #expect(MIDIDecode.ump(0x2390_3C7F) == .noteOn(note: 60, velocity: 1, channel: 0))
        #expect(MIDIDecode.ump(0x10F8_0000) == .ignored)
        #expect(MIDIDecode.ump(0x4090_3C00) == .ignored)
    }

    @Test func umpWordCountsSkipLongPackets() {
        #expect(MIDIDecode.umpWordCount(firstWord: 0x2090_3C7F) == 1)
        #expect(MIDIDecode.umpWordCount(firstWord: 0x3016_7E00) == 2)   // SysEx7
        #expect(MIDIDecode.umpWordCount(firstWord: 0x4090_3C00) == 2)   // MIDI 2.0 voice
        #expect(MIDIDecode.umpWordCount(firstWord: 0x5000_0000) == 4)
    }

    @Test func handlerSkipsSysExWordsAndStillPlays() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        // SysEx7 (2 words; 2nd word looks like a note on if misread), then a real note on.
        midi.handleUMPWordsForTesting([0x3016_7E7F, 0x2090_3B7F, 0x2090_3E64])
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(62))
        #expect(!engine.isNoteActiveForTesting(59))
    }

    // MARK: - CC123 / CC120 reach the engine

    @Test func allNotesOffUnderThePedalKeepsNotesUntilPedalUp() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 60, 100, 64, 100])   // two keys
        midi.parseMIDIBytesForTesting([0xB0, 64, 127])            // pedal down
        midi.parseMIDIBytesForTesting([0x80, 64, 0])              // 64 now pedal-held
        engine.processCommandsForTesting()
        #expect(!engine.isNoteReleasingForTesting(60))
        #expect(!engine.isNoteReleasingForTesting(64))

        // CC123 = note-off for every key: the pedal keeps both sounding.
        midi.parseMIDIBytesForTesting([0xB0, 123, 0])
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60) && !engine.isNoteReleasingForTesting(60))
        #expect(engine.isNoteActiveForTesting(64) && !engine.isNoteReleasingForTesting(64))

        midi.parseMIDIBytesForTesting([0xB0, 64, 0])              // pedal up
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
        #expect(engine.isNoteReleasingForTesting(64))
    }

    @Test func allNotesOffWithoutThePedalReleasesEveryKey() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 60, 100, 64, 100])
        engine.processCommandsForTesting()
        midi.parseMIDIBytesForTesting([0xB0, 123, 0])
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
        #expect(engine.isNoteReleasingForTesting(64))
    }

    @Test func deviceResetUnderThePedalStillReleasesEverything() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0xB0, 64, 127, 0x90, 60, 100])
        engine.processCommandsForTesting()
        midi.releaseEverything()
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
        #expect(!engine.sustainPedalDown)
    }

    @Test func allNotesOffClearsArpKeys() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .up
        engine.preset = preset
        engine.applyPresetForTesting()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 60, 100, 67, 100])
        engine.processCommandsForTesting()
        #expect(engine.heldKeysForArp.count == 2)
        midi.parseMIDIBytesForTesting([0xB0, 123, 0])
        engine.processCommandsForTesting()
        #expect(engine.heldKeysForArp.isEmpty)
    }

    @Test func allSoundOffSilencesImmediately() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 60, 100])
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        midi.parseMIDIBytesForTesting([0xB0, 120, 0])
        engine.processCommandsForTesting()
        #expect(!engine.isNoteActiveForTesting(60))
    }

    @Test func allNotesOffSurvivesAFullRing() {
        let queue = AudioCommandQueue(capacity: 4)
        for n in 0..<3 { _ = queue.push(.keyDown(midiNote: n, velocity: 1)) }
        #expect(queue.push(.allNotesOff))           // parked on the side channel
        var offs = Set<Int>()
        queue.drain(limit: 1000) { cmd in
            if case let .noteOff(n) = cmd { offs.insert(n) }
        }
        #expect(offs.count == 128)
    }

    // MARK: - Device reset runs after the MIDI ring

    @Test func deviceResetBeatsAKeyDownStillInTheMIDIRing() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0xB0, 64, 127])        // pedal down
        midi.parseMIDIBytesForTesting([0xE0, 0x7F, 0x7F])     // bend up
        midi.parseMIDIBytesForTesting([0x90, 60, 100])        // queued, not yet rendered
        midi.releaseEverything()                              // device unplugged
        engine.processCommandsForTesting()
        #expect(!engine.isNoteActiveForTesting(60) || engine.isNoteReleasingForTesting(60))
        #expect(!engine.sustainPedalDown)
        #expect(engine.pitchBendTarget == 0)
        #expect(engine.midiQueue.isEmpty)
        #expect(engine.commandQueueForTesting.isEmpty)
    }

    @Test func deviceResetReleasesNotesThatWereAlreadyPlaying() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 60, 100, 64, 100])
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        midi.releaseEverything()
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
        #expect(engine.isNoteReleasingForTesting(64))
        // A key pressed after the reset plays normally.
        midi.parseMIDIBytesForTesting([0x90, 67, 100])
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(67))
        #expect(!engine.isNoteReleasingForTesting(67))
    }

    @Test func onlySetupChangedTriggersARescan() {
        #expect(MIDIHandler.shouldRescan(for: .msgSetupChanged))
        #expect(!MIDIHandler.shouldRescan(for: .msgObjectAdded))
        #expect(!MIDIHandler.shouldRescan(for: .msgObjectRemoved))
        #expect(!MIDIHandler.shouldRescan(for: .msgPropertyChanged))
    }

    @Test func duplicateDeviceNamesAreDisambiguated() {
        #expect(MIDIHandler.uniqueNames(["KeyLab", "IAC Bus 1", "KeyLab"]) == ["KeyLab", "IAC Bus 1", "KeyLab (2)"])
    }

    // MARK: - Real MIDIEventList → handleEventList → MIDI ring → voice
    // Built with MIDIEventListInit/Add (the format CoreMIDI delivers); no client,
    // no virtual source, no device.

    @Test func eventListNoteReachesTheEngine() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)

        // Channel 16 note 61 on vel 100, a 2-word SysEx7 whose 2nd word looks
        // like a note-on for 59, then a note on for 62 in a second packet.
        sendEventList(midi, packets: [[0x209F_3D64, 0x3016_7E7F, 0x2090_3B7F], [0x2090_3E64]])
        #expect(!engine.midiQueue.isEmpty)
        #expect(engine.commandQueueForTesting.isEmpty)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(61))
        #expect(engine.isNoteActiveForTesting(62))
        #expect(!engine.isNoteActiveForTesting(59))

        sendEventList(midi, packets: [[0x208F_3D00]])
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(61))
        #expect(!engine.isNoteReleasingForTesting(62))
    }

    private func sendEventList(_ midi: MIDIHandler, packets: [[UInt32]]) {
        let byteSize = 1024
        let raw = UnsafeMutableRawPointer.allocate(byteCount: byteSize, alignment: 8)
        defer { raw.deallocate() }
        let list = raw.bindMemory(to: MIDIEventList.self, capacity: 1)
        var packet = MIDIEventListInit(list, ._1_0)
        // Distinct timestamps keep the packets separate (equal ones are merged).
        for (index, words) in packets.enumerated() {
            var w = words
            packet = MIDIEventListAdd(list, byteSize, packet, MIDITimeStamp(index + 1), w.count, &w)
        }
        #expect(list.pointee.numPackets == UInt32(packets.count))
        midi.handleEventListForTesting(list)
    }
}
