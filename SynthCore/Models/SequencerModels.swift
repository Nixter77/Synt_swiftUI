//
//  SequencerModels.swift
//  Synt_swiftUI
//

import Foundation

public enum ArpeggiatorMode: String, CaseIterable, Codable {
    case off = "Off"
    case up = "Up"
    case down = "Down"
    case upDown = "Up/Down"
    case random = "Random"
    case asPlayed = "As Played"
}

public enum TimeDivision: String, CaseIterable, Codable {
    case whole = "1/1"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"
    case wholeD = "1/1D"
    case halfD = "1/2D"
    case quarterD = "1/4D"
    case eighthD = "1/8D"
    case sixteenthD = "1/16D"
    case thirtySecondD = "1/32D"
    case wholeT = "1/1T"
    case halfT = "1/2T"
    case quarterT = "1/4T"
    case eighthT = "1/8T"
    case sixteenthT = "1/16T"
    case thirtySecondT = "1/32T"
    
    public var denominator: Double {
        switch self {
        case .whole, .wholeD, .wholeT: return 1.0
        case .half, .halfD, .halfT: return 2.0
        case .quarter, .quarterD, .quarterT: return 4.0
        case .eighth, .eighthD, .eighthT: return 8.0
        case .sixteenth, .sixteenthD, .sixteenthT: return 16.0
        case .thirtySecond, .thirtySecondD, .thirtySecondT: return 32.0
        }
    }

    public var multiplier: Double {
        switch self {
        case .whole, .half, .quarter, .eighth, .sixteenth, .thirtySecond:
            return 1.0
        case .wholeD, .halfD, .quarterD, .eighthD, .sixteenthD, .thirtySecondD:
            return 1.5
        case .wholeT, .halfT, .quarterT, .eighthT, .sixteenthT, .thirtySecondT:
            return 2.0 / 3.0
        }
    }

    public func duration(bpm: Float) -> Float {
        let safeBpm = max(20.0, min(300.0, bpm))
        return Float((60.0 / Double(safeBpm)) * (4.0 / denominator) * multiplier)
    }

    public func frequency(bpm: Float) -> Float {
        let dur = duration(bpm: bpm)
        return dur > 0 ? 1.0 / dur : 1.0
    }

    public var cyclesPerBeat: Double {
        let durationInBeats = (4.0 / denominator) * multiplier
        return durationInBeats > 0 ? 1.0 / durationInBeats : 1.0
    }
}

public struct SequencerStep: Identifiable, Codable, Hashable {
    public var id = UUID()
    public var isActive: Bool = false
    public var noteOffset: Int = 0 // Semitones relative to root
    public var velocity: Float = 0.8
    public var octave: Int = 0
    public var tie: Bool = false
    public var gate: Float = 0.8
    public var ratchet: Int = 1
    public var probability: Float = 1.0

    public enum CodingKeys: String, CodingKey {
        case id, isActive, noteOffset, velocity, octave, tie, gate, ratchet, probability
    }

    public init(
        id: UUID = UUID(),
        isActive: Bool = false,
        noteOffset: Int = 0,
        velocity: Float = 0.8,
        octave: Int = 0,
        tie: Bool = false,
        gate: Float = 0.8,
        ratchet: Int = 1,
        probability: Float = 1.0
    ) {
        self.id = id
        self.isActive = isActive
        self.noteOffset = noteOffset
        self.velocity = velocity
        self.octave = octave
        self.tie = tie
        self.gate = gate
        self.ratchet = ratchet
        self.probability = probability
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? false
        noteOffset = try c.decodeIfPresent(Int.self, forKey: .noteOffset) ?? 0
        velocity = try c.decodeIfPresent(Float.self, forKey: .velocity) ?? 0.8
        octave = try c.decodeIfPresent(Int.self, forKey: .octave) ?? 0
        tie = try c.decodeIfPresent(Bool.self, forKey: .tie) ?? false
        gate = try c.decodeIfPresent(Float.self, forKey: .gate) ?? 0.8
        ratchet = try c.decodeIfPresent(Int.self, forKey: .ratchet) ?? 1
        probability = try c.decodeIfPresent(Float.self, forKey: .probability) ?? 1.0
    }
}

