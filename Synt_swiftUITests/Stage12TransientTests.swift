//
//  Stage12TransientTests.swift
//  Synt_swiftUITests
//
//  Tests for Stage 3: DSPTransientShaper and insert chain integration.
//

import XCTest
@testable import SynthCore

final class Stage12TransientTests: XCTestCase {

    func testTransientShaperBitExactBypass() {
        let engineA = AudioEngine()
        let engineB = AudioEngine()
        engineA.prepare(sampleRate: 44100, maxFrames: 512)
        engineB.prepare(sampleRate: 44100, maxFrames: 512)

        var preset = SynthPreset.defaultPreset
        preset.transientEnabled = false
        preset.transientAttack = 0.8
        preset.transientSustain = -0.5
        preset.transientOutput = 1.5

        engineA.applyPresetDSP(RTPresetSnapshot(from: preset, rendersAllDelayInDSP: false))
        engineB.applyPresetDSP(RTPresetSnapshot(from: preset, rendersAllDelayInDSP: false))

        // Trigger note 60 on both
        engineA.noteOn(midiNote: 60, velocity: 100)
        engineB.noteOn(midiNote: 60, velocity: 100)

        var bufAL = [Float](repeating: 0, count: 512)
        var bufAR = [Float](repeating: 0, count: 512)
        var bufBL = [Float](repeating: 0, count: 512)
        var bufBR = [Float](repeating: 0, count: 512)

        bufAL.withUnsafeMutableBufferPointer { pAL in
            bufAR.withUnsafeMutableBufferPointer { pAR in
                engineA.renderBlock(intoL: pAL.baseAddress!, intoR: pAR.baseAddress!, frameCount: 512)
            }
        }
        bufBL.withUnsafeMutableBufferPointer { pBL in
            bufBR.withUnsafeMutableBufferPointer { pBR in
                engineB.renderBlock(intoL: pBL.baseAddress!, intoR: pBR.baseAddress!, frameCount: 512)
            }
        }

        for i in 0..<512 {
            XCTAssertEqual(bufAL[i].bitPattern, bufBL[i].bitPattern, "Mismatch at frame \(i) on Left")
            XCTAssertEqual(bufAR[i].bitPattern, bufBR[i].bitPattern, "Mismatch at frame \(i) on Right")
        }
    }

    func testTransientShaperAttackBoostAndCut() {
        let shaperBoost = DSPTransientShaper(sampleRate: 44100)
        let shaperCut = DSPTransientShaper(sampleRate: 44100)

        // Generate synthetic impulse followed by silence
        var input = [Float](repeating: 0, count: 256)
        input[0] = 0.9
        input[1] = 0.5
        input[2] = 0.2

        var boostPeak: Float = 0
        var cutPeak: Float = 0

        for i in 0..<256 {
            let (bL, _) = shaperBoost.process(left: input[i], right: input[i], attack: 1.0, sustain: 0.0, output: 1.0, mix: 1.0)
            let (cL, _) = shaperCut.process(left: input[i], right: input[i], attack: -1.0, sustain: 0.0, output: 1.0, mix: 1.0)
            boostPeak = max(boostPeak, abs(bL))
            cutPeak = max(cutPeak, abs(cL))
        }

        XCTAssertGreaterThan(boostPeak, cutPeak, "Attack boost peak should exceed cut peak")
        XCTAssertGreaterThan(boostPeak, 0.9, "Attack +1 should boost initial onset peak")
    }

    func testTransientShaperSustainTail() {
        let shaperBoost = DSPTransientShaper(sampleRate: 44100)
        let shaperCut = DSPTransientShaper(sampleRate: 44100)

        // Continuous sine wave tone
        var boostTailSum: Float = 0
        var cutTailSum: Float = 0

        for i in 0..<2000 {
            let s = sin(Float(i) * 0.1) * 0.5
            let (bL, _) = shaperBoost.process(left: s, right: s, attack: 0.0, sustain: 1.0, output: 1.0, mix: 1.0)
            let (cL, _) = shaperCut.process(left: s, right: s, attack: 0.0, sustain: -1.0, output: 1.0, mix: 1.0)
            if i > 500 {
                boostTailSum += abs(bL)
                cutTailSum += abs(cL)
            }
        }

        XCTAssertGreaterThan(boostTailSum, cutTailSum, "Sustain boost should yield more energy than sustain cut")
    }

    func testTransientShaperNoNaNOrDenormals() {
        let shaper = DSPTransientShaper(sampleRate: 44100)

        let badInputs: [Float] = [0.0, Float.nan, Float.infinity, -Float.infinity, 1e-25, -1e-30, 50.0, -50.0]

        for inVal in badInputs {
            for _ in 0..<64 {
                let (outL, outR) = shaper.process(
                    left: inVal,
                    right: inVal,
                    attack: 0.5,
                    sustain: -0.5,
                    output: 1.2,
                    mix: 1.0
                )
                XCTAssertTrue(outL.isFinite, "Output Left must be finite for input \(inVal)")
                XCTAssertTrue(outR.isFinite, "Output Right must be finite for input \(inVal)")
                XCTAssertFalse(outL.isSubnormal, "Subnormal output detected on Left for input \(inVal)")
                XCTAssertFalse(outR.isSubnormal, "Subnormal output detected on Right for input \(inVal)")
            }
        }
    }

    func testTransientShaperParameterSmoothingNoClicks() {
        let shaper = DSPTransientShaper(sampleRate: 44100)
        var maxDelta: Float = 0
        var lastL: Float = 0

        for i in 0..<1000 {
            // Rapid parameter jumps
            let attack: Float = (i % 50 < 25) ? 1.0 : -1.0
            let sustain: Float = (i % 70 < 35) ? 1.0 : -1.0
            let outGain: Float = (i % 30 < 15) ? 0.2 : 1.8
            let mix: Float = (i % 40 < 20) ? 0.0 : 1.0

            let (outL, _) = shaper.process(left: 0.5, right: 0.5, attack: attack, sustain: sustain, output: outGain, mix: mix)
            if i > 0 {
                maxDelta = max(maxDelta, abs(outL - lastL))
            }
            lastL = outL
        }

        // With smoothing, per-sample delta on continuous 0.5 input should be gentle
        XCTAssertLessThan(maxDelta, 0.5, "Parameter smoothing should prevent harsh step clicks")
    }
}
