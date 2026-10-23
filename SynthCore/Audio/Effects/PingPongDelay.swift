//
//  PingPongDelay.swift
//  Synt_swiftUI
//
//  Real-time stereo ping-pong delay with cross-feedback and damping filter.
//

import Foundation

public final class PingPongDelay {
    public var enabled: Bool = false
    public var delayTime: Float = 0.3 // seconds (0.001...2.0)
    public var feedback: Float = 0.4  // 0...0.95
    public var mix: Float = 0.0       // 0...1.0
    /// true = ping-pong (L/R cross feedback). false = plain stereo delay.
    public var crossFeed: Bool = true

    private var bufferL: [Float]
    private var bufferR: [Float]
    private var writeIndex: Int = 0
    private var bufferSize: Int
    private var sampleRate: Double

    // Damping one-pole lowpass filter to prevent harsh high-frequency buildup
    private var dampL: Float = 0
    private var dampR: Float = 0

    public init(sampleRate: Double = 44100.0, maxDelaySeconds: Double = 2.0) {
        let rate = max(8000.0, sampleRate)
        self.sampleRate = rate
        self.bufferSize = Int(rate * maxDelaySeconds) + 256
        self.bufferL = [Float](repeating: 0, count: self.bufferSize)
        self.bufferR = [Float](repeating: 0, count: self.bufferSize)
    }

    public func setSampleRate(_ newRate: Double) {
        let rate = max(8000.0, newRate)
        guard abs(rate - sampleRate) > 0.5 else { return }
        sampleRate = rate
        bufferSize = Int(sampleRate * 2.0) + 256
        bufferL = [Float](repeating: 0, count: bufferSize)
        bufferR = [Float](repeating: 0, count: bufferSize)
        writeIndex = 0
        dampL = 0
        dampR = 0
    }

    public func reset() {
        for i in 0..<bufferL.count {
            bufferL[i] = 0
            bufferR[i] = 0
        }
        writeIndex = 0
        dampL = 0
        dampR = 0
        isClearing = false
    }

    public private(set) var isClearing: Bool = false
    private var clearCursor: Int = 0
    public var totalCount: Int { bufferL.count }

    public func startIncrementalClear() {
        clearCursor = 0
        isClearing = !bufferL.isEmpty
    }

    public func cancelIncrementalClear() {
        isClearing = false
        clearCursor = 0
    }

    @inline(__always)
    public func clearIncremental(count: Int = 11000) {
        guard isClearing else { return }
        let total = bufferL.count
        guard total > 0, clearCursor < total else {
            isClearing = false
            return
        }
        let end = min(total, clearCursor + count)
        for i in clearCursor..<end {
            bufferL[i] = 0
            bufferR[i] = 0
        }
        clearCursor = end
        if clearCursor >= total {
            isClearing = false
            writeIndex = 0
            dampL = 0
            dampR = 0
        }
    }

    @inline(__always)
    public func process(inputL: Float, inputR: Float, mix mixOverride: Float? = nil) -> (Float, Float) {
        let effMix = mixOverride ?? self.mix
        guard enabled && effMix > 0.001 else { return (inputL, inputR) }

        let delaySamples = Double(max(0.001, min(2.0, delayTime))) * sampleRate
        let delayedL = readInterpolated(buffer: bufferL, delaySamples: delaySamples)
        let delayedR = readInterpolated(buffer: bufferR, delaySamples: delaySamples)

        // Damping lowpass at ~8 kHz
        let alpha: Float = 0.6
        dampL += alpha * (delayedL - dampL)
        dampR += alpha * (delayedR - dampR)

        let fb = max(0, min(0.95, feedback))

        // Ping-Pong cross feedback:
        // Left buffer receives inputL (and mono content) + Right delayed feedback
        // Right buffer receives cross-fed Left delayed feedback
        let monoInput = (inputL + inputR) * 0.5
        let stereoDiff = inputR - inputL

        let toL: Float
        let toR: Float
        if crossFeed {
            toL = monoInput + dampR * fb
            toR = stereoDiff * 0.5 + dampL * fb
        } else {
            toL = inputL + dampL * fb
            toR = inputR + dampR * fb
        }

        bufferL[writeIndex] = toL.isFinite ? toL : 0
        bufferR[writeIndex] = toR.isFinite ? toR : 0

        writeIndex += 1
        if writeIndex >= bufferSize {
            writeIndex = 0
        }

        let wetL = dampL
        let wetR = dampR

        let dry = 1.0 - effMix
        let outL = inputL * dry + wetL * effMix
        let outR = inputR * dry + wetR * effMix

        return (outL.isFinite ? outL : inputL, outR.isFinite ? outR : inputR)
    }

    @inline(__always)
    private func readInterpolated(buffer: [Float], delaySamples: Double) -> Float {
        var readPos = Double(writeIndex) - delaySamples
        while readPos < 0 { readPos += Double(bufferSize) }
        while readPos >= Double(bufferSize) { readPos -= Double(bufferSize) }

        let i0 = Int(readPos)
        let frac = Float(readPos - Double(i0))
        let i1 = (i0 + 1) % bufferSize

        let s0 = buffer[i0]
        let s1 = buffer[i1]
        return s0 + (s1 - s0) * frac
    }
}
