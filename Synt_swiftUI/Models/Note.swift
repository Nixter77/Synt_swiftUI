//
//  Note.swift
//  Synt_swiftUI
//

import Foundation

struct Note: Hashable, Identifiable {
    let id = UUID()
    let midiNote: Int
    let name: String
    let isBlack: Bool

    var frequency: Double {
        440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
    }

    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func noteName(for midiNote: Int) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = midiNote % 12
        return "\(noteNames[noteIndex])\(octave)"
    }

    static func isBlackKey(_ midiNote: Int) -> Bool {
        let noteIndex = midiNote % 12
        return [1, 3, 6, 8, 10].contains(noteIndex)
    }

    init(midiNote: Int) {
        self.midiNote = midiNote
        self.name = Note.noteName(for: midiNote)
        self.isBlack = Note.isBlackKey(midiNote)
    }
}

struct ActiveNote: Identifiable {
    let id = UUID()
    let note: Note
    var velocity: Float
    var phase: Double = 0.0
    var phase2: Double = 0.0
    var currentFrequency: Double = 0.0 // For portamento
    var targetFrequency: Double = 0.0 // For unison/detune target
    var envelopePhase: EnvelopePhase = .attack
    var envelopeValue: Float = 0.0
    var envelopeTime: Double = 0.0
    var releaseStartValue: Float = 0.0
    var isReleasing: Bool = false
    var pan: Float = 0.0 // -1.0 (Left) to 1.0 (Right)
}

enum EnvelopePhase {
    case attack
    case decay
    case sustain
    case release
    case finished
}
