//
//  Distortion.swift
//  Synt_swiftUI
//
//  Multiple distortion types for sound design.
//  Stage 4: auto gain compensation + anti-pop reset on enable toggle.
//

import Foundation

enum DistortionType: String, CaseIterable, Codable {
    case softClip = "Soft Clip"
    case hardClip = "Hard Clip"
    case tubeSaturation = "Tube"
    case tapeSaturation = "Tape"
    case bitcrusher = "Bitcrush"
    case wavefolder = "Wavefold"
}

final class Distortion {

    var type: DistortionType = .softClip
    var drive: Float = 0.5      // 0.0 to 1.0
    var tone: Float = 0.5       // 0.0 (dark) to 1.0 (bright)
    var mix: Float = 0.5        // Dry/Wet

    /// When toggled, internal filter/hold state is cleared to avoid clicks (DC / pops).
    var enabled: Bool = false {
        didSet {
            if enabled != oldValue {
                reset()
            }
        }
    }

    private var lowpassState: Float = 0.0
    private var highpassState: Float = 0.0
    private var holdSample: Float = 0.0
    private var holdCounter: Int = 0

    init() {}

    @inline(__always)
    func process(_ input: Float) -> Float {
        guard enabled && mix > 0.001 else { return input }

        var processed: Float

        switch type {
        case .softClip:
            processed = processSoftClip(input)
        case .hardClip:
            processed = processHardClip(input)
        case .tubeSaturation:
            processed = processTube(input)
        case .tapeSaturation:
            processed = processTape(input)
        case .bitcrusher:
            processed = processBitcrush(input)
        case .wavefolder:
            processed = processWavefold(input)
        }

        // Auto gain compensation — keep wet loudness roughly stable vs drive
        processed *= autoGainCompensation()

        processed = applyTone(processed)

        return input * (1.0 - mix) + processed * mix
    }

    @inline(__always)
    func processStereo(inputL: Float, inputR: Float) -> (Float, Float) {
        // Mono algorithms; independent tone state would need dual filters —
        // process mid-side-ish by sequential mono (tone state shared is acceptable for now).
        return (process(inputL), process(inputR))
    }

    // MARK: - Gain compensation

    /// Approximate inverse of drive boost so wet peak stays near dry for unit inputs.
    @inline(__always)
    func autoGainCompensation() -> Float {
        let d = max(0, min(1, drive))
        switch type {
        case .softClip:
            let g = 1.0 + d * 10.0
            return 1.0 / max(1.0, 0.65 * sqrt(g) + 0.35)
        case .hardClip:
            // Hard clip can jump to ±threshold after large drive — tame by drive only.
            return 1.0 / (1.0 + d * 4.0)
        case .tubeSaturation:
            return 1.0 / (1.0 + d * 3.5)
        case .tapeSaturation:
            return 1.0 / (1.0 + d * 2.5)
        case .bitcrusher:
            return 1.0
        case .wavefolder:
            return 1.0 / (1.0 + d * 3.0)
        }
    }

    // MARK: - Distortion Algorithms

    @inline(__always)
    private func processSoftClip(_ input: Float) -> Float {
        let gain = 1.0 + drive * 10.0
        return tanh(input * gain)
    }

    @inline(__always)
    private func processHardClip(_ input: Float) -> Float {
        let gain = 1.0 + drive * 15.0
        let threshold = max(0.05, 1.0 - drive * 0.7)
        let driven = input * gain
        return max(-threshold, min(threshold, driven))
    }

    @inline(__always)
    private func processTube(_ input: Float) -> Float {
        let gain = 1.0 + drive * 8.0
        let driven = input * gain
        if driven >= 0 {
            return 1.0 - exp(-driven)
        } else {
            return -tanh(-driven * 1.2)
        }
    }

    @inline(__always)
    private func processTape(_ input: Float) -> Float {
        let gain = 1.0 + drive * 5.0
        var driven = input * gain
        let x = driven
        if abs(x) < 0.333 {
            driven = 2.0 * x
        } else if abs(x) < 0.667 {
            let sign: Float = x >= 0 ? 1.0 : -1.0
            let absX = abs(x)
            driven = sign * (3.0 - pow(2.0 - 3.0 * absX, 2.0)) / 3.0
        } else {
            driven = x >= 0 ? 1.0 : -1.0
        }
        return driven
    }

    @inline(__always)
    private func processBitcrush(_ input: Float) -> Float {
        let bits = max(2, Int(16.0 - drive * 12.0))
        let levels = Float(1 << bits)
        let quantized = floor(input * levels + 0.5) / levels

        let holdLength = max(1, Int(1.0 + drive * 31.0))
        holdCounter += 1
        if holdCounter >= holdLength {
            holdCounter = 0
            holdSample = quantized
        }
        return holdSample
    }

    @inline(__always)
    private func processWavefold(_ input: Float) -> Float {
        let gain = 1.0 + drive * 8.0
        var value = input * gain
        let folds = Int(1.0 + drive * 4.0)
        for _ in 0..<folds {
            if value > 1.0 {
                value = 2.0 - value
            } else if value < -1.0 {
                value = -2.0 - value
            }
        }
        while abs(value) > 1.0 {
            if value > 1.0 {
                value = 2.0 - value
            } else if value < -1.0 {
                value = -2.0 - value
            }
        }
        return value
    }

    // MARK: - Tone

    @inline(__always)
    private func applyTone(_ input: Float) -> Float {
        if tone < 0.5 {
            let cutoff = 0.1 + tone * 1.8
            lowpassState = lowpassState + cutoff * (input - lowpassState)
            return lowpassState
        } else if tone > 0.5 {
            let amount = (tone - 0.5) * 2.0
            let cutoff: Float = 0.05
            highpassState = highpassState + cutoff * (input - highpassState)
            let highpassed = input - highpassState
            return input + highpassed * amount * 2.0
        }
        return input
    }

    func reset() {
        lowpassState = 0.0
        highpassState = 0.0
        holdSample = 0.0
        holdCounter = 0
    }
}
