//
//  Stage10CriticalTests.swift
//  Synt_swiftUITests
//
//  Stage 1: Critical DSP fixes for GROK_BUILD_TASKS_SYNT_10:
//  - R7-1: Hilbert network second sideband <= -40 dB
//  - R7-3: NaN check before fastTanh; reset on NaN fires, no DC
//  - R7-4: Release curve starts from actual level, not 1.0
//  - R7-5: Attack curve starts from current level (retrigger/legato without dips)
//  - R7-2: Amp LFO with stereo phase applies once (no doubled tremolo)
//

import Foundation
import Testing
@testable import SynthCore

@Suite struct Stage10CriticalTests {

    // MARK: - R7-1: Hilbert Network Sideband Suppression

    @Test func frequencyShifterSecondSidebandAtLeast40dBDown() {
        let shifter = DSPFrequencyShifter()
        let sr: Float = 44100.0
        let fIn: Float = 1000.0
        let shiftHz: Float = 100.0
        let samples = 8192

        var out = [Float](repeating: 0, count: samples)
        for i in 0..<samples {
            let t = Float(i) / sr
            let sig = sin(2.0 * Float.pi * fIn * t)
            let (l, _) = shifter.process(
                inputL: sig,
                inputR: sig,
                shiftHz: shiftHz,
                mix: 1.0,
                feedback: 0.0,
                sampleRate: sr
            )
            out[i] = l
        }

        // Measure energy at target (1100 Hz) vs unwanted image (900 Hz) via Goertzel or DFT
        // Discard first 2048 samples for filter settle
        let start = 2048
        let n = samples - start

        func dftMagnitude(at freq: Float) -> Float {
            var re: Float = 0
            var im: Float = 0
            let omega = 2.0 * Float.pi * freq / sr
            for i in 0..<n {
                let sample = out[start + i]
                // Apply Hann window
                let w = 0.5 * (1.0 - cos(2.0 * Float.pi * Float(i) / Float(n)))
                let windowed = sample * w
                let phase = omega * Float(i)
                re += windowed * cos(phase)
                im -= windowed * sin(phase)
            }
            return sqrt(re * re + im * im)
        }

        let magTarget = dftMagnitude(at: fIn + shiftHz) // 1100 Hz
        let magImage = dftMagnitude(at: fIn - shiftHz)  // 900 Hz

        #expect(magTarget > 0.1)
        let suppressionDB = 20.0 * log10(magImage / magTarget)
        // Expected: second sideband <= -40 dB
        #expect(suppressionDB <= -40.0, "Second sideband suppression was \(suppressionDB) dB, expected <= -40 dB")
    }

    // MARK: - R7-3: NaN check before fastTanh; on NaN reset filter and feedback

    @Test func filterFeedbackRecoversFromNaNWithoutDCOffset() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)
        var preset = SynthPreset.defaultPreset
        preset.filterFeedback = 0.95
        preset.filterType = .lowPass
        preset.filterCutoff = 1000.0
        preset.filterResonance = 0.5
        engine.preset = preset

        engine.handleNoteOn(midiNote: 60, velocity: 1.0)
        _ = engine.renderOneSample()

        // Inject NaN directly into voice filter feedback
        engine.voices[0].filterFeedbackState = Float.nan
        engine.voices[0].filter.x1 = Float.nan

        // Render samples: the engine must detect non-finite, reset filter, and not produce NaN or DC peg
        for _ in 0..<500 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
            #expect(!l.isNaN && !r.isNaN)
        }

        #expect(engine.voices[0].filterFeedbackState.isFinite)
        #expect(!engine.voices[0].filterFeedbackState.isNaN)
    }

    // MARK: - R7-4: Release Curve Starts from Actual Level

    @Test func releaseCurveStartsFromActualLevelWithoutJumpToUnity() {
        var adsr = ADSREnvelope(attack: 0.01, decay: 0.1, sustain: 0.5, release: 0.2)
        adsr.releaseCurve = 0.5 // Non-zero curve

        var phase: EnvelopePhase = .release
        var time: Double = 0.0
        let lowReleaseLevel: Float = 0.00005 // Lower than 0.0001 threshold

        let val = adsr.process(
            currentValue: lowReleaseLevel,
            phase: &phase,
            time: &time,
            releaseStartValue: lowReleaseLevel,
            isReleasing: true,
            sampleRate: 44100.0
        )

        // Must not jump to 1.0!
        #expect(val <= lowReleaseLevel + 0.0001, "Expected release to start from \(lowReleaseLevel), got \(val)")
        #expect(val >= 0.0)
    }

    // MARK: - R7-5: Attack Curve Starts from Current Level

    @Test func attackCurveStartsFromCurrentLevelWithoutDipping() {
        var adsr = ADSREnvelope(attack: 0.1, decay: 0.1, sustain: 0.5, release: 0.2)
        adsr.attackCurve = 0.6 // Convex curve

        var phase: EnvelopePhase = .attack
        var time: Double = 0.0
        let currentLevel: Float = 0.55 // Legato / retrigger from 0.55

        let val = adsr.process(
            currentValue: currentLevel,
            phase: &phase,
            time: &time,
            releaseStartValue: 0.0,
            isReleasing: false,
            sampleRate: 44100.0
        )

        // On first sample of retrigger, value must be >= currentLevel, NOT dip towards 0!
        #expect(val >= currentLevel - 0.001, "Expected attack to start >= \(currentLevel), but dipped to \(val)")
        #expect(val <= 1.0)
    }

    // MARK: - R7-2: Amp LFO with Stereo Phase Applies Once

    @Test func ampLFOWithStereoPhaseDoesNotDoubleTremolo() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)
        var preset = SynthPreset.defaultPreset
        preset.lfoEnabled = true
        preset.lfoTarget = .amplitude
        preset.lfoDepth = 0.5
        preset.lfoRate = 5.0
        preset.lfoStereoPhase = 0.0
        engine.preset = preset

        engine.handleNoteOn(midiNote: 60, velocity: 1.0)

        // Render at stereo phase 0
        var monoMin: Float = 1.0
        var monoMax: Float = 0.0
        for _ in 0..<8820 {
            let (l, _) = engine.renderOneSample()
            if l > 0.01 {
                monoMin = min(monoMin, l)
                monoMax = max(monoMax, l)
            }
        }
        let monoRange = monoMax - monoMin

        // Now set stereo phase 180 degrees
        preset.lfoStereoPhase = 180.0
        engine.preset = preset
        engine.handleNoteOn(midiNote: 60, velocity: 1.0)

        var stereoMin: Float = 1.0
        var stereoMax: Float = 0.0
        for _ in 0..<8820 {
            let (l, _) = engine.renderOneSample()
            if l > 0.01 {
                stereoMin = min(stereoMin, l)
                stereoMax = max(stereoMax, l)
            }
        }
        let stereoRange = stereoMax - stereoMin

        // Stereo tremolo modulation depth should be approximately the same as mono, NOT doubled!
        let ratio = stereoRange / max(0.001, monoRange)
        #expect(ratio > 0.7 && ratio < 1.3, "Stereo tremolo range \(stereoRange) should match mono \(monoRange), ratio \(ratio)")
    }
}
