//
//  MIDIClockTests.swift
//  MIDI clock parsing, 120 BPM lock, and Start / Stop transport.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct MIDIClockTests {
    @Test func clockInsideNoteOnKeepsRunningStatus() {
        var parser = MIDIByteParser()
        let early = parser.parse([0x90, 0xF8, 60, 100])
        #expect(early == [
            .clock,
            .noteOn(note: 60, velocity: Float(100) / 127, channel: 0)
        ])

        var transport = MIDIByteParser()
        #expect(transport.parse([0xFA, 0xF8, 0xFB, 0xFC]) == [.songStart, .clock, .songContinue, .songStop])

        var sensing = MIDIByteParser()
        let notes = sensing.parse([0x90, 0xFE, 60, 40, 0xF9, 0xFD, 62, 40])
        #expect(notes == [
            .noteOn(note: 60, velocity: Float(40) / 127, channel: 0),
            .noteOn(note: 62, velocity: Float(40) / 127, channel: 0)
        ])
    }

    @Test func clockStreamAt120BPMLocksCachedBPM() {
        let engine = AudioEngine()
        var preset = engine.preset
        preset.syncSource = .midiClock
        preset.bpm = 90
        engine.preset = preset
        engine.applyPresetForTesting()
        _ = engine.renderFramesForTesting(1)

        let gap = 919
        for tick in 0..<25 {
            _ = engine.midiQueue.push(.midiClock)
            engine.processCommandQueue()
            if tick < 24 {
                _ = engine.renderFramesForTesting(gap)
            }
        }
        #expect(abs(engine.cachedBPM - 120) < 0.5)
        #expect(engine.preset.bpm == 90)
        engine.pollMetering()
        #expect(abs(engine.externalTempo - 120) < 0.5)
    }

    @Test func internalSyncIgnoresTheClock() {
        let engine = AudioEngine()
        engine.preset.bpm = 100
        engine.applyPresetForTesting()
        for _ in 0..<30 {
            _ = engine.midiQueue.push(.midiClock)
            _ = engine.midiQueue.push(.midiStart)
            engine.processCommandQueue()
            _ = engine.renderFramesForTesting(900)
        }
        #expect(abs(engine.cachedBPM - 100) < 0.01)
        #expect(!engine.midiClockRunning)
        #expect(!engine.seqMirror.playing)
    }

    @Test func startResetsAndStopHoldsThePhase() {
        let engine = AudioEngine()
        var preset = engine.preset
        preset.syncSource = .midiClock
        preset.lfoEnabled = true
        preset.lfoRate = 5
        preset.lfoWaveform = .sine
        engine.preset = preset
        engine.applyPresetForTesting()
        _ = engine.renderFramesForTesting(5_000)

        _ = engine.midiQueue.push(.midiStart)
        engine.processCommandQueue()
        #expect(engine.midiClockRunning)
        #expect(engine.seqMirror.playing)
        #expect(engine.seqMirror.stepIndex == 0)
        #expect(engine.seqMirror.phase == 0)
        #expect(engine.clockPhase == 0)

        let started = engine.lfo.nextRawValue(sampleRate: engine.sampleRate)
        let fresh = LFO()
        fresh.rate = engine.lfo.rate
        fresh.waveform = .sine
        #expect(started == fresh.nextRawValue(sampleRate: engine.sampleRate))

        _ = engine.renderFramesForTesting(2_000)
        let phase = engine.seqMirror.phase
        let step = engine.seqMirror.stepIndex
        #expect(phase > 0)

        _ = engine.midiQueue.push(.midiStop)
        engine.processCommandQueue()
        #expect(!engine.midiClockRunning)
        #expect(!engine.seqMirror.playing)
        _ = engine.renderFramesForTesting(2_000)
        #expect(engine.seqMirror.phase == phase)
        #expect(engine.seqMirror.stepIndex == step)

        _ = engine.midiQueue.push(.midiContinue)
        engine.processCommandQueue()
        #expect(engine.midiClockRunning)
        #expect(engine.seqMirror.playing)
        #expect(engine.seqMirror.phase == phase)
        #expect(engine.seqMirror.stepIndex == step)
    }
}
