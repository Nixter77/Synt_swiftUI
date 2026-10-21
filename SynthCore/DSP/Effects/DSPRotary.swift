//
//  DSPRotary.swift
//  SynthCore
//
//  Optional Leslie-style rotor. Off in the engine skips this entirely, so the
//  insert chain stays bit-exact. The delay buffer and sine table are built
//  once; process does not allocate and does not call exp or pow.
//

import Foundation

public final class DSPRotary {
    private static let tableSize = 1024
    private static let tableMask = 1023
    private static let sine: [Float] = {
        (0..<tableSize).map { i in
            Float(sin(2 * Double.pi * Double(i) / Double(tableSize)))
        }
    }()

    private static let bufferSize = 4096

    private var bufferL: [Float]
    private var bufferR: [Float]
    private var writeIndex = 0
    private var sampleRate: Float = 44_100
    private var lpCoeff: Float = 0.1
    private var low: Float = 0
    private var hornPhase: Float = 0
    private var drumPhase: Float = 0.2
    private var hornHz: Float = 0
    private var drumHz: Float = 0

    public init(sampleRate: Double = 44_100) {
        bufferL = [Float](repeating: 0, count: Self.bufferSize)
        bufferR = [Float](repeating: 0, count: Self.bufferSize)
        setSampleRate(sampleRate)
    }

    /// Main thread or sample-rate change only. Does not grow the delay buffer.
    public func setSampleRate(_ rate: Double) {
        guard rate > 1 else { return }
        sampleRate = Float(rate)
        let fc = 800.0
        lpCoeff = Float(1 - exp(-2 * Double.pi * fc / rate))
        if lpCoeff < 0 { lpCoeff = 0 }
        if lpCoeff > 1 { lpCoeff = 1 }
    }

    public func reset() {
        for i in 0..<Self.bufferSize {
            bufferL[i] = 0
            bufferR[i] = 0
        }
        writeIndex = 0
        low = 0
        hornPhase = 0
        drumPhase = 0.2
        hornHz = 0
        drumHz = 0
    }

    /// Place the rotors on their targets. Call from the preset apply, not per sample.
    public func snapSpeeds(hornSlow: Float, hornFast: Float, drumSlow: Float, drumFast: Float, fast: Float) {
        let amount = Self.clamp01(fast)
        hornHz = Self.blend(hornSlow, hornFast, amount)
        drumHz = Self.blend(drumSlow, drumFast, amount)
    }

    public func process(
        inputL: Float,
        inputR: Float,
        hornSlow: Float,
        hornFast: Float,
        drumSlow: Float,
        drumFast: Float,
        fast: Float,
        drive: Float,
        mix: Float,
        accelHz: Float
    ) -> (Float, Float) {
        if !inputL.isFinite || !inputR.isFinite { return (0, 0) }
        let wetMix = Self.clamp01(mix)
        if wetMix <= 0 { return (inputL, inputR) }
        let sr = sampleRate
        if sr < 2 { return (inputL, inputR) }

        let amount = Self.clamp01(fast)
        let hornTarget = Self.blend(hornSlow, hornFast, amount)
        let drumTarget = Self.blend(drumSlow, drumFast, amount)
        let step = max(0, accelHz) / sr
        hornHz = Self.slew(hornHz, hornTarget, step)
        drumHz = Self.slew(drumHz, drumTarget, step)

        let mono = flush(0.5 * (inputL + inputR))
        low = flush(low + lpCoeff * (mono - low))
        let high = flush(mono - low)

        hornPhase = Self.wrap(hornPhase + hornHz / sr)
        drumPhase = Self.wrap(drumPhase + drumHz / sr)

        bufferL[writeIndex] = inputL
        bufferR[writeIndex] = inputR

        let base = sr * 0.002
        let hornDelay = base + sr * 0.0011 * Self.sineSample(hornPhase)
        let drumDelay = base + sr * 0.00055 * Self.sineSample(drumPhase)
        let hornL = read(bufferL, delay: hornDelay)
        let hornR = read(bufferR, delay: hornDelay)
        let drumL = read(bufferL, delay: drumDelay)
        let drumR = read(bufferR, delay: drumDelay)

        let hornGainL = 0.55 + 0.45 * Self.sineSample(hornPhase)
        let hornGainR = 0.55 + 0.45 * Self.sineSample(Self.wrap(hornPhase + 0.37))
        let drumGainL = 0.70 + 0.30 * Self.sineSample(drumPhase)
        let drumGainR = 0.70 + 0.30 * Self.sineSample(Self.wrap(drumPhase + 0.61))

        var wetL = flush(high * hornGainL + low * drumGainL)
        var wetR = flush(high * hornGainR + low * drumGainR)
        // A touch of the delayed rotor keeps the sides from collapsing to one gain curve.
        wetL = flush(wetL * 0.85 + hornL * hornGainL * 0.15 + drumL * drumGainL * 0.15)
        wetR = flush(wetR * 0.85 + hornR * hornGainR * 0.15 + drumR * drumGainR * 0.15)
        wetL = shape(wetL, drive: drive)
        wetR = shape(wetR, drive: drive)

        writeIndex += 1
        if writeIndex >= Self.bufferSize { writeIndex = 0 }

        let dry = 1 - wetMix
        return (
            flush(inputL * dry + wetL * wetMix),
            flush(inputR * dry + wetR * wetMix)
        )
    }

    private func read(_ buffer: [Float], delay: Float) -> Float {
        let clamped = min(max(delay, 1), Float(Self.bufferSize - 2))
        let pos = Float(writeIndex) - clamped
        var base = pos
        if base < 0 { base += Float(Self.bufferSize) }
        let i0 = Int(base) % Self.bufferSize
        let frac = base - Float(Int(base))
        let i1 = (i0 + 1) % Self.bufferSize
        let a = buffer[i0]
        return flush(a + (buffer[i1] - a) * frac)
    }

    private func shape(_ x: Float, drive: Float) -> Float {
        let d = max(0, drive)
        if d <= 0.0001 { return x }
        let y = x * (1 + d * 6)
        let ax = abs(y)
        return flush(y / (1 + ax))
    }

    private func flush(_ x: Float) -> Float {
        if !x.isFinite || abs(x) < 1.0e-15 { return 0 }
        return x
    }

    private static func sineSample(_ phase: Float) -> Float {
        let scaled = phase * Float(tableSize)
        let i0 = Int(scaled) & tableMask
        let frac = scaled - Float(Int(scaled))
        let i1 = (i0 + 1) & tableMask
        let a = sine[i0]
        return a + (sine[i1] - a) * frac
    }

    private static func wrap(_ phase: Float) -> Float {
        var p = phase
        if p >= 1 { p -= Float(Int(p)) }
        if p < 0 { p = 0 }
        return p
    }

    private static func slew(_ current: Float, _ target: Float, _ step: Float) -> Float {
        let delta = target - current
        if abs(delta) <= step { return target }
        return current + (delta > 0 ? step : -step)
    }

    private static func blend(_ slow: Float, _ fast: Float, _ amount: Float) -> Float {
        return slow + (fast - slow) * amount
    }

    private static func clamp01(_ value: Float) -> Float {
        if value <= 0 { return 0 }
        if value >= 1 { return 1 }
        return value
    }
}
