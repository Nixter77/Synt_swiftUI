//
//  LadderFilter.swift
//  Synt_swiftUI
//
//  4-pole TPT ladder (Zavalishin, The Art of VA Filter Design).
//  Feedback stops just short of self-oscillation. Input uses a saturating tanh.
//  State lives on the voice. No allocation.
//

import Foundation

struct LadderFilter {
    private var z1: Float = 0
    private var z2: Float = 0
    private var z3: Float = 0
    private var z4: Float = 0
    private var G: Float = 0
    private var k: Float = 0
    private var cachedCutoff: Float = -1
    private var cachedResonance: Float = -1
    private var cachedRate: Float = -1

    mutating func reset() {
        z1 = 0
        z2 = 0
        z3 = 0
        z4 = 0
    }

    /// `G` is passed in so the state write does not overlap a read of `self`.
    /// Each pole is saturated (Huovilainen) so a cutoff sweep cannot run away.
    @inline(__always)
    private static func stage(_ x: Float, z: inout Float, G: Float) -> Float {
        let v = (x - z) * G
        let y = AudioMath.fastTanh(v + z)
        z = 2 * y - z
        if abs(z) < 1e-15 { z = 0 }
        return y
    }

    mutating func process(
        _ input: Float,
        cutoff: Float,
        resonance: Float,
        drive: Float,
        sampleRate: Float
    ) -> Float {
        if cutoff != cachedCutoff || resonance != cachedResonance || sampleRate != cachedRate {
            cachedCutoff = cutoff
            cachedResonance = resonance
            cachedRate = sampleRate
            let rate = max(sampleRate, 8_000)
            let fc = min(max(cutoff, 20), rate * 0.45)
            let g = tan(min(Float.pi * fc / rate, 1.5))
            G = g / (1 + g)
            let res = min(1, max(0, resonance))
            k = min(3.8, res * 3.8)
        }

        let driveGain = 1 + min(1, max(0, drive)) * 8
        let xin = AudioMath.fastTanh(input * driveGain)
        let g = G
        let G2 = g * g
        let G3 = G2 * g
        // Each stored pole contributes (1 - G) * z to the output (Zavalishin).
        let gp = 1 - g
        let S = gp * (G3 * z1 + G2 * z2 + g * z3 + z4)
        let denom = 1 + k * G2 * G2
        let u = (xin - k * S) / denom
        let y1 = Self.stage(u, z: &z1, G: g)
        let y2 = Self.stage(y1, z: &z2, G: g)
        let y3 = Self.stage(y2, z: &z3, G: g)
        let y4 = Self.stage(y3, z: &z4, G: g)
        if !y4.isFinite || !z1.isFinite || !z4.isFinite {
            reset()
            return 0
        }
        return y4
    }
}
