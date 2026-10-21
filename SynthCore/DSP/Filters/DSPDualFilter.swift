//
//  DSPDualFilter.swift
//  SynthCore
//
//  Dual filter module supporting serial and parallel routing with balance control.
//  Wraps the existing SynthFilter engine without modifying any existing files.
//

import Foundation

public enum DualFilterRouting: String, Codable, Sendable, CaseIterable {
    case serial = "Serial"
    case parallel = "Parallel"
    /// Voice default. Appended so Serial and Parallel keep their raw values.
    case off = "Off"
}

public final class DSPDualFilter {
    // Underlying filter instances for Left and Right channels
    public let filter1L: SynthFilter
    public let filter1R: SynthFilter
    public let filter2L: SynthFilter
    public let filter2R: SynthFilter
    /// Filter 2 formant bank. Allocated in init, not on the render thread.
    public let formant = DSPFormantFilter()
    /// Filter 2 comb / resonator.
    public let combL = DSPCombFilter()
    public let combR = DSPCombFilter()

    public var vowel: Float {
        get { formant.vowel }
        set { formant.vowel = newValue }
    }

    // Routing & Mix
    public var routing: DualFilterRouting = .serial
    /// 0.0 = Filter 1 only, 0.5 = 50/50 balance, 1.0 = Filter 2 (in parallel) or Filter 1->2 (in serial)
    public var balance: Float = 0.5
    public var mix: Float = 1.0

    // Convenience accessors for Filter 1
    public var type1: FilterType {
        get { filter1L.type }
        set {
            filter1L.type = newValue
            filter1R.type = newValue
        }
    }

    public var cutoff1: Float {
        get { filter1L.cutoff }
        set {
            filter1L.cutoff = newValue
            filter1R.cutoff = newValue
        }
    }

    public var resonance1: Float {
        get { filter1L.resonance }
        set {
            filter1L.resonance = newValue
            filter1R.resonance = newValue
        }
    }

    // Convenience accessors for Filter 2
    public var type2: FilterType {
        get { filter2L.type }
        set {
            filter2L.type = newValue
            filter2R.type = newValue
        }
    }

    public var cutoff2: Float {
        get { filter2L.cutoff }
        set {
            filter2L.cutoff = newValue
            filter2R.cutoff = newValue
        }
    }

    public var resonance2: Float {
        get { filter2L.resonance }
        set {
            filter2L.resonance = newValue
            filter2R.resonance = newValue
        }
    }

    private var sampleRate: Float = 44100.0

    // Preallocated buffers for block processing
    private var scratchBufferL: [Float] = []
    private var scratchBufferR: [Float] = []

    public init(sampleRate: Double = 44100.0, maxFrames: Int = 512) {
        self.filter1L = SynthFilter()
        self.filter1R = SynthFilter()
        self.filter2L = SynthFilter()
        self.filter2R = SynthFilter()
        prepare(sampleRate: sampleRate, maxFrames: maxFrames)
    }

    public func prepare(sampleRate: Double, maxFrames: Int = 512) {
        self.sampleRate = max(1.0, Float(sampleRate))
        if scratchBufferL.count < maxFrames {
            scratchBufferL = Array(repeating: 0.0, count: maxFrames)
            scratchBufferR = Array(repeating: 0.0, count: maxFrames)
        }
        formant.prepare(sampleRate: sampleRate, maxFrames: maxFrames)
    }

    public func reset() {
        filter1L.reset()
        filter1R.reset()
        filter2L.reset()
        filter2R.reset()
        formant.reset()
        combL.reset()
        combR.reset()
    }

    @inline(__always)
    private func filter2Mono(_ input: Float, channel: SynthFilter) -> Float {
        if type2 == .formant {
            return formant.process(input)
        }
        if type2 == .comb {
            return combL.process(input, cutoff: cutoff2, resonance: resonance2, sampleRate: Float(sampleRate))
        }
        return channel.process(input, sampleRate: sampleRate)
    }

    /// Filter 1 already ran on the voice. Off returns `filtered` with no second stage.
    @inline(__always)
    public func processFilter2(dry: Float, filtered: Float) -> Float {
        if routing == .off { return filtered }
        let bal = max(0, min(1, balance))
        let second: Float
        switch routing {
        case .off:
            return filtered
        case .serial:
            second = filter2Mono(max(-6, min(6, filtered)), channel: filter2L)
        case .parallel:
            second = filter2Mono(max(-6, min(6, dry)), channel: filter2L)
        }
        let wet = (1 - bal) * filtered + bal * second
        return max(-12, min(12, wet))
    }

    @inline(__always)
    public func process(_ input: Float) -> Float {
        if routing == .off || mix <= 0.0001 { return input }

        let inClamped = max(-6.0, min(6.0, input))
        let bal = max(0.0, min(1.0, balance))
        let wet: Float

        switch routing {
        case .off:
            return input
        case .parallel:
            let out1 = filter1L.process(inClamped, sampleRate: sampleRate)
            let out2 = filter2Mono(inClamped, channel: filter2L)
            wet = (1.0 - bal) * out1 + bal * out2

        case .serial:
            let out1 = filter1L.process(inClamped, sampleRate: sampleRate)
            let out2 = filter2Mono(out1, channel: filter2L)
            wet = (1.0 - bal) * out1 + bal * out2
        }

        let clampedWet = max(-12.0, min(12.0, wet))
        if mix >= 0.9999 { return clampedWet }
        return input + mix * (clampedWet - input)
    }

    @inline(__always)
    public func process(inputL: Float, inputR: Float) -> (Float, Float) {
        if routing == .off || mix <= 0.0001 { return (inputL, inputR) }

        let inL = max(-6.0, min(6.0, inputL))
        let inR = max(-6.0, min(6.0, inputR))
        let bal = max(0.0, min(1.0, balance))

        let wetL: Float
        let wetR: Float

        switch routing {
        case .off:
            return (inputL, inputR)
        case .parallel:
            let out1L = filter1L.process(inL, sampleRate: sampleRate)
            let out1R = filter1R.process(inR, sampleRate: sampleRate)
            let out2: (Float, Float)
            if type2 == .formant {
                out2 = formant.process(inputL: inL, inputR: inR)
            } else if type2 == .comb {
                out2 = (
                    combL.process(inL, cutoff: cutoff2, resonance: resonance2, sampleRate: Float(sampleRate)),
                    combR.process(inR, cutoff: cutoff2, resonance: resonance2, sampleRate: Float(sampleRate))
                )
            } else {
                out2 = (
                    filter2L.process(inL, sampleRate: sampleRate),
                    filter2R.process(inR, sampleRate: sampleRate)
                )
            }
            wetL = (1.0 - bal) * out1L + bal * out2.0
            wetR = (1.0 - bal) * out1R + bal * out2.1

        case .serial:
            let out1L = filter1L.process(inL, sampleRate: sampleRate)
            let out1R = filter1R.process(inR, sampleRate: sampleRate)
            let out2: (Float, Float)
            if type2 == .formant {
                out2 = formant.process(inputL: out1L, inputR: out1R)
            } else if type2 == .comb {
                out2 = (
                    combL.process(out1L, cutoff: cutoff2, resonance: resonance2, sampleRate: Float(sampleRate)),
                    combR.process(out1R, cutoff: cutoff2, resonance: resonance2, sampleRate: Float(sampleRate))
                )
            } else {
                out2 = (
                    filter2L.process(out1L, sampleRate: sampleRate),
                    filter2R.process(out1R, sampleRate: sampleRate)
                )
            }
            wetL = (1.0 - bal) * out1L + bal * out2.0
            wetR = (1.0 - bal) * out1R + bal * out2.1
        }

        let clampedWetL = max(-12.0, min(12.0, wetL))
        let clampedWetR = max(-12.0, min(12.0, wetR))

        if mix >= 0.9999 { return (clampedWetL, clampedWetR) }
        return (inputL + mix * (clampedWetL - inputL), inputR + mix * (clampedWetR - inputR))
    }

    public func process(
        bufferL: UnsafeMutablePointer<Float>,
        bufferR: UnsafeMutablePointer<Float>,
        frameCount: Int
    ) {
        if routing == .off || mix <= 0.0001 { return }

        for i in 0..<frameCount {
            let (l, r) = process(inputL: bufferL[i], inputR: bufferR[i])
            bufferL[i] = l
            bufferR[i] = r
        }
    }
}
