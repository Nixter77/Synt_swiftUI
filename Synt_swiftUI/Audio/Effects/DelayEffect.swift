//
//  DelayEffect.swift
//  Synt_swiftUI
//

import AVFoundation

class DelayEffect {
    let delay = AVAudioUnitDelay()

    var delayTime: Float = 0.3 {
        didSet {
            delay.delayTime = TimeInterval(delayTime)
        }
    }

    var feedback: Float = 0.4 {
        didSet {
            delay.feedback = feedback * 100.0
        }
    }

    var wetDryMix: Float = 0.0 {
        didSet {
            delay.wetDryMix = wetDryMix
        }
    }

    init() {
        delay.delayTime = TimeInterval(delayTime)
        delay.feedback = feedback * 100.0
        delay.wetDryMix = wetDryMix
        delay.lowPassCutoff = 15000.0
    }
}
