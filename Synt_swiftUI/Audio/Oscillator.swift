//
//  Oscillator.swift
//  Synt_swiftUI
//

import Foundation

struct Oscillator {
    var waveform: WaveformType = .sawtooth
    var volume: Float = 0.7
    var octave: Int = 0
    var detune: Float = 0.0
    var pulseWidth: Float = 0.5 // For Square wave (PWM)

    /// Shared wavetable engine (owned by AudioEngine). Only used when `waveform == .wavetable`.
    /// Class reference — not copied by value; safe for struct Oscillator.
    var wavetableEngine: WavetableOscillator? = nil
    /// Morph 0…1 across wavetable frames (smoothed inside the engine).
    var wavetableMorph: Float = 0.0
    var wavetableSampleRate: Double = 44100.0

    func generateSample(
        phase: Double,
        phaseIncrement: Double,
        noiseValue: Float = 0.0,
        pulseWidthOverride: Float? = nil
    ) -> Float {
        let sample: Float
        let twoPi = AudioMath.twoPi
        let normalizedPhase = phase / twoPi
        let normalizedIncrement = phaseIncrement / twoPi
        let pw = Double(max(0.05, min(0.95, pulseWidthOverride ?? pulseWidth)))

        switch waveform {
        case .sine:
            sample = Float(sin(phase))

        case .sawtooth:
            // Naive Sawtooth: 2 * phase - 1
            var value = 2.0 * normalizedPhase - 1.0

            // Apply PolyBLEP correction for discontinuity at phase 0/1
            value -= polyBLEP(t: normalizedPhase, dt: normalizedIncrement)

            sample = Float(value)

        case .square:
            // Variable Pulse Width Square
            // 1 if phase < pw, else -1
            var value = normalizedPhase < pw ? 1.0 : -1.0

            // PolyBLEP for rising edge at 0
            value += polyBLEP(t: normalizedPhase, dt: normalizedIncrement)

            // PolyBLEP for falling edge at pulseWidth
            var phaseShifted = normalizedPhase - pw
            if phaseShifted < 0.0 { phaseShifted += 1.0 }

            value -= polyBLEP(t: phaseShifted, dt: normalizedIncrement)

            sample = Float(value)

        case .triangle:
            let t = normalizedPhase
            sample = Float(4.0 * abs(t - 0.5) - 1.0)

        case .noise:
            sample = noiseValue

        case .wavetable:
            // Raw table sample (no engine volume) → single volume multiply below.
            // Morph is advanced once per audio sample in AudioEngine, not per voice.
            if let engine = wavetableEngine {
                sample = engine.generateSample(
                    phase: phase,
                    phaseIncrement: phaseIncrement,
                    sampleRate: wavetableSampleRate
                )
            } else {
                // Fallback if engine not attached — keep signal finite
                sample = Float(sin(phase))
            }
        }

        // Single gain stage for all waveforms (including wavetable).
        return sample * volume
    }
    
    // PolyBLEP (Polynomial Band-Limited Step) function
    // t: normalized phase [0, 1]
    // dt: normalized phase increment
    private func polyBLEP(t: Double, dt: Double) -> Double {
        guard dt > 0.0 && dt < 1.0 else { return 0.0 }

        // Discontinuity at 0 (or 1)
        
        // 0 < t < dt: Interpolate beginning of step
        if t < dt {
            let u = t / dt
            return u + u - u * u - 1.0
        }
        // 1 - dt < t < 1: Interpolate end of step
        else if t > 1.0 - dt {
            let u = (t - 1.0) / dt
            return u * u + u + u + 1.0
        }
        
        return 0.0
    }

    func frequencyWithModifiers(_ baseFrequency: Double) -> Double {
        var frequency = baseFrequency

        if octave != 0 {
            frequency *= pow(2.0, Double(octave))
        }

        if detune != 0 {
            frequency = AudioMath.detuneFrequency(frequency, cents: detune)
        }

        return frequency
    }
}

