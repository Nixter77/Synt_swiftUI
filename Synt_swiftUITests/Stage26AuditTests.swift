//
//  Stage26AuditTests.swift
//  SYNT_26: nightly audit SYNT25 fixes. Every test fails (or traps) on eabdaee.
//

import XCTest
import AudioToolbox
import Synchronization
@testable import SynthCore

final class Stage26AuditTests: XCTestCase {
    static let desc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
                                                componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)

    // MARK: P1-1 (R22-1) — hosts build the AU off main; DEBUG strict check must not trap.

    func testP1_1_AUConstructedOffMainDoesNotTripStrictCheck() throws {
        #if DEBUG
        XCTAssertTrue(AudioEngine.strictMainThreadApplyPreset, "strict check is the DEBUG default")
        #endif
        let done = expectation(description: "built")
        nonisolated(unsafe) var unit: SyntAudioUnit?
        DispatchQueue.global(qos: .userInitiated).async {
            unit = try? SyntAudioUnit(componentDescription: Self.desc)
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        let au = try XCTUnwrap(unit)
        #if DEBUG
        XCTAssertEqual(au.engine.applyPresetOffMainCountForTesting, 0)
        #endif
        XCTAssertTrue(au.engine.rendersAllReverbInDSP)
        XCTAssertTrue(au.engine.rendersAllDelayInDSP)
        XCTAssertTrue(au.engine.usesHostTransport)
        XCTAssertTrue(au.engine.cachedDSPReverb, "initial apply already saw the AU flags")
    }
}
