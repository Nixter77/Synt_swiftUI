//
//  ModulationAndVoiceTests.swift
//  Synt_swiftUITests
//
//  Stage 3: Velocity scaling, mod env 3, matrix sources, glide modes and mono priority.
//

import Testing
import Foundation
@testable import SynthCore

@Suite struct ModulationAndVoiceTests {

    @Test func velocityToVolumeZeroGivesIdenticalLoudnessForDifferentVelocities() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.velocityToVolume = 0.0
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.prepare(sampleRate: 44_100, maxFrames: 256)

        // Note at velocity 0.1
        for i in 0..<AudioEngine.maxVoices { engine.voices[i].deactivate() }
        engine.handleNoteOn(midiNote: 60, velocity: 0.1)
        var bufferQuiet: [Float] = []
        for _ in 0..<100 {
            let (l, _) = engine.renderOneSample()
            bufferQuiet.append(l)
        }

        // Note at velocity 1.0
        for i in 0..<AudioEngine.maxVoices { engine.voices[i].deactivate() }
        engine.handleNoteOn(midiNote: 60, velocity: 1.0)
        var bufferLoud: [Float] = []
        for _ in 0..<100 {
            let (l, _) = engine.renderOneSample()
            bufferLoud.append(l)
        }

        #expect(bufferQuiet.count == bufferLoud.count)
        for i in 0..<bufferQuiet.count {
            #expect(abs(bufferQuiet[i] - bufferLoud[i]) < 1e-5)
        }
    }

    @Test func modEnvToPitchSettlesAfterDecayTime() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.modEnvAttack = 0.001
        preset.modEnvDecay = 0.050 // 50 ms
        preset.modEnvSustain = 0.0
        preset.modEnvRelease = 0.010
        preset.modMatrix = [ModMatrixEntry(source: .modEnv, destination: .pitch1, amount: 1.0)]
        engine.preset = preset
        engine.applyPresetForTesting()
        let sampleRate = 44_100.0
        engine.prepare(sampleRate: sampleRate, maxFrames: 256)

        engine.handleNoteOn(midiNote: 69, velocity: 1.0) // A4 = 440 Hz

        // Render 20 ms (~882 samples) — mod envelope is still decaying, pitch should be elevated
        for _ in 0..<Int(0.020 * sampleRate) {
            _ = engine.renderOneSample()
        }
        let voiceMid = engine.voices.first { $0.isActive }!
        #expect(voiceMid.modEnvelopeValue > 0.05, "Mod env should still be active at 20 ms")

        // Render until 70 ms total (> 50 ms decay + 4 ms min attack)
        for _ in 0..<Int(0.050 * sampleRate) {
            _ = engine.renderOneSample()
        }
        let voiceLate = engine.voices.first { $0.isActive }!
        #expect(voiceLate.modEnvelopeValue == 0.0, "Mod env should be fully settled to sustain (0.0) after 70 ms")
    }

    @Test func randomToPanGivesSpreadAndIsDeterministicWithFixedSeed() {
        func collectPanValues(seed: UInt32) -> [Float] {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.modMatrix = [ModMatrixEntry(source: .random, destination: .pan, amount: 1.0)]
            engine.preset = preset
            engine.applyPresetForTesting()
            engine.prepare(sampleRate: 44_100, maxFrames: 64)
            engine.randomSeed = seed

            var pans: [Float] = []
            for note in 0..<100 {
                for i in 0..<AudioEngine.maxVoices {
                    engine.voices[i].deactivate()
                }
                let midi = 60 + (note % 12)
                engine.handleNoteOn(midiNote: midi, velocity: 0.8)
                let active = engine.voices.first { $0.isActive && $0.midiNote == midi && !$0.isReleasing }!
                pans.append(active.randomValue)
            }
            return pans
        }

        let run1 = collectPanValues(seed: 0xDEADBEEF)
        let run2 = collectPanValues(seed: 0xDEADBEEF)

        #expect(run1.count == 100)
        #expect(run1 == run2, "Random mod source must be bit-deterministic for identical seeds")

        let unique = Set(run1)
        #expect(unique.count > 50, "Random mod source should provide rich spread across 100 notes")
        let minVal = run1.min()!
        let maxVal = run1.max()!
        #expect(minVal < -0.5, "Spread should cover negative range")
        #expect(maxVal > 0.5, "Spread should cover positive range")
    }

    @Test func rateGlideSlidesTwiceAsLongForOctaveThanSixSemitones() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.voiceMode = .legato
        preset.glideMode = .rate
        preset.portamento = 0.100 // 100 ms for 12 semitones
        engine.preset = preset
        engine.applyPresetForTesting()
        let sampleRate = 44_100.0
        engine.prepare(sampleRate: sampleRate, maxFrames: 256)

        // Helper to measure steps to complete 50% frequency transition
        func measureHalfWaySamples(from startNote: Int, to endNote: Int) -> Int {
            for i in 0..<AudioEngine.maxVoices {
                engine.voices[i].deactivate()
            }
            engine.lastPlayedFrequency = nil
            engine.handleNoteOn(midiNote: startNote, velocity: 0.8)
            // Render 200 samples to stabilize at start note
            for _ in 0..<200 { _ = engine.renderOneSample() }

            let startFreq = AudioMath.midiToFrequency(startNote)
            let endFreq = AudioMath.midiToFrequency(endNote)
            let halfWayFreq = startFreq + (endFreq - startFreq) * 0.5

            engine.handleNoteOn(midiNote: endNote, velocity: 0.8)
            var samples = 0
            while samples < 44_100 {
                _ = engine.renderOneSample()
                samples += 1
                guard let v = engine.voices.first(where: { $0.isActive && $0.midiNote == endNote && !$0.isReleasing }) else {
                    continue
                }
                if v.currentFrequency >= halfWayFreq {
                    break
                }
            }
            return samples
        }

        let samples12 = measureHalfWaySamples(from: 60, to: 72) // 12 semitones
        let samples6 = measureHalfWaySamples(from: 60, to: 66)  // 6 semitones

        // Ratio should be very close to 2.0 (tolerance 1.7 ... 2.3)
        let ratio = Double(samples12) / Double(samples6)
        #expect(ratio >= 1.7 && ratio <= 2.3, "Octave glide (\(samples12)) must take ~2x longer than 6 semitones (\(samples6)), ratio: \(ratio)")
    }

    @Test func monoPrioritySelectsCorrectHeldNote() {
        var stack = MonoNoteStack()
        stack.push(note: 60, velocity: 0.7)
        stack.push(note: 72, velocity: 0.8)
        stack.push(note: 48, velocity: 0.9)

        #expect(stack.activeNote(priority: .last)?.note == 48)
        #expect(stack.activeNote(priority: .low)?.note == 48)
        #expect(stack.activeNote(priority: .high)?.note == 72)

        stack.remove(note: 48)
        #expect(stack.activeNote(priority: .last)?.note == 72)
        #expect(stack.activeNote(priority: .low)?.note == 60)
        #expect(stack.activeNote(priority: .high)?.note == 72)
    }

    @Test func glideLegatoOnlyGlidesOnlyWhenOverlapping() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.voiceMode = .poly
        preset.glideLegatoOnly = true
        preset.portamento = 0.5
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.prepare(sampleRate: 44_100, maxFrames: 256)

        // Staccato note 60 -> note off -> clear voices
        engine.handleNoteOn(midiNote: 60, velocity: 0.8)
        for _ in 0..<50 { _ = engine.renderOneSample() }
        engine.handleNoteOff(midiNote: 60)
        for i in 0..<AudioEngine.maxVoices { engine.voices[i].deactivate() }

        // Note 72 played with no notes held
        engine.handleNoteOn(midiNote: 72, velocity: 0.8)
        let vStaccato = engine.voices.first { $0.isActive && $0.midiNote == 72 }!
        let targetFreq = AudioMath.midiToFrequency(72)
        #expect(abs(vStaccato.currentFrequency - targetFreq) < 0.01, "Staccato note with legatoOnly should start immediately at target frequency")
    }
}
