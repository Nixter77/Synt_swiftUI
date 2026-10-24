//
//  Stage19Stage2Tests.swift
//  SYNT_19 Stage 2: R16-1 — a retired user table is released (on main) only after render
//  acknowledges it no longer reads it; several swaps before a drain must not free it.
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage19Stage2Tests: XCTestCase {

    /// Fresh table that is never put into the compile cache: the oscillator is its only owner.
    private func unownedCompiled(_ seed: Float) -> CompiledMipData {
        var frames: [[Float]] = []
        for f in 0..<2 {
            var fr = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 { fr[i] = sinf(2 * .pi * Float(i) / 2048 * (1 + Float(f))) * seed }
            frames.append(fr)
        }
        return WavetableOscillator.compile(wavetable: Wavetable(name: "S19-\(seed)", frames: frames))
    }

    func testR16_1_UnownedTableReadByRenderSurvivesSeveralSwapsUntilAck() {
        let osc = WavetableOscillator()
        weak var weakA: CompiledMipData?
        do {
            let a = unownedCompiled(0.5)
            weakA = a
            osc.instanceUserCompiled = a      // never published to slots, not cached
        }
        XCTAssertNotNil(weakA)
        osc.loadBuiltinRT(index: 5)           // render now reads A's flat view (rtView)
        XCTAssertNotEqual(osc.rtUserAck.load(ordering: .relaxed), 0)

        // Main swaps the user table three times before render pulls anything.
        osc.instanceUserCompiled = unownedCompiled(0.6)
        osc.instanceUserCompiled = unownedCompiled(0.7)
        osc.instanceUserCompiled = unownedCompiled(0.8)
        XCTAssertNotNil(weakA, "R16-1: table render still reads must not be freed by main swaps")
        XCTAssertEqual(osc.retiredUserTableCountForTesting, 1, "only the acked table is retained; B, C freed")

        // Render can still read it safely.
        let s = osc.generateSample(phase: 0.3, phaseIncrement: 0.01)
        XCTAssertTrue(s.isFinite)

        // Render moves on (builtin) → ack cleared → main's next drain frees A, on main.
        osc.loadBuiltinRT(index: 0)
        XCTAssertEqual(osc.rtUserAck.load(ordering: .relaxed), 0)
        XCTAssertNotNil(weakA, "render itself never releases")
        XCTAssertTrue(Thread.isMainThread)
        osc.syncFromRenderMain()
        XCTAssertNil(weakA, "freed on main after the ack")
        XCTAssertEqual(osc.retiredUserTableCountForTesting, 0)
    }

    func testR16_1_MainPublishClearsAckSoRetiredTableIsReleased() {
        let osc = WavetableOscillator()
        weak var weakA: CompiledMipData?
        do {
            let a = unownedCompiled(0.4)
            weakA = a
            osc.instanceUserCompiled = a
        }
        osc.loadBuiltinRT(index: 5)
        osc.instanceUserCompiled = unownedCompiled(0.9)
        XCTAssertNotNil(weakA)
        osc.loadBuiltin(index: 2)             // main publish
        osc.pullNewWavetableRT()              // render adopts it → rtView nil, ack 0
        XCTAssertEqual(osc.rtUserAck.load(ordering: .relaxed), 0)
        osc.drainRetiredUserTablesMain()
        XCTAssertNil(weakA)
    }
}
