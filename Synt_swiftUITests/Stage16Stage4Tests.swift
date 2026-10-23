//
//  Stage16Stage4Tests.swift
//  SYNT_16 Stage 4 lows: R13-8 (CC 38 cents), R13-5 (no blob re-hash on main), R13-6 (no mip compile in loadBuiltin(5)).
//
import XCTest
@testable import SynthCore

final class Stage16Stage4Tests: XCTestCase {
    private func route(_ e: AudioEngine, cc: UInt8, value: UInt8, channel: UInt8) {
        let msg = MIDIMessage.controlChange(controller: cc, value: value, channel: channel)
        if let cmd = AudioEngine.command(for: msg, mpeEnabled: e.cachedMpeEnabled, zone: e.cachedMpeZone,
                                         memberCount: e.cachedMpeMemberChannelCount) {
            e.handleCommand(cmd)
        }
    }

    /// Fails on old code: CC 38 was ignored, range stayed 12.
    func testR13_8_DataEntryLSBAddsCentsToMemberRange() {
        let e = AudioEngine(coreOnly: true)
        e.preset.mpeEnabled = true
        for (cc, v) in [(101, 0), (100, 0), (6, 12), (38, 50)] as [(UInt8, UInt8)] {
            route(e, cc: cc, value: v, channel: 1)
        }
        XCTAssertEqual(e.cachedMpePitchBendRange, 12.5, accuracy: 1e-5)
        XCTAssertTrue(e.pollMPEConfigMailbox())
        XCTAssertEqual(e.mpePitchBendRange, 12.5, accuracy: 1e-5, "cents survive the mailbox")
    }

    /// Fails on old code: master range stayed integer 3.
    func testR13_8_DataEntryLSBOnMasterChannel() {
        let e = AudioEngine(coreOnly: true)
        e.preset.mpeEnabled = true
        for (cc, v) in [(101, 0), (100, 0), (6, 3), (38, 25)] as [(UInt8, UInt8)] {
            route(e, cc: cc, value: v, channel: 0)
        }
        XCTAssertEqual(e.cachedPitchBendRange, 3.25, accuracy: 1e-5)
        e.pollMPEConfigMailbox()
        XCTAssertEqual(e.controllerMasterPitchBendRange ?? -1, 3.25, accuracy: 1e-5)
    }

    /// Guard: CC 38 for RPN 6 (MCM) is ignored; integer RPN 0 still exact.
    func testR13_8_LSBIgnoredForMCMAndIntegerRangeExact() {
        let e = AudioEngine(coreOnly: true)
        e.preset.mpeEnabled = true
        for (cc, v) in [(101, 0), (100, 6), (6, 9), (38, 77)] as [(UInt8, UInt8)] {
            route(e, cc: cc, value: v, channel: 0)
        }
        XCTAssertEqual(e.cachedMpeMemberChannelCount, 9)
        for (cc, v) in [(101, 0), (100, 0), (6, 24)] as [(UInt8, UInt8)] {
            route(e, cc: cc, value: v, channel: 2)
        }
        XCTAssertEqual(e.cachedMpePitchBendRange, 24)
    }

    /// Second applyPreset with the same user-WT blob takes the no-hash fast path.
    func testR13_5_SameUserBlobSkipsRehash() {
        let e = AudioEngine(coreOnly: true)
        let data = WavetableOscillator.basicWavetables[3].compressedSerializedData()
        e.preset.userWavetableData = data
        let deadline = Date().addingTimeInterval(20)
        while e.userCompiledWavetable == nil && Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
        XCTAssertNotNil(e.userCompiledWavetable)
        let before = e.userWTFastPathCountForTesting
        e.applyPreset()
        e.applyPreset()
        XCTAssertGreaterThanOrEqual(e.userWTFastPathCountForTesting - before, 2)
        // A different blob must take the slow path.
        let before2 = e.userWTFastPathCountForTesting
        e.preset.userWavetableData = WavetableOscillator.basicWavetables[2].compressedSerializedData()
        XCTAssertEqual(e.userWTFastPathCountForTesting, before2)
    }

    /// Fails on old code: loadBuiltin(5) compiled mips for a table without instanceUserCompiled.
    func testR13_6_LoadBuiltin5NeverCompiles() {
        let osc = WavetableOscillator()
        osc.instanceUserWavetable = WavetableOscillator.basicWavetables[4]
        osc.instanceUserCompiled = nil
        osc.loadBuiltin(index: 5)
        XCTAssertEqual(osc.currentBuiltinIndex, 0, "falls back to builtin 0, no compile")
        XCTAssertEqual(osc.userTableWithoutMipsCountForTesting, 1)
    }
}
