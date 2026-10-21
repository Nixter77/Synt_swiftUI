//
//  DSPCharacterTone.swift
//  SynthCore
//
//  Output character contour (Warm / Bright). Gentle tone curve applied
//  right before final ceiling. Real-time safe: zero allocations, zero locks.
//

import Foundation

public enum CharacterMode: String, CaseIterable, Codable, Sendable {
    case off = "Off"
    case warm = "Warm"
    case bright = "Bright"
}

public final class DSPCharacterTone: @unchecked Sendable {
    // 1-pole low and high filters for shelving tone curves
    private var lowState: Float = 0.0
    private var highState: Float = 0.0

    public init() {}

    public func reset() {
        lowState = 0.0
        highState = 0.0
    }

    @inline(__always)
    public func process(_ input: Float, mode: CharacterMode, sampleRate: Float) -> Float {
        guard mode != .off else { return input }

        let dt = 1.0 / max(22050.0, sampleRate)

        switch mode {
        case .off:
            return input

        case .warm:
            // Warm: low boost (+1.5 dB) and high rolloff (-2 dB) + soft saturation
            // Low pole ~ 250 Hz
            let lowCutoff: Float = 250.0
            let lowAlpha = min(0.99, Float(2.0 * Double.pi) * lowCutoff * dt)
            lowState += lowAlpha * (input - lowState)

            // High pole ~ 7000 Hz
            let highCutoff: Float = 7000.0
            let highAlpha = min(0.99, Float(2.0 * Double.pi) * highCutoff * dt)
            highState += highAlpha * (input - highState)

            // Shape: add some low warmth, gentle high cut
            let shaped = highState + lowState * 0.2
            // Subtle 2nd harmonic warmth
            let warm = shaped + 0.08 * (shaped * shaped)
            return AudioMath.fastTanh(warm)

        case .bright:
            // Bright: high shelf boost (+2.5 dB above 4 kHz)
            let highCutoff: Float = 4000.0
            let highAlpha = min(0.99, Float(2.0 * Double.pi) * highCutoff * dt)
            highState += highAlpha * (input - highState)
            let highs = input - highState

            let boosted = input + highs * 0.35
            return AudioMath.fastTanh(boosted)
        }
    }
}
