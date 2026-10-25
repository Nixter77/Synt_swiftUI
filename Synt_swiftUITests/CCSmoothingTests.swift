//
//  CCSmoothingTests.swift
//  Zipper CC glides over ~8 ms, and a knob waits for the current value after a patch change.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct CCSmoothingTests {
    @Test func ccStepFromZeroToFullIsARampWithoutStairs() {
        let engine = AudioEngine()
        engine.applySingleParameterRT(target: .pitch1, rawValue: 0)
        _ = engine.renderFramesForTesting(8_000)
        let floor = engine.oscillator1.detune
        #expect(abs(floor - (-50)) < 0.05)

        engine.applySingleParameterRT(target: .pitch1, rawValue: 127)
        let atJump = engine.oscillator1.detune
        #expect(abs(atJump - floor) < 1e-4, "the sample of the CC must not already be the new value")

        var previous = atJump
        var rises = 0
        var maxStep: Float = 0
        for _ in 0..<2_000 {
            _ = engine.renderOneSample()
            let value = engine.oscillator1.detune
            let step = value - previous
            #expect(step >= -1e-5)
            if step > 1e-6 { rises += 1 }
            if step > maxStep { maxStep = step }
            previous = value
        }
        #expect(rises > 200, "a 7-bit stair would move in one sample")
        #expect(maxStep < 1, "one sample moved \(maxStep), the full throw is 100 cents")
        #expect(previous < 50)
        _ = engine.renderFramesForTesting(8_000)
        #expect(abs(engine.oscillator1.detune - 50) < 0.05)
    }

    @Test func softTakeoverDoesNotJumpAfterAPresetChange() {
        let engine = AudioEngine()
        MIDICCLearnStore.shared.attachEngine(engine)
        MIDICCLearnStore.shared.clearMappings()
        MIDICCLearnStore.shared.map(cc: 20, to: .attack)

        var patch = SynthPreset.defaultPreset
        patch.name = "Takeover"
        patch.attack = 0.01
        engine.preset = patch
        engine.processCommandsForTesting()

        let presetAttack = engine.preset.attack
        let liveAttack = engine.envelope.attack
        let position = MIDIControlTarget.attack.rawMIDI(matching: presetAttack)
        #expect(position == 1)

        engine.applySingleParameterFromMIDI(cc: 20, value: 127)
        _ = engine.midiQueue.push(.controlChange(cc: 20, value: 127))
        engine.processCommandQueue()
        #expect(engine.preset.attack == presetAttack)
        #expect(engine.envelope.attack == liveAttack)
        #expect(abs(engine.ccAttackTarget - liveAttack) < 1e-6)

        engine.applySingleParameterFromMIDI(cc: 20, value: UInt8(position))
        _ = engine.midiQueue.push(.controlChange(cc: 20, value: UInt8(position)))
        engine.processCommandQueue()
        #expect(abs(engine.preset.attack - presetAttack) < 0.05)
        #expect(abs(engine.envelope.attack - liveAttack) < 0.05)

        engine.applySingleParameterFromMIDI(cc: 20, value: 127)
        _ = engine.midiQueue.push(.controlChange(cc: 20, value: 127))
        engine.processCommandQueue()
        #expect(engine.preset.attack > 1.5)
        #expect(abs(engine.envelope.attack - liveAttack) < 0.05, "catching the knob must not jump the envelope")
        _ = engine.renderFramesForTesting(8_000)
        #expect(abs(engine.envelope.attack - engine.preset.attack) < 0.02)

        MIDICCLearnStore.shared.clearMappings()
    }

    @Test func resonanceCCBaseDoesNotDriftUnderModulation() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.name = "Resonance Base"
        preset.filterResonance = 0.2
        preset.lfoEnabled = true
        preset.lfoRate = 8
        preset.lfoTarget = .none
        preset.modMatrix = [ModMatrixEntry(source: .lfo1, destination: .resonance, amount: 1)]
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.processCommandsForTesting()

        let writtenBase = engine.filterL.resonance
        engine.applySingleParameterRT(target: .resonance, rawValue: 90)
        let captured = engine.ccResonanceBaseRT
        #expect(captured == writtenBase)
        #expect(engine.ccResonanceRT > 0.5)

        engine.noteOn(midiNote: 60)
        engine.processCommandsForTesting()
        let metrics = engine.renderFramesMetricsForTesting(4_000)
        #expect(metrics.nanCount == 0)
        #expect(engine.ccResonanceBaseRT == captured)
        #expect(engine.filterL.resonance == writtenBase)
    }

    @Test func ccStepSmoothingOnCutoffAndFilterADSRAndMorph() {
        let engine = AudioEngine()
        engine.snapCCTargetsFromLive()

        // Cutoff via CC (smoothedFilterCutoff glides one-pole toward cachedFilterCutoff)
        let initialCutoff = engine.smoothedFilterCutoff
        engine.applySingleParameterRT(target: .cutoff, rawValue: 127)
        #expect(abs(engine.smoothedFilterCutoff - initialCutoff) < 1e-4, "cutoff should not jump immediately")
        _ = engine.renderOneSample()
        #expect(engine.smoothedFilterCutoff > initialCutoff, "cutoff starts gliding")

        // Filter attack via CC
        let initialFA = engine.filterEnvelope.attack
        engine.applySingleParameterRT(target: .filterAttack, rawValue: 127)
        #expect(abs(engine.filterEnvelope.attack - initialFA) < 1e-4, "filter attack should not jump immediately")
        _ = engine.renderOneSample()
        #expect(engine.filterEnvelope.attack > initialFA, "filter attack starts gliding")

        // WtMorph1 via CC
        let initialMorph = engine.oscillator1.wavetableMorph
        engine.applySingleParameterRT(target: .wtMorph1, rawValue: 127)
        #expect(abs(engine.oscillator1.wavetableMorph - initialMorph) < 1e-4, "wtMorph should not jump immediately")
        _ = engine.renderOneSample()
        #expect(engine.oscillator1.wavetableMorph > initialMorph, "wtMorph starts gliding")

        // Render remaining ~8ms (2000 samples)
        _ = engine.renderFramesForTesting(2_000)
        #expect(engine.smoothedFilterCutoff > 15000)
        #expect(engine.filterEnvelope.attack > 1.9)
        #expect(engine.oscillator1.wavetableMorph > 0.95)
    }
}
