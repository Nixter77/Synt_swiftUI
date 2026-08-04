//
//  ADSREnvelope.swift
//  Synt_swiftUI
//

import Foundation

struct ADSREnvelope {
    var attack: Float = 0.01
    var decay: Float = 0.1
    var sustain: Float = 0.7
    var release: Float = 0.3

    /// - Parameter releaseOverride: when set (e.g. 1 ms voice-steal), used instead of `release`.
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
        let releaseTime = max(0.0, releaseOverride ?? release)

        if isReleasing && phase != .release && phase != .finished {
            phase = .release
            time = 0.0
        }

        switch phase {
        case .attack:
            if attack <= 0.001 {
                value = 1.0
                phase = .decay
                time = 0.0
            } else {
                value = Float(time / Double(attack))
                if value >= 1.0 {
                    value = 1.0
                    phase = .decay
                    time = 0.0
                }
            }

        case .decay:
            if decay <= 0.001 {
                value = sustain
                phase = .sustain
            } else {
                let decayProgress = Float((time + deltaTime) / Double(decay))
                let coefficient = Float(exp(-5.0 * deltaTime / Double(decay)))
                value = sustain + (value - sustain) * coefficient
                if decayProgress >= 1.0 || abs(value - sustain) < 0.0001 {
                    value = sustain
                    phase = .sustain
                }
            }

        case .sustain:
            value = sustain

        case .release:
            // Treat only near-zero as instant; 1 ms steal-release must still ramp.
            if releaseTime <= 0.0001 {
                value = 0.0
                phase = .finished
            } else {
                let releaseProgress = Float((time + deltaTime) / Double(releaseTime))
                let coefficient = Float(exp(-5.0 * deltaTime / Double(releaseTime)))
                value = value * coefficient
                if releaseProgress >= 1.0 || value < 0.0001 {
                    value = 0.0
                    phase = .finished
                }
            }

        case .finished:
            value = 0.0
        }

        time += deltaTime

        return AudioMath.clamp(value, min: 0.0, max: 1.0)
    }
}
