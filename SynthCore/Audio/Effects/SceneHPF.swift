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
        lastHz = -1
        lastRate = 0
    }

    public func process(left: Float, right: Float, hz: Float, sampleRate: Float) -> (Float, Float) {
        let rate = max(sampleRate, 1)
        let cutoff = min(max(hz, 20), rate * 0.45)
        if cutoff != lastHz || rate != lastRate {
            lastHz = cutoff
            lastRate = rate
            coeff = exp(-2 * Float.pi * cutoff / rate)
        }
        let yL = coeff * (y1L + left - x1L)
        let yR = coeff * (y1R + right - x1R)
        x1L = left
        y1L = yL
        x1R = right
        y1R = yR
        return (yL, yR)
    }
}
