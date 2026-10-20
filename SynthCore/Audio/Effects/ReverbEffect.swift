//
//  ReverbEffect.swift
//  Synt_swiftUI
//

import AVFoundation

public class ReverbEffect {
    public let reverb = AVAudioUnitReverb()

    public var wetDryMix: Float = 20.0 {
        didSet {
            reverb.wetDryMix = wetDryMix
        }
    }

    /// Last discrete IR slot (0…4). −1 before the first apply.
    private var lastRoomSlot: Int = -1
    /// How many times `loadFactoryPreset` ran (init + slot changes). Tests only.
    private(set) var factoryPresetLoadCount: Int = 0

    public init() {
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = wetDryMix
        lastRoomSlot = Self.roomSlot(for: 0.5)
        factoryPresetLoadCount = 1
    }

    /// Five factory IRs mapped from the 0…1 Room knob.
    public static func roomSlot(for size: Float) -> Int {
        switch size {
        case ..<0.2: return 0
        case ..<0.4: return 1
        case ..<0.6: return 2
        case ..<0.8: return 3
        default: return 4
        }
    }

    public static func factoryPreset(forSlot slot: Int) -> AVAudioUnitReverbPreset {
        switch slot {
        case 0: return .smallRoom
        case 1: return .mediumRoom
        case 2: return .mediumHall
        case 3: return .largeHall
        default: return .largeHall
        }
    }

    /// Drop the reverb tail so a wet pad cannot start sounding on its own.
    public func reset() {
        reverb.reset()
    }

    /// Reloads the IR only when the discrete room slot changes (avoids tail cuts on every knob).
    public func setRoomSize(_ size: Float) {
        let slot = Self.roomSlot(for: size)
        guard slot != lastRoomSlot else { return }
        lastRoomSlot = slot
        reverb.loadFactoryPreset(Self.factoryPreset(forSlot: slot))
        factoryPresetLoadCount += 1
    }
}
