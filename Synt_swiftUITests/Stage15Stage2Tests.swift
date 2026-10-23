//
//  Stage15Stage2Tests.swift
//  SYNT_15 Stage 2: R12-2 (RPN CCs stay plain CCs when MPE is off), R12-4 (master vs member RPN 0).
//

import XCTest
@testable import SynthCore

final class Stage15Stage2Tests: XCTestCase {

    private func route(_ engine: AudioEngine, cc: UInt8, value: UInt8, channel: UInt8, mpe: Bool) {
        let msg = MIDIMessage.controlChange(controller: cc, value: value, channel: channel)
        if let cmd = AudioEngine.command(for: msg, mpeEnabled: mpe) { engine.handleCommand(cmd) }
    }

    private func rpn(_ engine: AudioEngine, channel: UInt8, rpn: UInt8, value: UInt8, mpe: Bool = true) {
        route(engine, cc: 101, value: 0, channel: channel, mpe: mpe)
        route(engine, cc: 100, value: rpn, channel: channel, mpe: mpe)
        route(engine, cc: 6, value: value, channel: channel, mpe: mpe)
    }

    func testR12_2_RPNControllersAreOrdinaryCCsWhenMPEOff() {
        for cc: UInt8 in [6, 38, 100, 101] {
            for ch: UInt8 in [0, 1, 9] {
                let msg = MIDIMessage.controlChange(controller: cc, value: 33, channel: ch)
                XCTAssertEqual(AudioEngine.command(for: msg, mpeEnabled: false), .controlChange(cc: cc, value: 33),
                               "CC\(cc) ch\(ch) with MPE off must stay a plain CC (MIDI-learn)")
            }
            let on = MIDIMessage.controlChange(controller: cc, value: 33, channel: 1)
            XCTAssertEqual(AudioEngine.command(for: on, mpeEnabled: true), .mpeControlChange(channel: 1, cc: cc, value: 33))
        }
    }

    func testR12_2_DAWRPN0WithMPEOffDoesNotTouchMPERange() {
        let engine = AudioEngine(coreOnly: true)
        XCTAssertFalse(engine.cachedMpeEnabled)
        let before = engine.preset.mpePitchBendRange
        rpn(engine, channel: 0, rpn: 0, value: 2, mpe: false)
        rpn(engine, channel: 1, rpn: 0, value: 12, mpe: false)
        engine.pollMPEConfigMailbox()
        XCTAssertEqual(engine.cachedMpePitchBendRange, 48)
        XCTAssertEqual(engine.preset.mpePitchBendRange, before)
        XCTAssertFalse(engine.preset.mpeEnabled)
    }

    /// Typical controller boot: MCM on master, RPN 0 = 48 on a member, RPN 0 = 2 on the master.
    func testR12_4_TypicalControllerSequenceKeepsMemberRange48() {
        let engine = AudioEngine(coreOnly: true)
        engine.cachedMpeEnabled = true
        engine.cachedMpePitchBendRange = 24
        rpn(engine, channel: 0, rpn: 6, value: 15)
        rpn(engine, channel: 1, rpn: 0, value: 48)
        rpn(engine, channel: 0, rpn: 0, value: 2)
        XCTAssertEqual(engine.cachedMpePitchBendRange, 48, "master RPN 0 must not overwrite the member range")
        XCTAssertEqual(engine.cachedPitchBendRange, 2)
        engine.pollMPEConfigMailbox()
        XCTAssertEqual(engine.preset.mpePitchBendRange, 48)
        // SYNT_16 R13-9: master range is runtime-only (not written into the preset).
        XCTAssertEqual(engine.controllerMasterPitchBendRange, 2)
        XCTAssertEqual(engine.cachedPitchBendRange, 2)
    }

    func testR12_4_UpperZoneMasterIsChannel16() {
        let engine = AudioEngine(coreOnly: true)
        engine.cachedMpeEnabled = true
        rpn(engine, channel: 15, rpn: 6, value: 7)
        XCTAssertEqual(engine.cachedMpeZone, .upper)
        rpn(engine, channel: 14, rpn: 0, value: 36)
        rpn(engine, channel: 15, rpn: 0, value: 5)
        XCTAssertEqual(engine.cachedMpePitchBendRange, 36)
        XCTAssertEqual(engine.cachedPitchBendRange, 5)
    }

    func testR12_4_RPN0RecomputesPendingChannelBendMultiplier() {
        let engine = AudioEngine(coreOnly: true)
        engine.cachedMpeEnabled = true
        engine.cachedMpePitchBendRange = 48
        engine.handleCommand(.mpePitchBend(channel: 1, value: 0.5))   // bend before note-on
        XCTAssertEqual(engine.mpeChannelStates[1].pitchBendMultiplier, 4, accuracy: 1e-9)
        rpn(engine, channel: 1, rpn: 0, value: 24)
        XCTAssertEqual(engine.mpeChannelStates[1].pitchBendMultiplier, 2, accuracy: 1e-9,
                       "a note started after RPN 0 must use the new range")
    }
}
