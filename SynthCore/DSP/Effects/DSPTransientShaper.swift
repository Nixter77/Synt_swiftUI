//
//  DSPTransientShaper.swift
//  SynthCore
//
//  Differential envelope transient shaper.
//  Zero allocation, zero locks, zero per-sample transcendental math.
//

import Foundation

public final class DSPTransientShaper {
    private var sampleRate: Float = 44100

    // Cached one-pole filter coefficients
    private var fastAttackCoeff: Float = 0
    private var fastReleaseCoeff: Float = 0
    private var slowAttackCoeff: Float = 0
    private var slowReleaseCoeff: Float = 0

    // Stereo-linked envelope detectors
    private var fastEnv: Float = 0
    private var slowEnv: Float = 0

    // Parameter smoothers (~10 ms slew) to eliminate clicks on sweeps
    private var smoothedAttack: Float = 0
    private var smoothedSustain: Float = 0
    private var smoothedOutput: Float = 1.0
    private var smoothedMix: Float = 1.0
    private var paramCoeff: Float = 0

    public init(sampleRate: Float = 44100) {
        setSampleRate(sampleRate)
    }

    public func setSampleRate(_ rate: Float) {
        let sr = max(8000, rate)
        sampleRate = sr
        // Fast envelope: attack ~1 ms, release ~15 ms
        fastAttackCoeff = 1.0 - exp(-1.0 / (0.001 * sr))
        fastReleaseCoeff = 1.0 - exp(-1.0 / (0.015 * sr))
        // Slow envelope: attack ~15 ms, release ~80 ms
        slowAttackCoeff = 1.0 - exp(-1.0 / (0.015 * sr))
        slowReleaseCoeff = 1.0 - exp(-1.0 / (0.080 * sr))
        // Parameter smoothing: ~10 ms
        paramCoeff = 1.0 - exp(-1.0 / (0.010 * sr))
    }

    public func reset() {
        fastEnv = 0
        slowEnv = 0
        smoothedAttack = 0
        smoothedSustain = 0
        smoothedOutput = 1.0
        smoothedMix = 1.0
    }

    @inline(__always)
    public func process(
        left: Float,
        right: Float,
        attack: Float,
        sustain: Float,
        output: Float,
        mix: Float
    ) -> (Float, Float) {
        // Parameter smoothing
        smoothedAttack += (attack - smoothedAttack) * paramCoeff
        smoothedSustain += (sustain - smoothedSustain) * paramCoeff
        smoothedOutput += (output - smoothedOutput) * paramCoeff
        smoothedMix += (mix - smoothedMix) * paramCoeff

        let inL = left.isFinite ? (abs(left) < 1e-15 ? 0 : left) : 0
        let inR = right.isFinite ? (abs(right) < 1e-15 ? 0 : right) : 0

        let peak = max(abs(inL), abs(inR))

        // Fast envelope follower
        let fastCoeff = peak > fastEnv ? fastAttackCoeff : fastReleaseCoeff
        fastEnv += (peak - fastEnv) * fastCoeff
        if fastEnv < 1e-9 || !fastEnv.isFinite { fastEnv = 0 }

        // Slow envelope follower
        let slowCoeff = peak > slowEnv ? slowAttackCoeff : slowReleaseCoeff
        slowEnv += (peak - slowEnv) * slowCoeff
        if slowEnv < 1e-9 || !slowEnv.isFinite { slowEnv = 0 }

        // Differential transient detection
        let diff = max(0, fastEnv - slowEnv)

        // Normalized transient and sustain energy
        let denom = max(slowEnv, 1e-4)
        let transientNorm = min(4.0, diff / denom)
        let sustainNorm = min(2.0, slowEnv / (fastEnv + 1e-4))

        // Gain calculation
        let attackGain = max(0.0, 1.0 + smoothedAttack * transientNorm * 2.0)
        let sustainGain = max(0.0, 1.0 + smoothedSustain * sustainNorm)
        let totalGain = min(8.0, attackGain * sustainGain) * smoothedOutput

        let shapedL = inL * totalGain
        let shapedR = inR * totalGain

        let outL = inL + (shapedL - inL) * smoothedMix
        let outR = inR + (shapedR - inR) * smoothedMix

        let flushL = abs(outL) < 1e-15 ? 0 : outL
        let flushR = abs(outR) < 1e-15 ? 0 : outR
        return (flushL.isFinite ? flushL : 0, flushR.isFinite ? flushR : 0)
    }
}
