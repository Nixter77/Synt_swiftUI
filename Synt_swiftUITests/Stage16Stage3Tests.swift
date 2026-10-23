//
//  Stage16Stage3Tests.swift
//  SYNT_16 Stage 3: R13-4, wavetable LFO follows the oscillator's selected table.
//
import XCTest
import Foundation
@testable import SynthCore

final class Stage16Stage3Tests: XCTestCase {

    private func ref(_ t: [Float], _ norm: Double) -> Float {
        let n = t.count
        let pos = norm * Double(n)
        let i0 = Int(pos) % n, i1 = (i0 + 1) % n
        let f = Float(pos - Double(Int(pos)))
        return t[i0] * (1 - f) + t[i1] * f
    }

    /// SYNT_17 R14-5: LFO shapes are peak-normalized.
    static func normalized(_ f: [Float]) -> [Float] {
        let p = f.reduce(Float(0)) { max($0, abs($1)) }
        return p > 1e-6 ? f.map { $0 / p } : f
    }

    private func renderOffMain(_ engine: AudioEngine, _ frames: Int) -> Int {
        let done = expectation(description: "render")
        var nan = 0
        DispatchQueue.global(qos: .userInteractive).async {
            nan = engine.renderFramesForTesting(frames).nanCount
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        return nan
    }

    /// Fails on old code: LFO always read builtin 0 frame 16 regardless of table.
    func testR13_4_WavetableLFOFollowsOsc1Table() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.lfo.waveform = .wavetable
        engine.oscillator1.waveform = .wavetable // SYNT_17 R14-5: LFO follows osc1 only in wavetable mode
        engine.wavetableEngine1.loadBuiltin(index: 2)
        let posBefore = engine.wavetableEngine1.targetFramePosition
        XCTAssertEqual(renderOffMain(engine, 512), 0)
        XCTAssertEqual(engine.wavetableEngine1.targetFramePosition, posBefore, "morph untouched")
        let expected = Self.normalized(LFOShapeTable.middleFrame(of: WavetableOscillator.basicWavetables[2]))
        var maxDiffFromDefault: Float = 0
        for k in 0..<64 {
            let norm = Double(k) / 64.0
            let v = engine.lfo.sampleWaveform(at: norm * 2 * .pi)
            XCTAssertEqual(v, ref(expected, norm), accuracy: 1e-4)
            maxDiffFromDefault = max(maxDiffFromDefault, abs(v - ref(LFO.defaultWavetable, norm)))
        }
        XCTAssertGreaterThan(maxDiffFromDefault, 0.05, "table 2 shape differs from default")
    }

    /// Fails on old code: LFO2 is bound to osc2's table independently of osc1.
    func testR13_4_LFO2FollowsOsc2TableIndependently() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.lfo.waveform = .wavetable
        engine.lfo2.waveform = .wavetable
        engine.oscillator1.waveform = .wavetable // SYNT_17 R14-5
        engine.oscillator2.waveform = .wavetable
        engine.wavetableEngine1.loadBuiltin(index: 0)
        engine.wavetableEngine2.loadBuiltin(index: 4)
        XCTAssertEqual(renderOffMain(engine, 256), 0)
        let t2 = Self.normalized(LFOShapeTable.middleFrame(of: WavetableOscillator.basicWavetables[4]))
        for k in 0..<32 {
            let norm = Double(k) / 32.0
            XCTAssertEqual(engine.lfo.sampleWaveform(at: norm * 2 * .pi), ref(LFO.defaultWavetable, norm), accuracy: 1e-4)
            XCTAssertEqual(engine.lfo2.sampleWaveform(at: norm * 2 * .pi), ref(t2, norm), accuracy: 1e-4)
        }
    }

    /// Guard: builtin 0's middle frame is the SYNT_15 default shape (no audible change for Init).
    func testR13_4_Builtin0ShapeEqualsLegacyDefault() {
        XCTAssertEqual(LFOShapeTable.middleFrame(of: WavetableOscillator.basicWavetables[0]), LFO.defaultWavetable)
    }
}
