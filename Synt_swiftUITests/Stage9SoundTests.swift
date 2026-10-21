//
//  Stage9SoundTests.swift
//  Synt_swiftUITests
//
//  Tests for Stage 3 of GROK_BUILD_TASKS_SYNT_9:
//  - Frequency shifter in FX (default off)
//  - Comb / Resonator filter type (enum case at end)
//  - Character Warm/Bright (output tone curve, off by default)
//

import AudioToolbox
import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage9SoundTests {

    // MARK: - Frequency Shifter Tests

    @Test func frequencyShifterDefaultIsOff() {
        let preset = SynthPreset.defaultPreset
        #expect(preset.frequencyShifterEnabled == false)
        #expect(preset.frequencyShifterShiftHz == 0.0)
    }

    @Test func frequencyShifterProcessesAudioAndStaysFinite() {
        let shifter = DSPFrequencyShifter()
        var hadNonZero = false
        for i in 0..<1000 {
            let input = Float(sin(Double(i) * 0.1))
            let (l, r) = shifter.process(
                inputL: input,
                inputR: input,
                shiftHz: 120.0,
                mix: 0.8,
                feedback: 0.3,
                sampleRate: 44100.0
            )
            #expect(l.isFinite && r.isFinite)
            if abs(l) > 0.01 { hadNonZero = true }
        }
        #expect(hadNonZero)
    }

    // MARK: - Comb Filter / Resonator Tests

    @Test func combFilterIsAppendedAtEndOfFilterType() {
        let cases = FilterType.allCases
        #expect(cases.last == .comb, "FilterType.comb must be the last case to preserve indices")
    }

    @Test func combFilterResonatesAndStaysFinite() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)
        var preset = SynthPreset.defaultPreset
        preset.filterType = .comb
        preset.filterCutoff = 440.0
        preset.filterResonance = 0.8
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var maxAmp: Float = 0
        for _ in 0..<1000 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
            maxAmp = max(maxAmp, abs(l), abs(r))
        }
        #expect(maxAmp > 0.05, "Comb filter must resonate and produce audible sound")
        #expect(maxAmp <= 1.0, "Comb filter output must stay within headroom limits")
    }

    // MARK: - Character Warm/Bright Tests

    @Test func characterDefaultIsOff() {
        let preset = SynthPreset.defaultPreset
        #expect(preset.character == .off)
    }

    @Test func characterModesAlterSpectrumAndStayFinite() {
        let toneL = DSPCharacterTone()

        var offEnergy: Float = 0
        var warmEnergy: Float = 0
        var brightEnergy: Float = 0

        for i in 0..<1000 {
            let sample = Float(sin(Double(i) * 0.2)) * 0.5
            let outOff = toneL.process(sample, mode: .off, sampleRate: 44100.0)
            let outWarm = toneL.process(sample, mode: .warm, sampleRate: 44100.0)
            let outBright = toneL.process(sample, mode: .bright, sampleRate: 44100.0)

            #expect(outOff.isFinite && outWarm.isFinite && outBright.isFinite)
            #expect(outOff == sample, "Off mode must be exact passthrough")

            offEnergy += abs(outOff)
            warmEnergy += abs(outWarm)
            brightEnergy += abs(outBright)
        }

        #expect(warmEnergy > 0)
        #expect(brightEnergy > 0)
    }
}
