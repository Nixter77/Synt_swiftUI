//
//  MIDIPerformanceTests.swift
//  Pitch bend, mod wheel, and sustain. Init stays put until a message arrives.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct MIDIPerformanceTests {

    @Test func fullBendUpRaisesA4ByTwoSemitones() {
        let plain = fundamentalHz(bend: nil)
        let bent = fundamentalHz(bend: 1)
        let expected = plain * pow(2, 2.0 / 12.0)
        let error = abs(bent - expected) / expected
        #expect(error < 0.005, "bent \(bent) Hz, expected \(expected) Hz, plain \(plain) Hz")
    }

    @Test func sustainHoldsTheNoteUntilThePedalLifts() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.attack = 0.001
        preset.decay = 0.01
        preset.sustain = 1
        preset.release = 0.4
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1)
        engine.sustainPedal(down: true)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        #expect(!engine.isNoteReleasingForTesting(60))

        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        #expect(!engine.isNoteReleasingForTesting(60))

        engine.sustainPedal(down: false)
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
    }

    @Test func modWheelScalesPresetLFODepth() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.lfoEnabled = true
        preset.lfoDepth = 0.4
        engine.preset = preset
        engine.applyPresetForTesting()
        _ = engine.renderOneSample()
        #expect(abs(engine.lfo.depth - 0.4) < 0.0001)

        engine.modWheel(0)
        engine.processCommandsForTesting()
        _ = engine.renderOneSample()
        #expect(engine.lfo.depth == 0)

        engine.modWheel(1)
        engine.processCommandsForTesting()
        _ = engine.renderOneSample()
        #expect(abs(engine.lfo.depth - 0.4) < 0.0001)
    }

    @Test func midiBytesReachBendWheelAndPedal() {
        let engine = AudioEngine()
        let midi = MIDIHandler()
        midi.audioEngine = engine
        midi.parseMIDIBytesForTesting([0xE0, 0x7F, 0x7F])
        midi.parseMIDIBytesForTesting([0xB0, 1, 64])
        midi.parseMIDIBytesForTesting([0xB0, 64, 127])
        engine.processCommandsForTesting()
        #expect(abs(engine.pitchBendTarget - 1) < 0.0001)
        #expect(abs(engine.modWheel - Float(64) / 127) < 0.0001)
        #expect(engine.sustainPedalDown)
    }

    @Test func midiUsesItsOwnRingNotTheUIRing() {
        let engine = AudioEngine()
        let midi = MIDIHandler()
        midi.audioEngine = engine
        midi.parseMIDIBytesForTesting([0x90, 60, 100])
        #expect(engine.commandQueueForTesting.isEmpty)
        #expect(!engine.midiQueue.isEmpty)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        midi.parseMIDIBytesForTesting([0x80, 60, 0])
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
    }

    @Test func midiKeyFollowsArpModeOnTheAudioThread() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .up
        engine.preset = preset
        engine.applyPresetForTesting()
        let midi = MIDIHandler()
        midi.audioEngine = engine
        midi.parseMIDIBytesForTesting([0x90, 64, 100])
        engine.processCommandsForTesting()
        #expect(engine.heldKeysForArp.contains(64))
        #expect(!engine.isNoteActiveForTesting(64))

        // Arp switched off while the key is down: the key-up still clears the arp.
        preset.arpMode = .off
        engine.preset = preset
        engine.applyPresetForTesting()
        midi.parseMIDIBytesForTesting([0x80, 64, 0])
        engine.processCommandsForTesting()
        #expect(!engine.heldKeysForArp.contains(64))
    }

    @Test func initWithoutMIDIIsSampleIdenticalAcrossEngines() {
        #expect(initBuffer() == initBuffer())
    }

    @Test func oldJSONKeepsPitchBendRangeAtTwoSemitones() throws {
        let json = #"{"name":"Old Patch"}"#.data(using: .utf8)!
        let preset = try JSONDecoder().decode(SynthPreset.self, from: json)
        #expect(preset.pitchBendRange == 2)
        #expect(SynthPreset.defaultPreset.pitchBendRange == 2)
    }

    private func initBuffer() -> [Float] {
        let engine = AudioEngine()
        engine.preset = .defaultPreset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        var samples: [Float] = []
        samples.reserveCapacity(1024)
        for _ in 0..<512 {
            let (left, right) = engine.renderOneSample()
            samples.append(left)
            samples.append(right)
        }
        return samples
    }

    private func fundamentalHz(bend: Float?) -> Double {
        let engine = AudioEngine()
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
        preset.pitchBendRange = 2
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 69, velocity: 1)
        if let bend {
            engine.pitchBend(bend)
        }
        engine.processCommandsForTesting()

        _ = engine.renderFramesForTesting(Int(44_100 * 0.25))

        var crossings = 0
        var previous: Float = 0
        for _ in 0..<44_100 {
            let (left, right) = engine.renderOneSample()
            let sample = (left + right) * 0.5
            if previous <= 0, sample > 0 { crossings += 1 }
            previous = sample
        }
        return Double(crossings)
    }
}
