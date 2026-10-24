//
//  Stage22Stage1Tests.swift
//  SYNT_22 Stage 1: R18-1 (LFO shape pointers vs LRU eviction) and R14-4 (shape leak per compile).
//

import XCTest
@testable import SynthCore

final class Stage22Stage1Tests: XCTestCase {
    override func setUp() { WavetableOscillator.clearCacheForTesting() }
    override func tearDown() { WavetableOscillator.clearCacheForTesting() }

    private func userTable(_ seed: Int) -> Wavetable {
        let frames: [[Float]] = (0..<4).map { f in
            (0..<256).map { i in Float(sin(Double(i) * 2 * .pi / 256 * Double(1 + (seed + f) % 7)) * (0.5 + Double(seed % 5) * 0.1)) }
        }
        return Wavetable(name: "U\(seed)", frames: frames)
    }

    /// R14-4: before SYNT_22 every compile allocated a new immortal shape, so an evicted table that
    /// was compiled again leaked again (unbounded with the SYNT_21 LRU cache).
    func testR14_4_RecompileReusesInternedLFOShape() {
        let t = userTable(3)
        let a = WavetableOscillator.compile(wavetable: t, sampleRate: 44100)
        let b = WavetableOscillator.compile(wavetable: t, sampleRate: 44100)
        XCTAssertFalse(a === b)
        XCTAssertEqual(Int(bitPattern: a.lfoShape), Int(bitPattern: b.lfoShape),
                       "the same frame must reuse one immortal LFO shape")
        let before = LFOShapeTable.internedCountForTesting
        for _ in 0..<10 { _ = WavetableOscillator.compile(wavetable: t, sampleRate: 44100) }
        XCTAssertEqual(LFOShapeTable.internedCountForTesting, before, "recompiles must not grow the shape set")
    }

    /// R18-1 stress: > 16 user tables, three publishes inside one 5 ms LFO fade, every compiled
    /// table released (evicted + rotated out of the slots). The pointers the LFO holds
    /// (current + fading previous shape) must still read the original data: shapes are not owned by
    /// `CompiledMipData`, so the eviction cannot free them.
    func testR18_1_LFOShapePointersOutliveEvictedTablesDuringFade() {
        let engine = AudioEngine()
        var p = SynthPreset.defaultPreset
        p.osc1Waveform = .wavetable
        p.lfoWaveform = .wavetable
        engine.preset = p
        engine.applyPresetForTesting()
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { bufL.deallocate(); bufR.deallocate() }
        engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: 64)

        var shapes: [(UnsafePointer<LFOShapeTable>, [Float])] = []
        weak var weakLast: CompiledMipData?
        autoreleasepool {
            for i in 0..<24 {
                let c = WavetableOscillator.compile(wavetable: userTable(100 + i), sampleRate: 44100)
                let copy = Array(UnsafeBufferPointer(start: c.lfoShape.pointee.data, count: c.lfoShape.pointee.count))
                shapes.append((c.lfoShape, copy))
                WavetableOscillator.setCachedCompiled(c, for: WavetableCacheKey(contentHash: 0xAB00 &+ UInt64(i), sampleRate: 44100))
                engine.wavetableEngine1.instanceUserCompiled = c
                engine.wavetableEngine1.loadBuiltin(index: 5)
                // 3 publishes per 5 ms fade: render a 16-frame block in between.
                if i % 3 != 2 { engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: 16) }
                weakLast = i == 0 ? c : weakLast
            }
            // Push the first tables out of every owner: cache (LRU 16), slots, user table.
            for k in 0..<4 { engine.wavetableEngine1.loadBuiltin(index: k % 5) }
            engine.wavetableEngine1.instanceUserCompiled = nil
            engine.wavetableEngine1.drainRetiredUserTablesMain()
        }
        XCTAssertNil(WavetableOscillator.getCachedCompiled(for: WavetableCacheKey(contentHash: 0xAB00, sampleRate: 44100)))
        XCTAssertNil(weakLast, "first table must really be freed for the stress to mean anything")
        for _ in 0..<20 { engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: 16) }
        for (ptr, copy) in shapes {
            let now = Array(UnsafeBufferPointer(start: ptr.pointee.data, count: ptr.pointee.count))
            XCTAssertEqual(now, copy, "LFO shape memory must survive its table")
        }
        for i in 0..<64 { XCTAssertTrue(bufL[i].isFinite) }
    }
}
