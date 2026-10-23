//
//  Stage15Stage3Tests.swift
//  SYNT_15 Stage 3: R12-3 (zone + member count drive routing), R12-5 (standalone RPN/MCM).
//

import XCTest
@testable import SynthCore

final class Stage15Stage3Tests: XCTestCase {

    private func cmd(_ m: MIDIMessage, zone: MPEZone, n: Int) -> AudioCommand? {
        AudioEngine.command(for: m, mpeEnabled: true, zone: zone, memberCount: n)
    }

    func testR12_3_LowerZoneMemberCountLimitsRouting() {
        for ch: UInt8 in 1...3 {
            XCTAssertEqual(cmd(.noteOn(note: 60, velocity: 1, channel: ch), zone: .lower, n: 3),
                           .mpeKeyDown(midiNote: 60, velocity: 1, channel: ch))
        }
        XCTAssertEqual(cmd(.noteOn(note: 60, velocity: 1, channel: 4), zone: .lower, n: 3), .keyDown(midiNote: 60, velocity: 1),
                       "channel outside the zone is not a member")
        XCTAssertEqual(cmd(.noteOn(note: 60, velocity: 1, channel: 0), zone: .lower, n: 3), .keyDown(midiNote: 60, velocity: 1))
        XCTAssertEqual(cmd(.pitchBend(0.5, channel: 5), zone: .lower, n: 3), .setPitchBend(0.5))
        XCTAssertEqual(cmd(.pitchBend(0.5, channel: 0), zone: .lower, n: 3), .setPitchBend(0.5), "master bend is global")
    }

    func testR12_3_UpperZoneMasterIsCh16AndMembersBelowIt() {
        // Upper zone, 4 members: ch12…15 (0-based 11…14), master ch16 (15).
        XCTAssertEqual(cmd(.pitchBend(0.25, channel: 15), zone: .upper, n: 4), .setPitchBend(0.25),
                       "upper-zone master bend must be global, not per-note")
        XCTAssertEqual(cmd(.channelPressure(0.4, channel: 15), zone: .upper, n: 4), .setAftertouch(0.4))
        XCTAssertEqual(cmd(.pitchBend(0.25, channel: 14), zone: .upper, n: 4), .mpePitchBend(channel: 14, value: 0.25))
        XCTAssertEqual(cmd(.pitchBend(0.25, channel: 11), zone: .upper, n: 4), .mpePitchBend(channel: 11, value: 0.25))
        XCTAssertEqual(cmd(.pitchBend(0.25, channel: 10), zone: .upper, n: 4), .setPitchBend(0.25))
        XCTAssertEqual(cmd(.pitchBend(0.25, channel: 1), zone: .upper, n: 4), .setPitchBend(0.25),
                       "ch2 is not a member of the upper zone")
        XCTAssertEqual(cmd(.noteOn(note: 64, velocity: 1, channel: 1), zone: .upper, n: 4), .keyDown(midiNote: 64, velocity: 1))
    }

    func testR12_3_ZeroMembersMeansNoPerNoteRouting() {
        XCTAssertEqual(cmd(.noteOn(note: 60, velocity: 1, channel: 1), zone: .lower, n: 0), .keyDown(midiNote: 60, velocity: 1))
    }

    private func drain(_ engine: AudioEngine) {
        for i in 0..<engine.midiScheduleCount { engine.handleCommand(engine.midiSchedule[i].command) }
        engine.midiScheduleCount = 0
    }

    func testR12_3_AURenderPathUsesCachedZone() {
        let engine = AudioEngine(coreOnly: true)
        engine.cachedMpeEnabled = true
        engine.cachedMpeZone = .upper
        engine.cachedMpeMemberChannelCount = 2
        // Note-on on ch2 (1) is outside the upper zone → global key, not per-channel state.
        var bytes: [UInt8] = [0xE1, 0x00, 0x60]   // pitch bend on ch2
        bytes.withUnsafeBufferPointer { engine.enqueueMIDI($0.baseAddress!, count: 3, sampleOffset: 0) }
        drain(engine)
        XCTAssertEqual(engine.mpeChannelStates[1].pitchBend, 0, "ch2 is not a member of a 2-channel upper zone")
        bytes = [0xEE, 0x00, 0x60]   // pitch bend on ch15 (14) → member
        bytes.withUnsafeBufferPointer { engine.enqueueMIDI($0.baseAddress!, count: 3, sampleOffset: 0) }
        drain(engine)
        XCTAssertNotEqual(engine.mpeChannelStates[14].pitchBend, 0)
    }

    /// R12-5: standalone MIDI path (MIDI thread → midiQueue) parses MCM / RPN through the shared router.
    func testR12_5_StandaloneMCMAndRPNReachRender() {
        let engine = AudioEngine(coreOnly: true)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        let midiThread = DispatchQueue(label: "fake.coremidi")
        let done = expectation(description: "midi")
        midiThread.async {
            XCTAssertTrue(engine.midiMPEControlChange(controller: 101, value: 0, channel: 0))
            XCTAssertTrue(engine.midiMPEControlChange(controller: 100, value: 6, channel: 0))
            XCTAssertTrue(engine.midiMPEControlChange(controller: 6, value: 5, channel: 0))
            XCTAssertTrue(engine.midiMPEControlChange(controller: 74, value: 127, channel: 3))
            XCTAssertFalse(engine.midiMPEControlChange(controller: 7, value: 100, channel: 0), "ordinary CC stays ordinary")
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        engine.processCommandQueue()   // render drain
        XCTAssertEqual(engine.cachedMpeMemberChannelCount, 5)
        XCTAssertEqual(engine.mpeChannelStates[3].timbre, 1, accuracy: 1e-6)
        engine.pollMPEConfigMailbox()
        XCTAssertEqual(engine.mpeMemberChannelCount, 5, "main mirror updates the standalone routing state")
        XCTAssertFalse(engine.isStandaloneMPEMember(6), "ch7 is outside a 5-member lower zone")
        XCTAssertTrue(engine.isStandaloneMPEMember(5))
    }

    func testR12_5_StandaloneRPNCCsArePlainWhenMPEOff() {
        let engine = AudioEngine(coreOnly: true)
        XCTAssertFalse(engine.midiMPEControlChange(controller: 6, value: 5, channel: 0))
        XCTAssertFalse(engine.midiMPEControlChange(controller: 74, value: 5, channel: 1))
    }
}
