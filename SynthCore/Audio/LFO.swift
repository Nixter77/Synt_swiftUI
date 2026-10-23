//
//  LFO.swift
//  Synt_swiftUI
//

import Foundation

public enum LFOMode: String, Codable, CaseIterable, Sendable {
    case free
    case retrigger
    case oneShot
}

public class LFO {
    public var rate: Float = 5.0
    public var depth: Float = 0.5
    public var waveform: WaveformType = .sine
    public var target: LFOTarget = .pitch
    public var enabled: Bool = false
    public var mode: LFOMode = .free
    public var startPhaseDegrees: Float = 0.0
    public var stereoPhaseOffsetDegrees: Float = 0.0
    /// Kept for source compatibility. R12-8: the LFO no longer reads the oscillator engine
    /// (that advanced its morph smoothing and did ARC/bank pulls per sample).
    public weak var wavetableEngine: WavetableOscillator?
    public static let defaultWavetable: [Float] = WavetableOscillator.basicWavetables[0].frames[16]
    /// Immortal copy of `defaultWavetable` read on the render thread without ARC.
    static let defaultTablePointer: UnsafePointer<Float> = {
        let t = defaultWavetable
        let p = UnsafeMutablePointer<Float>.allocate(capacity: max(1, t.count))
        p.initialize(from: t, count: t.count)
        return UnsafePointer(p)
    }()
    private let tablePtr: UnsafePointer<Float> = LFO.defaultTablePointer
    private let tableCount: Int = LFO.defaultWavetable.count

    public internal(set) var phase: Double = 0.0
    public private(set) var isCompleted: Bool = false
    private var cycleProgress: Double = 0.0
    public internal(set) var lastRandomValue: Float = 0.0
    /// LCG for S&H. Float.random hits the system RNG (can lock) on the audio thread.
    private var randomState: UInt32 = 0x9E37_79B9

    public func setRandomSeed(_ seed: UInt32) {
        randomState = seed == 0 ? 0x9E37_79B9 : seed
        lastRandomValue = Float(randomState) / Float(UInt32.max) * 2 - 1
    }

    public func reset() {
        phase = 0.0
        cycleProgress = 0.0
        isCompleted = false
    }

    public func trigger() {
        let norm = Double(startPhaseDegrees.truncatingRemainder(dividingBy: 360.0) / 360.0)
        let positiveNorm = norm < 0 ? norm + 1.0 : norm
        phase = positiveNorm * AudioMath.twoPi
        cycleProgress = 0.0
        isCompleted = false
    }

    public func syncPhase(beat: Double, rateInCyclesPerBeat: Double) {
        let normStart = Double(startPhaseDegrees.truncatingRemainder(dividingBy: 360.0) / 360.0)
        let total = beat * rateInCyclesPerBeat + normStart
        var norm = total.truncatingRemainder(dividingBy: 1.0)
        if norm < 0 { norm += 1.0 }
        phase = norm * AudioMath.twoPi
    }

    public func getValue(sampleRate: Double) -> Float {
        guard enabled else { return 0.0 }
        return nextValue(sampleRate: sampleRate)
    }

    /// One sample of the LFO, whether or not the direct target is enabled.
    /// The matrix calls this when a row uses LFO 1 and the toggle is off.
    public func nextValue(sampleRate: Double, rateOverride: Float? = nil) -> Float {
        nextRawValue(sampleRate: sampleRate, rateOverride: rateOverride) * depth
    }

    /// Bipolar −1…1, before Depth. Matrix rows use this so their Amount is the depth.
    public func nextRawValue(sampleRate: Double, rateOverride: Float? = nil) -> Float {
        if mode == .oneShot && isCompleted {
            return 0.0
        }
        let usedRate = rateOverride ?? rate
        let phaseIncrement = AudioMath.twoPi * Double(usedRate) / sampleRate
        phase += phaseIncrement
        if mode == .oneShot {
            cycleProgress += phaseIncrement
            if cycleProgress >= AudioMath.twoPi {
                isCompleted = true
            }
        }

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
            value = sampleDefaultWavetable(normalizedPhase: phase / AudioMath.twoPi)
        }

        return value
    }

    private func sampleDefaultWavetable(normalizedPhase: Double) -> Float {
        var norm = normalizedPhase
        norm -= floor(norm)
        let table = tablePtr
        let count = tableCount
        guard count > 0 else { return 0.0 }
        let pos = norm * Double(count)
        let idx0 = Int(pos) % count
        let idx1 = (idx0 + 1) % count
        let frac = Float(pos - floor(pos))
        return table[idx0] * (1.0 - frac) + table[idx1] * frac
    }

    /// Samples the current LFO waveform at an arbitrary phase in [0, 2pi).
    public func sampleWaveform(at p: Double) -> Float {
        var norm = p / AudioMath.twoPi
        norm -= floor(norm)
        let normalizedPhase = norm
        let wrappedP = norm * AudioMath.twoPi

        switch waveform {
        case .sine:
            return Float(sin(wrappedP))
        case .triangle:
            return Float(4.0 * abs(normalizedPhase - 0.5) - 1.0)
        case .sawtooth:
            return Float(2.0 * normalizedPhase - 1.0)
        case .square:
            return wrappedP < Double.pi ? 1.0 : -1.0
        case .noise:
            return lastRandomValue
        case .wavetable:
            return sampleDefaultWavetable(normalizedPhase: normalizedPhase)
        }
    }

    /// Returns (left, right) raw LFO values. When stereoPhaseOffsetDegrees == 0, left == right.
    public func nextStereoRawValue(sampleRate: Double, rateOverride: Float? = nil) -> (left: Float, right: Float) {
        if mode == .oneShot && isCompleted {
            return (0.0, 0.0)
        }
        let leftVal = nextRawValue(sampleRate: sampleRate, rateOverride: rateOverride)
        if stereoPhaseOffsetDegrees == 0.0 {
            return (leftVal, leftVal)
        }
        let offsetRad = Double(stereoPhaseOffsetDegrees) * AudioMath.twoPi / 360.0
        var rPhase = (phase + offsetRad).truncatingRemainder(dividingBy: AudioMath.twoPi)
        if rPhase < 0 { rPhase += AudioMath.twoPi }
        let rightVal = sampleWaveform(at: rPhase)
        return (leftVal, rightVal)
    }

    public func modulateFilter(_ cutoff: Float, lfoValue: Float) -> Float {
        let modulation = lfoValue * 2000.0
        return max(20.0, cutoff + modulation)
    }

    public func modulateAmplitude(_ amplitude: Float, lfoValue: Float) -> Float {
        let modulation = (lfoValue + 1.0) / 2.0
        return amplitude * modulation
    }
}
