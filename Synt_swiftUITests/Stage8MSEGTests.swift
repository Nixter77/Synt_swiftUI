//
//  Stage8MSEGTests.swift
//  MSEG 1 as a matrix source: render-thread tick, preset load, atomic bank.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage8MSEGTests {

    private func engine(_ mutate: (inout SynthPreset) -> Void) -> AudioEngine {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        mutate(&preset)
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        return engine
    }

    private func routePitch(_ patch: inout SynthPreset) {
        patch.modMatrix = [ModMatrixEntry(source: .mseg, destination: .pitch1, amount: 0.2)]
        patch.osc2Enabled = false
        patch.attack = 0.001
        patch.decay = 0.2
        patch.sustain = 1
        patch.release = 1
    }

    @Test func emptyPresetDoesNotTickAndMatchesTheDefaultRender() {
        let idle = AudioEngine()
        #expect(idle.mseg.hasPoints == false)
        #expect(idle.mseg.evaluate(at: 0.5) == 0)
        idle.prepare(sampleRate: 44_100, maxFrames: 256)
        idle.handleNoteOn(midiNote: 60, velocity: 1)
        for _ in 0..<256 {
            _ = idle.renderOneSample()
        }
        #expect(idle.mseg.phase == 0)
        #expect(idle.mseg.hasPoints == false)

        let plain = engine { _ in }
        let wild = engine { patch in
            patch.mseg.rateHz = 40
            patch.mseg.syncMode = .beats
            patch.mseg.syncBeats = 8
            patch.mseg.isOneShot = true
        }
        plain.handleNoteOn(midiNote: 57, velocity: 1)
        wild.handleNoteOn(midiNote: 57, velocity: 1)
        var same = true
        for _ in 0..<400 {
            if plain.renderOneSample() != wild.renderOneSample() {
                same = false
                break
            }
        }
        #expect(same)
    }

    @Test func presetSwapPublishesTheIdleBank() {
        let engine = AudioEngine()
        var rising = SynthPreset.defaultPreset
        rising.mseg.points = [
            DSPMSEGPoint(time: 0, value: 0),
            DSPMSEGPoint(time: 1, value: 1)
        ]
        rising.mseg.sustainIndex = nil
        engine.preset = rising
        #expect(abs(engine.mseg.evaluate(at: 0.5) - 0.5) < 1.0e-4)

        var flat = rising
        flat.mseg.points = [
            DSPMSEGPoint(time: 0, value: -1),
            DSPMSEGPoint(time: 0.25, value: -1),
            DSPMSEGPoint(time: 1, value: -1)
        ]
        engine.preset = flat
        #expect(abs(engine.mseg.evaluate(at: 0) - (-1)) < 1.0e-4)
        #expect(abs(engine.mseg.evaluate(at: 0.5) - (-1)) < 1.0e-4)
        #expect(abs(engine.mseg.evaluate(at: 1) - (-1)) < 1.0e-4)

        var cleared = flat
        cleared.mseg = MSEGPreset()
        engine.preset = cleared
        #expect(engine.mseg.hasPoints == false)
        #expect(engine.mseg.evaluate(at: 0.5) == 0)
    }

    @Test func retriggerPerNoteResetsPhase() {
        let engine = engine { patch in
            self.routePitch(&patch)
            patch.mseg.points = [
                DSPMSEGPoint(time: 0, value: 0),
                DSPMSEGPoint(time: 1, value: 1)
            ]
            patch.mseg.rateHz = 2
            patch.mseg.triggerMode = .retrigger
            patch.mseg.sustainIndex = nil
        }
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        for _ in 0..<2_000 {
            _ = engine.renderOneSample()
        }
        #expect(engine.mseg.phase > 0.02)
        #expect(engine.mseg.isRunning)
        engine.handleNoteOn(midiNote: 64, velocity: 1)
        #expect(engine.mseg.phase == 0)
        let restarted = engine.renderOneSample()
        #expect(restarted.0.isFinite && restarted.1.isFinite)
        #expect(engine.mseg.phase > 0)
        #expect(engine.mseg.phase < 0.01)
    }

    @Test func loopIndicesConfinePhase() {
        let engine = engine { patch in
            self.routePitch(&patch)
            patch.mseg.points = [
                DSPMSEGPoint(time: 0, value: 0),
                DSPMSEGPoint(time: 0.2, value: 0.2),
                DSPMSEGPoint(time: 0.8, value: 0.8),
                DSPMSEGPoint(time: 1, value: 1)
            ]
            patch.mseg.rateHz = 10
            patch.mseg.loopStartIndex = 1
            patch.mseg.loopEndIndex = 2
            patch.mseg.sustainIndex = nil
        }
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        var entered = false
        var underEnd = true
        for _ in 0..<4_000 {
            _ = engine.renderOneSample()
            if engine.mseg.phase >= 0.2 { entered = true }
            if engine.mseg.phase > 0.81 { underEnd = false }
        }
        #expect(entered)
        #expect(underEnd)
        var confined = true
        for _ in 0..<22_050 {
            _ = engine.renderOneSample()
            let phase = engine.mseg.phase
            if phase < 0.19 || phase > 0.81 {
                confined = false
                break
            }
        }
        #expect(confined)
        #expect(engine.mseg.isRunning)
    }

    @Test func freeRunWrapsWhenThereIsNoSustain() {
        let engine = engine { patch in
            self.routePitch(&patch)
            patch.mseg.points = [
                DSPMSEGPoint(time: 0, value: 0.9),
                DSPMSEGPoint(time: 1, value: -0.4)
            ]
            patch.mseg.rateHz = 20
            patch.mseg.sustainIndex = nil
            patch.mseg.isOneShot = false
        }
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        for _ in 0..<3_000 {
            _ = engine.renderOneSample()
        }
        #expect(engine.mseg.isRunning)
        #expect(engine.mseg.phase > 0.2)
        #expect(engine.mseg.phase < 0.5)
        #expect(abs(engine.mseg.currentValue - (-0.4)) > 0.05)
    }

    @Test func releaseWithoutLoopStopsAndHoldsTheLastValue() {
        let engine = engine { patch in
            self.routePitch(&patch)
            patch.mseg.points = [
                DSPMSEGPoint(time: 0, value: 0.8),
                DSPMSEGPoint(time: 0.3, value: 1),
                DSPMSEGPoint(time: 1, value: -0.5)
            ]
            patch.mseg.rateHz = 4
            patch.mseg.isOneShot = false
            patch.mseg.sustainIndex = 1
            patch.mseg.loopStartIndex = nil
            patch.mseg.loopEndIndex = nil
        }
        engine.handleNoteOn(midiNote: 57, velocity: 1)
        for _ in 0..<20_000 {
            _ = engine.renderOneSample()
        }
        #expect(engine.mseg.isSustaining)
        #expect(abs(engine.mseg.phase - 0.3) < 1.0e-3)
        #expect(abs(engine.mseg.currentValue - 1) < 1.0e-3)

        engine.handleNoteOff(midiNote: 57)
        for _ in 0..<1_000 {
            _ = engine.renderOneSample()
        }
        #expect(engine.mseg.isRunning)
        #expect(engine.mseg.phase > 0.35)
        #expect(engine.mseg.phase < 0.55)

        for _ in 0..<12_000 {
            _ = engine.renderOneSample()
        }
        #expect(engine.mseg.isRunning == false)
        #expect(engine.mseg.phase == 1)
        #expect(engine.mseg.currentValue == -0.5)
        var finite = true
        for _ in 0..<4_000 {
            let frame = engine.renderOneSample()
            if !frame.0.isFinite || !frame.1.isFinite { finite = false }
        }
        #expect(finite)
        #expect(engine.mseg.phase == 1)
        #expect(engine.mseg.currentValue == -0.5)
        #expect(engine.mseg.isRunning == false)
    }

    @Test func hostTempoScalesBeatsWithoutWritingPresetBPM() {
        func phase(at tempo: Double) -> (phase: Float, bpm: Float) {
            let engine = engine { patch in
                self.routePitch(&patch)
                patch.mseg.points = [
                    DSPMSEGPoint(time: 0, value: 0),
                    DSPMSEGPoint(time: 1, value: 1)
                ]
                patch.mseg.syncMode = .beats
                patch.mseg.syncBeats = 4
                patch.mseg.sustainIndex = nil
            }
            let authored = engine.preset.bpm
            engine.handleNoteOn(midiNote: 60, velocity: 1)
            engine.adoptHostContext(tempo: tempo, transportMoving: true)
            #expect(engine.preset.bpm == authored)
            #expect(engine.cachedBPM == Float(tempo))
            for _ in 0..<4_410 {
                _ = engine.renderOneSample()
            }
            #expect(engine.preset.bpm == authored)
            return (engine.mseg.phase, authored)
        }

        let slow = phase(at: 60)
        let fast = phase(at: 120)
        #expect(slow.bpm == 120)
        #expect(fast.bpm == 120)
        #expect(fast.phase > slow.phase * 1.7)
        #expect(slow.phase > 0.01)
        #expect(fast.phase < 0.2)
    }

    @Test func missingMSEGStaysEmptyAndAuthoredPointsRoundTrip() throws {
        let missing = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old"}"#.utf8))
        #expect(missing.mseg.points.isEmpty)
        #expect(missing.mseg.sustainIndex == nil)
        #expect(missing.mseg.loopStartIndex == nil)

        var authored = SynthPreset.defaultPreset
        authored.mseg.points = [
            DSPMSEGPoint(time: 0, value: -0.25, curve: 0.5),
            DSPMSEGPoint(time: 0.5, value: 0.75, curve: -0.25),
            DSPMSEGPoint(time: 1, value: 0, curve: 0)
        ]
        authored.mseg.isOneShot = true
        authored.mseg.syncMode = .beats
        authored.mseg.rateHz = 3
        authored.mseg.syncBeats = 2
        authored.mseg.triggerMode = .continuous
        authored.mseg.loopStartIndex = 0
        authored.mseg.loopEndIndex = 2
        authored.mseg.sustainIndex = 1
        let data = try JSONEncoder().encode(authored)
        let back = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(back.mseg == authored.mseg)
    }

    @Test func presetLoadSortsAndClamps() throws {
        let json = """
        {"name":"Messy","mseg":{"points":[{"time":1.4,"value":2.5,"curve":3},{"time":-0.4,"value":-2,"curve":-3},{"time":0.4,"value":0.2,"curve":0}],"rateHz":900,"syncBeats":0.001,"loopStartIndex":40,"sustainIndex":-5}}
        """
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(json.utf8))
        #expect(decoded.mseg.points.count == 3)
        #expect(decoded.mseg.points[0].time == 0)
        #expect(decoded.mseg.points[1].time == Float(0.4))
        #expect(decoded.mseg.points[2].time == 1)
        #expect(decoded.mseg.points[0].value == -1)
        #expect(decoded.mseg.points[1].value == Float(0.2))
        #expect(decoded.mseg.points[2].value == 1)
        #expect(decoded.mseg.points[0].curve == -1)
        #expect(decoded.mseg.points[1].curve == 0)
        #expect(decoded.mseg.points[2].curve == 1)
        #expect(decoded.mseg.rateHz == 100)
        #expect(decoded.mseg.syncBeats == 0.0625)
        #expect(decoded.mseg.loopStartIndex == 2)
        #expect(decoded.mseg.sustainIndex == 0)

        let engine = AudioEngine()
        engine.preset = decoded
        #expect(engine.mseg.evaluate(at: 0) == -1)
        #expect(engine.mseg.evaluate(at: 1) == 1)

        var unsorted = SynthPreset.defaultPreset
        unsorted.mseg.points = [
            DSPMSEGPoint(time: 0.75, value: 0.25),
            DSPMSEGPoint(time: 0.25, value: -0.25)
        ]
        unsorted.mseg.sustainIndex = nil
        engine.preset = unsorted
        #expect(engine.mseg.evaluate(at: 0) == -0.25)
        #expect(engine.mseg.evaluate(at: 1) == 0.25)

        var messy = unsorted
        messy.mseg.loopStartIndex = 9
        messy.mseg.sustainIndex = -4
        let cleaned = messy.sanitized()
        #expect(cleaned.mseg.points[0].time == 0.25)
        #expect(cleaned.mseg.loopStartIndex == 1)
        #expect(cleaned.mseg.sustainIndex == 0)
    }

    /// 120 BPM, 4 beats is 2 seconds. 4410 samples at 48 kHz land on 4410/96000.
    /// The same count at the init 44.1 kHz rate lands on 4410/88200.
    @Test func beatsAt48kDoNotAdvanceAt44100() {
        let engine = engine { patch in
            self.routePitch(&patch)
            patch.mseg.points = [
                DSPMSEGPoint(time: 0, value: 0),
                DSPMSEGPoint(time: 1, value: 1)
            ]
            patch.mseg.syncMode = .beats
            patch.mseg.syncBeats = 4
            patch.mseg.sustainIndex = nil
            patch.mseg.isOneShot = false
        }
        engine.applySampleRateForTesting(48_000, rebuildGraph: false)
        #expect(engine.cachedBPM == 120)
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        let samples = 4410
        for _ in 0..<samples {
            _ = engine.renderOneSample()
        }
        let live = Float(samples) / 96_000
        let stale = Float(samples) / 88_200
        #expect(abs(engine.mseg.phase - live) < 0.001)
        #expect(abs(engine.mseg.phase - stale) > 0.002)
    }

    @Test func deleteAllPointsRendersZeroInsteadOfTheLastLevel() {
        let engine = engine { patch in
            self.routePitch(&patch)
            patch.mseg.points = [
                DSPMSEGPoint(time: 0, value: 1),
                DSPMSEGPoint(time: 1, value: 1)
            ]
            patch.mseg.rateHz = 0.5
            patch.mseg.sustainIndex = nil
        }
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        let held = engine.renderOneSample()
        #expect(held.0.isFinite && held.1.isFinite)
        #expect(abs(engine.mseg.currentValue - 1) < 1.0e-3)

        var cleared = engine.preset
        cleared.mseg.points = []
        engine.preset = cleared
        #expect(engine.mseg.hasPoints == false)
        #expect(engine.preset.modMatrix.contains { $0.source == .mseg })

        let frame = engine.renderOneSample()
        #expect(frame.0.isFinite && frame.1.isFinite)
        #expect(engine.mseg.currentValue == 0)
    }
}
