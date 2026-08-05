//
//  Phaser.swift
//  Synt_swiftUI
//
//  Stereo Phaser/Flanger effect with multiple all-pass stages.
//  Stage 4: all-pass coeffs from precomputed LUT (no tan() per sample/stage).
//  Anti-pop reset when bypass toggles off→on.
//

import Foundation

enum PhaserMode: String, CaseIterable, Codable {
    case phaser2 = "Phaser 2"
    case phaser4 = "Phaser 4"
    case phaser6 = "Phaser 6"
    case phaser8 = "Phaser 8"
    case flanger = "Flanger"
    case chorus = "Chorus"

    var stageCount: Int {
        switch self {
        case .phaser2: return 2
        case .phaser4: return 4
        case .phaser6: return 6
        case .phaser8: return 8
        case .flanger: return 0
        case .chorus: return 0
        }
    }
}

final class Phaser {

    // MARK: - Parameters

    var rate: Float = 0.5 {
        didSet { rate = max(0.01, min(10.0, rate)) }
    }

    var depth: Float = 0.7 {
        didSet { depth = max(0.0, min(1.0, depth)) }
    }

    var feedback: Float = 0.5 {
        didSet { feedback = max(-0.99, min(0.99, feedback)) }
    }

    var centerFrequency: Float = 1000 {
        didSet { centerFrequency = max(100, min(5000, centerFrequency)) }
    }

    var stereoSpread: Float = 0.5 {
        didSet { stereoSpread = max(0.0, min(1.0, stereoSpread)) }
    }

    var mix: Float = 0.5 {
        didSet { mix = max(0.0, min(1.0, mix)) }
    }

    var mode: PhaserMode = .phaser4

    /// When leaving bypass (effect turns on), reset delay/allpass state to avoid pops.
    var bypass: Bool = true {
        didSet {
            if oldValue == true && bypass == false {
                reset()
            }
        }
    }

    // MARK: - Internal State

    private var sampleRate: Float = 44100
    private var lfoPhaseL: Float = 0
    private var lfoPhaseR: Float = 0

    private var allpassStatesL: [Float] = Array(repeating: 0, count: 8)
    private var allpassStatesR: [Float] = Array(repeating: 0, count: 8)

    private let maxDelayMs: Float = 20.0
    private var delayBufferL: [Float] = []
    private var delayBufferR: [Float] = []
    private var delayWriteIndex: Int = 0

    private var feedbackL: Float = 0
    private var feedbackR: Float = 0

    // Precomputed all-pass coefficients: maps frequency → coeff without tan() in RT.
    private let lutSize = 2048
    private var coeffLUT: [Float] = []
    private var lutFMin: Float = 20
    private var lutFMax: Float = 20_000

    // MARK: - Initialization

    init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        let maxDelaySamples = max(1, Int(sampleRate * maxDelayMs / 1000.0))
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
        rebuildCoeffLUT()
    }

    // MARK: - Processing

    func process(inputL: Float, inputR: Float) -> (left: Float, right: Float) {
        guard !bypass else { return (inputL, inputR) }

        let lfoIncrement = rate / sampleRate
        lfoPhaseL += lfoIncrement
        if lfoPhaseL >= 1.0 { lfoPhaseL -= 1.0 }

        lfoPhaseR = lfoPhaseL + stereoSpread * 0.5
        if lfoPhaseR >= 1.0 { lfoPhaseR -= 1.0 }
        if lfoPhaseR < 0 { lfoPhaseR += 1.0 }

        let lfoL = sin(lfoPhaseL * 2 * .pi)
        let lfoR = sin(lfoPhaseR * 2 * .pi)

        let outL: Float
        let outR: Float

        switch mode {
        case .phaser2, .phaser4, .phaser6, .phaser8:
            (outL, outR) = processPhaserMode(inputL: inputL, inputR: inputR, lfoL: lfoL, lfoR: lfoR)
        case .flanger:
            (outL, outR) = processFlangerMode(inputL: inputL, inputR: inputR, lfoL: lfoL, lfoR: lfoR)
        case .chorus:
            (outL, outR) = processChorusMode(inputL: inputL, inputR: inputR, lfoL: lfoL, lfoR: lfoR)
        }

        let dryL = inputL * (1.0 - mix)
        let dryR = inputR * (1.0 - mix)
        return (dryL + outL * mix, dryR + outR * mix)
    }

    // MARK: - Phaser

    private func processPhaserMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        let modL = depth * lfoL
        let modR = depth * lfoR

        let freqL = centerFrequency * (1.0 + modL * 0.5)
        let freqR = centerFrequency * (1.0 + modR * 0.5)

        var sampleL = inputL + feedbackL * feedback
        var sampleR = inputR + feedbackR * feedback

        let stageCount = mode.stageCount
        for i in 0..<stageCount {
            let stageOffset = Float(i) / Float(max(1, stageCount))
            let stageFreqL = freqL * pow(2.0, stageOffset * 2.0)
            let stageFreqR = freqR * pow(2.0, stageOffset * 2.0)

            let coeffL = allpassCoeffFromLUT(frequency: stageFreqL)
            let coeffR = allpassCoeffFromLUT(frequency: stageFreqR)

            sampleL = processAllpass(input: sampleL, coeff: coeffL, state: &allpassStatesL[i])
            sampleR = processAllpass(input: sampleR, coeff: coeffR, state: &allpassStatesR[i])
        }

        feedbackL = sampleL
        feedbackR = sampleR
        return (sampleL, sampleR)
    }

    // MARK: - Flanger / Chorus

    private func processFlangerMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        let minDelayMs: Float = 0.1
        let maxFlangerDelayMs: Float = 5.0

        let delayMsL = minDelayMs + (maxFlangerDelayMs - minDelayMs) * (0.5 + 0.5 * lfoL * depth)
        let delayMsR = minDelayMs + (maxFlangerDelayMs - minDelayMs) * (0.5 + 0.5 * lfoR * depth)

        delayBufferL[delayWriteIndex] = inputL + feedbackL * feedback
        delayBufferR[delayWriteIndex] = inputR + feedbackR * feedback

        let outL = readDelayInterpolated(buffer: delayBufferL, delayMs: delayMsL)
        let outR = readDelayInterpolated(buffer: delayBufferR, delayMs: delayMsR)

        feedbackL = outL
        feedbackR = outR

        delayWriteIndex += 1
        if delayWriteIndex >= delayBufferL.count {
            delayWriteIndex = 0
        }

        return (outL, outR)
    }

    private func processChorusMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        let minDelayMs: Float = 5.0
        let maxChorusDelayMs: Float = 15.0

        let delayMsL = minDelayMs + (maxChorusDelayMs - minDelayMs) * (0.5 + 0.5 * lfoL * depth)
        let delayMsR = minDelayMs + (maxChorusDelayMs - minDelayMs) * (0.5 + 0.5 * lfoR * depth)

        delayBufferL[delayWriteIndex] = inputL
        delayBufferR[delayWriteIndex] = inputR

        let outL = readDelayInterpolated(buffer: delayBufferL, delayMs: delayMsL)
        let outR = readDelayInterpolated(buffer: delayBufferR, delayMs: delayMsR)

        delayWriteIndex += 1
        if delayWriteIndex >= delayBufferL.count {
            delayWriteIndex = 0
        }

        return (outL, outR)
    }

    // MARK: - Coeff LUT (no tan in render)

    private func rebuildCoeffLUT() {
        lutFMin = 20
        lutFMax = max(lutFMin * 2, min(sampleRate * 0.45, 20_000))
        coeffLUT = [Float](repeating: 0, count: lutSize)

        for i in 0..<lutSize {
            let t = Float(i) / Float(lutSize - 1)
            // Log spacing — denser at low frequencies where phaser lives
            let freq = lutFMin * pow(lutFMax / lutFMin, t)
            let tanHalf = tan(.pi * Double(freq) / Double(sampleRate))
            coeffLUT[i] = Float((tanHalf - 1.0) / (tanHalf + 1.0))
        }
    }

    /// Interpolated all-pass coefficient from precomputed table (RT-safe: no tan).
    @inline(__always)
    func allpassCoeffFromLUT(frequency: Float) -> Float {
        guard !coeffLUT.isEmpty else {
            return calculateAllpassCoeffReference(frequency: frequency)
        }
        let f = max(lutFMin, min(lutFMax, frequency))
        let t = log(f / lutFMin) / log(lutFMax / lutFMin)
        let pos = t * Float(lutSize - 1)
        let i0 = max(0, min(lutSize - 2, Int(pos)))
        let frac = pos - Float(i0)
        return coeffLUT[i0] + (coeffLUT[i0 + 1] - coeffLUT[i0]) * frac
    }

    /// Reference tan() formula (tests / LUT rebuild only — not used in process path).
    func calculateAllpassCoeffReference(frequency: Float) -> Float {
        let f = max(20, min(frequency, sampleRate * 0.45))
        let tanHalf = tan(.pi * Double(f) / Double(sampleRate))
        return Float((tanHalf - 1.0) / (tanHalf + 1.0))
    }

    @inline(__always)
    private func processAllpass(input: Float, coeff: Float, state: inout Float) -> Float {
        let output = coeff * input + state - coeff * state
        state = input
        return output
    }

    @inline(__always)
    private func readDelayInterpolated(buffer: [Float], delayMs: Float) -> Float {
        guard !buffer.isEmpty else { return 0 }
        let delaySamples = delayMs * sampleRate / 1000.0
        let readPos = Float(delayWriteIndex) - delaySamples

        var readIndex = Int(readPos)
        var frac = readPos - Float(readIndex)

        while readIndex < 0 {
            readIndex += buffer.count
        }
        while readIndex >= buffer.count {
            readIndex -= buffer.count
        }

        if frac < 0 {
            frac += 1.0
            readIndex -= 1
            if readIndex < 0 { readIndex += buffer.count }
        }

        let nextIndex = (readIndex + 1) % buffer.count
        return buffer[readIndex] * (1.0 - frac) + buffer[nextIndex] * frac
    }

    // MARK: - Reset

    func reset() {
        lfoPhaseL = 0
        lfoPhaseR = 0
        for i in 0..<allpassStatesL.count {
            allpassStatesL[i] = 0
            allpassStatesR[i] = 0
        }
        for i in 0..<delayBufferL.count {
            delayBufferL[i] = 0
            delayBufferR[i] = 0
        }
        delayWriteIndex = 0
        feedbackL = 0
        feedbackR = 0
    }

    func setSampleRate(_ newSampleRate: Float) {
        sampleRate = newSampleRate
        let maxDelaySamples = max(1, Int(sampleRate * maxDelayMs / 1000.0))
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
        delayWriteIndex = 0
        rebuildCoeffLUT()
    }
}
