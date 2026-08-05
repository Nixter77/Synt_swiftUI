//
//  Phaser.swift
//  Synt_swiftUI
//
//  Stereo Phaser/Flanger with multi-stage all-pass.
//  Fix: proper 1st-order allpass (x[n-1] + y[n-1] state), limited feedback,
//  finite guards so a bad sample cannot silence the whole engine.
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

    var rate: Float = 0.4 {
        didSet { rate = max(0.01, min(8.0, rate)) }
    }

    var depth: Float = 0.55 {
        didSet { depth = max(0.0, min(1.0, depth)) }
    }

    /// Keep default modest — high feedback + bad allpass previously blew up to Inf.
    var feedback: Float = 0.25 {
        didSet { feedback = max(-0.85, min(0.85, feedback)) }
    }

    var centerFrequency: Float = 800 {
        didSet { centerFrequency = max(80, min(4000, centerFrequency)) }
    }

    var stereoSpread: Float = 0.5 {
        didSet { stereoSpread = max(0.0, min(1.0, stereoSpread)) }
    }

    var mix: Float = 0.45 {
        didSet { mix = max(0.0, min(1.0, mix)) }
    }

    var mode: PhaserMode = .phaser4

    /// Leaving bypass resets state (anti-pop).
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

    // True 1st-order allpass needs previous input AND previous output per stage.
    private var apXL: [Float] = Array(repeating: 0, count: 8)
    private var apYL: [Float] = Array(repeating: 0, count: 8)
    private var apXR: [Float] = Array(repeating: 0, count: 8)
    private var apYR: [Float] = Array(repeating: 0, count: 8)

    private let maxDelayMs: Float = 20.0
    private var delayBufferL: [Float] = []
    private var delayBufferR: [Float] = []
    private var delayWriteIndex: Int = 0

    private var feedbackL: Float = 0
    private var feedbackR: Float = 0

    private let lutSize = 1024
    private var coeffLUT: [Float] = []
    private var lutFMin: Float = 40
    private var lutFMax: Float = 8_000

    // MARK: - Init

    init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        let maxDelaySamples = max(1, Int(sampleRate * maxDelayMs / 1000.0))
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
        rebuildCoeffLUT()
    }

    // MARK: - Process

    func process(inputL: Float, inputR: Float) -> (left: Float, right: Float) {
        guard !bypass else { return (inputL, inputR) }

        // Guard poison on input (recover if upstream ever sends NaN)
        let inL = finiteOrZero(inputL)
        let inR = finiteOrZero(inputR)

        let lfoInc = rate / max(1, sampleRate)
        lfoPhaseL += lfoInc
        if lfoPhaseL >= 1 { lfoPhaseL -= 1 }
        if lfoPhaseL < 0 { lfoPhaseL += 1 }

        var phaseR = lfoPhaseL + stereoSpread * 0.5
        if phaseR >= 1 { phaseR -= 1 }
        if phaseR < 0 { phaseR += 1 }

        let lfoL = sin(lfoPhaseL * 2 * Float.pi)
        let lfoR = sin(phaseR * 2 * Float.pi)

        let wetL: Float
        let wetR: Float

        switch mode {
        case .phaser2, .phaser4, .phaser6, .phaser8:
            (wetL, wetR) = processPhaserMode(inputL: inL, inputR: inR, lfoL: lfoL, lfoR: lfoR)
        case .flanger:
            (wetL, wetR) = processFlangerMode(inputL: inL, inputR: inR, lfoL: lfoL, lfoR: lfoR)
        case .chorus:
            (wetL, wetR) = processChorusMode(inputL: inL, inputR: inR, lfoL: lfoL, lfoR: lfoR)
        }

        let m = mix
        var outL = inL * (1 - m) + wetL * m
        var outR = inR * (1 - m) + wetR * m

        // Hard safety: never pass non-finite / extreme peaks into the rest of the synth
        outL = clampSample(outL)
        outR = clampSample(outR)
        if !outL.isFinite || !outR.isFinite {
            reset()
            return (inL, inR)
        }
        return (outL, outR)
    }

    // MARK: - Phaser stages

    private func processPhaserMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        // Limit feedback state before injection
        let fb = feedback
        var sampleL = inputL + clampFeedback(feedbackL) * fb
        var sampleR = inputR + clampFeedback(feedbackR) * fb
        sampleL = clampSample(sampleL)
        sampleR = clampSample(sampleR)

        // Modulate base frequency gently (0.5x … 1.5x of center)
        let baseL = centerFrequency * (1.0 + 0.5 * depth * lfoL)
        let baseR = centerFrequency * (1.0 + 0.5 * depth * lfoR)

        let stages = mode.stageCount
        for i in 0..<stages {
            // Spread stages over ~2 octaves (was *2 → too high → bad coeffs)
            let t = Float(i) / Float(max(1, stages - 1))
            let stageFreqL = clampFreq(baseL * pow(2.0, t * 1.5))
            let stageFreqR = clampFreq(baseR * pow(2.0, t * 1.5))

            let aL = allpassCoeffFromLUT(frequency: stageFreqL)
            let aR = allpassCoeffFromLUT(frequency: stageFreqR)

            sampleL = processAllpass(sampleL, coeff: aL, x1: &apXL[i], y1: &apYL[i])
            sampleR = processAllpass(sampleR, coeff: aR, x1: &apXR[i], y1: &apYR[i])
        }

        feedbackL = clampFeedback(sampleL)
        feedbackR = clampFeedback(sampleR)
        return (sampleL, sampleR)
    }

    // MARK: - Flanger / Chorus

    private func processFlangerMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        guard !delayBufferL.isEmpty else { return (inputL, inputR) }

        let minD: Float = 0.2
        let maxD: Float = 4.0
        let dL = minD + (maxD - minD) * (0.5 + 0.5 * lfoL * depth)
        let dR = minD + (maxD - minD) * (0.5 + 0.5 * lfoR * depth)

        let fb = clampFeedback(feedbackL) * feedback * 0.7
        delayBufferL[delayWriteIndex] = clampSample(inputL + fb)
        delayBufferR[delayWriteIndex] = clampSample(inputR + clampFeedback(feedbackR) * feedback * 0.7)

        let outL = readDelayInterpolated(buffer: delayBufferL, delayMs: dL)
        let outR = readDelayInterpolated(buffer: delayBufferR, delayMs: dR)

        feedbackL = clampFeedback(outL)
        feedbackR = clampFeedback(outR)
        advanceDelayWrite()
        return (outL, outR)
    }

    private func processChorusMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        guard !delayBufferL.isEmpty else { return (inputL, inputR) }

        let minD: Float = 5.0
        let maxD: Float = 14.0
        let dL = minD + (maxD - minD) * (0.5 + 0.5 * lfoL * depth)
        let dR = minD + (maxD - minD) * (0.5 + 0.5 * lfoR * depth)

        delayBufferL[delayWriteIndex] = inputL
        delayBufferR[delayWriteIndex] = inputR

        let outL = readDelayInterpolated(buffer: delayBufferL, delayMs: dL)
        let outR = readDelayInterpolated(buffer: delayBufferR, delayMs: dR)
        advanceDelayWrite()
        return (outL, outR)
    }

    private func advanceDelayWrite() {
        delayWriteIndex += 1
        if delayWriteIndex >= delayBufferL.count {
            delayWriteIndex = 0
        }
    }

    // MARK: - Allpass (correct difference equation)

    /// y[n] = a*x[n] + x[n-1] - a*y[n-1]
    @inline(__always)
    private func processAllpass(
        _ x: Float,
        coeff a: Float,
        x1: inout Float,
        y1: inout Float
    ) -> Float {
        // Clamp coeff to open unit interval for stability
        let aC = max(-0.99, min(0.99, a))
        let y = aC * x + x1 - aC * y1
        x1 = x
        y1 = finiteOrZero(y)
        return y1
    }

    // MARK: - Coeff LUT

    private func rebuildCoeffLUT() {
        lutFMin = 40
        // Stay well below Nyquist so tan(π f/sr) stays finite and well-conditioned
        lutFMax = max(lutFMin * 2, min(sampleRate * 0.35, 10_000))
        coeffLUT = [Float](repeating: 0, count: lutSize)

        for i in 0..<lutSize {
            let t = Float(i) / Float(max(1, lutSize - 1))
            let freq = lutFMin * pow(lutFMax / lutFMin, t)
            coeffLUT[i] = calculateAllpassCoeffReference(frequency: freq)
        }
    }

    @inline(__always)
    func allpassCoeffFromLUT(frequency: Float) -> Float {
        guard coeffLUT.count >= 2 else {
            return calculateAllpassCoeffReference(frequency: frequency)
        }
        let f = clampFreq(frequency)
        let denom = log(lutFMax / lutFMin)
        guard denom > 0.0001 else {
            return calculateAllpassCoeffReference(frequency: f)
        }
        let t = log(max(f, lutFMin) / lutFMin) / denom
        let pos = max(0, min(1, t)) * Float(lutSize - 1)
        let i0 = max(0, min(lutSize - 2, Int(pos)))
        let frac = pos - Float(i0)
        let c = coeffLUT[i0] + (coeffLUT[i0 + 1] - coeffLUT[i0]) * frac
        return max(-0.99, min(0.99, c))
    }

    func calculateAllpassCoeffReference(frequency: Float) -> Float {
        let f = clampFreq(frequency)
        let arg = Double.pi * Double(f) / Double(sampleRate)
        // Keep argument safely below π/2
        let safeArg = min(arg, Double.pi * 0.49)
        let th = tan(safeArg)
        let c = Float((th - 1.0) / (th + 1.0))
        return max(-0.99, min(0.99, c))
    }

    // MARK: - Delay read

    @inline(__always)
    private func readDelayInterpolated(buffer: [Float], delayMs: Float) -> Float {
        let n = buffer.count
        guard n > 1 else { return 0 }

        let delaySamples = max(1, min(Float(n - 1), delayMs * sampleRate / 1000.0))
        var readPos = Float(delayWriteIndex) - delaySamples
        while readPos < 0 { readPos += Float(n) }

        var i0 = Int(readPos) % n
        if i0 < 0 { i0 += n }
        let frac = readPos - floor(readPos)
        let i1 = (i0 + 1) % n
        return buffer[i0] * (1 - frac) + buffer[i1] * frac
    }

    // MARK: - Safety helpers

    @inline(__always)
    private func finiteOrZero(_ x: Float) -> Float {
        x.isFinite ? x : 0
    }

    @inline(__always)
    private func clampSample(_ x: Float) -> Float {
        guard x.isFinite else { return 0 }
        return max(-2, min(2, x))
    }

    @inline(__always)
    private func clampFeedback(_ x: Float) -> Float {
        guard x.isFinite else { return 0 }
        return max(-0.95, min(0.95, x))
    }

    @inline(__always)
    private func clampFreq(_ f: Float) -> Float {
        max(lutFMin, min(lutFMax, f))
    }

    // MARK: - Reset

    func reset() {
        lfoPhaseL = 0
        for i in 0..<8 {
            apXL[i] = 0; apYL[i] = 0
            apXR[i] = 0; apYR[i] = 0
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
        sampleRate = max(8000, newSampleRate)
        let maxDelaySamples = max(1, Int(sampleRate * maxDelayMs / 1000.0))
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
        delayWriteIndex = 0
        rebuildCoeffLUT()
        reset()
    }
}
