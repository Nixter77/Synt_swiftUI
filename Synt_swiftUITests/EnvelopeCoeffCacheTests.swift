//
//  EnvelopeCoeffCacheTests.swift
//  SYNT_61 D3.1: ADSR one-pole coefficients are cached, and the Float matches
//  a direct exp(-5 * dt / T) of the same arguments.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct EnvelopeCoeffCacheTests {
    private static func directCoeff(timeSeconds: Double, sampleRate: Double) -> Float {
        let deltaTime = 1.0 / sampleRate
        return Float(exp(-5.0 * deltaTime / timeSeconds))
    }

    @Test func attackDecayAndReleaseMatchDirectExp() {
        var env = ADSREnvelope(attack: 0.02, decay: 0.3, sustain: 0.35, release: 0.45)
        let sr = 44_100.0

        var phase = EnvelopePhase.attack
        var time = 0.0
        var value: Float = 0
        let attackT = Double(max(ADSREnvelope.minAttackSeconds, env.attack))
        let attackCoeff = Self.directCoeff(timeSeconds: attackT, sampleRate: sr)
        for _ in 0..<80 {
            let prev = value
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0, isReleasing: false, sampleRate: sr
            )
            let expected = AudioMath.clamp(1.0 - (1.0 - prev) * attackCoeff, min: 0, max: 1)
            #expect(phase == .attack)
            #expect(value.bitPattern == expected.bitPattern)
        }

        phase = .decay
        time = 0
        value = 1
        let decayT = max(0.003, Double(env.decay))
        let decayCoeff = Self.directCoeff(timeSeconds: decayT, sampleRate: sr)
        for _ in 0..<80 {
            let prev = value
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0, isReleasing: false, sampleRate: sr
            )
            let expected = AudioMath.clamp(env.sustain + (prev - env.sustain) * decayCoeff, min: 0, max: 1)
            #expect(phase == .decay)
            #expect(value.bitPattern == expected.bitPattern)
        }

        phase = .release
        time = 0
        value = 0.7
        let releaseT = Double(max(ADSREnvelope.minReleaseSeconds, env.release))
        let releaseCoeff = Self.directCoeff(timeSeconds: releaseT, sampleRate: sr)
        for _ in 0..<80 {
            let prev = value
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: 0.7, isReleasing: true, sampleRate: sr
            )
            let expected = AudioMath.clamp(prev * releaseCoeff, min: 0, max: 1)
            #expect(phase == .release)
            #expect(value.bitPattern == expected.bitPattern)
        }
    }

    @Test func changedAttackAndSampleRateRefillTheCache() {
        var env = ADSREnvelope(attack: 0.05, decay: 0.2, sustain: 0.5, release: 0.2)
        var phase = EnvelopePhase.attack
        var time = 0.0
        var value: Float = 0
        let sr = 44_100.0
        _ = env.process(
            currentValue: value, phase: &phase, time: &time,
            releaseStartValue: 0, isReleasing: false, sampleRate: sr
        )
        env.attack = 0.2
        let prev = value
        value = env.process(
            currentValue: value, phase: &phase, time: &time,
            releaseStartValue: 0, isReleasing: false, sampleRate: sr
        )
        let attackT = Double(max(ADSREnvelope.minAttackSeconds, env.attack))
        let expected = AudioMath.clamp(
            1.0 - (1.0 - prev) * Self.directCoeff(timeSeconds: attackT, sampleRate: sr),
            min: 0, max: 1
        )
        #expect(value.bitPattern == expected.bitPattern)

        let sr2 = 48_000.0
        let prev2 = value
        value = env.process(
            currentValue: value, phase: &phase, time: &time,
            releaseStartValue: 0, isReleasing: false, sampleRate: sr2
        )
        let expected2 = AudioMath.clamp(
            1.0 - (1.0 - prev2) * Self.directCoeff(timeSeconds: attackT, sampleRate: sr2),
            min: 0, max: 1
        )
        #expect(value.bitPattern == expected2.bitPattern)
    }

    @Test func fastAndNormalReleaseShareOneCacheWithoutCrosstalk() {
        var env = ADSREnvelope(attack: 0.01, decay: 0.1, sustain: 0.8, release: 0.8)
        let sr = 44_100.0
        let normalT = Double(max(ADSREnvelope.minReleaseSeconds, env.release))
        let fastT = Double(max(ADSREnvelope.minReleaseSeconds, ADSREnvelope.fastReleaseSeconds))
        let normalCoeff = Self.directCoeff(timeSeconds: normalT, sampleRate: sr)
        let fastCoeff = Self.directCoeff(timeSeconds: fastT, sampleRate: sr)
        var value: Float = 0.85
        for _ in 0..<6 {
            var phase = EnvelopePhase.release
            var time = 0.0
            let prevNormal = value
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: prevNormal, isReleasing: true, sampleRate: sr, releaseOverride: nil
            )
            #expect(value.bitPattern == AudioMath.clamp(prevNormal * normalCoeff, min: 0, max: 1).bitPattern)

            phase = .release
            time = 0
            let prevFast = value
            value = env.process(
                currentValue: value, phase: &phase, time: &time,
                releaseStartValue: prevFast, isReleasing: true, sampleRate: sr,
                releaseOverride: ADSREnvelope.fastReleaseSeconds
            )
            #expect(value.bitPattern == AudioMath.clamp(prevFast * fastCoeff, min: 0, max: 1).bitPattern)
        }
    }
}
