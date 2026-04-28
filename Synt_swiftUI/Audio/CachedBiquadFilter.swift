//
//  CachedBiquadFilter.swift
//  Synt_swiftUI
//
//  Biquad filter with coefficient caching and parameter smoothing.
//  Coefficients are only recalculated when cutoff/resonance changes.
//

import Foundation

final class CachedBiquadFilter {
    var type: FilterType = .lowPass {
        didSet { if oldValue != type { isDirty = true } }
    }

    var cutoff: Float = 5000.0 {
        didSet {
            if abs(oldValue - cutoff) > 0.1 {
                targetCutoff = cutoff
            }
        }
    }

    var resonance: Float = 0.5 {
        didSet { if abs(oldValue - resonance) > 0.001 { isDirty = true } }
    }

    // Cached coefficients
    private var b0: Float = 0
    private var b1: Float = 0
    private var b2: Float = 0
    private var a1: Float = 0
    private var a2: Float = 0

    // Filter state
    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0

    // Dirty flag - recalculate only when needed
    private var isDirty: Bool = true

    // Parameter smoothing
    private var targetCutoff: Float = 5000.0
    private var smoothedCutoff: Float = 5000.0
    private let smoothingCoeff: Float = 0.995  // Per-sample smoothing

    // Cached sample rate for coefficient calculation
    private var cachedSampleRate: Float = 44100.0

    // Denormal threshold
    private let denormalThreshold: Float = 1.0e-15

    func reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
        isDirty = true
    }

    @inline(__always)
    func process(_ input: Float, sampleRate: Float) -> Float {
        // Parameter smoothing for cutoff
        let cutoffDiff = targetCutoff - smoothedCutoff
        if abs(cutoffDiff) > 0.1 {
            smoothedCutoff += cutoffDiff * (1.0 - smoothingCoeff)
            isDirty = true
        }

        // Recalculate coefficients only when dirty
        if isDirty || abs(cachedSampleRate - sampleRate) > 0.1 {
            cachedSampleRate = sampleRate
            recalculateCoefficients(sampleRate: sampleRate)
            isDirty = false
        }

        // Biquad filter processing
        var output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        // Denormal protection
        if abs(output) < denormalThreshold {
            output = 0.0
        }

        // Update state
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output

        return output
    }

    private func recalculateCoefficients(sampleRate: Float) {
        let normalizedCutoff = min(smoothedCutoff / sampleRate, 0.49)
        let omega = 2.0 * Float.pi * normalizedCutoff

        // Use fast approximations for sin/cos when possible
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)

        let q = max(0.1, resonance * 10.0)
        let alpha = sinOmega / (2.0 * q)

        var b0_raw: Float = 0, b1_raw: Float = 0, b2_raw: Float = 0
        var a0_raw: Float = 0, a1_raw: Float = 0, a2_raw: Float = 0

        switch type {
        case .lowPass:
            b0_raw = (1.0 - cosOmega) / 2.0
            b1_raw = 1.0 - cosOmega
            b2_raw = (1.0 - cosOmega) / 2.0
            a0_raw = 1.0 + alpha
            a1_raw = -2.0 * cosOmega
            a2_raw = 1.0 - alpha

        case .highPass:
            b0_raw = (1.0 + cosOmega) / 2.0
            b1_raw = -(1.0 + cosOmega)
            b2_raw = (1.0 + cosOmega) / 2.0
            a0_raw = 1.0 + alpha
            a1_raw = -2.0 * cosOmega
            a2_raw = 1.0 - alpha

        case .bandPass:
            b0_raw = alpha
            b1_raw = 0.0
            b2_raw = -alpha
            a0_raw = 1.0 + alpha
            a1_raw = -2.0 * cosOmega
            a2_raw = 1.0 - alpha
        }

        // Normalize coefficients
        let invA0 = 1.0 / a0_raw
        b0 = b0_raw * invA0
        b1 = b1_raw * invA0
        b2 = b2_raw * invA0
        a1 = a1_raw * invA0
        a2 = a2_raw * invA0
    }
}
