//
//  LiveStep2CCAndTemplateTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Live Step 2: Direct MIDI CC Modulation without applyPreset,
//  Expanded MIDI CC Learn, and Samson Graphite 49 Hardware Template.
//

import Foundation
import Combine
import Testing
@testable import Synt_swiftUI

@MainActor
struct LiveStep2CCAndTemplateTests {

    @Test func directCCDoesNotTriggerApplyPreset() {
        let engine = AudioEngine()
        MIDICCLearnStore.shared.attachEngine(engine)
        MIDICCLearnStore.shared.clearMappings()

        // Map CC 74 to cutoff
        MIDICCLearnStore.shared.map(cc: 74, to: .cutoff)

        let initialCallCount = engine.applyPresetCallCountForTesting

        // 1. Apply single parameter via applySingleParameterFromMIDI
        engine.applySingleParameterFromMIDI(cc: 74, value: 127)

        #expect(engine.applyPresetCallCountForTesting == initialCallCount,
                "Direct MIDI CC modulation must NOT trigger applyPreset()")
        #expect(engine.preset.filterCutoff > 19000.0,
                "Cutoff in preset should be updated near 20000 Hz")
        // Main is display-only: render-owned DSP state waits for the audio thread.
        let cutoffBefore = engine.cachedFilterCutoff
        #expect(cutoffBefore < 19000.0, "main must not write the render's cutoff")
        _ = engine.midiQueue.push(.controlChange(cc: 74, value: 127))
        engine.processCommandQueue()
        #expect(engine.cachedFilterCutoff > 19000.0,
                "audio thread applies the CC to cachedFilterCutoff")

        // 2. Modulate Amp Attack (CC 20)
        MIDICCLearnStore.shared.map(cc: 20, to: .attack)
        engine.applySingleParameterFromMIDI(cc: 20, value: 64)

        #expect(engine.applyPresetCallCountForTesting == initialCallCount,
                "Modulating attack via MIDI CC must NOT trigger applyPreset()")
        #expect(abs(engine.preset.attack - 1.0) < 0.1,
                "Amp attack should be near 1.0s")
        let attackBefore = engine.envelope.attack
        #expect(abs(attackBefore - 1.0) > 0.1, "main must not write the live envelope")
        _ = engine.midiQueue.push(.controlChange(cc: 20, value: 64))
        engine.processCommandQueue()
        #expect(abs(engine.envelope.attack - 1.0) < 0.1,
                "Live envelope attack should be near 1.0s after the audio thread drains")

        MIDICCLearnStore.shared.clearMappings()
    }

    @Test func audioThreadDirectCCExecution() {
        let engine = AudioEngine()
        MIDICCLearnStore.shared.attachEngine(engine)
        MIDICCLearnStore.shared.clearMappings()
        MIDICCLearnStore.shared.map(cc: 74, to: .cutoff)

        // Reset patch state so filter cutoff is at default
        engine.resetPatchStateRT()

        // Push CC into midiQueue (as MIDIHandler does from CoreMIDI thread)
        let pushed = engine.midiQueue.push(.controlChange(cc: 74, value: 127))
        #expect(pushed, "midiQueue must accept controlChange command")

        // Drain on audio thread
        engine.processCommandQueue()

        #expect(engine.cachedFilterCutoff > 19000.0,
                "Audio thread must apply controlChange directly to cachedFilterCutoff")

        MIDICCLearnStore.shared.clearMappings()
    }

    @Test func expandedMIDICCLearnWorkflow() {
        let store = MIDICCLearnStore.shared
        store.clearMappings()

        var preset = SynthPreset.defaultPreset

        // 1. Learn Reverb Mix (outside old ModDestination)
        store.startLearning(for: .reverbMix)
        #expect(store.learningTarget == .reverbMix)

        let handled = store.handleIncomingCC(91, value: 100, currentPreset: &preset)
        #expect(handled)
        #expect(store.learningTarget == nil, "Learning state must reset after CC is learned")
        #expect(store.cc(for: .reverbMix) == 91)
        #expect(abs(preset.reverbMix - (100.0 / 127.0)) < 0.01)

        // 2. Learn Macro 1
        store.startLearning(for: .macro1)
        let handledMacro = store.handleIncomingCC(24, value: 127, currentPreset: &preset)
        #expect(handledMacro)
        #expect(store.cc(for: .macro1) == 24)
        #expect(abs(preset.macro1 - 1.0) < 0.01)

        // 3. Unmap Macro 1
        store.unmap(target: .macro1)
        #expect(store.cc(for: .macro1) == nil)

        store.clearMappings()
    }

    @Test func samsonGraphite49TemplateMappings() {
        let engine = AudioEngine()
        MIDICCLearnStore.shared.attachEngine(engine)
        MIDICCLearnStore.shared.applySamsonGraphite49Template()

        let store = MIDICCLearnStore.shared

        // Verify encoders
        #expect(store.cc(for: .cutoff) == SamsonGraphite49CC.encoderCutoff)
        #expect(store.cc(for: .resonance) == SamsonGraphite49CC.encoderResonance)
        #expect(store.cc(for: .filterEnvelopeAmount) == SamsonGraphite49CC.encoderFilterEnvAmount)
        #expect(store.cc(for: .wtMorph1) == SamsonGraphite49CC.encoderMorph1)
        #expect(store.cc(for: .fmAmount) == SamsonGraphite49CC.encoderFMAmount)
        #expect(store.cc(for: .reverbMix) == SamsonGraphite49CC.encoderReverbMix)
        #expect(store.cc(for: .chorusMix) == SamsonGraphite49CC.encoderChorusMix)
        #expect(store.cc(for: .delayMix) == SamsonGraphite49CC.encoderDelayMix)

        // Verify faders
        #expect(store.cc(for: .attack) == SamsonGraphite49CC.faderAttack)
        #expect(store.cc(for: .decay) == SamsonGraphite49CC.faderDecay)
        #expect(store.cc(for: .sustain) == SamsonGraphite49CC.faderSustain)
        #expect(store.cc(for: .release) == SamsonGraphite49CC.faderRelease)
        #expect(store.cc(for: .macro1) == SamsonGraphite49CC.faderMacro1)
        #expect(store.cc(for: .macro2) == SamsonGraphite49CC.faderMacro2)
        #expect(store.cc(for: .macro3) == SamsonGraphite49CC.faderMacro3)
        #expect(store.cc(for: .macro4) == SamsonGraphite49CC.faderMacro4)

        // Master Fader
        #expect(store.cc(for: .amp) == SamsonGraphite49CC.masterVolume)

        // Test controlling parameters through template
        engine.applySingleParameterFromMIDI(cc: SamsonGraphite49CC.encoderCutoff, value: 64)
        #expect(engine.preset.filterCutoff > 500.0 && engine.preset.filterCutoff < 2000.0)

        engine.applySingleParameterFromMIDI(cc: SamsonGraphite49CC.faderMacro1, value: 127)
        #expect(abs(engine.preset.macro1 - 1.0) < 0.01)

        store.clearMappings()
    }

    @Test func initGoldenHashPreserved() {
        let golden: UInt64 = 0xd1b3635203a4799e
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == golden,
                "Init hash changed to 0x\(String(hash, radix: 16)); expected 0x\(String(golden, radix: 16))")
    }

    @Test func ccDisplaySideIsCoalescedToLatestValuePerCC() {
        let c = CCCoalescer()
        #expect(c.post(cc: 74, value: 1))            // first post asks for a hop
        for v in 2...100 { #expect(!c.post(cc: 74, value: UInt8(v))) }
        #expect(!c.post(cc: 20, value: 64))
        #expect(!c.post(cc: 127, value: 127))
        let batch = c.drain()
        #expect(batch.map(\.cc) == [20, 74, 127])
        #expect(batch.map(\.value) == [64, 100, 127])
        #expect(c.drain().isEmpty)
        #expect(c.post(cc: 74, value: 5))            // next burst schedules again
    }

    @Test func midiCCSweepPublishesPresetOncePerDrainAndDSPOnlyOnAudioThread() {
        let engine = AudioEngine()
        MIDICCLearnStore.shared.attachEngine(engine)
        MIDICCLearnStore.shared.clearMappings()
        MIDICCLearnStore.shared.map(cc: 74, to: .cutoff)
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        var publishes = 0
        let sub = engine.objectWillChange.sink { publishes += 1 }
        for v in stride(from: 0, through: 127, by: 8) {
            midi.parseMIDIBytesForTesting([0xB0, 74, UInt8(v)])
        }
        midi.parseMIDIBytesForTesting([0xB0, 74, 127])
        let cutoffBefore = engine.cachedFilterCutoff
        midi.drainCCDisplay()                         // what the single main hop does
        #expect(publishes == 1)
        #expect(engine.preset.filterCutoff > 19000.0)
        #expect(engine.cachedFilterCutoff == cutoffBefore)
        engine.processCommandQueue()
        #expect(engine.cachedFilterCutoff > 19000.0)
        sub.cancel()
        MIDICCLearnStore.shared.clearMappings()
    }
}
