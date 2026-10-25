//
//  SampleRateTests.swift
//  A4 and the LFO stay on the clock when the engine rate changes.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct SampleRateTests {

    @Test func a4Is440HzAt44100And48000() {
        let at44 = fundamentalHz(sampleRate: 44_100)
        let at48 = fundamentalHz(sampleRate: 48_000)
        #expect(abs(at44 - 440) <= 1, "44100 Hz engine measured \(at44) Hz")
        #expect(abs(at48 - 440) <= 1, "48000 Hz engine measured \(at48) Hz")
    }

    @Test func lfoPeriodMatchesInSecondsAtBothRates() {
        let at44 = lfoPeriodSeconds(sampleRate: 44_100, rate: 5)
        let at48 = lfoPeriodSeconds(sampleRate: 48_000, rate: 5)
        #expect(abs(at44 - 0.2) < 0.002, "LFO period at 44100: \(at44) s")
        #expect(abs(at48 - 0.2) < 0.002, "LFO period at 48000: \(at48) s")
        #expect(abs(at44 - at48) < 0.002)
    }

    @Test func rebuildingTheGraphAdoptsTheNewSampleRate() {
        let engine = AudioEngine()
        engine.applySampleRateForTesting(48_000, rebuildGraph: true)
        #expect(abs(engine.sampleRate - 48_000) < 0.5)
        #expect(abs(engine.graphSampleRateForTesting - 48_000) < 0.5)
        #expect(abs(engine.sourceNodeSampleRateForTesting - 48_000) < 0.5)
    }

    private func fundamentalHz(sampleRate: Double) -> Double {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(sampleRate)
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .sine
        preset.osc1Volume = 0.8
        preset.osc2Enabled = false
        preset.attack = 0.001
        preset.decay = 0.01
        preset.sustain = 1
        preset.filterCutoff = 18_000
        preset.filterResonance = 0
        preset.chorusMix = 0
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.masterVolume = 0.7
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 69, velocity: 1)
        engine.processCommandsForTesting()

        let warmup = Int(sampleRate * 0.25)
        _ = engine.renderFramesForTesting(warmup)

        let frames = Int(sampleRate)
        var crossings = 0
        var previous: Float = 0
        for _ in 0..<frames {
            let (left, right) = engine.renderOneSample()
            let sample = (left + right) * 0.5
            if previous <= 0, sample > 0 { crossings += 1 }
            previous = sample
        }
        return Double(crossings)
    }

    /// Average seconds between upward crossings over two seconds of the engine LFO.
    private func lfoPeriodSeconds(sampleRate: Double, rate: Float) -> Double {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(sampleRate)
        engine.lfo.enabled = true
        engine.lfo.rate = rate
        engine.lfo.depth = 1
        engine.lfo.waveform = .sine
        engine.lfo.reset()

        let frames = Int(engine.sampleRate * 2)
        var first: Int?
        var last = 0
        var crossings = 0
        var previous: Float = 0
        for index in 0..<frames {
            let value = engine.lfo.getValue(sampleRate: engine.sampleRate)
            if previous <= 0, value > 0 {
                if first == nil { first = index }
                last = index
                crossings += 1
            }
            previous = value
        }
        guard let first, crossings >= 2 else { return -1 }
        return Double(last - first) / Double(crossings - 1) / engine.sampleRate
    }

    @Test func parameterSmoothingTimeIsRateIndependent() {
        #expect(AudioEngine.smoothingCoefficient(sampleRate: 44_100) == 0.999)
        // Same decay after 1 s of samples at either rate.
        let at44 = pow(Double(AudioEngine.smoothingCoefficient(sampleRate: 44_100)), 44_100)
        let at96 = pow(Double(AudioEngine.smoothingCoefficient(sampleRate: 96_000)), 96_000)
        #expect(abs(at44 - at96) < 1e-4)
        let engine = AudioEngine()
        engine.setSampleRateForTesting(96_000)
        #expect(engine.smoothingCoeff > 0.999)
    }
}
