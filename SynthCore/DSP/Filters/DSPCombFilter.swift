//
//  DSPCombFilter.swift
//  SynthCore
//
//  Feedback comb filter / resonator with fractional delay.
//  Real-time safe: zero allocations, zero locks.
//

import Foundation

public final class DSPCombFilter: @unchecked Sendable {
    // 16384 samples allows down to 20 Hz at up to 192 kHz sample rate (192,000 / 20 = 9600 <= 16382)
    private static let bufferSize = 16384
    private static let bufferMask = 16383

    private var buffer = [Float](repeating: 0, count: bufferSize)
    private var writeIndex: Int = 0

    public init() {}

    public func reset() {
        for i in 0..<Self.bufferSize {
            buffer[i] = 0
        }
        writeIndex = 0
    }

    @inline(__always)
    private static func flushDenormal(_ v: Float) -> Float {
        abs(v) < 1.0e-15 ? 0.0 : v
    }

    @inline(__always)
    public func process(
        _ input: Float,
        cutoff: Float,
        resonance: Float,
        sampleRate: Float
    ) -> Float {
        let safeCutoff = max(20.0, min(sampleRate * 0.48, cutoff))
        let delaySamples = max(1.0, min(Float(Self.bufferSize - 2), sampleRate / safeCutoff))

        let intDelay = Int(delaySamples)
        let frac = delaySamples - Float(intDelay)

        let r0 = (writeIndex - intDelay) & Self.bufferMask
        let r1 = (r0 - 1) & Self.bufferMask

        let delayed = buffer[r0] * (1.0 - frac) + buffer[r1] * frac

        // Resonance maps to feedback [0, 0.98]
        let g = max(-0.98, min(0.98, resonance * 0.98))
        let y = input + delayed * g

        let clamped = y.isFinite ? Self.flushDenormal(AudioMath.fastTanh(y)) : 0.0
        buffer[writeIndex] = clamped
        writeIndex = (writeIndex + 1) & Self.bufferMask

        return clamped
    }
}
