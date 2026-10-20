//
//  LiveStep3MonoLegatoMacrosTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Live Step 3: Poly / Mono / Legato voice modes,
//  Mono note stack with last-note priority & retrigger/glide,
//  and ModSource.macro1...4 modulation sources.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct LiveStep3MonoLegatoMacrosTests {

    @Test func monoNoteStackRetriggerAndReturn() {
        let engine = AudioEngine()
        engine.preset.voiceMode = .mono
        engine.applyPresetForTesting()

        // 1. Play C4 (MIDI note 60)
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.count == 1)
        #expect(engine.monoNoteStack.top?.note == 60)
        let activeC4 = engine.voices.filter { $0.isActive && !$0.isReleasing }
        #expect(!activeC4.isEmpty && activeC4.allSatisfy { $0.midiNote == 60 },
                "C4 should be the active sounding voice")

        // 2. Play E4 (MIDI note 64) while holding C4
        engine.noteOn(midiNote: 64, velocity: 0.8)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.count == 2)
        #expect(engine.monoNoteStack.top?.note == 64)
        let activeE4 = engine.voices.filter { $0.isActive && !$0.isReleasing }
        #expect(!activeE4.isEmpty && activeE4.allSatisfy { $0.midiNote == 64 },
                "E4 should now be the active sounding voice")

        // 3. Release E4 while still holding C4 -> should return to C4 with retrigger
        engine.noteOff(midiNote: 64)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.count == 1)
        #expect(engine.monoNoteStack.top?.note == 60)
        let returnedC4 = engine.voices.filter { $0.isActive && !$0.isReleasing }
        #expect(!returnedC4.isEmpty && returnedC4.allSatisfy { $0.midiNote == 60 },
                "Voice should return to sounding C4")
        #expect(returnedC4.first?.envelopePhase == .attack,
                "Returned note in mono mode must re-trigger with .attack phase")

        // 4. Release C4 -> all notes off, voice enters release
        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.isEmpty)
        let nonReleasing = engine.voices.filter { $0.isActive && !$0.isReleasing }
        #expect(nonReleasing.isEmpty, "No non-releasing voices should remain after all keys up")
    }

    @Test func legatoContinuousEnvelopeAndPortamento() {
        let engine = AudioEngine()
        engine.preset.voiceMode = .legato
        engine.preset.portamento = 0.25
        engine.applyPresetForTesting()

        // 1. Staccato start: C4 (MIDI note 60)
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.count == 1)
        guard let voiceC4 = engine.voices.first(where: { $0.isActive && !$0.isReleasing }) else {
            Issue.record("Expected active voice for C4")
            return
        }
        let expectedC4Freq = AudioMath.midiToFrequency(60)
        #expect(abs(voiceC4.currentFrequency - expectedC4Freq) < 0.01,
                "First note of phrase must start directly at target frequency with no portamento glide")

        // Render 200 samples to advance envelope
        for _ in 0..<200 {
            _ = engine.renderOneSample()
        }

        let voiceMid = engine.voices.first(where: { $0.isActive && !$0.isReleasing })!
        let midPhase = voiceMid.envelopePhase
        let midVal = voiceMid.envelopeValue
        #expect(midVal > 0.0, "Envelope should have advanced")

        // 2. Legato transition: play E4 (MIDI note 64) while holding C4
        engine.noteOn(midiNote: 64, velocity: 0.8)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.count == 2)
        #expect(engine.monoNoteStack.top?.note == 64)

        let voiceE4 = engine.voices.first(where: { $0.isActive && !$0.isReleasing })!
        #expect(voiceE4.midiNote == 64)
        #expect(voiceE4.envelopePhase == midPhase,
                "In legato mode, envelope phase must NOT reset to attack on note change")
        #expect(voiceE4.envelopeValue >= midVal * 0.9,
                "Envelope value must continue smoothly without dropping to 0")

        let expectedE4Freq = AudioMath.midiToFrequency(64)
        #expect(abs(voiceE4.targetFrequency - expectedE4Freq) < 0.01)
        #expect(abs(voiceE4.currentFrequency - expectedC4Freq) < 1.0,
                "With portamento 0.25s, current frequency should start gliding from C4 towards E4")

        // 3. Release E4 while holding C4 -> glides back to C4 without envelope reset
        engine.noteOff(midiNote: 64)
        engine.processCommandsForTesting()

        #expect(engine.monoNoteStack.count == 1)
        #expect(engine.monoNoteStack.top?.note == 60)
        let voiceReturned = engine.voices.first(where: { $0.isActive && !$0.isReleasing })!
        #expect(abs(voiceReturned.targetFrequency - expectedC4Freq) < 0.01,
                "Target frequency should glide back to C4")

        // 4. Release C4 -> all released
        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()
        #expect(engine.monoNoteStack.isEmpty)

        // 5. Staccato next note: G4 (MIDI note 67) after all notes were released
        engine.noteOn(midiNote: 67, velocity: 0.8)
        engine.processCommandsForTesting()

        let voiceG4 = engine.voices.first(where: { $0.isActive && !$0.isReleasing })!
        let expectedG4Freq = AudioMath.midiToFrequency(67)
        #expect(abs(voiceG4.currentFrequency - expectedG4Freq) < 0.01,
                "Staccato note after gap must NOT glide from previous released note")
    }

    @Test func macroModulatesMultipleTargetsSimultaneously() {
        let engine = AudioEngine()
        engine.preset = SynthPreset.defaultPreset
        engine.preset.filterCutoff = 2000.0
        engine.preset.osc1PulseWidth = 0.5
        engine.preset.modMatrix = [
            ModMatrixEntry(source: .macro1, destination: .cutoff, amount: 0.5),
            ModMatrixEntry(source: .macro1, destination: .pwm1, amount: 0.5)
        ]
        engine.applyPresetForTesting()

        // With macro1 = 0, matrixSource for macro1 returns 0
        let valZero = engine.matrixSource(.macro1, lfo: 0, lfo2: 0, env: 1, velocity: 1, modWheel: 0, keyTrack: 0)
        #expect(valZero == 0.0)

        // Set macro 1 via MIDI CC / single parameter
        // (audio thread side; the display side only updates `preset`)
        engine.applySingleParameterRT(target: .macro1, rawValue: 127)

        #expect(abs(engine.cachedMacro1 - 1.0) < 0.01)

        let valMax = engine.matrixSource(.macro1, lfo: 0, lfo2: 0, env: 1, velocity: 1, modWheel: 0, keyTrack: 0)
        #expect(abs(valMax - 1.0) < 0.01, "matrixSource(.macro1) should reflect cachedMacro1")
    }

    @Test func initGoldenHashPreserved() {
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == InitGoldenTests.golden["Init"],
                "Init golden hash must remain 100% bit-identical (0xd1b3635203a4799e)")
    }

    @Test(arguments: [VoiceMode.mono, VoiceMode.legato])
    func sustainPedalUpKeepsHeldKeyReleasableInMonoModes(mode: VoiceMode) {
        let engine = AudioEngine()
        engine.preset.voiceMode = mode
        engine.applyPresetForTesting()
        _ = engine.commandQueue.push(.setSustain(true))
        engine.noteOn(midiNote: 60, velocity: 0.8)       // A
        engine.processCommandsForTesting()
        engine.noteOff(midiNote: 60)                     // A held by pedal
        engine.noteOn(midiNote: 64, velocity: 0.8)       // B
        engine.processCommandsForTesting()
        _ = engine.commandQueue.push(.setSustain(false)) // pedal up, B still down
        engine.processCommandsForTesting()
        let sounding = engine.voices.filter { $0.isActive && !$0.isReleasing }
        #expect(!sounding.isEmpty && sounding.allSatisfy { $0.midiNote == 64 })
        engine.noteOff(midiNote: 64)                     // B up
        engine.processCommandsForTesting()
        #expect(engine.voices.filter { $0.isActive && !$0.isReleasing }.isEmpty,
                "B must not ring after its key-up")
        #expect(engine.monoNoteStack.isEmpty)
    }

    @Test(arguments: [VoiceMode.mono, VoiceMode.legato])
    func switchingFromPolyWithHeldKeysDoesNotLeaveStuckNotes(mode: VoiceMode) {
        let engine = AudioEngine()
        engine.preset.voiceMode = .poly
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.noteOn(midiNote: 64, velocity: 0.8)
        engine.processCommandsForTesting()
        engine.preset.voiceMode = mode
        engine.applyPresetForTesting()
        engine.processCommandsForTesting()
        engine.noteOff(midiNote: 60)
        engine.noteOff(midiNote: 64)
        engine.processCommandsForTesting()
        #expect(engine.voices.filter { $0.isActive && !$0.isReleasing }.isEmpty)
    }
}
