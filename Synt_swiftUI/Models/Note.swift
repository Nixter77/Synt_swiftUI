//
//  Note.swift
//  Synt_swiftUI
//

import Foundation

struct Note: Hashable, Identifiable {
    /// Stable id from MIDI number (no UUID — safe for audio-thread voice alloc).
    var id: Int { midiNote }
    let midiNote: Int
    let name: String
    let isBlack: Bool

    var frequency: Double {
        AudioMath.midiToFrequency(midiNote)
    }

    static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    static func noteName(for midiNote: Int) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = ((midiNote % 12) + 12) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }

    static func isBlackKey(_ midiNote: Int) -> Bool {
        let noteIndex = ((midiNote % 12) + 12) % 12
        return [1, 3, 6, 8, 10].contains(noteIndex)
    }

    init(midiNote: Int) {
        self.midiNote = midiNote
        self.name = Note.noteName(for: midiNote)
        self.isBlack = Note.isBlackKey(midiNote)
    }
}

/// Per-voice RT state. No heap ids — created on the audio thread.
struct ActiveNote {
    let midiNote: Int
    var velocity: Float
    var phase: Double = 0.0
    var phase2: Double = 0.0
    var currentFrequency: Double = 0.0
    var targetFrequency: Double = 0.0
    var envelopePhase: EnvelopePhase = .attack
    var envelopeValue: Float = 0.0
    var envelopeTime: Double = 0.0
    var releaseStartValue: Float = 0.0
    var isReleasing: Bool = false
    var pan: Float = 0.0

    init(midiNote: Int, velocity: Float, frequency: Double, pan: Float = 0.0) {
        self.midiNote = midiNote
        self.velocity = velocity
        self.currentFrequency = frequency
        self.targetFrequency = frequency
        self.pan = pan
    }
}

enum EnvelopePhase {
    case attack
    case decay
    case sustain
    case release
    case finished
}
