//
//  Phase8WorkflowTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase 8: Smart Mutate, MIDI File Export, and Audio Recording.
//

import Foundation
import Testing
import AVFoundation
@testable import Synt_swiftUI

@MainActor
struct Phase8WorkflowTests {

    @Test func smartMutateAltersParametersSafelyWithoutTouchingMasterVolume() {
        let original = SynthPreset.defaultPreset
        let mutated = PresetMutator.mutate(preset: original, amount: 0.15)

        // 1. Master volume MUST NOT change (to guarantee headroom safety)
        #expect(mutated.masterVolume == original.masterVolume)

        // 2. Name receives marker
        #expect(mutated.name.hasSuffix(" *"))

        // 3. Parameters stay within valid physical bounds
        #expect(mutated.filterCutoff >= 20.0 && mutated.filterCutoff <= 20000.0)
        #expect(mutated.filterResonance >= 0.0 && mutated.filterResonance <= 0.95)
        #expect(mutated.filterEnvelopeAmount >= -1.0 && mutated.filterEnvelopeAmount <= 1.0)
        #expect(mutated.attack >= 0.001 && mutated.attack <= 5.0)
        #expect(mutated.decay >= 0.01 && mutated.decay <= 10.0)
        #expect(mutated.sustain >= 0.0 && mutated.sustain <= 1.0)
        #expect(mutated.release >= 0.01 && mutated.release <= 10.0)
        #expect(mutated.lfoRate >= 0.05 && mutated.lfoRate <= 20.0)
        #expect(mutated.lfo2Rate >= 0.05 && mutated.lfo2Rate <= 20.0)
        #expect(mutated.delayFeedback >= 0.0 && mutated.delayFeedback <= 0.85)
        #expect(mutated.reverbMix >= 0.0 && mutated.reverbMix <= 0.8)

        // 4. Repeated mutations stay within bounds
        var iterative = original
        for _ in 0..<20 {
            iterative = PresetMutator.mutate(preset: iterative, amount: 0.15)
            #expect(iterative.filterCutoff >= 20.0 && iterative.filterCutoff <= 20000.0)
            #expect(iterative.filterResonance >= 0.0 && iterative.filterResonance <= 0.95)
            #expect(iterative.attack >= 0.001 && iterative.attack <= 5.0)
            #expect(iterative.release >= 0.01 && iterative.release <= 10.0)
            #expect(iterative.masterVolume == original.masterVolume)
        }
    }

    @Test func midiFileBuilderGeneratesValidSMFType0() {
        let steps: [SequencerStep] = (0..<16).map { i in
            SequencerStep(isActive: i % 2 == 0, noteOffset: i, velocity: 0.8, tie: i == 0, gate: 0.75)
        }

        let smfData = MIDIFileBuilder.buildSMF(steps: steps, rootNote: 60, bpm: 128.0)

        // 1. Minimum valid SMF header + track length
        #expect(smfData.count > 30)

        // 2. Magic header "MThd"
        let headerPrefix = Array(smfData[0..<4])
        #expect(headerPrefix == [0x4D, 0x54, 0x68, 0x64]) // "MThd"

        // 3. Header length is 6
        let headerLength = Array(smfData[4..<8])
        #expect(headerLength == [0x00, 0x00, 0x00, 0x06])

        // 4. Format 0, 1 track, 480 PPQN
        let formatAndTracks = Array(smfData[8..<14])
        #expect(formatAndTracks == [0x00, 0x00, 0x00, 0x01, 0x01, 0xE0])

        // 5. Track chunk "MTrk"
        let trackPrefix = Array(smfData[14..<18])
        #expect(trackPrefix == [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"

        // 6. Track ends with End-of-Track meta event [0xFF, 0x2F, 0x00]
        let endBytes = Array(smfData.suffix(3))
        #expect(endBytes == [0xFF, 0x2F, 0x00])
    }

    @Test func audioEngineAudioRecordingStartsAndStopsCleanly() {
        let engine = AudioEngine()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Test_Recording_\(UUID().uuidString).wav")

        #expect(!engine.isRecording)

        // Start recording
        let started = engine.startRecording(to: tempURL)
        #expect(started)
        #expect(engine.isRecording)

        // Stop recording
        let finishedURL = engine.stopRecording()
        #expect(!engine.isRecording)
        #expect(finishedURL == tempURL)

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test func performanceMacrosModulateParametersSafely() {
        let base = SynthPreset.defaultPreset

        // Neutral macros return unchanged preset
        let neutral = PerformanceMacros()
        #expect(neutral.isNeutral)
        let unchanged = neutral.apply(to: base)
        #expect(unchanged == base)

        // Positive & negative extremes stay within physical bounds and preserve masterVolume
        let macros = PerformanceMacros(brightness: 0.8, timbre: 0.7, movement: 0.6, space: 0.9)
        #expect(!macros.isNeutral)
        let applied = macros.apply(to: base)
        #expect(applied.masterVolume == base.masterVolume)
        #expect(applied.filterCutoff > base.filterCutoff)
        #expect(applied.osc1WavetableMorph > base.osc1WavetableMorph)
        #expect(applied.fmAmount > base.fmAmount)
        #expect(applied.lfoDepth > base.lfoDepth)
        #expect(applied.reverbMix > base.reverbMix)
        #expect(applied.delayMix > base.delayMix)
        #expect(applied.chorusMix > base.chorusMix)
    }

    @Test func midiFileBuilderRespectsStepOctaveAndLength() {
        var step = SequencerStep(isActive: true, noteOffset: 0, velocity: 0.8, tie: false, gate: 0.5)
        step.octave = 1 // +12 semitones from root 60 -> 72 (0x48)
        let steps = [step] + Array(repeating: SequencerStep(isActive: false), count: 15)

        let smfData = MIDIFileBuilder.buildSMF(steps: steps, rootNote: 60, bpm: 120.0, length: 4)
        // Verify Note-On (0x90, 72) is present in track data
        let bytes = [UInt8](smfData)
        var foundNote72 = false
        for i in 0..<(bytes.count - 2) {
            if bytes[i] == 0x90 && bytes[i + 1] == 72 {
                foundNote72 = true
                break
            }
        }
        #expect(foundNote72)
    }

    @Test func presetBrowserNavigatesExpansionPresets() {
        let firstExp = SynthPreset.expansionPresets[0]
        let secondExp = SynthPreset.expansionPresets[1]
        let lastExp = SynthPreset.expansionPresets[SynthPreset.expansionPresets.count - 1]

        #expect(PresetBrowser.counterLabel(for: firstExp) == "E01 / 050")
        #expect(PresetBrowser.counterLabel(for: lastExp) == "E50 / 050")
        #expect(PresetBrowser.step(from: firstExp, by: 1).name == secondExp.name)
        #expect(PresetBrowser.step(from: firstExp, by: -1).name == lastExp.name)
    }

    @Test func phase8PreservesInitGolden() {
        let golden: UInt64 = 0xd1b3635203a4799e
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == golden,
                "Init hash changed to 0x\(String(hash, radix: 16)); expected 0x\(String(golden, radix: 16))")
    }
}
