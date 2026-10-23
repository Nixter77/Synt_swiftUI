//
//  Stage16Stage2Tests.swift
//  SYNT_16 Stage 2: R13-2 (MCM switches zone), R13-3 (MCM resets 48/2),
//  MCM with MPE off stays ignored (documented), R13-9 (master RPN range not saved in preset).
//

import XCTest
@testable import SynthCore

final class Stage16Stage2Tests: XCTestCase {
    private func route(_ e: AudioEngine, cc: UInt8, value: UInt8, channel: UInt8) {
        let msg = MIDIMessage.controlChange(controller: cc, value: value, channel: channel)
        if let cmd = AudioEngine.command(for: msg, mpeEnabled: e.cachedMpeEnabled, zone: e.cachedMpeZone,
                                         memberCount: e.cachedMpeMemberChannelCount) {
            e.handleCommand(cmd)
        }
    }
    private func rpn(_ e: AudioEngine, channel: UInt8, rpn: UInt8, value: UInt8) {
        route(e, cc: 101, value: 0, channel: channel)
        route(e, cc: 100, value: rpn, channel: channel)
        route(e, cc: 6, value: value, channel: channel)
    }
    private func mpeEngine() -> AudioEngine {
        let e = AudioEngine(coreOnly: true)
        e.preset.mpeEnabled = true
        XCTAssertTrue(e.cachedMpeEnabled)
        return e
    }

    /// Lower zone N=10: an upper-zone MCM on ch16 must get through and switch the zone.
    func testR13_2_MCMOnChannel16SwitchesFromLowerZone() {
        let e = mpeEngine()
        rpn(e, channel: 0, rpn: 6, value: 10)
        XCTAssertEqual(e.cachedMpeZone, .lower)
        rpn(e, channel: 15, rpn: 6, value: 7)
        XCTAssertEqual(e.cachedMpeZone, .upper)
        XCTAssertEqual(e.cachedMpeMemberChannelCount, 7)
    }

    /// Upper zone N<15: a lower-zone MCM on ch1 must get through.
    func testR13_2_MCMOnChannel1SwitchesFromUpperZone() {
        let e = mpeEngine()
        rpn(e, channel: 15, rpn: 6, value: 5)
        XCTAssertEqual(e.cachedMpeZone, .upper)
        rpn(e, channel: 0, rpn: 6, value: 12)
        XCTAssertEqual(e.cachedMpeZone, .lower)
        XCTAssertEqual(e.cachedMpeMemberChannelCount, 12)
    }

    /// MCM only from ch1/ch16; RPN 0 from outside the zone does not change the member range.
    func testR13_2_RPNFromOutsideZoneIgnored() {
        let e = mpeEngine()
        rpn(e, channel: 0, rpn: 6, value: 4)          // lower, members ch2…ch5
        e.handleCommand(.mpeControlChange(channel: 9, cc: 101, value: 0))
        e.handleCommand(.mpeControlChange(channel: 9, cc: 100, value: 6))
        e.handleCommand(.mpeControlChange(channel: 9, cc: 6, value: 2))
        XCTAssertEqual(e.cachedMpeMemberChannelCount, 4, "MCM is valid only on ch1/ch16")
        e.handleCommand(.mpeControlChange(channel: 9, cc: 101, value: 0))
        e.handleCommand(.mpeControlChange(channel: 9, cc: 100, value: 0))
        e.handleCommand(.mpeControlChange(channel: 9, cc: 6, value: 12))
        XCTAssertEqual(e.cachedMpePitchBendRange, 48)
    }

    /// R13-3: MCM resets member range to 48 and master range to 2.
    func testR13_3_MCMResetsBendRanges() {
        let e = mpeEngine()
        rpn(e, channel: 0, rpn: 6, value: 15)
        rpn(e, channel: 1, rpn: 0, value: 12)
        rpn(e, channel: 0, rpn: 0, value: 7)
        XCTAssertEqual(e.cachedMpePitchBendRange, 12)
        XCTAssertEqual(e.cachedPitchBendRange, 7)
        e.handleCommand(.mpePitchBend(channel: 3, value: 0.5))
        rpn(e, channel: 0, rpn: 6, value: 15)
        XCTAssertEqual(e.cachedMpePitchBendRange, 48)
        XCTAssertEqual(e.cachedPitchBendRange, 2)
        XCTAssertEqual(e.mpeChannelStates[3].pitchBendMultiplier, 4, accuracy: 1e-9, "multipliers follow the reset range")
    }

    /// Documented decision: with MPE off, MCM does not switch MPE on (off by default; MIDI-learn intact).
    func testMCMWithMPEOffDoesNotEnableMPE() {
        let e = AudioEngine(coreOnly: true)
        XCTAssertFalse(e.cachedMpeEnabled)
        rpn(e, channel: 0, rpn: 6, value: 15)
        XCTAssertFalse(e.cachedMpeEnabled)
        XCTAssertFalse(e.pollMPEConfigMailbox())
    }

    /// R13-9: master RPN 0 is never written into the (savable) preset.
    func testR13_9_MasterRPNRangeNotSavedInPreset() throws {
        let e = mpeEngine()
        let before = e.preset.pitchBendRange
        rpn(e, channel: 0, rpn: 0, value: 9)
        XCTAssertEqual(e.cachedPitchBendRange, 9)
        e.pollMPEConfigMailbox()
        XCTAssertEqual(e.preset.pitchBendRange, before)
        XCTAssertEqual(e.controllerMasterPitchBendRange, 9)
        let saved = try JSONDecoder().decode(SynthPreset.self, from: JSONEncoder().encode(e.preset))
        XCTAssertEqual(saved.pitchBendRange, before)
        e.preset.filterCutoff = 600    // snapshot repeats the host value → controller master range kept
        XCTAssertEqual(e.cachedPitchBendRange, 9)
    }
}
