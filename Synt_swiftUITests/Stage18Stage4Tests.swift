//
//  Stage18Stage4Tests.swift
//  SYNT_18 Stage 4: R15-8 (controller MPE override summary + reset), R15-9 (MCM selection on
//  ch1/ch16 outside the zone is not double-routed to a learned CC 100/101).
//
import XCTest
import Foundation
@testable import SynthCore

final class Stage18Stage4Tests: XCTestCase {

    private func mpeEngine(zone: MPEZone = .lower, count: Int = 15) -> AudioEngine {
        let e = AudioEngine(coreOnly: true)
        e.mpeEnabled = true
        e.cachedMpeEnabled = true
        e.cachedMpeZone = zone
        e.cachedMpeMemberChannelCount = count
        e.cachedMpePitchBendRange = 48
        e.cachedPitchBendRange = 2
        return e
    }

    private func cc(_ e: AudioEngine, _ ch: UInt8, _ c: UInt8, _ v: UInt8) {
        e.handleCommand(.mpeControlChange(channel: ch, cc: c, value: v))
    }

    /// Fails on old code at runtime: CC 101/100 of the MCM also moved the learned macros.
    func testR15_9_MCMSelectOutsideZoneDoesNotMoveLearnedCC() {
        let e = mpeEngine(zone: .lower, count: 7)
        MIDICCLearnStore.shared.attachEngine(e)
        MIDICCLearnStore.shared.clearMappings()
        defer { MIDICCLearnStore.shared.clearMappings() }
        MIDICCLearnStore.shared.map(cc: 101, to: .macro1)
        MIDICCLearnStore.shared.map(cc: 100, to: .macro2)
        e.processCommandsForTesting()
        let m1 = e.cachedMacro1, m2 = e.cachedMacro2
        cc(e, 15, 101, 0); cc(e, 15, 100, 6); cc(e, 15, 6, 5)   // MCM upper zone, 5 members
        XCTAssertEqual(e.cachedMpeZone, .upper)
        XCTAssertEqual(e.cachedMpeMemberChannelCount, 5)
        XCTAssertEqual(e.cachedMacro1, m1, "CC101=0 of an MCM must not also drive a learned CC 101")
        XCTAssertEqual(e.cachedMacro2, m2, "CC100=6 of an MCM must not also drive a learned CC 100")
    }

    /// Guard (R14-7 still holds): other CC 100/101 values outside the zone stay plain CCs.
    func testR15_9_OtherCC101ValuesStayPlainCC() {
        let e = mpeEngine(zone: .lower, count: 7)
        MIDICCLearnStore.shared.attachEngine(e)
        MIDICCLearnStore.shared.clearMappings()
        defer { MIDICCLearnStore.shared.clearMappings() }
        MIDICCLearnStore.shared.map(cc: 101, to: .macro1)
        e.processCommandsForTesting()
        let m1 = e.cachedMacro1
        cc(e, 15, 101, 100)
        XCTAssertNotEqual(e.cachedMacro1, m1)
    }

    func testR15_8_OverrideSummaryAndResetToMySettings() {
        let e = mpeEngine()
        e.handleRPN(channel: 15, rpn: 6, value: 5)
        XCTAssertTrue(e.pollMPEConfigMailbox())
        XCTAssertEqual(e.controllerMPEOverrideSummary, "Controller: Upper zone, 5 members, ±48 st, master ±2 st")
        XCTAssertEqual(e.mpeZone, .upper)

        e.resetControllerMPEOverrides()
        XCTAssertNil(e.controllerMPEOverrideSummary)
        XCTAssertNil(e.controllerMasterPitchBendRange)
        XCTAssertEqual(e.mpeZone, e.controllerMPEMain.baseZone)
        e.processCommandsForTesting()   // render drains .clearMPEControllerOverrides
        XCTAssertFalse(e.mpeCtl.hasOverride)
        XCTAssertEqual(e.cachedMpeZone, e.mpeCtl.baseZone)
        XCTAssertEqual(e.cachedMpeMemberChannelCount, e.mpeCtl.baseMemberCount)
        XCTAssertTrue(e.pollMPEConfigMailbox())
        XCTAssertNil(e.controllerMPEOverrideSummary)
    }

    func testR15_8_SummaryNilWithoutOverride() {
        XCTAssertNil(MPEControllerOverride().overrideSummary)
        var o = MPEControllerOverride(); o.enabled = false
        XCTAssertEqual(o.overrideSummary, "Controller: MPE off")
    }
}
