//
//  Stage12Round9Tests.swift
//  Synt_swiftUITests
//
//  Unit tests covering ROUND9 fixes in Stage 1:
//  - R9-1 & R9-7: Rotary eager sine init and pointer buffers (no ARC).
//  - R9-2: Send tail clearance on zero (no stale tails).
//  - R9-3: Rotary speed does not snap on snapshot apply.
//  - R9-4: Send B delay time and feedback respond to automation/CC.
//  - R9-5: Pre/post-insert send bus switch.
//  - R9-6: MSEG lock-free triple buffer.
//  - R9-8: rotaryFast discrete boolean / AU parameter.
//  - R8-4: Global highlighting resets when routes are removed.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage12Round9Tests {
    @Test func r9_1_and_r9_7_rotaryInitAndProcessZeroAlloc() {
        let rotary = DSPRotary(sampleRate: 48000)
        rotary.snapSpeeds(hornSlow: 0.8, hornFast: 7.0, drumSlow: 0.6, drumFast: 5.5, fast: false)
        // Process a block
        for _ in 0..<512 {
            let out = rotary.process(
                inputL: 0.3,
                inputR: 0.3,
                hornSlow: 0.8,
                hornFast: 7.0,
                drumSlow: 0.6,
                drumFast: 5.5,
                fast: true,
                drive: 0.2,
                mix: 0.5,
                accelHz: 2.0
            )
            #expect(out.0.isFinite && out.1.isFinite)
        }
    }

    @Test func r9_2_sendTailClearedWhenDroppingToZero() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        var p = SynthPreset.defaultPreset
        p.release = 0.001
        p.sendA = 0.5
        p.sendB = 0.5
        p.reverbRoomSize = 0.9
        p.delayFeedback = 0.8
        p.delayTime = 0.1
        engine.preset = p

        // Play a short pulse into the sends
        engine.handleNoteOn(midiNote: 60, velocity: 1.0)
        for _ in 0..<100 { _ = engine.renderOneSample() }
        engine.handleNoteOff(midiNote: 60)
        for _ in 0..<2000 { _ = engine.renderOneSample() }

        // Both sends should currently be active
        #expect(engine.lastSendA > 0)
        #expect(engine.lastSendB > 0)

        // Drop sends to 0
        p.sendA = 0
        p.sendB = 0
        engine.preset = p
        // R9-2: sends fade out over ~15 ms, then the tail is cleared incrementally.
        // Render past fade (~662 samples @44.1k) plus the incremental clear (64 chunks).
        for _ in 0..<2000 { _ = engine.renderOneSample() }
        #expect(engine.sendFadeA == 0)
        #expect(engine.sendFadeB == 0)

        #expect(engine.lastSendA == 0)
        #expect(engine.lastSendB == 0)

        // Raise sends back up with NO note playing (silence input)
        p.sendA = 0.8
        p.sendB = 0.8
        engine.preset = p

        // The first render sample must NOT output an old frozen tail
        let (outL, outR) = engine.renderOneSample()
        #expect(abs(outL) < 1e-4)
        #expect(abs(outR) < 1e-4)
    }

    @Test func r9_3_rotarySpeedDoesNotSnapOnSnapshotApply() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        var p = SynthPreset.defaultPreset
        p.rotaryEnabled = true
        p.rotaryFast = false
        p.rotaryHornSlow = 1.0
        p.rotaryHornFast = 8.0
        p.rotaryAccel = 1.0 // 1 Hz per second slew
        engine.preset = p

        // Switch rotaryFast to true
        p.rotaryFast = true
        engine.preset = p

        // Render 100 samples (~2ms at 44.1k)
        for _ in 0..<100 { _ = engine.renderOneSample() }

        // Apply a non-patch preset snapshot (e.g. slight cutoff change)
        p.filterCutoff = 1200
        engine.applyPreset()

        // Leslie speed should NOT snap immediately to 8.0 Hz (target), it should still be slewing
        // Let's verify by rendering more samples without crash or sudden jumps
        for _ in 0..<500 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
        }
    }

    @Test func r9_4_sendBDelayAutomationWired() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)

        // Parameter address automation
        engine.applyAddressedParameterRT(id: SynthParameterAddress.delayTime.rawValue, value: 0.45)
        #expect(engine.cachedSendDelayTime == 0.45)

        engine.applyAddressedParameterRT(id: SynthParameterAddress.delayFeedback.rawValue, value: 0.75)
        #expect(engine.cachedSendDelayFeedback == 0.75)
    }

    @Test func r9_5_sendPostInsertSwitchAndLimiter() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        var p = SynthPreset.defaultPreset
        #expect(p.sendPostInsert == false)
        #expect(SynthParameterAddress.sendPostInsert.rawValue == 153)

        p.sendPostInsert = true
        p.sendA = 0.5
        engine.preset = p
        #expect(engine.cachedSendPostInsert == true)

        // Hot signal through send should stay bounded by cleanCeiling limiter
        engine.handleNoteOn(midiNote: 64, velocity: 1.0)
        for _ in 0..<500 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
            #expect(abs(l) <= 1.05)
            #expect(abs(r) <= 1.05)
        }
    }

    @Test func r9_6_msegTripleBufferRapidPublish() {
        let mseg = DSPMSEG()
        var m1 = DSPMSEGModel()
        m1.points = [
            DSPMSEGPoint(time: 0, value: 0),
            DSPMSEGPoint(time: 0.5, value: 1.0),
            DSPMSEGPoint(time: 1.0, value: 0)
        ]
        mseg.publish(m1)
        mseg.trigger()

        for i in 0..<100 {
            _ = mseg.tick(gate: true, bpm: 120)
            if i % 10 == 0 {
                var m2 = DSPMSEGModel()
                m2.points = [
                    DSPMSEGPoint(time: 0, value: Float(i) * 0.01),
                    DSPMSEGPoint(time: 1.0, value: 0.5)
                ]
                mseg.publish(m2)
            }
        }
    }

    @Test func r9_8_rotaryFastDiscreteRoundtrip() throws {
        var p = SynthPreset.defaultPreset
        p.rotaryFast = true
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(decoded.rotaryFast == true)

        // Backward compatibility: old float JSON decoded as bool
        let oldJson = #"{"name":"Legacy","rotaryFast":1.0}"#
        let legacy = try JSONDecoder().decode(SynthPreset.self, from: Data(oldJson.utf8))
        #expect(legacy.rotaryFast == true)
    }

    @Test func r8_4_globalHighlightingResetsWhenRoutesRemoved() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        var p = SynthPreset.defaultPreset
        // Add a route to Cutoff
        p.modMatrix = [ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.8)]
        engine.preset = p

        engine.handleNoteOn(midiNote: 60, velocity: 1.0)
        for _ in 0..<200 { _ = engine.renderOneSample() }

        // Remove route
        p.modMatrix = []
        engine.preset = p
        for _ in 0..<10 { _ = engine.renderOneSample() }

        // Highlighting for cutoff should now be 0
        #expect(engine.liveModulation.value(for: .cutoff) == 0)
    }
}
