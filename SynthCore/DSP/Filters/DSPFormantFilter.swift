//
//  DSPFormantFilter.swift
//  SynthCore
//
//  Formant filter with smooth morphing across vowels A, E, I, O, U.
//  Uses parallel 2nd-order bandpass resonators derived from acoustic formant tables.
//

import Foundation

public final class DSPFormantFilter {
    public struct FormantEntry {
        public let f1: Float
        public let f2: Float
        public let f3: Float
        public let f4: Float
        public let f5: Float
        public let g1: Float
        public let g2: Float
        public let g3: Float
        public let g4: Float
        public let g5: Float

        public init(
            f1: Float, f2: Float, f3: Float, f4: Float, f5: Float,
            g1: Float, g2: Float, g3: Float, g4: Float, g5: Float
        ) {
            self.f1 = f1; self.f2 = f2; self.f3 = f3; self.f4 = f4; self.f5 = f5
            self.g1 = g1; self.g2 = g2; self.g3 = g3; self.g4 = g4; self.g5 = g5
        }
    }

    /// Acoustic formant frequencies (Hz) and relative gains for vowels [A, E, I, O, U].
    public static let vowelTable: [FormantEntry] = [
        // 0: A (/ɑ/ as in "father")
        FormantEntry(f1: 800,  f2: 1200, f3: 2500, f4: 3500, f5: 4500,
                     g1: 1.00, g2: 0.50, g3: 0.20, g4: 0.08, g5: 0.03),
        // 1: E (/ɛ/ as in "bed")
        FormantEntry(f1: 530,  f2: 1840, f3: 2480, f4: 3500, f5: 4500,
                     g1: 1.00, g2: 0.40, g3: 0.15, g4: 0.06, g5: 0.03),
        // 2: I (/i/ as in "meet")
        FormantEntry(f1: 270,  f2: 2290, f3: 3010, f4: 3500, f5: 4500,
                     g1: 1.00, g2: 0.25, g3: 0.10, g4: 0.05, g5: 0.02),
        // 3: O (/ɔ/ as in "thought")
        FormantEntry(f1: 500,  f2: 850,  f3: 2500, f4: 3500, f5: 4500,
                     g1: 1.00, g2: 0.45, g3: 0.12, g4: 0.05, g5: 0.02),
        // 4: U (/u/ as in "boot")
        FormantEntry(f1: 300,  f2: 870,  f3: 2240, f4: 3500, f5: 4500,
                     g1: 1.00, g2: 0.30, g3: 0.08, g4: 0.04, g5: 0.02)
    ]

    public struct ResonatorCoeffs {
        public var b0: Float = 0
        public var b2: Float = 0
        public var a1: Float = 0
        public var a2: Float = 0
        public var gain: Float = 1.0
    }

    public struct ResonatorState {
        public var x1: Float = 0
        public var x2: Float = 0
        public var y1: Float = 0
        public var y2: Float = 0

        @inline(__always)
        public mutating func reset() {
            x1 = 0
            x2 = 0
            y1 = 0
            y2 = 0
        }

        @inline(__always)
        public mutating func process(_ x: Float, coeffs: ResonatorCoeffs) -> Float {
            var y = coeffs.b0 * x + coeffs.b2 * x2 - coeffs.a1 * y1 - coeffs.a2 * y2
            if !y.isFinite {
                reset()
                return 0
            }
            if abs(y) < 1.0e-15 {
                y = 0
            }
            y = max(-12.0, min(12.0, y))
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y * coeffs.gain
        }
    }

    // Parameters
    public var vowel: Float = 0.0 {
        didSet {
            if abs(oldValue - vowel) > 1.0e-4 { isDirty = true }
        }
    }

    public var q: Float = 6.0 {
        didSet {
            if abs(oldValue - q) > 1.0e-4 { isDirty = true }
        }
    }

    public var resonance: Float = 0.5 {
        didSet {
            if abs(oldValue - resonance) > 1.0e-4 { isDirty = true }
        }
    }

    public var mix: Float = 1.0

    // DSP state
    private var sampleRate: Float = 44100.0
    private var isDirty: Bool = true

    // 5 formant bands
    private var coeffs: (ResonatorCoeffs, ResonatorCoeffs, ResonatorCoeffs, ResonatorCoeffs, ResonatorCoeffs)
    private var statesL: (ResonatorState, ResonatorState, ResonatorState, ResonatorState, ResonatorState)
    private var statesR: (ResonatorState, ResonatorState, ResonatorState, ResonatorState, ResonatorState)

    // Preallocated buffers for block processing
    private var scratchBufferL: [Float] = []
    private var scratchBufferR: [Float] = []

    public init(sampleRate: Double = 44100.0, maxFrames: Int = 512) {
        let dummy = ResonatorCoeffs()
        self.coeffs = (dummy, dummy, dummy, dummy, dummy)
        let state = ResonatorState()
        self.statesL = (state, state, state, state, state)
        self.statesR = (state, state, state, state, state)
        prepare(sampleRate: sampleRate, maxFrames: maxFrames)
    }

    public func prepare(sampleRate: Double, maxFrames: Int) {
        self.sampleRate = max(8000.0, Float(sampleRate))
        if scratchBufferL.count < maxFrames {
            scratchBufferL = Array(repeating: 0.0, count: maxFrames)
            scratchBufferR = Array(repeating: 0.0, count: maxFrames)
        }
        isDirty = true
        updateCoefficientsIfNeeded()
    }

    public func reset() {
        statesL.0.reset()
        statesL.1.reset()
        statesL.2.reset()
        statesL.3.reset()
        statesL.4.reset()

        statesR.0.reset()
        statesR.1.reset()
        statesR.2.reset()
        statesR.3.reset()
        statesR.4.reset()
    }

    @inline(__always)
    public func process(_ input: Float) -> Float {
        updateCoefficientsIfNeeded()
        if mix <= 0.0001 { return input }

        let inClamped = max(-3.0, min(3.0, input))

        var out: Float = 0.0
        out += statesL.0.process(inClamped, coeffs: coeffs.0)
        out += statesL.1.process(inClamped, coeffs: coeffs.1)
        out += statesL.2.process(inClamped, coeffs: coeffs.2)
        out += statesL.3.process(inClamped, coeffs: coeffs.3)
        out += statesL.4.process(inClamped, coeffs: coeffs.4)

        // Soft limit output
        out = max(-3.0, min(3.0, out))

        if mix >= 0.9999 { return out }
        return input + mix * (out - input)
    }

    @inline(__always)
    public func process(inputL: Float, inputR: Float) -> (Float, Float) {
        updateCoefficientsIfNeeded()
        if mix <= 0.0001 { return (inputL, inputR) }

        let inL = max(-3.0, min(3.0, inputL))
        let inR = max(-3.0, min(3.0, inputR))

        var outL: Float = 0.0
        outL += statesL.0.process(inL, coeffs: coeffs.0)
        outL += statesL.1.process(inL, coeffs: coeffs.1)
        outL += statesL.2.process(inL, coeffs: coeffs.2)
        outL += statesL.3.process(inL, coeffs: coeffs.3)
        outL += statesL.4.process(inL, coeffs: coeffs.4)

        var outR: Float = 0.0
        outR += statesR.0.process(inR, coeffs: coeffs.0)
        outR += statesR.1.process(inR, coeffs: coeffs.1)
        outR += statesR.2.process(inR, coeffs: coeffs.2)
        outR += statesR.3.process(inR, coeffs: coeffs.3)
        outR += statesR.4.process(inR, coeffs: coeffs.4)

        outL = max(-3.0, min(3.0, outL))
        outR = max(-3.0, min(3.0, outR))

        if mix >= 0.9999 { return (outL, outR) }
        return (inputL + mix * (outL - inputL), inputR + mix * (outR - inputR))
    }

    public func process(
        bufferL: UnsafeMutablePointer<Float>,
        bufferR: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        updateCoefficientsIfNeeded()
        if mix <= 0.0001 { return }

        for i in 0..<frameCount {
            let (l, r) = process(inputL: bufferL[i], inputR: bufferR[i])
            bufferL[i] = l
            bufferR[i] = r
        }
    }

    @inline(__always)
    private func updateCoefficientsIfNeeded() {
        guard isDirty else { return }
        isDirty = false

        let v = max(0.0, min(4.0, vowel))
        let baseIdx = min(3, Int(v))
        let frac = v - Float(baseIdx)
        let nextIdx = baseIdx + 1

        let t0 = Self.vowelTable[baseIdx]
        let t1 = Self.vowelTable[nextIdx]

        // Smooth interpolation of formant frequencies and gains
        let f1 = (1.0 - frac) * t0.f1 + frac * t1.f1
        let f2 = (1.0 - frac) * t0.f2 + frac * t1.f2
        let f3 = (1.0 - frac) * t0.f3 + frac * t1.f3
        let f4 = (1.0 - frac) * t0.f4 + frac * t1.f4
        let f5 = (1.0 - frac) * t0.f5 + frac * t1.f5

        let g1 = (1.0 - frac) * t0.g1 + frac * t1.g1
        let g2 = (1.0 - frac) * t0.g2 + frac * t1.g2
        let g3 = (1.0 - frac) * t0.g3 + frac * t1.g3
        let g4 = (1.0 - frac) * t0.g4 + frac * t1.g4
        let g5 = (1.0 - frac) * t0.g5 + frac * t1.g5

        let effectiveQ = max(0.5, min(40.0, q * (1.0 + resonance * 3.0)))

        coeffs.0 = makeBandpass(frequency: f1, q: effectiveQ, gain: g1)
        coeffs.1 = makeBandpass(frequency: f2, q: effectiveQ * 1.1, gain: g2)
        coeffs.2 = makeBandpass(frequency: f3, q: effectiveQ * 1.2, gain: g3)
        coeffs.3 = makeBandpass(frequency: f4, q: effectiveQ * 1.3, gain: g4)
        coeffs.4 = makeBandpass(frequency: f5, q: effectiveQ * 1.4, gain: g5)
    }

    @inline(__always)
    private func makeBandpass(frequency: Float, q: Float, gain: Float) -> ResonatorCoeffs {
        let nyquistLimit = sampleRate * 0.48
        let clampedFreq = max(20.0, min(nyquistLimit, frequency))
        let omega = 2.0 * Float.pi * (clampedFreq / sampleRate)
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)

        let safeQ = max(0.2, q)
        let alpha = sinOmega / (2.0 * safeQ)
        let a0 = 1.0 + alpha
        let invA0 = 1.0 / a0

        var c = ResonatorCoeffs()
        c.b0 = alpha * invA0
        c.b2 = -alpha * invA0
        c.a1 = (-2.0 * cosOmega) * invA0
        c.a2 = (1.0 - alpha) * invA0
        c.gain = gain
        return c
    }
}
