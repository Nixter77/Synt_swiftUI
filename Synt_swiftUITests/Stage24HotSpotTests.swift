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

    /// SYNT_25 R21-2: the cached split equals the pre-SYNT_24 formula for every (position, count),
    /// including repeated keys, count changes at the same position, and edge positions.
    func testCachedFrameSplitMatchesReferenceFormula() {
        #if DEBUG
        let osc = WavetableOscillator()
        func reference(_ p: Float, _ n: Int) -> (Int, Int, Float) {
            let framePos = p * Float(max(0, n - 1))
            let i1 = max(0, min(n - 1, Int(framePos)))
            return (i1, min(i1 + 1, n - 1), framePos - Float(i1))
        }
        var rng = SystemRandomNumberGenerator()
        let counts = [1, 2, 3, 8, 64, 256]
        var positions: [Float] = [0, 1, 0.5, Float.ulpOfOne, 1 - Float.ulpOfOne.magnitude, -0.0]
        for _ in 0..<2000 { positions.append(Float.random(in: 0...1, using: &rng)) }
        for p in positions {
            for n in counts + counts.reversed() {   // count change at same position
                for _ in 0..<2 {                    // repeated key hits the cache
                    let c = osc.frameSplitForTesting(position: p, frameCount: n)
                    let r = reference(p, n)
                    XCTAssertEqual(c.0, r.0); XCTAssertEqual(c.1, r.1)
                    XCTAssertEqual(c.2.bitPattern, r.2.bitPattern, "p=\(p) n=\(n)")
                    if c.0 != r.0 || c.2.bitPattern != r.2.bitPattern { return }
                }
            }
        }
        #endif
    }
}
