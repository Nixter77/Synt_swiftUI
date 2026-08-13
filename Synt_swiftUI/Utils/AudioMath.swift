//
//  AudioMath.swift
//  Synt_swiftUI
//

import Foundation

enum AudioMath {
    static let twoPi = 2.0 * Double.pi

    static func midiToFrequency(_ midiNote: Int) -> Double {
        440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
    }

    static func frequencyToMidi(_ frequency: Double) -> Int {
        Int(round(69.0 + 12.0 * log2(frequency / 440.0)))
    }

    static func detuneFrequency(_ frequency: Double, cents: Float) -> Double {
        frequency * pow(2.0, Double(cents) / 1200.0)
    }

    static func linearToDecibels(_ linear: Float) -> Float {
        guard linear > 0 else { return -Float.infinity }
        return 20.0 * log10(linear)
    }

    static func decibelsToLinear(_ decibels: Float) -> Float {
        pow(10.0, decibels / 20.0)
    }

    static func clamp(_ value: Float, min: Float, max: Float) -> Float {
        Swift.min(Swift.max(value, min), max)
    }

    /// Power-preserving scale: `1 / sqrt(max(1, activeVoices))`.
    /// Too hot for real chords (notes add nearly in phase). Live path uses `busScale`.
    static func polyphonyScale(activeVoices: Int) -> Float {
        Float(1.0 / sqrt(Double(max(1, activeVoices))))
    }

    /// Fixed peak budget for the mix bus. Musical notes are correlated, so
    /// they add closer to linearly than `1/√N`. `1/N` keeps a 4-note chord
    /// at the same peak as one note instead of ~6 dB hotter.
    static func busScale(activeVoices: Int) -> Float {
        1.0 / Float(max(1, activeVoices))
    }

    /// Apple Delay/Reverb sit *after* the synth clipper, so a 50% cathedral
    /// pad (Slow Motion) piles tails into clip while Init (20% hall) stays clean.
    /// 0…0.25 maps 1:1 (Init unchanged). Above that compresses toward 40% wet.
    static func appleFXWetPercent(_ mix: Float) -> Float {
        let m = max(0, min(1, mix))
        if m <= 0.25 { return m * 100 }
        return 25 + (m - 0.25) / 0.75 * 15
    }

    /// Soft clip toward ±threshold via tanh. Keeps peaks under the ceiling without hard edges.
    /// Default threshold 0.5 ≈ −6 dB headroom before downstream FX.
    static func softClip(_ value: Float, threshold: Float = 0.5) -> Float {
        guard threshold > 0 else { return 0 }
        return threshold * tanh(value / threshold)
    }

    /// Full Env Amt / matrix amount = this many octaves of cutoff travel.
    static let filterModOctaves: Float = 5.0

    /// Musical cutoff: `base * 2^(modulation * octaves)`, clamped to 20 Hz … 0.45·Fs.
    /// `modulation` is typically envelope×amount or a summed bipolar matrix (≈ −2…2).
    static func exponentialCutoff(
        base: Float,
        modulation: Float,
        octaves: Float = filterModOctaves,
        sampleRate: Double
    ) -> Float {
        let minC: Float = 20
        let maxC = Float(sampleRate) * 0.45
        let safeBase = max(minC, min(maxC, base))
        let mod = max(-2, min(2, modulation))
        let hz = safeBase * pow(2.0, mod * octaves)
        return max(minC, min(maxC, hz))
    }

    /// Equal-power stereo gains for pan in −1…1. Center is ~0.707 / 0.707 (not a second bus pan).
    static func constantPowerGains(pan: Float) -> (left: Float, right: Float) {
        let p = max(-1, min(1, pan))
        let angle = (p + 1.0) * Float.pi / 4.0
        return (cos(angle), sin(angle))
    }
}
