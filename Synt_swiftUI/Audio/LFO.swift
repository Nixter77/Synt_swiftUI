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

    func reset() {
        phase = 0.0
    }

    func getValue(sampleRate: Double) -> Float {
        guard enabled else { return 0.0 }

        let phaseIncrement = AudioMath.twoPi * Double(rate) / sampleRate
        phase += phaseIncrement

        if phase >= AudioMath.twoPi {
            phase -= AudioMath.twoPi
            // Trigger Sample & Hold update
            lastRandomValue = Float.random(in: -1.0...1.0)
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
        }

        return value * depth
    }

    func modulateFrequency(_ frequency: Double, lfoValue: Float) -> Double {
        let semitones = Double(lfoValue) * 2.0
        return frequency * pow(2.0, semitones / 12.0)
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
