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
}

struct SequencerStep: Identifiable, Codable, Hashable {
    var id = UUID()
    var isActive: Bool = false
    var noteOffset: Int = 0 // Semitones relative to root
    var velocity: Float = 0.8
    var octave: Int = 0
}
