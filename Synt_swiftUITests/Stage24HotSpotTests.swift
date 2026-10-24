//
//  Stage24HotSpotTests.swift
//  SYNT_24 Stage 2: render-path wavetable hot spots (no per-voice pull, cached frame split).
//  Perf itself is guarded by Stage22WavetablePerfBudget; these pin bit-exactness.
//

import XCTest
@testable import SynthCore

final class Stage24HotSpotTests: XCTestCase {

    /// The no-pull path and the cached frame split must equal the reference path bit-for-bit,
    /// including when framePosition changes between calls (cache invalidation).
    func testNoPullAndFrameCacheBitExact() {
        let a = WavetableOscillator()
        let b = WavetableOscillator()
        a.loadBuiltinRT(index: 1); b.loadBuiltinRT(index: 1)
        a.pullNewWavetableRT(); b.pullNewWavetableRT()
        var phase = 0.0
        let inc = 2 * Double.pi * 220 / 44100
        for i in 0..<4000 {
            let pos = Float(i % 97) / 96
            a.targetFramePosition = pos; b.targetFramePosition = pos
            a.advanceMorph(); b.advanceMorph()
            for v in 0..<3 {
                let p = phase + Double(v) * 0.37
                let x = a.generateSample(phase: p, phaseIncrement: inc)
                let y = b.generateSampleNoPull(phase: p, phaseIncrement: inc)
                XCTAssertEqual(x.bitPattern, y.bitPattern, "i=\(i) v=\(v)")
                if x.bitPattern != y.bitPattern { return }
            }
            phase += inc
            if phase > 2 * Double.pi { phase -= 2 * Double.pi }
        }
    }
}
