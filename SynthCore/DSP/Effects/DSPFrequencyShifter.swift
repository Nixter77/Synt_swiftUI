//
//  DSPFrequencyShifter.swift
//  SynthCore
//
//  Single-sideband (SSB) frequency shifter using an all-pass Hilbert transform
//  network (Niemitalo / HIIR 4-stage allpass pair with 1-sample delay) and
//  quadrature carrier oscillator. Real-time safe: zero allocations, zero locks.
//

import Foundation

private struct AllpassChain4 {
    var f0: Float = 0
    var f1: Float = 0
    var f2: Float = 0
    var f3: Float = 0

    @inline(__always)
    mutating func reset() {
        f0 = 0
        f1 = 0
        f2 = 0
        f3 = 0
    }

    @inline(__always)
    var isFinite: Bool {
        f0.isFinite && f1.isFinite && f2.isFinite && f3.isFinite
    }
}

public final class DSPFrequencyShifter: @unchecked Sendable {
    // 4-stage allpass Hilbert network coefficients (Niemitalo c = a^2)
    // Branch 1 (H1, with 1-sample delay):
    // a = [0.6923878, 0.9360654322959, 0.9882295226860, 0.9987488452737]
    // c1 = a^2
    private static let c1 = AllpassChain4(
        f0: 0.47940087,
        f1: 0.87621850,
        f2: 0.97659760,
        f3: 0.99749926
    )

    // Branch 2 (H2, no delay, +90 deg relative to H1):
    // a = [0.4021921162426, 0.8561710882420, 0.9722909545651, 0.9952884791278]
    // c2 = a^2
    private static let c2 = AllpassChain4(
        f0: 0.16175850,
        f1: 0.73302893,
        f2: 0.94534970,
        f3: 0.99059916
    )

    // State for Left channel: Direct Form II (w1, w2 per section)
    private var w1L_1 = AllpassChain4()
    private var w2L_1 = AllpassChain4()
    private var delayL_1: Float = 0.0

    private var w1L_2 = AllpassChain4()
    private var w2L_2 = AllpassChain4()

    private var feedbackL: Float = 0.0

    // State for Right channel
    private var w1R_1 = AllpassChain4()
    private var w2R_1 = AllpassChain4()
    private var delayR_1: Float = 0.0

    private var w1R_2 = AllpassChain4()
    private var w2R_2 = AllpassChain4()

    private var feedbackR: Float = 0.0

    private var carrierPhase: Double = 0.0

    public init() {}

    public func reset() {
        w1L_1.reset()
        w2L_1.reset()
        w1L_2.reset()
        w2L_2.reset()
        w1R_1.reset()
        w2R_1.reset()
        w1R_2.reset()
        w2R_2.reset()
        delayL_1 = 0
        delayR_1 = 0
        feedbackL = 0
        feedbackR = 0
        carrierPhase = 0
    }

    @inline(__always)
    private var hasFiniteState: Bool {
        w1L_1.isFinite && w2L_1.isFinite && delayL_1.isFinite
            && w1L_2.isFinite && w2L_2.isFinite && feedbackL.isFinite
            && w1R_1.isFinite && w2R_1.isFinite && delayR_1.isFinite
            && w1R_2.isFinite && w2R_2.isFinite && feedbackR.isFinite
            && carrierPhase.isFinite
    }

    @inline(__always)
    private static func flushDenormal(_ x: Float) -> Float {
        abs(x) < 1.0e-18 ? 0.0 : x
    }

    @inline(__always)
    private static func processAllpass4(
        _ input: Float,
        coeffs: AllpassChain4,
        w1: inout AllpassChain4,
        w2: inout AllpassChain4
    ) -> Float {
        let w0_0 = input + coeffs.f0 * w2.f0
        let y0 = coeffs.f0 * w0_0 - w2.f0
        w2.f0 = flushDenormal(w1.f0)
        w1.f0 = flushDenormal(w0_0)

        let w0_1 = y0 + coeffs.f1 * w2.f1
        let y1 = coeffs.f1 * w0_1 - w2.f1
        w2.f1 = flushDenormal(w1.f1)
        w1.f1 = flushDenormal(w0_1)

        let w0_2 = y1 + coeffs.f2 * w2.f2
        let y2 = coeffs.f2 * w0_2 - w2.f2
        w2.f2 = flushDenormal(w1.f2)
        w1.f2 = flushDenormal(w0_2)

        let w0_3 = y2 + coeffs.f3 * w2.f3
        let y3 = coeffs.f3 * w0_3 - w2.f3
        w2.f3 = flushDenormal(w1.f3)
        w1.f3 = flushDenormal(w0_3)

        return y3
    }

    @inline(__always)
    private func processBranch1(
        _ input: Float,
        w1: inout AllpassChain4,
        w2: inout AllpassChain4,
        delay: inout Float
    ) -> Float {
        let v = Self.processAllpass4(input, coeffs: Self.c1, w1: &w1, w2: &w2)
        let out = delay
        delay = Self.flushDenormal(v)
        return out
    }

    @inline(__always)
    private func processBranch2(
        _ input: Float,
        w1: inout AllpassChain4,
        w2: inout AllpassChain4
    ) -> Float {
        Self.processAllpass4(input, coeffs: Self.c2, w1: &w1, w2: &w2)
    }

    public func process(
        inputL: Float,
        inputR: Float,
        shiftHz: Float,
        mix: Float,
        feedback: Float,
        sampleRate: Float
    ) -> (left: Float, right: Float) {
        if !hasFiniteState {
            reset()
        }

        let safeInL: Float = inputL.isFinite ? inputL : 0.0
        let safeInR: Float = inputR.isFinite ? inputR : 0.0
        let safeShiftHz: Float = shiftHz.isFinite ? shiftHz : 0.0
        let safeSampleRate: Float = sampleRate.isFinite ? sampleRate : 44100.0
        let m: Float = mix.isFinite ? min(1.0, max(0.0, mix)) : 0.0
        let fb: Float = feedback.isFinite ? min(0.95, max(-0.95, feedback)) : 0.0

        if m <= 0.0001 && abs(fb) <= 0.0001 {
            return (safeInL, safeInR)
        }

        let inL = Self.flushDenormal(safeInL + feedbackL * fb)
        let inR = Self.flushDenormal(safeInR + feedbackR * fb)

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

        let deltaPhase = AudioMath.twoPi * Double(safeShiftHz) / Double(max(1.0, safeSampleRate))
        carrierPhase += deltaPhase
        if carrierPhase >= AudioMath.twoPi {
            carrierPhase -= AudioMath.twoPi
        } else if carrierPhase < 0 {
            carrierPhase += AudioMath.twoPi
        }

        let outL = Self.flushDenormal(safeInL * (1.0 - m) + shiftedL * m)
        let outR = Self.flushDenormal(safeInR * (1.0 - m) + shiftedR * m)

        if !outL.isFinite || !outR.isFinite || !hasFiniteState {
            reset()
            return (safeInL, safeInR)
        }
        return (outL, outR)
    }
}
