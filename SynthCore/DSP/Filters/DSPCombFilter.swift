//
//  DSPCombFilter.swift
//  SynthCore
//
//  Feedback comb filter / resonator with fractional delay.
//  Real-time safe: zero allocations, zero locks.
//

import Foundation

public final class DSPCombFilter: @unchecked Sendable {
    private static let bufferSize = 4096
    private static let bufferMask = 4095

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

        let clamped = y.isFinite ? AudioMath.fastTanh(y) : 0.0
        buffer[writeIndex] = clamped
        writeIndex = (writeIndex + 1) & Self.bufferMask

        return clamped
    }
}
