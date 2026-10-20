//
//  DelayEffect.swift
//  Synt_swiftUI
//

import AVFoundation

public class DelayEffect {
    public let delay = AVAudioUnitDelay()

    public var delayTime: Float = 0.3 {
        didSet {
            delay.delayTime = TimeInterval(delayTime)
        }
    }

    /// Linear 0…1. `AVAudioUnitDelay.feedback` is a percent (0…100).
    public var feedback: Float = 0.4 {
        didSet {
            let clamped = max(0, min(1, feedback))
            if clamped != feedback {
                feedback = clamped
                return
            }
            delay.feedback = clamped * 100.0
        }
    }

    public var wetDryMix: Float = 0.0 {
        didSet {
            delay.wetDryMix = wetDryMix
        }
    }

    public init() {
        delay.delayTime = TimeInterval(delayTime)
        delay.feedback = feedback * 100.0
        delay.wetDryMix = wetDryMix
        delay.lowPassCutoff = 15000.0
    }

    /// Drop the delay line so a wet preset cannot replay the previous patch.
    public func reset() {
        delay.reset()
    }
}
