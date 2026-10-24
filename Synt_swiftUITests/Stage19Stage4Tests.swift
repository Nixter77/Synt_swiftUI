//
//  Stage19Stage4Tests.swift
//  SYNT_19 Stage 4: R15-8 in the AU — the plugin exposes the controller MPE override summary
//  (with a publisher for the AU view) and "Reset to My Settings".
//

import XCTest
import AudioToolbox
import Combine
@testable import SynthCore

final class Stage19Stage4Tests: XCTestCase {

    func testR15_8_AUExposesOverrideSummaryAndReset() throws {
        let description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
                                                    componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)
        let au = try SyntAudioUnit(componentDescription: description)
        let e = au.engine
        e.mpeEnabled = true
        e.cachedMpeEnabled = true
        e.cachedMpeZone = .lower
        e.cachedMpeMemberChannelCount = 15
        e.cachedMpePitchBendRange = 48
        e.cachedPitchBendRange = 2
        XCTAssertNil(au.controllerMPEOverrideSummary)

        var seen: [String?] = []
        let c = au.controllerMPEOverrideSummaryPublisher.sink { seen.append($0) }
        defer { c.cancel() }

        e.handleRPN(channel: 15, rpn: 6, value: 5)     // MCM on the upper zone (render)
        au.drainControllerMPEConfig()                  // AU main timer
        XCTAssertEqual(au.controllerMPEOverrideSummary, "Controller: Upper zone, 5 members, ±48 st, master ±2 st")

        au.resetControllerMPEOverrides()
        XCTAssertNil(au.controllerMPEOverrideSummary)
        e.processCommandsForTesting()
        XCTAssertFalse(e.mpeCtl.hasOverride)
        au.drainControllerMPEConfig()
        XCTAssertNil(au.controllerMPEOverrideSummary)
        XCTAssertEqual(seen.first ?? "x", nil)
        XCTAssertTrue(seen.contains("Controller: Upper zone, 5 members, ±48 st, master ±2 st"))
        XCTAssertEqual(seen.last ?? "x", nil)
    }
}
