//
//  ADSREnvelope.swift
//  Synt_swiftUI
//
//  Exponential-ish ADSR with minimum attack/release times so factory
//  presets with 0.001s attack never hard-step to full amplitude (clicks).
//

import Foundation

struct ADSREnvelope {
    var attack: Float = 0.01
    var decay: Float = 0.1
    var sustain: Float = 0.7
    var release: Float = 0.3

    /// Floor for attack/release — below this the ear hears a click on note on/off.
    static let minAttackSeconds: Float = 0.004   // 4 ms
    static let minReleaseSeconds: Float = 0.012  // 12 ms
    /// Fast release used by voice steal / re-trigger fade-out.
    static let fastReleaseSeconds: Float = 0.006 // 6 ms

    func process(
        currentValue: Float,
        phase: inout EnvelopePhase,
        time: inout Double,
        releaseStartValue: Float,
        isReleasing: Bool,
        sampleRate: Double,
        releaseOverride: Float? = nil
    ) -> Float {
        let deltaTime = 1.0 / sampleRate
        var value = currentValue

        let attackT = max(Self.minAttackSeconds, attack)
        let releaseT = max(Self.minReleaseSeconds, releaseOverride ?? release)

        if isReleasing && phase != .release && phase != .finished {
            phase = .release
            time = 0.0
        }

        switch phase {
        case .attack:
            // Smooth raise: 1 - e^(-k t/T) reaches ~1 at t≈T (k≈5)
            let a = Double(attackT)
            let coeff = Float(exp(-5.0 * deltaTime / a))
            value = 1.0 - (1.0 - value) * coeff
            time += deltaTime
            if time >= a || value >= 0.999 {
                value = 1.0
                phase = .decay
                time = 0.0
            }

        case .decay:
            let d = max(0.003, Double(decay))
            if decay <= 0.001 {
                value = sustain
                phase = .sustain
                time = 0.0
            } else {
                let coefficient = Float(exp(-5.0 * deltaTime / d))
                value = sustain + (value - sustain) * coefficient
                time += deltaTime
                if time >= d || abs(value - sustain) < 0.0005 {
                    value = sustain
                    phase = .sustain
                    time = 0.0
                }
            }

        case .sustain:
            value = sustain

        case .release:
            let r = Double(releaseT)
            if releaseT <= 0.0001 {
                value = 0.0
                phase = .finished
            } else {
                let coefficient = Float(exp(-5.0 * deltaTime / r))
                value = value * coefficient
                time += deltaTime
                if time >= r || value < 0.0002 {
                    value = 0.0
                    phase = .finished
                }
            }

        case .finished:
            value = 0.0
        }

        return AudioMath.clamp(value, min: 0.0, max: 1.0)
    }
}
