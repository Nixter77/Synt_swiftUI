//
//  LFO.swift
//  Synt_swiftUI
//

import Foundation

class LFO {
    var rate: Float = 5.0
    var depth: Float = 0.5
    var waveform: WaveformType = .sine
    var target: LFOTarget = .pitch
    var enabled: Bool = false

    private var phase: Double = 0.0
    private var lastRandomValue: Float = 0.0
    /// LCG for S&H. Float.random hits the system RNG (can lock) on the audio thread.
    private var randomState: UInt32 = 0x9E37_79B9

    func reset() {
        phase = 0.0
    }

    func getValue(sampleRate: Double) -> Float {
        guard enabled else { return 0.0 }
        return nextValue(sampleRate: sampleRate)
    }

    /// One sample of the LFO, whether or not the direct target is enabled.
    /// The matrix calls this when a row uses LFO 1 and the toggle is off.
    func nextValue(sampleRate: Double, rateOverride: Float? = nil) -> Float {
        nextRawValue(sampleRate: sampleRate, rateOverride: rateOverride) * depth
    }

    /// Bipolar −1…1, before Depth. Matrix rows use this so their Amount is the depth.
    func nextRawValue(sampleRate: Double, rateOverride: Float? = nil) -> Float {
        let usedRate = rateOverride ?? rate
        let phaseIncrement = AudioMath.twoPi * Double(usedRate) / sampleRate
        phase += phaseIncrement

        if phase >= AudioMath.twoPi {
            phase -= AudioMath.twoPi
            // Trigger Sample & Hold update
            randomState = randomState &* 1_664_525 &+ 1_013_904_223
            lastRandomValue = Float(randomState) / Float(UInt32.max) * 2 - 1
        }

        var value: Float = 0.0

        switch waveform {
        case .sine:
            value = Float(sin(phase))

        case .triangle:
            let normalizedPhase = phase / AudioMath.twoPi
            value = Float(4.0 * abs(normalizedPhase - 0.5) - 1.0)

        case .sawtooth:
            let normalizedPhase = phase / AudioMath.twoPi
            value = Float(2.0 * normalizedPhase - 1.0)

        case .square:
            value = phase < Double.pi ? 1.0 : -1.0
            
        case .noise:
            // Sample & Hold (Random step)
            value = lastRandomValue

        case .wavetable:
            // LFO does not use multi-frame tables — sine is a safe fallback.
            value = Float(sin(phase))
        }

        return value
    }

    func modulateFilter(_ cutoff: Float, lfoValue: Float) -> Float {
        let modulation = lfoValue * 2000.0
        return max(20.0, cutoff + modulation)
    }

    func modulateAmplitude(_ amplitude: Float, lfoValue: Float) -> Float {
        let modulation = (lfoValue + 1.0) / 2.0
        return amplitude * modulation
    }
}
