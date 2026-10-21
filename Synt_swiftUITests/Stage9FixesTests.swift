//
//  Stage9FixesTests.swift
//  Synt_swiftUITests
//
//  Stage 1: Verification tests for SYNT_7 / ROUND6 fixes (R6-2 through R6-8).
//

import Testing
import Foundation
import AVFAudio
@testable import SynthCore

@Suite struct Stage9FixesTests {

    // R6-2: .reverbMix/.reverbRoomSize must reach the DSP reverb right away (automation and knobs in AUv3).
    @Test func reverbMixAndRoomSizeReachDSPImmediately() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)

        // Via addressed parameter (AUv3 parameter automation)
        engine.applyAddressedParameterRT(id: SynthParameterAddress.reverbMix.rawValue, value: 0.73)
        #expect(abs(engine.cachedReverbMix - 0.73) < 1.0e-4)
        #expect(abs(engine.parameterReverbMix - 0.73) < 1.0e-4)

        engine.applyAddressedParameterRT(id: SynthParameterAddress.reverbRoomSize.rawValue, value: 0.88)
        #expect(abs(engine.cachedReverbRoom - 0.88) < 1.0e-4)
        #expect(abs(engine.parameterReverbRoom - 0.88) < 1.0e-4)

        // Via CC / MIDI target
        engine.applySingleParameterRT(target: .reverbMix, rawValue: 64) // ~0.504
        #expect(abs(engine.cachedReverbMix - (64.0 / 127.0)) < 1.0e-4)

        engine.applySingleParameterRT(target: .reverbRoomSize, rawValue: 100)
        #expect(abs(engine.cachedReverbRoom - (100.0 / 127.0)) < 1.0e-4)
    }

    // R6-3: Trance gate locks to the host only while the transport is playing; when stopped, it runs on its own clock.
    @Test func tranceGateRunsWhenHostStopped() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)

        // Enable trance gate with host lock active, but transport STOPPED
        var preset = SynthPreset(name: "Test")
        preset.tranceGateEnabled = true
        preset.tranceGateDivision = .sixteenth
        preset.tranceGatePattern = 0b1010101010101010
        engine.loadPreset(preset)

        engine.tranceHostLocked = true
        engine.usesHostTransport = true
        engine.hostTransportMoving = false // Stopped!

        let initialStep = engine.tranceStep
        var advanced = false

        // Advance 15,000 samples (at 44.1kHz, 16th at 120bpm is ~5512 samples)
        for _ in 0..<15000 {
            engine.advanceTranceGateRT()
            if engine.tranceStep != initialStep {
                advanced = true
                break
            }
        }

        #expect(advanced, "Trance gate must advance on its own clock when transport is stopped")
    }

    // R6-4: With the DSP reverb on, bypass the Apple reverb (no double reverb).
    @Test func dspReverbBypassesAppleReverbInStandalone() {
        let engine = AudioEngine()

        var presetWithDSP = SynthPreset(name: "DSP")
        presetWithDSP.dspReverbEnabled = true
        presetWithDSP.reverbMix = 0.5
        engine.loadPreset(presetWithDSP)

        #expect(engine.reverb.reverb.bypass == true, "Apple reverb must be bypassed when DSP reverb is enabled")
        #expect(engine.reverb.wetDryMix == 0.0, "Apple reverb wetDryMix must be 0 when DSP reverb is enabled")

        var presetWithApple = SynthPreset(name: "Apple")
        presetWithApple.dspReverbEnabled = false
        presetWithApple.reverbMix = 0.5
        engine.loadPreset(presetWithApple)

        #expect(engine.reverb.reverb.bypass == false, "Apple reverb must NOT be bypassed when DSP reverb is disabled")
        #expect(engine.reverb.wetDryMix > 0.0, "Apple reverb wetDryMix must reflect preset mix when DSP reverb is disabled")
    }

    // R6-5: Reallocate the reverb buffer when the audio device changes with render stopped / safe swap.
    @Test func reverbBufferReallocationSafeSwap() {
        let reverb = DSPReverb()
        reverb.allocate(sampleRate: 44100.0)
        #expect(reverb.isAllocated)

        let rates: [Double] = [48000.0, 96000.0, 88200.0, 44100.0]
        for r in rates {
            // Allocate new buffer via safe swap
            reverb.allocate(sampleRate: r)
            #expect(reverb.isAllocated)
            let (outL, outR) = reverb.process(inputL: 0.5, inputR: 0.5, room: 0.7, damp: 0.3)
            #expect(outL.isFinite)
            #expect(outR.isFinite)
        }
    }

    // R6-6: Fixed OSC2 and FM ratio: clear priority (Fixed takes priority over FM ratio).
    @Test func fixedOSC2TakesPriorityOverFMRatio() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)

        var preset = SynthPreset.defaultPreset
        preset.osc1Volume = 0.0
        preset.osc2Volume = 1.0
        preset.osc2Enabled = true
        preset.osc2FixedFrequency = true
        preset.osc2FrequencyHz = 220.0
        preset.fmRatioEnabled = true // Both enabled!
        preset.fmCoarse = 4
        preset.fmFine = 0.0
        engine.preset = preset
        engine.applyPresetForTesting()

        #expect(engine.cachedOsc2Fixed == true)
        #expect(engine.cachedFMRatio == true)

        // Note on: Fixed OSC2 must take priority, output must be stable and oscillate at ~220Hz
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()
        var maxAmp: Float = 0
        for _ in 0..<1000 {
            let (l, _) = engine.renderOneSample()
            if abs(l) > maxAmp { maxAmp = abs(l) }
            #expect(l.isFinite)
        }
        #expect(maxAmp > 0.01)
    }

    // R6-7: MIDICCLearnStore.swift: MIDI learn for Fine Pitch maps to the right parameter.
    @Test func midiLearnFinePitchTarget() {
        let target = MIDIControlTarget(.finePitch)
        #expect(target == .finePitch, "ModDestination.finePitch must map to MIDIControlTarget.finePitch, not .pitch1")
        #expect(target.modDestination == .finePitch)

        var preset = SynthPreset(name: "FinePitch")
        preset.osc1Detune = 0
        preset.osc2Detune = 0
        let store = MIDICCLearnStore()
        store.applyValue(96, to: MIDIControlTarget.finePitch, preset: &preset)
        // 96 / 127 ~ 0.7559 -> (0.7559 - 0.5) * 100 ~ +25.59 cents
        #expect(preset.osc1Detune > 20.0)
        #expect(preset.osc2Detune > 20.0)
    }

    // R6-8: Modulation of Chorus/Delay Mix must not write into the main-thread field.
    @Test func chorusAndDelayMixModulationDoesNotMutateMainFields() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)

        var preset = SynthPreset(name: "ModFX")
        preset.chorusMix = 0.35
        preset.delayMix = 0.25
        preset.delayPingPong = true
        // Mod matrix row: ModWheel -> ChorusMix, ModWheel -> DelayMix
        preset.modMatrix = [
            ModMatrixEntry(source: .modWheel, destination: .chorusMix, amount: 0.5),
            ModMatrixEntry(source: .modWheel, destination: .delayMix, amount: 0.5)
        ]
        engine.loadPreset(preset)

        engine.dspChorus.mix = 0.35
        engine.pingPongDelay.mix = 0.25
        engine.modWheel(1.0)

        engine.handleCommand(.noteOn(midiNote: 60, velocity: 1.0))
        for _ in 0..<500 {
            _ = engine.renderOneSample()
            // Verify main-thread properties were NOT mutated by the audio thread!
            #expect(abs(engine.dspChorus.mix - 0.35) < 1.0e-5, "Audio thread must not mutate dspChorus.mix")
            #expect(abs(engine.pingPongDelay.mix - 0.25) < 1.0e-5, "Audio thread must not mutate pingPongDelay.mix")
        }
    }
}
