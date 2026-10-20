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

/// Per-voice RT state for a fixed pool (no Dictionary / no heap ids).
struct ActiveNote {
    var isActive: Bool = false
    var midiNote: Int = 0
    var velocity: Float = 0
    var phase: Double = 0.0
    var phase2: Double = 0.0
    var subPhase: Double = 0.0
    var currentFrequency: Double = 0.0
    var targetFrequency: Double = 0.0
    var envelopePhase: EnvelopePhase = .attack
    var envelopeValue: Float = 0.0
    var envelopeTime: Double = 0.0
    var releaseStartValue: Float = 0.0
    var filterEnvelopePhase: EnvelopePhase = .attack
    var filterEnvelopeValue: Float = 0.0
    var filterEnvelopeTime: Double = 0.0
    var filterReleaseStartLevel: Float = 0.0
    var isReleasing: Bool = false
    /// When set, release uses a short fade (steal / re-trigger / abandoned tail) instead of preset release.
    var fastRelease: Bool = false
    /// Musical note-off order. Higher is newer. Fast fades do not become "fresh tails".
    var releaseSerial: Int = 0
    var pan: Float = 0.0
    /// Alias for pan (Phase V2.3)
    var voicePan: Float {
        get { pan }
        set { pan = newValue }
    }
    /// Per-voice analog drift state
    var driftState: Float = 0.0
    var driftPhase: Float = 0.0
    var driftMul: Double = 1.0
    var driftCutoffMul: Float = 1.0
    /// `1/U` for this note's unison stack. Independent MIDI notes stay at 1.
    var unisonScale: Float = 1.0
    /// Per-voice filter memory. Coeffs are shared; this state is not.
    var filter = BiquadMemory()
    /// Per-voice coefficients for filter envelope / key tracking. Refreshed every
    /// few samples; unused while both amounts are 0 (shared coeffs apply).
    var voiceFilterCoeffs = BiquadCoeffs()
    var filterControlTick: Int = 0
    var polyAftertouch: Float = 0.0
    var partial: Int = 0
    var partialCount: Int = 1

    // Noise filtering state (Paul Kellet pinking filter & brownian leaky integrator)
    var pinkState0: Float = 0.0
    var pinkState1: Float = 0.0
    var pinkState2: Float = 0.0
    var brownState: Float = 0.0

    mutating func filterNoise(_ white: Float, color: NoiseColor) -> Float {
        switch color {
        case .white:
            return white
        case .pink:
            pinkState0 = 0.99765 * pinkState0 + white * 0.0990460
            pinkState1 = 0.96300 * pinkState1 + white * 0.2965164
            pinkState2 = 0.57000 * pinkState2 + white * 1.0526913
            return (pinkState0 + pinkState1 + pinkState2 + white * 0.1848) * 0.5
        case .brown:
            brownState = 0.95 * brownState + white * 0.1
            return brownState * 2.5
        }
    }

    static let inactive = ActiveNote()

    mutating func activate(
        midiNote: Int,
        velocity: Float,
        frequency: Double,
        pan: Float = 0.0,
        unisonScale: Float = 1.0,
        partial: Int = 0,
        partialCount: Int = 1
    ) {
        self.isActive = true
        self.midiNote = midiNote
        self.velocity = velocity
        let start = AudioMath.voiceStartPhases(
            midiNote: midiNote,
            partial: partial,
            partialCount: partialCount
        )
        self.phase = start.0
        self.phase2 = start.1
        self.subPhase = start.0
        self.currentFrequency = frequency
        self.targetFrequency = frequency
        self.envelopePhase = .attack
        self.envelopeValue = 0
        self.envelopeTime = 0
        self.releaseStartValue = 0
        self.filterEnvelopePhase = .attack
        self.filterEnvelopeValue = 0
        self.filterEnvelopeTime = 0
        self.filterReleaseStartLevel = 0
        self.isReleasing = false
        self.fastRelease = false
        self.releaseSerial = 0
        self.pan = pan
        self.unisonScale = unisonScale
        self.driftState = 0.0
        self.driftPhase = Float((midiNote * 31 + partial * 79) % 628) / 100.0
        self.driftMul = 1.0
        self.driftCutoffMul = 1.0
        self.pinkState0 = 0.0
        self.pinkState1 = 0.0
        self.pinkState2 = 0.0
        self.brownState = 0.0
        self.filter.reset()
        self.filterControlTick = 0
        self.polyAftertouch = 0.0
        self.partial = partial
        self.partialCount = partialCount
    }

    /// Soft end: enter short release instead of hard cut (avoids clicks).
    mutating func beginFastRelease() {
        guard isActive, !isReleasing else { return }
        isReleasing = true
        fastRelease = true
        releaseStartValue = envelopeValue
        envelopeTime = 0
        if envelopePhase != .release && envelopePhase != .finished {
            envelopePhase = .release
        }
        filterReleaseStartLevel = filterEnvelopeValue
        filterEnvelopeTime = 0
        if filterEnvelopePhase != .release && filterEnvelopePhase != .finished {
            filterEnvelopePhase = .release
        }
    }

    /// Shorten a tail that is already in release. Time must restart: the envelope
    /// finishes when time exceeds the release length, so an old tail would
    /// otherwise drop to zero on the next sample.
    mutating func accelerateRelease() {
        guard isActive, envelopePhase != .finished else { return }
        if !isReleasing {
            beginFastRelease()
            return
        }
        guard !fastRelease else { return }
        fastRelease = true
        releaseStartValue = envelopeValue
        envelopeTime = 0
        envelopePhase = .release
        filterReleaseStartLevel = filterEnvelopeValue
        filterEnvelopeTime = 0
        filterEnvelopePhase = .release
    }

    mutating func deactivate() {
        isActive = false
        envelopeValue = 0
        envelopePhase = .finished
        filterEnvelopeValue = 0
        filterEnvelopePhase = .finished
        filterReleaseStartLevel = 0
        isReleasing = false
        fastRelease = false
        driftState = 0
        driftPhase = 0
        driftMul = 1.0
        driftCutoffMul = 1.0
        pinkState0 = 0.0
        pinkState1 = 0.0
        pinkState2 = 0.0
        brownState = 0.0
        polyAftertouch = 0.0
        filter.reset()
    }
}

enum EnvelopePhase {
    case attack
    case decay
    case sustain
    case release
    case finished
}
