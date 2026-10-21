//
//  DSPFrequencyShifter.swift
//  SynthCore
//
//  Single-sideband (SSB) frequency shifter using an all-pass Hilbert transform
//  network (Niemitalo / HIIR 4-stage allpass pair with 1-sample delay) and
//  quadrature carrier oscillator. Real-time safe: zero allocations, zero locks.
//

import Foundation

public final class DSPFrequencyShifter: @unchecked Sendable {
    // 4-stage allpass Hilbert network coefficients (Niemitalo c = a^2)
    // Branch 1 (H1, with 1-sample delay):
    // a = [0.6923878, 0.9360654322959, 0.9882295226860, 0.9987488452737]
    // c1 = a^2
    private let c1: [Float] = [
        0.47940087,
        0.87621850,
        0.97659760,
        0.99749926
    ]

    // Branch 2 (H2, no delay, +90 deg relative to H1):
    // a = [0.4021921162426, 0.8561710882420, 0.9722909545651, 0.9952884791278]
    // c2 = a^2
    private let c2: [Float] = [
        0.16175850,
        0.73302893,
        0.94534970,
        0.99059916
    ]

    // State for Left channel: Direct Form II (w1, w2 per section)
    private var w1L_1 = [Float](repeating: 0, count: 4)
    private var w2L_1 = [Float](repeating: 0, count: 4)
    private var delayL_1: Float = 0.0

    private var w1L_2 = [Float](repeating: 0, count: 4)
    private var w2L_2 = [Float](repeating: 0, count: 4)

    private var feedbackL: Float = 0.0

    // State for Right channel
    private var w1R_1 = [Float](repeating: 0, count: 4)
    private var w2R_1 = [Float](repeating: 0, count: 4)
    private var delayR_1: Float = 0.0

    private var w1R_2 = [Float](repeating: 0, count: 4)
    private var w2R_2 = [Float](repeating: 0, count: 4)

    private var feedbackR: Float = 0.0

    private var carrierPhase: Double = 0.0

    public init() {}

    public func reset() {
        for i in 0..<4 {
            w1L_1[i] = 0; w2L_1[i] = 0
            w1L_2[i] = 0; w2L_2[i] = 0
            w1R_1[i] = 0; w2R_1[i] = 0
            w1R_2[i] = 0; w2R_2[i] = 0
        }
        delayL_1 = 0
        delayR_1 = 0
        feedbackL = 0
        feedbackR = 0
        carrierPhase = 0
    }

    @inline(__always)
    private static func flushDenormal(_ x: Float) -> Float {
        abs(x) < 1.0e-18 ? 0.0 : x
    }

    @inline(__always)
    private func processBranch1(
        _ input: Float,
        w1: inout [Float],
        w2: inout [Float],
        delay: inout Float
    ) -> Float {
        var v = input
        for k in 0..<4 {
            let c = c1[k]
            let w0 = v + c * w2[k]
            let y = c * w0 - w2[k]
            w2[k] = Self.flushDenormal(w1[k])
            w1[k] = Self.flushDenormal(w0)
            v = y
        }
        let out = delay
        delay = Self.flushDenormal(v)
        return out
    }

    @inline(__always)
    private func processBranch2(
        _ input: Float,
        w1: inout [Float],
        w2: inout [Float]
    ) -> Float {
        var v = input
        for k in 0..<4 {
            let c = c2[k]
            let w0 = v + c * w2[k]
            let y = c * w0 - w2[k]
            w2[k] = Self.flushDenormal(w1[k])
            w1[k] = Self.flushDenormal(w0)
            v = y
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
        let inL = Self.flushDenormal(inputL + feedbackL * fb)
        let inR = Self.flushDenormal(inputR + feedbackR * fb)

        let iL = processBranch1(inL, w1: &w1L_1, w2: &w2L_1, delay: &delayL_1)
        let qL = processBranch2(inL, w1: &w1L_2, w2: &w2L_2)

        let iR = processBranch1(inR, w1: &w1R_1, w2: &w2R_1, delay: &delayR_1)
        let qR = processBranch2(inR, w1: &w1R_2, w2: &w2R_2)

        let cosC = Float(cos(carrierPhase))
        let sinC = Float(sin(carrierPhase))

        // Upper sideband (f + delta): I * cos + Q * sin
        let shiftedL = iL * cosC + qL * sinC
        let shiftedR = iR * cosC + qR * sinC

        feedbackL = shiftedL.isFinite ? Self.flushDenormal(AudioMath.cleanCeiling(shiftedL)) : 0
        feedbackR = shiftedR.isFinite ? Self.flushDenormal(AudioMath.cleanCeiling(shiftedR)) : 0

        let deltaPhase = AudioMath.twoPi * Double(shiftHz) / Double(max(1.0, sampleRate))
        carrierPhase += deltaPhase
        if carrierPhase >= AudioMath.twoPi {
            carrierPhase -= AudioMath.twoPi
        } else if carrierPhase < 0 {
            carrierPhase += AudioMath.twoPi
        }

        let m = min(1.0, max(0.0, mix))
        let outL = Self.flushDenormal(inputL * (1.0 - m) + shiftedL * m)
        let outR = Self.flushDenormal(inputR * (1.0 - m) + shiftedR * m)

        return (
            outL.isFinite ? outL : inputL,
            outR.isFinite ? outR : inputR
        )
    }
}
