//
//  EnvelopeAnalogModelTests.swift
//  SYNT_63 D3.3 / D3.8: analog EarLevel timing, digital LUT, legacy scale identity.
//

import Foundation
@testable import SynthCore
import Testing

struct EnvelopeAnalogModelTests {
    private let sampleRate = 48_000.0

    private func step(
        _ env: inout ADSREnvelope,
        value: inout Float,
        phase: inout EnvelopePhase,
        time: inout Double,
        releasing: Bool = false,
        releaseStart: Float = 1
    ) -> Float {
        value = env.process(
            currentValue: value,
            phase: &phase,
            time: &time,
            releaseStartValue: releaseStart,
            isReleasing: releasing,
            sampleRate: sampleRate
        )
        return value
    }

    /// EarLevel attack from 0: y(n) = (1 + ratio) * (1 − coef^n), coef^N = ratio / (1 + ratio).
    private func analogAttackSample(for level: Double, samples: Double) -> Double {
        let ratio = Double(ADSREnvelope.analogRatioA)
        let coef = exp(log(ratio / (1 + ratio)) / samples)
        let remain = 1 - level / (1 + ratio)
        return log(remain) / log(coef)
    }

    @Test func analogAttackTenToNinetyMatchesTheEarLevelInterval() {
        let attack: Float = 0.1
        var env = ADSREnvelope(attack: attack, decay: 2, sustain: 1, release: 1)
        env.model = .analog
        var phase = EnvelopePhase.attack
        var time = 0.0
        var value: Float = 0
        let samples = Double(attack) * sampleRate
        var t10: Int?
        var t90: Int?
        var done: Int?
        let limit = Int(samples * 1.5)
        for i in 1...limit {
            step(&env, value: &value, phase: &phase, time: &time)
            if t10 == nil, value >= 0.1 { t10 = i }
            if t90 == nil, value >= 0.9 { t90 = i }
            if phase != .attack {
                done = i
                break
            }
        }
        let measured = Double((t90 ?? 0) - (t10 ?? 0))
        let analytic = analogAttackSample(for: 0.9, samples: samples) - analogAttackSample(for: 0.1, samples: samples)
        #expect(t10 != nil)
        #expect(t90 != nil)
        #expect(abs(measured - analytic) / samples <= 0.05)
        #expect(abs(Double(done ?? 0) - samples) / samples <= 0.05)
        // ratioA 0.3 makes 10→90 about three quarters of T, not T itself.
        #expect(analytic / samples > 0.7)
        #expect(analytic / samples < 0.8)
    }

    @Test func analogReleaseFromUnityReachesMinusEightyInTime() {
        let release: Float = 0.25
        var env = ADSREnvelope(attack: 0.01, decay: 0.1, sustain: 0.8, release: release)
        env.model = .analog
        var phase = EnvelopePhase.release
        var time = 0.0
        var value: Float = 1
        let samples = Double(release) * sampleRate
        let early = Int((0.95 * samples).rounded(.down))
        for _ in 0..<early {
            step(&env, value: &value, phase: &phase, time: &time, releasing: true)
        }
        #expect(value > ADSREnvelope.analogRatioDR)
        #expect(phase == .release)
        var crossed: Int?
        let late = Int((1.05 * samples).rounded(.up))
        for i in (early + 1)...late {
            step(&env, value: &value, phase: &phase, time: &time, releasing: true)
            if value <= ADSREnvelope.analogRatioDR || phase == .finished {
                crossed = i
                break
            }
        }
        let at = Double(crossed ?? 0)
        #expect(abs(at - samples) / samples <= 0.05)
    }

    @Test func analogDecayFromUnityHitsSustainAtTime() {
        let decay: Float = 0.2
        let sustain: Float = 0.4
        var env = ADSREnvelope(attack: 0.01, decay: decay, sustain: sustain, release: 0.3)
        env.model = .analog
        var phase = EnvelopePhase.decay
        var time = 0.0
        var value: Float = 1
        let samples = Double(decay) * sampleRate
        let early = Int((0.9 * samples).rounded(.down))
        for _ in 0..<early {
            step(&env, value: &value, phase: &phase, time: &time)
        }
        #expect(value > sustain)
        #expect(phase == .decay)
        var done = false
        let late = Int((1.05 * samples).rounded(.up))
        for _ in (early + 1)...late {
            step(&env, value: &value, phase: &phase, time: &time)
            if phase == .sustain {
                done = true
                break
            }
        }
        #expect(done)
        #expect(abs(value - sustain) < 0.001)
    }

    @Test func digitalCurveZeroMatchesLegacyBits() {
        func run(model: EnvelopeModel) -> [UInt32] {
            var env = ADSREnvelope(attack: 0.03, decay: 0.2, sustain: 0.45, release: 0.3)
            env.model = model
            var phase = EnvelopePhase.attack
            var time = 0.0
            var value: Float = 0
            var bits: [UInt32] = []
            for _ in 0..<40 {
                step(&env, value: &value, phase: &phase, time: &time)
                bits.append(value.bitPattern)
            }
            phase = .decay
            time = 0
            value = 1
            for _ in 0..<40 {
                step(&env, value: &value, phase: &phase, time: &time)
                bits.append(value.bitPattern)
            }
            phase = .release
            time = 0
            value = 0.6
            for _ in 0..<40 {
                step(&env, value: &value, phase: &phase, time: &time, releasing: true, releaseStart: 0.6)
                bits.append(value.bitPattern)
            }
            return bits
        }
        let legacy = run(model: .legacy)
        let digital = run(model: .digital)
        #expect(legacy == digital)
    }

    @Test func legacyScalesOfOneMatchTheUnscaledCall() {
        func run(explicit: Bool) -> [UInt32] {
            var env = ADSREnvelope(attack: 0.02, decay: 0.12, sustain: 0.5, release: 0.2)
            var phase = EnvelopePhase.attack
            var time = 0.0
            var value: Float = 0
            var bits: [UInt32] = []
            for _ in 0..<25 {
                if explicit {
                    value = env.process(
                        currentValue: value, phase: &phase, time: &time,
                        releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate,
                        attackScale: 1, decayScale: 1, releaseScale: 1
                    )
                } else {
                    value = env.process(
                        currentValue: value, phase: &phase, time: &time,
                        releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate
                    )
                }
                bits.append(value.bitPattern)
            }
            return bits
        }
        #expect(run(explicit: true) == run(explicit: false))
    }

    @Test func digitalCurveTracksThePowerLaw() {
        let curve: Float = -0.5
        var legacy = ADSREnvelope(attack: 0.05, decay: 0.2, sustain: 0, release: 0.2)
        legacy.attackCurve = curve
        var digital = legacy
        digital.model = .digital
        var phaseL = EnvelopePhase.attack
        var phaseD = EnvelopePhase.attack
        var timeL = 0.0
        var timeD = 0.0
        var valueL: Float = 0
        var valueD: Float = 0
        var worst: Float = 0
        var mid: Float = 1
        for i in 0..<1_200 {
            step(&legacy, value: &valueL, phase: &phaseL, time: &timeL)
            step(&digital, value: &valueD, phase: &phaseD, time: &timeD)
            let err = abs(valueL - valueD)
            worst = max(worst, err)
            if i == 1_199 { mid = err }
        }
        // x^0.4 is steep at the origin, so the 256-point line is looser there.
        // Mid-attack the line sits on the power curve.
        #expect(worst < 0.05)
        #expect(mid < 0.002)
    }

    @Test func shortAttackFloorIsLegacyFourMillisecondsUntilTheFlag() {
        func samplesToFinish(allow: Bool) -> Int {
            var env = ADSREnvelope(attack: 0.0005, decay: 1, sustain: 1, release: 1)
            env.model = .analog
            env.allowShortAttack = allow
            var phase = EnvelopePhase.attack
            var time = 0.0
            var value: Float = 0
            for i in 1...2_000 {
                step(&env, value: &value, phase: &phase, time: &time)
                if phase != .attack { return i }
            }
            return 2_000
        }
        let blocked = samplesToFinish(allow: false)
        let open = samplesToFinish(allow: true)
        let floorSamples = Double(ADSREnvelope.minAttackSeconds) * sampleRate
        let shortSamples = Double(ADSREnvelope.shortAttackSeconds) * sampleRate
        #expect(abs(Double(blocked) - floorSamples) / floorSamples <= 0.05)
        #expect(abs(Double(open) - shortSamples) / shortSamples <= 0.05)
        #expect(open * 4 < blocked)
    }
}
