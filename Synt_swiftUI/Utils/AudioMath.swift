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

    /// Power-preserving polyphony scale: `1 / sqrt(max(1, activeVoices))`.
    /// Keeps chord loudness from growing linearly with voice count.
    static func polyphonyScale(activeVoices: Int) -> Float {
        Float(1.0 / sqrt(Double(max(1, activeVoices))))
    }

    /// Soft clip toward ±threshold via tanh. Keeps peaks under the ceiling without hard edges.
    /// Default threshold 0.5 ≈ −6 dB headroom before downstream FX.
    static func softClip(_ value: Float, threshold: Float = 0.5) -> Float {
        guard threshold > 0 else { return 0 }
        return threshold * tanh(value / threshold)
    }
}
