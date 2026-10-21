//
//  Stage7BugTests.swift
//  Filter-feedback bounds, trance-gate host phase, Haas de-click, curve interpolation.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage7BugTests {

    @Test func filterFeedbackAtUnityStaysFiniteForTenSeconds() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.filterType = .lowPass
        preset.filterCutoff = 800
        preset.filterResonance = 0.95
        preset.filterDrive = 0
        preset.filterFeedback = 1
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.chorusMix = 0
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        let frames = 44_100 * 10
        var finite = true
        var peak: Float = 0
        for _ in 0..<frames {
            let (l, r) = engine.renderOneSample()
            if !l.isFinite || !r.isFinite {
                finite = false
                break
            }
            peak = max(peak, abs(l), abs(r))
        }
        #expect(finite)
        #expect(peak > 0.001)
        #expect(engine.voices.contains { $0.isActive && $0.filterFeedbackState.isFinite })
    }

    @Test func tranceGateFollowsAHostLocateAndLoop() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120
        preset.tranceGateEnabled = true
        preset.tranceGatePattern = 0x0001
        preset.tranceGateDepth = 1
        preset.tranceGateSmooth = 0
        preset.tranceGateDivision = .sixteenth
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)

        engine.adoptHostContext(tempo: 120, transportMoving: true, beatPosition: 0)
        _ = engine.renderOneSample()
        #expect(engine.tranceStep == 0)
        #expect(engine.tranceGain == 1)

        engine.adoptHostContext(tempo: 120, transportMoving: true, beatPosition: 0.25)
        _ = engine.renderOneSample()
        #expect(engine.tranceStep == 1)
        #expect(engine.tranceGain == 0)

        engine.adoptHostContext(tempo: 120, transportMoving: false, beatPosition: 4)
        engine.usesHostTransport = true
        engine.hostTransportMoving = false
        _ = engine.renderOneSample()
        #expect(engine.tranceStep == 0)
        #expect(engine.tranceGain == 1)
        let held = engine.tranceHostBeat
        _ = engine.renderOneSample()
        #expect(engine.tranceHostBeat == held)
    }

    @Test func haasRisingFromZeroDoesNotClick() {
        let tool = DSPStereoTool()
        let rate: Float = 44_100
        for _ in 0..<200 {
            _ = tool.process(
                left: 0.4,
                right: 0.6,
                width: 1,
                midSide: 0,
                haasMs: 0,
                monoBassHz: 0,
                sampleRate: rate
            )
        }
        var previous: Float = 0.6
        var maxJump: Float = 0
        for _ in 0..<300 {
            let (_, right) = tool.process(
                left: 0.4,
                right: 0.6,
                width: 1,
                midSide: 0,
                haasMs: 20,
                monoBassHz: 0,
                sampleRate: rate
            )
            maxJump = max(maxJump, abs(right - previous))
            previous = right
            #expect(right.isFinite)
        }
        #expect(maxJump < 0.05)
    }

    @Test func remapLookupInterpolatesBetweenTablePoints() {
        let matrix = RTModMatrix()
        matrix.publish([
            ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 1, curve: .exponential)
        ])
        let (slots, count) = matrix.snapshot()
        #expect(count == 1)
        let bank = slots[0].tableBank
        let looked = matrix.lookup(bank: bank, slot: 0, source: 0.5)
        #expect(abs(looked - ModCurve.exponential.remap(0.5)) < 0.02)

        let last = Float(RTModMatrix.tableSize - 1)
        let scaled = (Float(0.5) + 1) * 0.5 * last
        let i0 = Int(scaled)
        let frac = scaled - Float(i0)
        #expect(frac > 0.01)
        let at0 = matrix.lookup(bank: bank, slot: 0, source: Float(i0) / last * 2 - 1)
        let at1 = matrix.lookup(bank: bank, slot: 0, source: Float(i0 + 1) / last * 2 - 1)
        let expected = at0 + (at1 - at0) * frac
        #expect(abs(looked - expected) < 0.0001)
    }
}
