//
//  Phase2WavetableTests.swift
//  Synt_swiftUITests
//
//  Tests for Phase 2: Full Wavetable Synthesis (5 tables + morph modulation)
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct Phase2WavetableTests {

    @Test func allFiveWavetablesLoadAndRenderFiniteAudio() {
        for tableIndex in 0..<5 {
            var preset = SynthPreset.defaultPreset
            preset.osc1Waveform = .wavetable
            preset.osc1WavetableIndex = tableIndex
            preset.osc1WavetableMorph = 0.5
            preset.osc2Enabled = false

            let engine = AudioEngine()
            engine.preset = preset
            engine.applyPresetForTesting()
            engine.noteOn(midiNote: 60, velocity: 0.8)
            engine.processCommandsForTesting()

            var peak: Float = 0
            var finite = true
            let sampleCount = 4410
            for _ in 0..<sampleCount {
                let (l, r) = engine.renderOneSample()
                if !l.isFinite || !r.isFinite { finite = false }
                peak = max(peak, abs(l), abs(r))
            }

            #expect(finite, "Table \(tableIndex) produced NaN/Inf")
            #expect(peak > 0.01, "Table \(tableIndex) is silent (peak \(peak))")
            #expect(peak < 1.5, "Table \(tableIndex) peak \(peak) is too loud")
        }
    }

    @Test func wavetableIndexDecodesSafelyWithDefault() throws {
        let minimalJSON = """
        {
            "name": "Legacy Preset"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let preset = try decoder.decode(SynthPreset.self, from: minimalJSON)
        #expect(preset.osc1WavetableIndex == 0)
        #expect(preset.osc2WavetableIndex == 0)
    }

    @Test func wavetableSanitizeClampsIndex() {
        var preset = SynthPreset.defaultPreset
        preset.osc1WavetableIndex = 99
        preset.osc2WavetableIndex = -10
        let sanitized = preset.sanitized()
        #expect(sanitized.osc1WavetableIndex == 5)
        #expect(sanitized.osc2WavetableIndex == 0)
    }

    @Test func wavetableMorphModulationAltersSignal() {
        var stillPreset = SynthPreset.defaultPreset
        stillPreset.osc1Waveform = .wavetable
        stillPreset.osc1WavetableIndex = 2 // Digital
        stillPreset.osc1WavetableMorph = 0.1
        stillPreset.osc2Enabled = false
        stillPreset.lfoEnabled = true
        stillPreset.lfoRate = 5.0
        stillPreset.lfoDepth = 1.0
        stillPreset.lfoTarget = .none
        stillPreset.modMatrix = []

        var modPreset = stillPreset
        modPreset.modMatrix = [
            ModMatrixEntry(source: .lfo1, destination: .wtMorph1, amount: 0.8)
        ]

        let count = 44100 / 2 // 0.5s
        let stillAudio = renderPreset(stillPreset, count: count)
        let modAudio = renderPreset(modPreset, count: count)

        var diffSum: Float = 0
        for i in 0..<count {
            let diff = stillAudio[i] - modAudio[i]
            diffSum += diff * diff
        }
        let rmsDiff = sqrt(diffSum / Float(count))
        #expect(rmsDiff > 1e-3, "Morph modulation should audibly alter the digital wavetable signal")
    }

    @Test func wavetableMorphProducesSmoothTransition() {
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .wavetable
        preset.osc1WavetableIndex = 0
        preset.osc1WavetableMorph = 0.0
        preset.osc2Enabled = false

        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 55, velocity: 0.8)
        engine.processCommandsForTesting()

        // Render 1000 samples at morph 0, then jump morph to 1.0, verify max delta between consecutive samples
        var prevSample: Float = 0
        var maxDelta: Float = 0
        for i in 0..<4410 {
            if i == 500 {
                preset.osc1WavetableMorph = 1.0
                engine.preset = preset
                engine.applyPresetForTesting()
            }
            let (l, _) = engine.renderOneSample()
            if i > 0 {
                let delta = abs(l - prevSample)
                maxDelta = max(maxDelta, delta)
            }
            prevSample = l
        }

        // At audio rates, delta between consecutive band-limited samples without clicks stays well under 0.8
        #expect(maxDelta < 0.8, "Max sample-to-sample jump during morph was \(maxDelta)")
    }

    private func renderPreset(_ preset: SynthPreset, count: Int) -> [Float] {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()

        var output = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let (l, _) = engine.renderOneSample()
            output[i] = l
        }
        return output
    }
}
