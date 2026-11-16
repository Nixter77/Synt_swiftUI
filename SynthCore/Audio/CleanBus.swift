//
//  CleanBus.swift
//  Synt_swiftUI
//
//  Lookahead peak rider extracted from AudioEngine+Render.swift.
//

import Foundation

/// Lookahead peak rider. Multiplies the whole waveform by a slow gain so a chord
/// that would have entered the tanh clipper stays linear. Gain does not track
/// individual waveform cycles (that would be another waveshaper).
public final class CleanBus {
    public static let capacity = 512
    public static let lookahead = 256
    public static let threshold = AudioMath.cleanBusThreshold

    private var bufL = [Float](repeating: 0, count: CleanBus.capacity)
    private var bufR = [Float](repeating: 0, count: CleanBus.capacity)
    private var write = 0
    private var env: Float = 0
    private var gain: Float = 1
    private var hold = 0
    private var envCoeff: Float = 1
    private var attCoeff: Float = 1
    private var relCoeff: Float = 0
    private var holdMax = 1
    private var coeffRate: Float = 0
    private var dcPole: Float = 0.9983
    private var dcXL: Float = 0
    private var dcXR: Float = 0
    private var dcYL: Float = 0
    private var dcYR: Float = 0

    public init(sampleRate: Float = 44100) {
        updateCoefficients(sampleRate: sampleRate)
    }

    public func setSampleRate(_ sampleRate: Float) {
        updateCoefficients(sampleRate: max(8_000, sampleRate))
    }

    public func reset() {
        for i in 0..<bufL.count {
            bufL[i] = 0
            bufR[i] = 0
        }
        write = 0
        env = 0
        gain = 1
        hold = 0
        dcXL = 0
        dcXR = 0
        dcYL = 0
        dcYR = 0
    }

    public func process(left: Float, right: Float, sampleRate: Float) -> (Float, Float) {
        let sr = sampleRate > 1000 ? sampleRate : coeffRate
        if sr != coeffRate { updateCoefficients(sampleRate: sr) }

        let xL = dcBlock(left.isFinite ? left : 0, x1: &dcXL, y1: &dcYL)
        let xR = dcBlock(right.isFinite ? right : 0, x1: &dcXR, y1: &dcYR)

        bufL[write] = xL
        bufR[write] = xR

        let peak = max(abs(xL), abs(xR))
        if peak >= env {
            env = peak
            hold = holdMax
        } else if hold > 0 {
            hold -= 1
        } else {
            env = max(peak, env * envCoeff)
        }

        let desired: Float = env > Self.threshold ? Self.threshold / env : 1
        let coeff: Float
        if desired < gain * 0.985 {
            coeff = attCoeff
        } else if desired > gain {
            coeff = relCoeff
        } else {
            coeff = 0
        }
        if coeff > 0 {
            gain += (desired - gain) * coeff
        }
        if !gain.isFinite || gain < 0 { gain = 1 }
        if gain > 1 { gain = 1 }

        let read = (write + Self.capacity - Self.lookahead) & (Self.capacity - 1)
        write = (write + 1) & (Self.capacity - 1)
        return (bufL[read] * gain, bufR[read] * gain)
    }

    private func updateCoefficients(sampleRate: Float) {
        coeffRate = sampleRate
        let sr = Double(sampleRate)
        envCoeff = Float(exp(-1.0 / (sr * 0.200)))
        attCoeff = Float(1.0 - exp(-1.0 / (sr * 0.0015)))
        relCoeff = Float(1.0 - exp(-1.0 / (sr * 0.150)))
        holdMax = max(1, Int(sampleRate * 0.040))
        dcPole = Float(exp(-2.0 * Double.pi * 12.0 / sr))
    }

    private func dcBlock(_ x: Float, x1: inout Float, y1: inout Float) -> Float {
        let y = x - x1 + dcPole * y1
        x1 = x
        if !y.isFinite || abs(y) > 16 {
            y1 = 0
            return 0
        }
        y1 = y
        return y
    }
}
