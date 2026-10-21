//
//  Phase3SynthesisTests.swift
//  Synt_swiftUITests
//
//  Tests for Phase 3: Synthesis Expansion (Sub-Oscillator, Linear FM, Hard Sync)
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct Phase3SynthesisTests {

    @Test func defaultsAndDecodersAreBackwardsCompatible() throws {
        let minimalJSON = """
        {
            "name": "Legacy Preset"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let preset = try decoder.decode(SynthPreset.self, from: minimalJSON)
        #expect(preset.subOscVolume == 0.0)
        #expect(preset.subOscOctave == -1)
        #expect(preset.subOscWaveform == .sine)
        #expect(preset.fmAmount == 0.0)
        #expect(!preset.oscSyncEnabled)
    }

    @Test func sanitizerClampsValues() {
        var preset = SynthPreset.defaultPreset
        preset.subOscVolume = 10.0
        preset.subOscOctave = -5
        preset.subOscWaveform = .sawtooth // unsupported for sub, should fallback to sine
        preset.fmAmount = 5.0

        let sanitized = preset.sanitized()
        #expect(sanitized.subOscVolume == 1.0)
        #expect(sanitized.subOscOctave == -1)
        #expect(sanitized.subOscWaveform == .sine)
        #expect(sanitized.fmAmount == 1.0)
    }

    @Test func subOscillatorRendersSubToneAndStaysFinite() {
        var plainPreset = SynthPreset.defaultPreset
        plainPreset.osc1Waveform = .sine
        plainPreset.osc2Enabled = false
        plainPreset.subOscVolume = 0.0

        var subPreset = plainPreset
        subPreset.subOscVolume = 0.8
        subPreset.subOscOctave = -1
        subPreset.subOscWaveform = .sine

        let count = 4410
        let plainAudio = renderPreset(plainPreset, count: count)
        let subAudio = renderPreset(subPreset, count: count)

        var maxPeak: Float = 0
        var diffSum: Float = 0
        for i in 0..<count {
            let l = subAudio[i]
            #expect(l.isFinite, "Sub oscillator produced NaN/Inf")
            maxPeak = max(maxPeak, abs(l))
            let d = l - plainAudio[i]
            diffSum += d * d
        }
        let rmsDiff = sqrt(diffSum / Float(count))
        #expect(rmsDiff > 0.01, "Sub oscillator should alter the audio signal")
        #expect(maxPeak <= 1.0, "Sub oscillator with headroom protection should not clip (peak \(maxPeak))")
    }

    @Test func subOscOctavesAndWavesProduceDistinctTimbres() {
        var basePreset = SynthPreset.defaultPreset
        basePreset.osc1Waveform = .sine
        basePreset.osc2Enabled = false
        basePreset.subOscVolume = 0.7

        var sinePreset = basePreset
        sinePreset.subOscWaveform = .sine

        var triPreset = basePreset
        triPreset.subOscWaveform = .triangle

        var sqrPreset = basePreset
        sqrPreset.subOscWaveform = .square

        let count = 4410
        let sineAudio = renderPreset(sinePreset, count: count)
        let triAudio = renderPreset(triPreset, count: count)
        let sqrAudio = renderPreset(sqrPreset, count: count)

        let diffTriSine = differenceRMS(triAudio, sineAudio)
        let diffSqrSine = differenceRMS(sqrAudio, sineAudio)
        #expect(diffTriSine > 0.005, "Triangle sub should differ from Sine sub")
        #expect(diffSqrSine > 0.01, "Square sub should differ from Sine sub")
    }

    @Test func fmCrossModulationAltersSpectrumWithoutOverload() {
        var plainPreset = SynthPreset.defaultPreset
        plainPreset.osc1Waveform = .sine
        plainPreset.osc2Enabled = false
        plainPreset.osc2Waveform = .sine
        plainPreset.osc2Octave = 1
        plainPreset.fmAmount = 0.0

        var fmPreset = plainPreset
        fmPreset.fmAmount = 0.8

        let count = 8820
        let plainAudio = renderPreset(plainPreset, count: count)
        let fmAudio = renderPreset(fmPreset, count: count)

        var maxPeak: Float = 0
        for s in fmAudio {
            #expect(s.isFinite, "FM produced NaN/Inf")
            maxPeak = max(maxPeak, abs(s))
        }

        let diff = differenceRMS(fmAudio, plainAudio)
        #expect(diff > 0.01, "FM cross-modulation should alter the output sound")
        #expect(maxPeak < 1.5, "FM peak \(maxPeak) should stay well-behaved")
    }

    @Test func hardSyncResetsSlavePhaseAndModifiesHarmonics() {
        var plainPreset = SynthPreset.defaultPreset
        plainPreset.osc1Waveform = .sawtooth
        plainPreset.osc2Enabled = true
        plainPreset.osc2Waveform = .sawtooth
        plainPreset.osc2Octave = 1
        plainPreset.osc2Detune = 15.0
        plainPreset.oscSyncEnabled = false

        var syncPreset = plainPreset
        syncPreset.oscSyncEnabled = true

        let count = 8820
        let plainAudio = renderPreset(plainPreset, count: count)
        let syncAudio = renderPreset(syncPreset, count: count)

        var maxPeak: Float = 0
        for s in syncAudio {
            #expect(s.isFinite, "Sync produced NaN/Inf")
            maxPeak = max(maxPeak, abs(s))
        }

        let diff = differenceRMS(syncAudio, plainAudio)
        #expect(diff > 0.005, "Hard Sync should audibly alter the harmonic spectrum")
        #expect(maxPeak < 1.5, "Sync peak \(maxPeak) should stay under limit")
    }

    private func renderPreset(_ preset: SynthPreset, count: Int) -> [Float] {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 55, velocity: 0.8)
        engine.processCommandsForTesting()

        var output = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let (l, _) = engine.renderOneSample()
            output[i] = l
        }
        return output
    }

    private func differenceRMS(_ a: [Float], _ b: [Float]) -> Float {
        let count = min(a.count, b.count)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count {
            let d = a[i] - b[i]
            sum += d * d
        }
        return sqrt(sum / Float(count))
    }
}
