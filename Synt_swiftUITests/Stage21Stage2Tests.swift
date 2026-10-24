//
//  Stage21Stage2Tests.swift
//  SYNT_21 Stage 2: R15-6/7 — the user-table compile cache is bounded (LRU), and an evicted
//  table is freed only when nothing else (oscillator slot / retired list) retains it.
//

import XCTest
@testable import SynthCore

final class Stage21Stage2Tests: XCTestCase {
    override func setUp() { WavetableOscillator.clearCacheForTesting() }
    override func tearDown() { WavetableOscillator.clearCacheForTesting() }

    private func key(_ i: Int) -> WavetableCacheKey { WavetableCacheKey(contentHash: 0xC0FFEE00 &+ UInt64(i), sampleRate: 44100) }

    func testR15_7_CompiledCacheEvictsOldestAndFreesIt() {
        let table = WavetableOscillator.basicWavetables[0]
        weak var weakFirst: CompiledMipData?
        autoreleasepool {
            let first = WavetableOscillator.compile(wavetable: table, sampleRate: 44100)
            weakFirst = first
            WavetableOscillator.setCachedCompiled(first, for: key(0))
        }
        XCTAssertNotNil(weakFirst, "cache retains its entry")
        let shared = WavetableOscillator.compile(wavetable: table, sampleRate: 44100)
        for i in 1...40 { WavetableOscillator.setCachedCompiled(shared, for: key(i)) }
        XCTAssertNil(WavetableOscillator.getCachedCompiled(for: key(0)), "cache must be bounded")
        XCTAssertNil(weakFirst, "evicted entry with no other owner must be freed")
        XCTAssertNotNil(WavetableOscillator.getCachedCompiled(for: key(40)))
    }

    func testR15_7_EvictionKeepsTableInUseAlive() {
        let table = WavetableOscillator.basicWavetables[1]
        let inUse = WavetableOscillator.compile(wavetable: table, sampleRate: 44100)
        weak var weakInUse: CompiledMipData? = inUse
        let osc = WavetableOscillator()
        osc.instanceUserCompiled = inUse
        WavetableOscillator.setCachedCompiled(inUse, for: key(0))
        let shared = WavetableOscillator.compile(wavetable: table, sampleRate: 44100)
        for i in 1...40 { WavetableOscillator.setCachedCompiled(shared, for: key(i)) }
        XCTAssertNil(WavetableOscillator.getCachedCompiled(for: key(0)))
        XCTAssertNotNil(weakInUse, "oscillator still owns the evicted table")
        XCTAssertTrue(osc.instanceUserCompiled === weakInUse)
    }

    func testR15_7_RecentlyUsedEntrySurvives() {
        let shared = WavetableOscillator.compile(wavetable: WavetableOscillator.basicWavetables[0], sampleRate: 44100)
        WavetableOscillator.setCachedCompiled(shared, for: key(0))
        for i in 1...40 {
            WavetableOscillator.setCachedCompiled(shared, for: key(i))
            XCTAssertNotNil(WavetableOscillator.getCachedCompiled(for: key(0)))  // keeps key 0 hot
        }
        XCTAssertNil(WavetableOscillator.getCachedCompiled(for: key(1)))
    }
}
