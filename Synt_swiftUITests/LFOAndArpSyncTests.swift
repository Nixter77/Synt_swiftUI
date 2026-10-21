//
//  LFOAndArpSyncTests.swift
//  Synt_swiftUITests
//

import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct LFOAndArpSyncTests {

    @Test func lfoRetriggerProducesIdenticalFirstSamplesOnConsecutiveNotes() {
        let engine = AudioEngine()
        engine.lfo.enabled = true
        engine.lfo.mode = .retrigger
        engine.lfo.rate = 4.0
        engine.lfo.waveform = .sine
        engine.lfo.startPhaseDegrees = 45.0

        // Play Note 1
        engine.handleNoteOn(midiNote: 60, velocity: 0.8)
        var note1Samples: [Float] = []
        for _ in 0..<100 {
            note1Samples.append(engine.lfo.nextValue(sampleRate: 44100))
        }

        // Advance 333 ms worth of samples
        let advanceSamples = Int(0.333 * 44100)
        for _ in 0..<advanceSamples {
            _ = engine.lfo.nextValue(sampleRate: 44100)
        }

        // Play Note 2 (333 ms later)
        engine.handleNoteOn(midiNote: 64, velocity: 0.8)
        var note2Samples: [Float] = []
        for _ in 0..<100 {
            note2Samples.append(engine.lfo.nextValue(sampleRate: 44100))
        }

        #expect(note1Samples.count == 100)
        #expect(note2Samples.count == 100)
        for i in 0..<100 {
            #expect(abs(note1Samples[i] - note2Samples[i]) < 1e-6, "Sample \(i) must match between notes: \(note1Samples[i]) vs \(note2Samples[i])")
        }
    }

    @Test func lfoPhaseLocksToHostBeatPosition() {
        let lfo = LFO()
        lfo.startPhaseDegrees = 0.0

        // fake beat 4.5 at rate 1.0 -> fract(4.5 * 1.0) = 0.5
        lfo.syncPhase(beat: 4.5, rateInCyclesPerBeat: 1.0)
        let normalizedPhase = lfo.phase / AudioMath.twoPi
        #expect(abs(normalizedPhase - 0.5) < 1e-5, "Fake beat 4.5 must give normalized phase 0.5, got \(normalizedPhase)")

        // With start phase 90 degrees (0.25 of cycle)
        lfo.startPhaseDegrees = 90.0
        lfo.syncPhase(beat: 4.5, rateInCyclesPerBeat: 1.0)
        let phaseWithOffset = lfo.phase / AudioMath.twoPi
        #expect(abs(phaseWithOffset - 0.75) < 1e-5, "Fake beat 4.5 with 90° start phase must give 0.75, got \(phaseWithOffset)")

        // Via AudioEngine adoptHostContext
        let engine = AudioEngine()
        engine.cachedLfoTempoSync = true
        engine.cachedLfoSyncDivision = .quarter // 1 cycle per beat
        engine.adoptHostContext(tempo: 120.0, transportMoving: true, beatPosition: 4.5)
        let enginePhase = engine.lfo.phase / AudioMath.twoPi
        #expect(abs(enginePhase - 0.5) < 1e-5, "Host beat 4.5 via adoptHostContext must synchronize LFO phase to 0.5")
    }

    @Test func eighthTripletStepDurationAt120BPMIs166Point67ms() {
        let div = TimeDivision.eighthT
        let durationSec = div.duration(bpm: 120.0)
        let durationMs = durationSec * 1000.0
        #expect(abs(durationMs - 166.66667) < 0.05, "1/8T at 120 BPM must equal 166.67 ms, got \(durationMs) ms")
    }

    @Test func arpeggiatorLatchKeepsPlayingAfterNoteOff() {
        let engine = AudioEngine()
        engine.cachedArpMode = .up
        engine.cachedArpLatch = true
        engine.arp.mode = .up
        engine.arp.latch = true

        // Press chord: C4 (60), E4 (64), G4 (67)
        engine.handleCommand(.arpKeyDown(midiNote: 60))
        engine.handleCommand(.arpKeyDown(midiNote: 64))
        engine.handleCommand(.arpKeyDown(midiNote: 67))

        #expect(engine.heldKeysForArp.count == 3)
        #expect(engine.latchedKeysForArp.count == 3)
        #expect(engine.arp.sortedNotes == [60, 64, 67])

        // Release all keys
        engine.handleCommand(.arpKeyUp(midiNote: 60))
        engine.handleCommand(.arpKeyUp(midiNote: 64))
        engine.handleCommand(.arpKeyUp(midiNote: 67))

        #expect(engine.heldKeysForArp.isEmpty, "Physical keys must be released")
        #expect(engine.latchedKeysForArp.count == 3, "Latched keys must remain held")
        #expect(engine.arp.sortedNotes == [60, 64, 67], "Arp notes must continue playing after note-off under latch")

        var random: UInt32 = 12345
        #expect(engine.arp.advanceTick(randomSource: &random) == 60)
        #expect(engine.arp.advanceTick(randomSource: &random) == 64)
        #expect(engine.arp.advanceTick(randomSource: &random) == 67)
        #expect(engine.arp.advanceTick(randomSource: &random) == 60)

        // Strum a new chord after keys were released: replaces latched chord
        engine.handleCommand(.arpKeyDown(midiNote: 72))
        #expect(engine.latchedKeysForArp.count == 1)
        #expect(engine.arp.sortedNotes == [72])
    }

    @Test func arpeggiatorAsPlayedPreservesStruckOrder() {
        var arp = ArpeggiatorEngine()
        arp.mode = .asPlayed

        // Struck order: G4 (67), C4 (60), E4 (64)
        let playedOrder = [67, 60, 64]
        var keys = MIDIKeySet()
        for k in playedOrder { keys.insert(k) }

        arp.setHeldKeys(keys, playedOrder: playedOrder)
        #expect(arp.sortedNotes == [67, 60, 64], "asPlayed must maintain played order rather than numeric ascending")

        var random: UInt32 = 12345
        #expect(arp.advanceTick(randomSource: &random) == 67)
        #expect(arp.advanceTick(randomSource: &random) == 60)
        #expect(arp.advanceTick(randomSource: &random) == 64)
        #expect(arp.advanceTick(randomSource: &random) == 67)
    }
}
