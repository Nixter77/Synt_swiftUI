//
//  SequencerModels.swift
//  Synt_swiftUI
//

import Foundation

enum ArpeggiatorMode: String, CaseIterable, Codable {
    case off = "Off"
    case up = "Up"
    case down = "Down"
    case upDown = "Up/Down"
    case random = "Random"
}

enum TimeDivision: String, CaseIterable, Codable {
    case whole = "1/1"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"
    case thirtySecond = "1/32"
    
    var denominator: Double {
        switch self {
        case .whole: return 1.0
        case .half: return 2.0
        case .quarter: return 4.0
        case .eighth: return 8.0
        case .sixteenth: return 16.0
        case .thirtySecond: return 32.0
        }
    }

    func duration(bpm: Float) -> Float {
        let safeBpm = max(20.0, min(300.0, bpm))
        return Float((60.0 / Double(safeBpm)) * (4.0 / denominator))
    }

    func frequency(bpm: Float) -> Float {
        let dur = duration(bpm: bpm)
        return dur > 0 ? 1.0 / dur : 1.0
    }
}

struct SequencerStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var isActive: Bool = false
    var noteOffset: Int = 0 // Semitones relative to root
    var velocity: Float = 0.8
    var octave: Int = 0
    var tie: Bool = false
    var gate: Float = 0.8
    var ratchet: Int = 1
    var probability: Float = 1.0

    enum CodingKeys: String, CodingKey {
        case id, isActive, noteOffset, velocity, octave, tie, gate, ratchet, probability
    }

    init(
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

    init(from decoder: Decoder) throws {
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

