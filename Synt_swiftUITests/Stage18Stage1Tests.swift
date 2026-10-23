//
//  Stage18Stage1Tests.swift
//  SYNT_18 Stage 1: R15-2 — generateSample reads a flat POD view (no ARC) and gets the
//  mip octave from the binary exponent (no per-sample log2). Output must be bit-identical.
//

import XCTest
@testable import SynthCore

final class Stage18Stage1Tests: XCTestCase {

    /// Flat path vs. the pre-SYNT_18 array path, every builtin, every mip octave, several morphs.
    func testR15_2_FlatPathBitIdenticalToArrayPath() {
        let osc = WavetableOscillator()
        let sr = 44100.0
        var compared = 0
        for idx in 0..<WavetableOscillator.basicWavetables.count {
            osc.loadBuiltin(index: idx)
            osc.pullNewWavetableRT()
            for morph in [Float(0), 0.13, 0.5, 0.77, 1] {
                osc.targetFramePosition = morph
                osc.reset()
                var f = 15.0
                while f < 21_000 {
                    let inc = 2 * Double.pi * f / sr
                    var phase = 0.1
                    for _ in 0..<64 {
                        let a = osc.generateSample(phase: phase, phaseIncrement: inc, sampleRate: sr)
                        let b = osc.generateSampleArrayPathForTesting(phase: phase, phaseIncrement: inc, sampleRate: sr)
                        if a.bitPattern != b.bitPattern {
                            XCTFail("table \(idx) morph \(morph) f \(f) phase \(phase): \(a) != \(b)")
                            return
                        }
                        phase += inc * 7.3
                        compared += 1
                    }
                    f *= 1.37
                }
            }
        }
        XCTAssertGreaterThan(compared, 10_000)
    }

    /// The exponent-based octave equals the old Int(log2(max(20,f)/20)) on a dense sweep and at
    /// every octave edge (exact powers of two and their neighbours).
    func testR15_2_MipOctaveMatchesLog2() {
        func old(_ f: Double) -> Int { Int(log2(max(20.0, f) / 20.0)) }
        var f = 0.5
        while f < 200_000 {
            XCTAssertEqual(WavetableOscillator.mipOctave(forFrequency: f), old(f), "f=\(f)")
            f *= 1.0007
        }
        for k in 0...14 {
            let edge = 20.0 * pow(2.0, Double(k))
            for g in [edge.nextDown, edge, edge.nextUp, edge.nextDown.nextDown] {
                XCTAssertEqual(WavetableOscillator.mipOctave(forFrequency: g), old(g), "edge f=\(g)")
            }
        }
    }

    /// The flat copy matches the compiled Swift arrays element for element.
    func testR15_2_FlatViewMirrorsMipMaps() {
        let osc = WavetableOscillator()
        osc.loadBuiltin(index: 3)
        guard let c = osc.activeCompiled else { return XCTFail("no table") }
        let v = c.flatView.pointee
        XCTAssertEqual(v.octaves, c.mipMaps.count)
        XCTAssertEqual(v.frames, c.mipMaps[0].count)
        XCTAssertEqual(v.samplesPerFrame, c.mipMaps[0][0].count)
        for o in [0, 5, v.octaves - 1] {
            for fr in [0, v.frames / 2, v.frames - 1] {
                let p = v.frame(octave: o, index: fr)
                for i in stride(from: 0, to: v.samplesPerFrame, by: 97) {
                    XCTAssertEqual(p[i].bitPattern, c.mipMaps[o][fr][i].bitPattern)
                }
            }
        }
    }
}
