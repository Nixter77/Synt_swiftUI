//
//  CodeReviewImprovementsTests.swift
//  Synt_swiftUITests
//
//  Verification tests for DSP safety (SceneHPF, DSPFrequencyShifter),
//  true stereo L/R metering (AtomicMeteringState, AudioMeterModel, AudioEngine),
//  and visualizer helpers (OscilloscopeView.risingZeroCrossingIndex, OutputSpectrumCalculator).
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct CodeReviewImprovementsTests {

    // MARK: - SceneHPF

    @Test func sceneHPFProducesFiniteOutputOnNonFiniteInputsAndRecovers() {
        let hpf = SceneHPF()

        let nonFiniteCases: [(Float, Float, Float, Float)] = [
            (.nan, .nan, 120, 44_100),
            (.infinity, -.infinity, 120, 44_100),
            (0.5, -0.5, .nan, 44_100),
            (0.5, -0.5, 120, .infinity),
        ]

        for (l, r, hz, sr) in nonFiniteCases {
            let (outL, outR) = hpf.process(left: l, right: r, hz: hz, sampleRate: sr)
            #expect(outL.isFinite)
            #expect(outR.isFinite)
        }

        // Subsequent finite signal recovers cleanly.
        for i in 0..<64 {
            let s = sin(Float(i) * 0.1) * 0.5
            let (outL, outR) = hpf.process(left: s, right: -s, hz: 120, sampleRate: 44_100)
            #expect(outL.isFinite)
            #expect(outR.isFinite)
        }
    }

    @Test func sceneHPFFlushesDenormalsAndTinyTailToZero() {
        let hpf = SceneHPF()

        // Tiny sub-1e-15 input flushes cleanly to zero.
        let (tinyL, tinyR) = hpf.process(left: 1e-20, right: -1e-25, hz: 120, sampleRate: 44_100)
        #expect(tinyL == 0)
        #expect(tinyR == 0)

        // Impulse followed by silence decays to exact zero rather than lingering as denormals.
        _ = hpf.process(left: 1.0, right: -1.0, hz: 120, sampleRate: 44_100)
        var lastL: Float = 1.0
        var lastR: Float = -1.0
        for _ in 0..<5_000 {
            let (outL, outR) = hpf.process(left: 0, right: 0, hz: 120, sampleRate: 44_100)
            #expect(outL.isFinite && !outL.isSubnormal)
            #expect(outR.isFinite && !outR.isSubnormal)
            lastL = outL
            lastR = outR
        }
        #expect(lastL == 0)
        #expect(lastR == 0)
    }

    // MARK: - DSPFrequencyShifter

    @Test func frequencyShifterProducesFiniteShiftedStereoSignal() {
        let shifter = DSPFrequencyShifter()
        let sampleRate: Float = 44_100
        let n = 512

        var energy: Float = 0
        var diffEnergy: Float = 0
        for i in 0..<n {
            let phase = 2.0 * Float.pi * 440.0 * Float(i) / sampleRate
            let inL = sin(phase) * 0.5
            let inR = cos(phase) * 0.5
            let out = shifter.process(
                inputL: inL,
                inputR: inR,
                shiftHz: 150.0,
                mix: 1.0,
                feedback: 0.25,
                sampleRate: sampleRate
            )
            #expect(out.left.isFinite)
            #expect(out.right.isFinite)
            energy += out.left * out.left + out.right * out.right
            diffEnergy += abs(out.left - inL) + abs(out.right - inR)
        }

        #expect(energy > 1.0)
        #expect(diffEnergy > 1.0)
    }

    @Test func frequencyShifterRecoversCleanlyFromNaNAndInfInput() {
        let shifter = DSPFrequencyShifter()

        // Prime state with valid signal first.
        for i in 0..<32 {
            let s = sin(Float(i) * 0.1) * 0.4
            _ = shifter.process(inputL: s, inputR: s, shiftHz: 100, mix: 1.0, feedback: 0.5, sampleRate: 44_100)
        }

        // Feed non-finite samples and parameters.
        let bad = shifter.process(
            inputL: .nan,
            inputR: .infinity,
            shiftHz: .nan,
            mix: 1.0,
            feedback: 0.5,
            sampleRate: 44_100
        )
        #expect(bad.left.isFinite)
        #expect(bad.right.isFinite)

        let badParams = shifter.process(
            inputL: 0.3,
            inputR: -0.3,
            shiftHz: 50,
            mix: .nan,
            feedback: .infinity,
            sampleRate: .nan
        )
        #expect(badParams.left.isFinite)
        #expect(badParams.right.isFinite)

        // Confirm steady recovery on clean audio afterwards.
        var sumAbs: Float = 0
        for i in 0..<128 {
            let s = sin(Float(i) * 0.15) * 0.5
            let out = shifter.process(inputL: s, inputR: s, shiftHz: 80, mix: 1.0, feedback: 0.2, sampleRate: 44_100)
            #expect(out.left.isFinite)
            #expect(out.right.isFinite)
            sumAbs += abs(out.left) + abs(out.right)
        }
        #expect(sumAbs > 1.0)
    }

    @Test func frequencyShifterBypassesCleanlyWhenMixAndFeedbackAreZero() {
        let shifter = DSPFrequencyShifter()
        let inputs: [(Float, Float)] = [(0.25, -0.5), (-0.75, 0.125), (0.0, 0.9)]
        for (inL, inR) in inputs {
            let out = shifter.process(
                inputL: inL,
                inputR: inR,
                shiftHz: 250.0,
                mix: 0.0,
                feedback: 0.0,
                sampleRate: 44_100
            )
            #expect(out.left == inL)
            #expect(out.right == inR)
        }
    }

    // MARK: - True Stereo L/R Metering

    @Test func atomicMeteringStateStereoGettersAndSetters() {
        let state = AtomicMeteringState()
        state.setOutputLevel(0.75)
        state.setPeakLevel(0.92)
        state.setOutputLevelStereo(left: 0.31, right: 0.75)
        state.setPeakLevelStereo(left: 0.42, right: 0.92)

        #expect(state.getOutputLevel() == 0.75)
        #expect(state.getPeakLevel() == 0.92)
        #expect(state.getOutputLevelL() == 0.31)
        #expect(state.getOutputLevelR() == 0.75)
        #expect(state.getPeakLevelL() == 0.42)
        #expect(state.getPeakLevelR() == 0.92)
    }

    @Test func audioMeterModelStereoAndMonoIngestAndReset() {
        let model = AudioMeterModel()

        // Backward-compatible mono ingest populates L/R with mono fallbacks.
        let monoPublished = model.ingest(output: 0.4, peak: 0.6, now: 1.0)
        #expect(monoPublished)
        #expect(model.outputLevel == 0.4)
        #expect(model.peakLevel == 0.6)
        #expect(model.outputLevelL == 0.4)
        #expect(model.outputLevelR == 0.4)
        #expect(model.peakLevelL == 0.6)
        #expect(model.peakLevelR == 0.6)

        // Stereo ingest publishes distinct L/R values.
        let stereoPublished = model.ingest(
            output: 0.8,
            peak: 0.9,
            outputL: 0.2,
            outputR: 0.8,
            peakL: 0.3,
            peakR: 0.9,
            now: 2.0
        )
        #expect(stereoPublished)
        #expect(model.outputLevel == 0.8)
        #expect(model.peakLevel == 0.9)
        #expect(model.outputLevelL == 0.2)
        #expect(model.outputLevelR == 0.8)
        #expect(model.peakLevelL == 0.3)
        #expect(model.peakLevelR == 0.9)

        // Swapping L/R while mono max stays unchanged still counts as moved.
        let swapPublished = model.ingest(
            output: 0.8,
            peak: 0.9,
            outputL: 0.8,
            outputR: 0.2,
            peakL: 0.9,
            peakR: 0.3,
            now: 3.0
        )
        #expect(swapPublished)
        #expect(model.outputLevelL == 0.8)
        #expect(model.outputLevelR == 0.2)

        model.resetDisplay()
        #expect(model.outputLevel == 0)
        #expect(model.peakLevel == 0)
        #expect(model.outputLevelL == 0)
        #expect(model.outputLevelR == 0)
        #expect(model.peakLevelL == 0)
        #expect(model.peakLevelR == 0)
    }

    @Test func audioEnginePannedVoiceProducesDistinctStereoMeterLevels() {
        func renderPannedLevels(pan: Float) -> (l: Float, r: Float, peakL: Float, peakR: Float) {
            let engine = AudioEngine()
            engine.prepare(sampleRate: 44_100, maxFrames: 512)

            var preset = SynthPreset.defaultPreset
            preset.pan = pan
            preset.unisonVoices = 1
            preset.chorusMix = 0
            preset.delayMix = 0
            preset.reverbMix = 0
            preset.stereoEnabled = false
            engine.preset = preset
            engine.applyPresetForTesting()

            engine.noteOn(midiNote: 60, velocity: 1.0)
            engine.processCommandsForTesting()

            let frames = engine.levelUpdateInterval * 2 + 64
            for _ in 0..<frames {
                _ = engine.renderOneSample()
            }
            engine.pollMetering()

            let result = (
                l: engine.meters.outputLevelL,
                r: engine.meters.outputLevelR,
                peakL: engine.meters.peakLevelL,
                peakR: engine.meters.peakLevelR
            )

            engine.stop()
            #expect(engine.currentLevelL == 0)
            #expect(engine.currentLevelR == 0)
            #expect(engine.meteringState.getOutputLevelL() == 0)
            #expect(engine.meteringState.getOutputLevelR() == 0)

            return result
        }

        let leftPanned = renderPannedLevels(pan: -1.0)
        #expect(leftPanned.l > 0.02)
        #expect(leftPanned.l > leftPanned.r * 10.0)
        #expect(leftPanned.peakL > leftPanned.peakR * 10.0)

        let rightPanned = renderPannedLevels(pan: 1.0)
        #expect(rightPanned.r > 0.02)
        #expect(rightPanned.r > rightPanned.l * 10.0)
        #expect(rightPanned.peakR > rightPanned.peakL * 10.0)
    }

    // MARK: - Oscilloscope & Spectrum Helpers

    @Test func oscilloscopeRisingZeroCrossingIndexFindsExpectedTrigger() {
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: [], maxSearch: 16) == 0)
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: [0.5], maxSearch: 16) == 0)

        // Exact 0.0 -> positive counts as rising zero crossing (<= 0 then > 0).
        let atZero: [Float] = [0.4, 0.2, 0.0, 0.3, 0.5]
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: atZero, maxSearch: 4) == 2)

        // Negative -> positive crossing.
        let negToPos: [Float] = [0.2, -0.3, -0.1, 0.15, 0.4]
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: negToPos, maxSearch: 4) == 2)

        // Crossing past maxSearch falls back to 0.
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: negToPos, maxSearch: 2) == 0)

        // Falling-only or unipolar buffers fall back to 0.
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: [0.5, 0.2, 0.0, -0.1, -0.4], maxSearch: 4) == 0)
        #expect(OscilloscopeView.risingZeroCrossingIndex(in: [0.1, 0.2, 0.3, 0.4], maxSearch: 4) == 0)
    }

    @Test func outputSpectrumCalculatorHandlesShortBuffersRepeatsAndPeaksCleanly() {
        let calc = OutputSpectrumCalculator.shared

        #expect(calc.computeMagnitudes(from: []).isEmpty)
        #expect(calc.computeMagnitudes(from: [Float](repeating: 0, count: 511)).isEmpty)

        let n = 512
        let sampleRate = 44_100.0
        let lowSine: [Float] = (0..<n).map { i in
            Float(sin(2.0 * Double.pi * 1000.0 * Double(i) / sampleRate))
        }
        let highSine: [Float] = (0..<n).map { i in
            Float(sin(2.0 * Double.pi * 6000.0 * Double(i) / sampleRate))
        }

        let magsLow1 = calc.computeMagnitudes(from: lowSine)
        let magsHigh = calc.computeMagnitudes(from: highSine)
        let magsLow2 = calc.computeMagnitudes(from: lowSine)

        #expect(magsLow1.count == 256)
        #expect(magsHigh.count == 256)
        #expect(magsLow1 == magsLow2)
        #expect(magsLow1.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
        #expect(magsHigh.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })

        let lowPeakBin = magsLow1.enumerated().max(by: { $0.element < $1.element })?.offset ?? -1
        let highPeakBin = magsHigh.enumerated().max(by: { $0.element < $1.element })?.offset ?? -1
        #expect(abs(lowPeakBin - Int(round(1000.0 * Double(n) / sampleRate))) <= 1)
        #expect(abs(highPeakBin - Int(round(6000.0 * Double(n) / sampleRate))) <= 1)
        #expect(highPeakBin > lowPeakBin + 40)
    }
}
