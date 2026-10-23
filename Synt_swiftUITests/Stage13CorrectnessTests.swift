//
//  Stage13CorrectnessTests.swift
//  Synt_swiftUITests
//
//  Stage 2 tests for GROK_BUILD_TASKS_SYNT_13:
//  - R10-3: maxHarmonics correct at 44.1/48/96 kHz; single shared formula
//  - R10-4: seed applied only on render path; knob edits do not reset S&H
//  - R7-10: right-channel phase fix and stereo offset tests
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage13CorrectnessTests: XCTestCase {

    func testMaxHarmonicsAtDifferentSampleRates() throws {
        let sampleRates: [Double] = [44100.0, 48000.0, 96000.0]

        for sr in sampleRates {
            let harmonics = WavetableOscillator.mipMaxHarmonics(count: 11, sampleRate: sr)
            XCTAssertEqual(harmonics.count, 11)

            let nyquist = sr * 0.5
            for oct in 0..<11 {
                let fHigh = 20.0 * pow(2.0, Double(oct + 1))
                let expected = max(1, Int(floor(nyquist / fHigh)))
                XCTAssertEqual(harmonics[oct], expected, "Octave \(oct) maxHarmonic mismatch at SR \(sr)")
                XCTAssertEqual(harmonics[oct], WavetableOscillator.maxHarmonic(forOctave: oct, sampleRate: sr))
            }
        }

        // Oscillator setSampleRate triggers mip update
        let osc = WavetableOscillator()
        osc.setSampleRate(96000.0)
        let expected0 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 96000.0)
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected0)
    }

    func testSeedAppliedOnlyOnRenderPathAndKnobEditDoesNotResetSH() throws {
        let engine = AudioEngine()
        engine.preset.randomSeed = 0x98765432
        engine.preset.lfoEnabled = true
        engine.preset.lfoWaveform = .noise
        engine.preset.lfoRate = 50.0 // Fast enough to trigger S&H draws
        engine.applyPreset()

        // Render samples to advance LFO phase and draw random values
        for _ in 0..<1000 {
            _ = engine.renderOneSample()
        }

        let shValueBeforeKnobEdit = engine.lfo.lastRandomValue

        // Simulate knob editing on main thread
        engine.preset.filterCutoff = 3500.0
        engine.preset.filterResonance = 0.7
        engine.preset.attack = 0.05
        engine.applyPreset()

        // S&H must NOT reset on knob edit
        let shValueAfterKnobEdit = engine.lfo.lastRandomValue
        XCTAssertEqual(
            shValueAfterKnobEdit,
            shValueBeforeKnobEdit,
            "Knob edit via applyPreset must NOT reset S&H random state"
        )
    }

    func testR7_10RightChannelPhase() throws {
        let lfo = LFO()
        lfo.waveform = .sine
        lfo.rate = 100.0

        // Zero offset -> L and R strictly equal
        lfo.stereoPhaseOffsetDegrees = 0.0
        lfo.startPhaseDegrees = 45.0
        lfo.trigger()
        for _ in 0..<100 {
            let (l, r) = lfo.nextStereoRawValue(sampleRate: 44100.0)
            XCTAssertEqual(l, r, accuracy: 1e-6, "With 0 degree offset, L and R must match")
        }

        // 180 degrees offset -> L and R strictly inverted
        lfo.stereoPhaseOffsetDegrees = 180.0
        lfo.startPhaseDegrees = 0.0
        lfo.trigger()
        for _ in 0..<100 {
            let (l, r) = lfo.nextStereoRawValue(sampleRate: 44100.0)
            XCTAssertEqual(l, -r, accuracy: 1e-4, "With 180 degree offset, L and R must be inverted")
        }

        // 90 degrees offset -> orthogonal (sine vs cosine)
        lfo.stereoPhaseOffsetDegrees = 90.0
        lfo.startPhaseDegrees = 0.0
        lfo.trigger()
        let (l0, r0) = lfo.nextStereoRawValue(sampleRate: 44100.0)
        // At phase near 0, sin(0) ~ 0, cos(0) ~ 1
        XCTAssertLessThan(abs(l0), 0.1)
        XCTAssertGreaterThan(r0, 0.9)

        // Test triangle and saw waveforms with offset wrap
        for wf in [WaveformType.triangle, WaveformType.sawtooth, WaveformType.square] {
            lfo.waveform = wf
            lfo.stereoPhaseOffsetDegrees = 270.0
            lfo.startPhaseDegrees = 180.0
            lfo.trigger()
            for _ in 0..<200 {
                let (l, r) = lfo.nextStereoRawValue(sampleRate: 44100.0)
                XCTAssertTrue(l.isFinite && r.isFinite)
                XCTAssertGreaterThanOrEqual(l, -1.05)
                XCTAssertLessThanOrEqual(l, 1.05)
                XCTAssertGreaterThanOrEqual(r, -1.05)
                XCTAssertLessThanOrEqual(r, 1.05)
            }
        }
    }
}
