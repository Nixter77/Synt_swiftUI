//
//  DSPFrequencyShifter.swift
//  SynthCore
//
//  Single-sideband (SSB) frequency shifter using an all-pass Hilbert transform
//  network and quadrature oscillator. Real-time safe: zero allocations, zero locks.
//

import Foundation

public final class DSPFrequencyShifter: @unchecked Sendable {
    // 4-stage allpass Hilbert network coefficients
    // Designed for ~90-degree phase difference across 20 Hz - 20 kHz
    private let aCoeffs: [Float] = [0.161758, 0.733029, 0.94535, 0.990598]
    private let bCoeffs: [Float] = [0.479401, 0.872496, 0.977251, 0.997499]

    // State for Left channel
    private var aStateL_x = [Float](repeating: 0, count: 4)
    private var aStateL_y = [Float](repeating: 0, count: 4)
    private var bStateL_x = [Float](repeating: 0, count: 4)
    private var bStateL_y = [Float](repeating: 0, count: 4)
    private var feedbackL: Float = 0.0

    // State for Right channel
    private var aStateR_x = [Float](repeating: 0, count: 4)
    private var aStateR_y = [Float](repeating: 0, count: 4)
    private var bStateR_x = [Float](repeating: 0, count: 4)
    private var bStateR_y = [Float](repeating: 0, count: 4)
    private var feedbackR: Float = 0.0

    private var carrierPhase: Double = 0.0

    public init() {}

    public func reset() {
        for i in 0..<4 {
            aStateL_x[i] = 0; aStateL_y[i] = 0
            bStateL_x[i] = 0; bStateL_y[i] = 0
            aStateR_x[i] = 0; aStateR_y[i] = 0
            bStateR_x[i] = 0; bStateR_y[i] = 0
        }
        feedbackL = 0
        feedbackR = 0
        carrierPhase = 0
    }

    @inline(__always)
    private func processBranchA(_ input: Float, x: inout [Float], y: inout [Float]) -> Float {
        var v = input
        for k in 0..<4 {
            let a = aCoeffs[k]
            let x0 = v
            let y0 = a * x0 + x[k] - a * y[k]
            x[k] = x0
            y[k] = y0
            v = y0
        }
        return v
    }

    @inline(__always)
    private func processBranchB(_ input: Float, x: inout [Float], y: inout [Float]) -> Float {
        var v = input
        for k in 0..<4 {
            let b = bCoeffs[k]
            let x0 = v
            let y0 = b * x0 + x[k] - b * y[k]
            x[k] = x0
            y[k] = y0
            v = y0
        }
        return v
    }

    public func process(
        inputL: Float,
        inputR: Float,
        shiftHz: Float,
        mix: Float,
        feedback: Float,
        sampleRate: Float
    ) -> (left: Float, right: Float) {
        let fb = min(0.95, max(-0.95, feedback))
        let inL = inputL + feedbackL * fb
        let inR = inputR + feedbackR * fb

        let iL = processBranchA(inL, x: &aStateL_x, y: &aStateL_y)
        let qL = processBranchB(inL, x: &bStateL_x, y: &bStateL_y)

        let iR = processBranchA(inR, x: &aStateR_x, y: &aStateR_y)
        let qR = processBranchB(inR, x: &bStateR_x, y: &bStateR_y)

        let cosC = Float(cos(carrierPhase))
        let sinC = Float(sin(carrierPhase))

        // Upper sideband: I * cos - Q * sin
        let shiftedL = iL * cosC - qL * sinC
        let shiftedR = iR * cosC - qR * sinC

        feedbackL = shiftedL.isFinite ? AudioMath.cleanCeiling(shiftedL) : 0
        feedbackR = shiftedR.isFinite ? AudioMath.cleanCeiling(shiftedR) : 0

        let deltaPhase = AudioMath.twoPi * Double(shiftHz) / Double(sampleRate)
        carrierPhase += deltaPhase
        if carrierPhase >= AudioMath.twoPi {
            carrierPhase -= AudioMath.twoPi
        } else if carrierPhase < 0 {
            carrierPhase += AudioMath.twoPi
        }

        let m = min(1.0, max(0.0, mix))
        let outL = inputL * (1.0 - m) + shiftedL * m
        let outR = inputR * (1.0 - m) + shiftedR * m

        return (
            outL.isFinite ? outL : inputL,
            outR.isFinite ? outR : inputR
        )
    }
}
