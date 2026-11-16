//
//  SceneHPF.swift
//  One-pole high-pass in front of the FX chain. The render path calls it
//  only while the preset enables it.
//

import Foundation

public final class SceneHPF {
    private var x1L: Float = 0
    private var y1L: Float = 0
    private var x1R: Float = 0
    private var y1R: Float = 0
    private var coeff: Float = 0
    private var lastHz: Float = -1
    private var lastRate: Float = 0

    public func reset() {
        x1L = 0
        y1L = 0
        x1R = 0
        y1R = 0
        coeff = 0
        lastHz = -1
        lastRate = 0
    }

    public func process(left: Float, right: Float, hz: Float, sampleRate: Float) -> (Float, Float) {
        let inL: Float = left.isFinite ? left : 0
        let inR: Float = right.isFinite ? right : 0
        let safeRate: Float = sampleRate.isFinite ? sampleRate : 44_100
        let safeHz: Float = hz.isFinite ? hz : 120
        let rate = max(safeRate, 1)
        let cutoff = min(max(safeHz, 20), rate * 0.45)
        if cutoff != lastHz || rate != lastRate {
            lastHz = cutoff
            lastRate = rate
            coeff = exp(-2 * Float.pi * cutoff / rate)
        }
        var yL = coeff * (y1L + inL - x1L)
        var yR = coeff * (y1R + inR - x1R)
        if !yL.isFinite || !yR.isFinite {
            reset()
            return (0, 0)
        }
        if abs(yL) < 1e-15 { yL = 0 }
        if abs(yR) < 1e-15 { yR = 0 }
        x1L = inL
        y1L = yL
        x1R = inR
        y1R = yR
        return (yL, yR)
    }
}
