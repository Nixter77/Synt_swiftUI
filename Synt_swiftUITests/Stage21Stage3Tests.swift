//
//  Stage21Stage3Tests.swift
//  SYNT_21 Stage 3: R17-2 — two Resets before main polls must not let an entry render published
//  between them (after reset #1, before reset #2) restore an override.
//

import XCTest
@testable import SynthCore

final class Stage21Stage3Tests: XCTestCase {

    private func mpeEngine() -> AudioEngine {
        let e = AudioEngine(coreOnly: true)
        e.mpeEnabled = true
        e.cachedMpeEnabled = true
        e.cachedMpeZone = .lower
        e.cachedMpeMemberChannelCount = 15
        e.cachedMpePitchBendRange = 48
        e.cachedPitchBendRange = 2
        return e
    }

    func testR17_2_DoubleResetBeforeDrainIgnoresEntryBetweenResets() {
        let e = mpeEngine()
        e.handleRPN(channel: 15, rpn: 6, value: 5)
        XCTAssertTrue(e.pollMPEConfigMailbox())
        XCTAssertNotNil(e.controllerMPEOverrideSummary)

        e.resetControllerMPEOverrides()               // reset #1
        e.processCommandsForTesting()                 // render applies #1 (main has not polled)
        e.handleRPN(channel: 15, rpn: 6, value: 7)    // render: new entry after #1
        e.resetControllerMPEOverrides()               // reset #2, before main polled
        e.pollMPEConfigMailbox()
        XCTAssertNil(e.controllerMPEOverrideSummary, "entry from before reset #2 restored an override")
        e.processCommandsForTesting()                 // render applies #2
        e.pollMPEConfigMailbox()
        XCTAssertNil(e.controllerMPEOverrideSummary)
        XCTAssertFalse(e.mpeCtl.hasOverride)

        e.handleRPN(channel: 15, rpn: 6, value: 3)    // later controller change still shows
        XCTAssertTrue(e.pollMPEConfigMailbox())
        XCTAssertEqual(e.controllerMPEOverrideSummary?.contains("3 members"), true)
    }
}
