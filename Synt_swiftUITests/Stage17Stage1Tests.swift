//
//  Stage17Stage1Tests.swift
//  SYNT_17 Stage 1: R14-3 — built-in wavetables prepared off render on SR change;
//  loadBuiltin (incl. the R13-6 fallback from index 5) never locks or compiles.
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage17Stage1Tests: XCTestCase {

    /// Old code: after an SR change, loadBuiltin(1…4) missed the cache and compiled mips.
    func testR14_3_NoCompileInLoadBuiltinAfterSampleRateChange() {
        let osc = WavetableOscillator()
        osc.setSampleRate(37_800)       // rate no other test uses: a guaranteed cache miss on old code
        let compilesBefore = WavetableOscillator.compileCountForTesting.load(ordering: .relaxed)
        for i in 0...5 { osc.loadBuiltin(index: i) }    // 5 → no user table → R13-6 fallback to 0
        XCTAssertEqual(WavetableOscillator.compileCountForTesting.load(ordering: .relaxed), compilesBefore,
                       "loadBuiltin must never compile after an SR change")
        XCTAssertEqual(osc.currentBuiltinIndex, 0)
        XCTAssertEqual(osc.activeCompiled?.sampleRate ?? 0, 37_800, accuracy: 0.5)
    }

    /// Old code: loadBuiltin took cacheLock, so with the lock held elsewhere it blocked (would stall render).
    func testR14_3_LoadBuiltinDoesNotWaitOnCacheLock() {
        let osc = WavetableOscillator()
        osc.setSampleRate(41_000)
        let done = expectation(description: "loadBuiltin finished while cacheLock held")
        WavetableOscillator.withCacheLockHeldForTesting {
            DispatchQueue.global(qos: .userInteractive).async {
                for i in 0...5 { osc.loadBuiltin(index: i) }
                done.fulfill()
            }
            // Wait with the lock still held: lock-free code finishes, old code deadlocks until timeout.
            let r = XCTWaiter.wait(for: [done], timeout: 2.0)
            XCTAssertEqual(r, .completed, "loadBuiltin must not take cacheLock")
        }
    }

    /// The prepared tables really match the new rate for every built-in index.
    func testR14_3_AllBuiltinsPreparedForNewRate() {
        let osc = WavetableOscillator()
        osc.setSampleRate(88_200)
        for i in 0..<WavetableOscillator.basicWavetables.count {
            osc.loadBuiltin(index: i)
            XCTAssertEqual(osc.activeCompiled?.sampleRate ?? 0, 88_200, accuracy: 0.5, "builtin \(i)")
        }
    }
}
