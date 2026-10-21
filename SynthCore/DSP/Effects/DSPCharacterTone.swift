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
    private var dcX: Float = 0.0
    private var dcY: Float = 0.0

    private var coeffSampleRate: Float = -1
    private var coeffMode: CharacterMode = .off
    private var lowAlpha: Float = 0
    private var highAlpha: Float = 0
    private var dcPole: Float = 0

    public init() {}

    public func reset() {
        lowState = 0.0
        highState = 0.0
        dcX = 0.0
        dcY = 0.0
    }

    /// Poles and the warm DC coefficient. Recomputed when the rate or mode changes, not per sample.
    private func refreshCoeffs(mode: CharacterMode, sampleRate: Float) {
        let sr = max(22050.0, sampleRate)
        if coeffSampleRate == sr && coeffMode == mode { return }
        coeffSampleRate = sr
        coeffMode = mode
        let dt = 1.0 / sr
        switch mode {
        case .off:
            break
        case .warm:
            lowAlpha = min(0.99, Float(2.0 * Double.pi) * 250.0 * dt)
            highAlpha = min(0.99, Float(2.0 * Double.pi) * 7000.0 * dt)
            dcPole = Float(exp(-2.0 * Double.pi * 10.0 / Double(sr)))
        case .bright:
            highAlpha = min(0.99, Float(2.0 * Double.pi) * 4000.0 * dt)
        }
    }

    @inline(__always)
    public func process(_ input: Float, mode: CharacterMode, sampleRate: Float) -> Float {
        guard mode != .off else { return input }
        refreshCoeffs(mode: mode, sampleRate: sampleRate)

        switch mode {
        case .off:
            return input

        case .warm:
            // Warm: low boost and high rolloff + soft saturation.
            lowState += lowAlpha * (input - lowState)
            if abs(lowState) < 1.0e-15 { lowState = 0.0 }

            highState += highAlpha * (input - highState)
            if abs(highState) < 1.0e-15 { highState = 0.0 }

            let shaped = highState + lowState * 0.2
            let warmRaw = shaped + 0.08 * (shaped * shaped)
            let y = warmRaw - dcX + dcPole * dcY
            dcX = warmRaw
            let yFlushed = abs(y) < 1.0e-15 ? 0.0 : (y.isFinite ? y : 0.0)
            dcY = yFlushed
            return AudioMath.fastTanh(yFlushed)

        case .bright:
            highState += highAlpha * (input - highState)
            if abs(highState) < 1.0e-15 { highState = 0.0 }
            let highs = input - highState

            let boosted = input + highs * 0.35
            return AudioMath.fastTanh(boosted)
        }
    }
}
