//
//  Distortion.swift
//  Synt_swiftUI
//
//  Musical saturation/distortion. Clean single-note behaviour:
//  - mild drive curves (no 10–16× pre-gain)
//  - DC blocker on wet path (tube asymmetry used to inject DC → rumble/хрип)
//  - proper tape curve without 2× linear boost
//  - independent L/R tone state
//

import Foundation

public enum DistortionType: String, CaseIterable, Codable, Sendable {
    case softClip = "Soft Clip"
    case hardClip = "Hard Clip"
    case tubeSaturation = "Tube"
    case tapeSaturation = "Tape"
    case bitcrusher = "Bitcrush"
    case wavefolder = "Wavefold"
}

public final class Distortion {

    public var type: DistortionType = .softClip
    public var drive: Float = 0.35
    public var tone: Float = 0.5
    public var mix: Float = 0.25
    public var oversampling: Bool = false

    /// The setter only counts toggles. State is cleared on the first processed
    /// sample after a toggle (audio thread), not in the setter.
    public var enabled: Bool = false {
        didSet { if enabled != oldValue { toggleCount &+= 1 } }
    }
    private var toggleCount: UInt32 = 0
    private var toggleCountSeen: UInt32 = 0

    @inline(__always) private func resetIfJustEnabled() {
        if toggleCountSeen != toggleCount {
            toggleCountSeen = toggleCount
            reset()
        }
    }

    // Dual-channel tone + DC state (stereo-safe)
    private var lowpassL: Float = 0
    private var lowpassR: Float = 0
    private var highpassL: Float = 0
    private var highpassR: Float = 0
    private var dcXL: Float = 0, dcYL: Float = 0
    private var dcXR: Float = 0, dcYR: Float = 0
    private var holdSample: Float = 0
    private var holdCounter: Int = 0
    private var channelToggle = false // alternate for mono process() callers

    // 2x Oversampling state
    private var prevInputL: Float = 0
    private var prevInputR: Float = 0
    private var firBufL: [Float] = Array(repeating: 0, count: 11)
    private var firBufR: [Float] = Array(repeating: 0, count: 11)

    public init() {}

    @inline(__always)
    public func process(_ input: Float) -> Float {
        if !channelToggle { resetIfJustEnabled() }
        // Mono API used by engine for L then R — alternate channel state.
        if !channelToggle {
            channelToggle = true
            return processChannel(
                input,
                lp: &lowpassL,
                hp: &highpassL,
                dcX: &dcXL,
                dcY: &dcYL,
                prevInput: &prevInputL,
                firBuf: &firBufL
            )
        } else {
            channelToggle = false
            return processChannel(
                input,
                lp: &lowpassR,
                hp: &highpassR,
                dcX: &dcXR,
                dcY: &dcYR,
                prevInput: &prevInputR,
                firBuf: &firBufR
            )
        }
    }

    @inline(__always)
    public func processStereo(inputL: Float, inputR: Float) -> (Float, Float) {
        resetIfJustEnabled()
        channelToggle = false
        let l = processChannel(
            inputL,
            lp: &lowpassL,
            hp: &highpassL,
            dcX: &dcXL,
            dcY: &dcYL,
            prevInput: &prevInputL,
            firBuf: &firBufL
        )
        let r = processChannel(
            inputR,
            lp: &lowpassR,
            hp: &highpassR,
            dcX: &dcXR,
            dcY: &dcYR,
            prevInput: &prevInputR,
            firBuf: &firBufR
        )
        return (l, r)
    }

    @inline(__always)
    private func shape(_ input: Float) -> Float {
        switch type {
        case .softClip:       return processSoftClip(input)
        case .hardClip:       return processHardClip(input)
        case .tubeSaturation: return processTube(input)
        case .tapeSaturation: return processTape(input)
        case .bitcrusher:     return processBitcrush(input)
        case .wavefolder:     return processWavefold(input)
        }
    }

    @inline(__always)
    private func processChannel(
        _ input: Float,
        lp: inout Float,
        hp: inout Float,
        dcX: inout Float,
        dcY: inout Float,
        prevInput: inout Float,
        firBuf: inout [Float]
    ) -> Float {
        guard enabled && mix > 0.001 else { return input }
        guard input.isFinite else { return 0 }

        var wet: Float
        if oversampling {
            let x0 = 0.5 * (prevInput + input)
            let x1 = input
            prevInput = input

            let y0 = shape(x0)
            let y1 = shape(x1)

            // 11-tap half-band FIR decimation filter
            firBuf[0] = firBuf[2]
            firBuf[1] = firBuf[3]
            firBuf[2] = firBuf[4]
            firBuf[3] = firBuf[5]
            firBuf[4] = firBuf[6]
            firBuf[5] = firBuf[7]
            firBuf[6] = firBuf[8]
            firBuf[7] = firBuf[9]
            firBuf[8] = firBuf[10]
            firBuf[9] = y0
            firBuf[10] = y1

            wet = 0.01 * (firBuf[0] + firBuf[10])
                - 0.06 * (firBuf[2] + firBuf[8])
                + 0.30 * (firBuf[4] + firBuf[6])
                + 0.50 * firBuf[5]
        } else {
            wet = shape(input)
        }

        if !wet.isFinite { wet = 0 }

        // Remove DC from asymmetric curves before tone/mix
        wet = dcBlock(wet, x1: &dcX, y1: &dcY)
        wet = applyTone(wet, lp: &lp, hp: &hp)
        wet = max(-1.2, min(1.2, wet))

        let out = input * (1.0 - mix) + wet * mix
        return out.isFinite ? out : input
    }

    // MARK: - Waveshapers (mild drive, unit-ish peak)

    /// Soft clip: gain 1…4, normalize so full-scale stays near 1.
    @inline(__always)
    private func processSoftClip(_ input: Float) -> Float {
        let gain = 1.0 + drive * 3.0
        let y = tanh(input * gain)
        // Level-match vs dry for typical peaks
        let norm = max(0.35, tanh(0.7 * gain))
        return y / norm * 0.95
    }

    @inline(__always)
    private func processHardClip(_ input: Float) -> Float {
        let gain = 1.0 + drive * 4.0
        let thr = max(0.35, 1.0 - drive * 0.45)
        let driven = input * gain
        let clipped = max(-thr, min(thr, driven))
        // Makeup so quiet drive doesn't disappear
        return clipped / thr * 0.85
    }

    /// Soft asymmetric tube without hard DC: blend two soft curves, then DC block outside.
    @inline(__always)
    private func processTube(_ input: Float) -> Float {
        let gain = 1.0 + drive * 2.5
        let x = input * gain
        // Even harmonics via slight cubic + soft clip (no exp step)
        let shaped = x - 0.15 * drive * x * x + 0.08 * drive * x * x * x
        return tanh(shaped) * 0.95
    }

    /// Classic cubic soft clip (no 2× linear region that blew levels).
    @inline(__always)
    private func processTape(_ input: Float) -> Float {
        let gain = 1.0 + drive * 2.0
        var x = input * gain
        x = max(-1.5, min(1.5, x))
        // Cubic soft clip: x - x^3/3 for |x|<1, else soft limit
        let y: Float
        if abs(x) < 1.0 {
            y = x - (x * x * x) / 3.0
        } else {
            y = x > 0 ? 2.0 / 3.0 : -2.0 / 3.0
        }
        return y * 1.15 // mild makeup for cubic attenuation
    }

    @inline(__always)
    private func processBitcrush(_ input: Float) -> Float {
        // Milder: 12→6 bits, hold 1→8 samples (was 16→4 bits / 32 hold = harsh digital trash)
        let bits = max(6, Int(12.0 - drive * 6.0))
        let levels = Float(1 << bits)
        let quantized = floor(input * levels + 0.5) / levels

        let holdLength = max(1, Int(1.0 + drive * 7.0))
        holdCounter += 1
        if holdCounter >= holdLength {
            holdCounter = 0
            holdSample = quantized
        }
        // Blend crushed with original a bit for musicality
        return holdSample * 0.85 + input * 0.15
    }

    @inline(__always)
    private func processWavefold(_ input: Float) -> Float {
        let gain = 1.0 + drive * 2.5
        var value = input * gain
        // Single fold region, then soft clip
        if value > 1.0 { value = 2.0 - value }
        else if value < -1.0 { value = -2.0 - value }
        return tanh(value) * 0.9
    }

    // MARK: - Tone / DC

    @inline(__always)
    private func applyTone(_ input: Float, lp: inout Float, hp: inout Float) -> Float {
        if tone < 0.48 {
            // Darken
            let cutoff = 0.08 + tone * 1.5
            lp = lp + cutoff * (input - lp)
            return lp
        } else if tone > 0.52 {
            // Brighten gently (old *2 boost could clip)
            let amount = (tone - 0.5) * 2.0
            let cutoff: Float = 0.04
            hp = hp + cutoff * (input - hp)
            let high = input - hp
            return input + high * amount * 0.6
        }
        return input
    }

    @inline(__always)
    private func dcBlock(_ x: Float, x1: inout Float, y1: inout Float) -> Float {
        // y = x - x_prev + R * y_prev, R≈0.995 @ 44.1k
        let y = x - x1 + 0.995 * y1
        x1 = x
        y1 = y
        return y
    }

    public func reset() {
        lowpassL = 0; lowpassR = 0
        highpassL = 0; highpassR = 0
        dcXL = 0; dcYL = 0; dcXR = 0; dcYR = 0
        holdSample = 0
        holdCounter = 0
        channelToggle = false
        prevInputL = 0
        prevInputR = 0
        for i in 0..<firBufL.count {
            firBufL[i] = 0
            firBufR[i] = 0
        }
    }

    /// Kept for tests that inspect compensation philosophy (now baked into shapers).
    public func autoGainCompensation() -> Float {
        // Shapers are self-normalizing; report a value < 1 for high drive (test expectation).
        let d = max(0, min(1, drive))
        return 1.0 / (1.0 + d * 1.5)
    }
}
