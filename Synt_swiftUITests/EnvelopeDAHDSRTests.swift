//
//  EnvelopeDAHDSRTests.swift
//  SYNT_63 D3.2 / D3.4: filter curves, delay, and hold.
//

import Foundation
@testable import SynthCore
import Testing

@MainActor
struct EnvelopeDAHDSRTests {
    private let sampleRate = 48_000.0

    @Test func zeroDelayAndHoldSkipThosePhases() {
        var env = ADSREnvelope(attack: 0.01, decay: 0.2, sustain: 0.5, release: 0.2)
        var phase = EnvelopePhase.delay
        var time = 0.0
        var value: Float = 0
        value = env.process(
            currentValue: value, phase: &phase, time: &time,
            releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
        )
        #expect(phase == .attack)
        #expect(value == 0)

        env.attack = 0.01
        env.hold = 0
        phase = .attack
        time = 0
        value = 0
        let steps = Int(Double(max(ADSREnvelope.minAttackSeconds, env.attack)) * sampleRate) + 2
        for _ in 0..<steps {
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
            )
            if phase != .attack { break }
        }
        #expect(phase == .decay)
        #expect(value == 1)
    }

    @Test func delayHoldsSilenceThenHoldHoldsUnity() {
        var env = ADSREnvelope(attack: 0.02, decay: 0.3, sustain: 0.2, release: 0.2)
        env.delay = 0.03
        env.hold = 0.04
        var phase = EnvelopePhase.delay
        var time = 0.0
        var value: Float = 0.4
        var silent = true
        var delaySteps = 0
        while phase == .delay && delaySteps < 10_000 {
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
            )
            if value != 0 { silent = false }
            delaySteps += 1
        }
        #expect(silent)
        #expect(phase == .attack)
        #expect(abs(Double(delaySteps) - 0.03 * sampleRate) <= 1)

        var attackSteps = 0
        while phase == .attack && attackSteps < 10_000 {
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
            )
            attackSteps += 1
        }
        #expect(phase == .hold)
        #expect(value == 1)
        #expect(abs(Double(attackSteps) - 0.02 * sampleRate) <= 1)

        var holdUnity = true
        var holdSteps = 0
        while phase == .hold && holdSteps < 10_000 {
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
            )
            if value != 1 { holdUnity = false }
            holdSteps += 1
        }
        #expect(holdUnity)
        #expect(phase == .decay)
        #expect(abs(Double(holdSteps) - 0.04 * sampleRate) <= 1)
    }

    @Test func negativeFilterDecayDropsFasterThanLinear() {
        func midDecay(_ curve: Float, model: EnvelopeModel) -> Float {
            var env = ADSREnvelope(attack: 0.01, decay: 0.2, sustain: 0, release: 0.2)
            env.decayCurve = curve
            env.model = model
            var phase = EnvelopePhase.decay
            var time = 0.0
            var value: Float = 1
            let steps = Int(0.25 * 0.2 * sampleRate)
            for _ in 0..<steps {
                value = env.process(
                    currentValue: value, phase: &phase, time: &time,
                    releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
                )
            }
            return value
        }
        let rounded = midDecay(0.8, model: .legacy)
        let plucked = midDecay(-0.8, model: .legacy)
        let pluckedDigital = midDecay(-0.8, model: .digital)
        #expect(plucked < rounded)
        #expect(abs(pluckedDigital - plucked) < 0.02)
    }

    @Test func presetCopiesFilterCurvesDelayAndModel() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.filterAttackCurve = 0.25
        preset.filterDecayCurve = -0.35
        preset.filterReleaseCurve = 0.1
        preset.envelopeModel = .digital
        preset.ampDelay = 0.02
        preset.ampHold = 0.015
        preset.filterEnvDelay = 0.04
        preset.filterEnvHold = 0.05
        preset.attackCurve = 0
        engine.preset = preset
        engine.applyPresetForTesting()

        #expect(engine.filterEnvelope.attackCurve == 0.25)
        #expect(engine.filterEnvelope.decayCurve == -0.35)
        #expect(engine.filterEnvelope.releaseCurve == 0.1)
        #expect(engine.filterEnvelope.model == .digital)
        #expect(engine.filterEnvelope.delay == 0.04)
        #expect(engine.filterEnvelope.hold == 0.05)
        #expect(engine.envelope.model == .digital)
        #expect(engine.envelope.delay == 0.02)
        #expect(engine.envelope.hold == 0.015)
        #expect(engine.envelope.attackCurve == 0)
        #expect(engine.modEnvelope.model == .digital)
        #expect(engine.modEnvelope.delay == 0)
        #expect(engine.modEnvelope.attackCurve == 0)

        engine.noteOn(midiNote: 60, velocity: 0.7)
        engine.processCommandsForTesting()
        let voice = engine.voices.first { $0.isActive && $0.midiNote == 60 }
        #expect(voice?.envelopePhase == .delay)
        #expect(voice?.filterEnvelopePhase == .delay)
    }
}
