//
//  FXSlotID.swift
//  SynthCore
//

import Foundation

public enum FXSlotID: String, Codable, CaseIterable, Sendable {
    case eq = "eq"
    case distortion = "distortion"
    case phaser = "phaser"
    case chorus = "chorus"
    case delay = "delay"
    case reverb = "reverb"

    public static let defaultOrder: [FXSlotID] = [
        .eq,
        .distortion,
        .phaser,
        .chorus,
        .delay,
        .reverb
    ]

    public var displayName: String {
        switch self {
        case .eq: return "EQ"
        case .distortion: return "Distortion"
        case .phaser: return "Phaser"
        case .chorus: return "Chorus"
        case .delay: return "Delay"
        case .reverb: return "Reverb"
        }
    }
}

/// Fixed 6-element table for zero-allocation access on the audio thread.
public struct FXOrderTable: Sendable, Equatable {
    public var slot0: FXSlotID = .eq
    public var slot1: FXSlotID = .distortion
    public var slot2: FXSlotID = .phaser
    public var slot3: FXSlotID = .chorus
    public var slot4: FXSlotID = .delay
    public var slot5: FXSlotID = .reverb

    public init() {}

    public init(order: [FXSlotID]) {
        let clean = SynthPreset.sanitizeFXOrder(order)
        slot0 = clean[0]
        slot1 = clean[1]
        slot2 = clean[2]
        slot3 = clean[3]
        slot4 = clean[4]
        slot5 = clean[5]
    }

    public subscript(index: Int) -> FXSlotID {
        get {
            switch index {
            case 0: return slot0
            case 1: return slot1
            case 2: return slot2
            case 3: return slot3
            case 4: return slot4
            default: return slot5
            }
        }
        set {
            switch index {
            case 0: slot0 = newValue
            case 1: slot1 = newValue
            case 2: slot2 = newValue
            case 3: slot3 = newValue
            case 4: slot4 = newValue
            default: slot5 = newValue
            }
        }
    }

    public var asArray: [FXSlotID] {
        [slot0, slot1, slot2, slot3, slot4, slot5]
    }
}
