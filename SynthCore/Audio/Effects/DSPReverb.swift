//
//  DSPReverb.swift
//  Freeverb-style stereo reverb. Buffers are allocated in `allocate(sampleRate:)`,
//  which the Audio Unit calls from `allocateRenderResources`. `process` only
//  reads and writes that storage.
//

import Foundation

public final class DSPReverb {
    private static let combBase = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617]
    private static let allpassBase = [556, 441, 341, 225]
    private static let spread = 23

    private var memory: UnsafeMutablePointer<Float>?
    private var memoryCount = 0
    private var allocatedRate: Double = 0

    private var combLenL = [Int](repeating: 1, count: 8)
    private var combLenR = [Int](repeating: 1, count: 8)
    private var combOffL = [Int](repeating: 0, count: 8)
    private var combOffR = [Int](repeating: 0, count: 8)
    private var combIdxL = [Int](repeating: 0, count: 8)
    private var combIdxR = [Int](repeating: 0, count: 8)
    private var combFltL = [Float](repeating: 0, count: 8)
    private var combFltR = [Float](repeating: 0, count: 8)

    private var apLenL = [Int](repeating: 1, count: 4)
    private var apLenR = [Int](repeating: 1, count: 4)
    private var apOffL = [Int](repeating: 0, count: 4)
    private var apOffR = [Int](repeating: 0, count: 4)
    private var apIdxL = [Int](repeating: 0, count: 4)
    private var apIdxR = [Int](repeating: 0, count: 4)

    public var isAllocated: Bool { memory != nil }

    deinit {
        memory?.deallocate()
    }

    /// Main thread or `allocateRenderResources`. Never call from the render callback.
    public func allocate(sampleRate: Double) {
        let rate = min(192_000, max(8_000, sampleRate))
        if memory != nil && abs(rate - allocatedRate) < 0.5 { return }
        allocatedRate = rate
        var cursor = 0
        for i in 0..<8 {
            combLenL[i] = scaled(Self.combBase[i], rate: rate)
            combOffL[i] = cursor
            cursor += combLenL[i]
            combLenR[i] = scaled(Self.combBase[i] + Self.spread, rate: rate)
            combOffR[i] = cursor
            cursor += combLenR[i]
        }
        for i in 0..<4 {
            apLenL[i] = scaled(Self.allpassBase[i], rate: rate)
            apOffL[i] = cursor
            cursor += apLenL[i]
            apLenR[i] = scaled(Self.allpassBase[i] + Self.spread, rate: rate)
            apOffR[i] = cursor
            cursor += apLenR[i]
        }
        let mem = UnsafeMutablePointer<Float>.allocate(capacity: cursor)
        mem.initialize(repeating: 0, count: cursor)
        let oldMemory = memory
        memory = mem
        memoryCount = cursor
        reset()
        oldMemory?.deallocate()
    }

    public func reset() {
        guard let memory else { return }
        for i in 0..<memoryCount { memory[i] = 0 }
        for i in 0..<8 {
            combIdxL[i] = 0
            combIdxR[i] = 0
            combFltL[i] = 0
            combFltR[i] = 0
        }
        for i in 0..<4 {
            apIdxL[i] = 0
            apIdxR[i] = 0
        }
    }

    /// Wet stereo pair. The caller applies Mix. Returns the input when storage is missing.
    public func process(inputL: Float, inputR: Float, room: Float, damp: Float) -> (Float, Float) {
        guard let memory else { return (inputL, inputR) }
        let roomClamped = min(1, max(0, room))
        let feedback = min(0.96, 0.28 + 0.68 * roomClamped)
        let damp1 = min(0.95, max(0, damp))
        let damp2 = 1 - damp1
        var input = (inputL + inputR) * 0.22
        if abs(input) < 1e-20 { input = 0 }

        var wetL: Float = 0
        var wetR: Float = 0
        for i in 0..<8 {
            wetL += comb(memory, offset: combOffL[i], length: combLenL[i], index: &combIdxL[i], filter: &combFltL[i], input: input, feedback: feedback, damp1: damp1, damp2: damp2)
            wetR += comb(memory, offset: combOffR[i], length: combLenR[i], index: &combIdxR[i], filter: &combFltR[i], input: input, feedback: feedback, damp1: damp1, damp2: damp2)
        }
        for i in 0..<4 {
            wetL = allpass(memory, offset: apOffL[i], length: apLenL[i], index: &apIdxL[i], input: wetL)
            wetR = allpass(memory, offset: apOffR[i], length: apLenR[i], index: &apIdxR[i], input: wetR)
        }
        return (wetL * 0.18, wetR * 0.18)
    }

    private func scaled(_ base: Int, rate: Double) -> Int {
        max(8, Int((Double(base) * rate / 44_100.0).rounded()))
    }

    private func comb(
        _ memory: UnsafeMutablePointer<Float>,
        offset: Int,
        length: Int,
        index: inout Int,
        filter: inout Float,
        input: Float,
        feedback: Float,
        damp1: Float,
        damp2: Float
    ) -> Float {
        let at = offset + index
        var output = memory[at]
        if abs(output) < 1e-20 { output = 0 }
        filter = output * damp2 + filter * damp1
        if abs(filter) < 1e-20 { filter = 0 }
        memory[at] = input + filter * feedback
        index += 1
        if index >= length { index = 0 }
        return output
    }

    private func allpass(
        _ memory: UnsafeMutablePointer<Float>,
        offset: Int,
        length: Int,
        index: inout Int,
        input: Float
    ) -> Float {
        let at = offset + index
        var buf = memory[at]
        if abs(buf) < 1e-20 { buf = 0 }
        let output = -input + buf
        memory[at] = input + buf * 0.5
        index += 1
        if index >= length { index = 0 }
        return output
    }
}
