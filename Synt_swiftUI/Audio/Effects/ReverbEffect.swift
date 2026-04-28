//
//  ReverbEffect.swift
//  Synt_swiftUI
//

import AVFoundation

class ReverbEffect {
    let reverb = AVAudioUnitReverb()

    var wetDryMix: Float = 20.0 {
        didSet {
            reverb.wetDryMix = wetDryMix
        }
    }

    init() {
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = wetDryMix
    }

    func setRoomSize(_ size: Float) {
        let preset: AVAudioUnitReverbPreset

        switch size {
        case 0.0..<0.2:
            preset = .smallRoom
        case 0.2..<0.4:
            preset = .mediumRoom
        case 0.4..<0.6:
            preset = .mediumHall
        case 0.6..<0.8:
            preset = .largeHall
        default:
            preset = .cathedral
        }

        reverb.loadFactoryPreset(preset)
    }
}
