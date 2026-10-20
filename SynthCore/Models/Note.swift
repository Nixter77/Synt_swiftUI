//
//  Note.swift
//  Synt_swiftUI
//

import Foundation

public struct Note: Hashable, Identifiable {
    /// Stable id from MIDI number (no UUID — safe for audio-thread voice alloc).
    public var id: Int { midiNote }
    public let midiNote: Int
    public let name: String
    public let isBlack: Bool

    public var frequency: Double {
        AudioMath.midiToFrequency(midiNote)
    }

    public static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    public static func noteName(for midiNote: Int) -> String {
        let octave = (midiNote / 12) - 1
        let noteIndex = ((midiNote % 12) + 12) % 12
        return "\(noteNames[noteIndex])\(octave)"
    }

    public static func isBlackKey(_ midiNote: Int) -> Bool {
        let noteIndex = ((midiNote % 12) + 12) % 12
        return [1, 3, 6, 8, 10].contains(noteIndex)
    }

    public init(midiNote: Int) {
        self.midiNote = midiNote
        self.name = Note.noteName(for: midiNote)
        self.isBlack = Note.isBlackKey(midiNote)
    }
}

/// Per-voice RT state for a fixed pool (no Dictionary / no heap ids).
public struct ActiveNote {
    public var isActive: Bool = false
    public var midiNote: Int = 0
    public var velocity: Float = 0
    public var phase: Double = 0.0
    public var phase2: Double = 0.0
    public var subPhase: Double = 0.0
    public var currentFrequency: Double = 0.0
    public var targetFrequency: Double = 0.0
    public var envelopePhase: EnvelopePhase = .attack
    public var envelopeValue: Float = 0.0
    public var envelopeTime: Double = 0.0
    public var releaseStartValue: Float = 0.0
    public var filterEnvelopePhase: EnvelopePhase = .attack
    public var filterEnvelopeValue: Float = 0.0
    public var filterEnvelopeTime: Double = 0.0
    public var filterReleaseStartLevel: Float = 0.0
    public var modEnvelopePhase: EnvelopePhase = .attack
    public var modEnvelopeValue: Float = 0.0
    public var modEnvelopeTime: Double = 0.0
    public var modReleaseStartLevel: Float = 0.0
    public var randomValue: Float = 0.0
    public var glideIntervalSemitones: Float = 0.0
    public var isReleasing: Bool = false
    /// When set, release uses a short fade (steal / re-trigger / abandoned tail) instead of preset release.
    public var fastRelease: Bool = false
    /// Musical note-off order. Higher is newer. Fast fades do not become "fresh tails".
    public var releaseSerial: Int = 0
    public var pan: Float = 0.0
    /// Alias for pan (Phase V2.3)
    public var voicePan: Float {
        get { pan }
        set { pan = newValue }
    }
    /// Per-voice analog drift state
    public var driftState: Float = 0.0
    public var driftPhase: Float = 0.0
    public var driftMul: Double = 1.0
    public var driftCutoffMul: Float = 1.0
    /// `1/U` for this note's unison stack. Independent MIDI notes stay at 1.
    public var unisonScale: Float = 1.0
    /// Per-voice filter memory. Coeffs are shared; this state is not.
    public var filter = BiquadMemory()
    public var ladder = LadderFilter()
    /// Per-voice coefficients for filter envelope / key tracking. Refreshed every
    /// few samples; unused while both amounts are 0 (shared coeffs apply).
    public var voiceFilterCoeffs = BiquadCoeffs()
    public var filterControlTick: Int = 0
    public var polyAftertouch: Float = 0.0
    public var partial: Int = 0
    public var partialCount: Int = 1

    // Noise filtering state (Paul Kellet pinking filter & brownian leaky integrator)
    public var pinkState0: Float = 0.0
    public var pinkState1: Float = 0.0
    public var pinkState2: Float = 0.0
    public var brownState: Float = 0.0

    public mutating func filterNoise(_ white: Float, color: NoiseColor) -> Float {
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

    public static let inactive = ActiveNote()

    public mutating func activate(
        midiNote: Int,
        velocity: Float,
        frequency: Double,
        pan: Float = 0.0,
        unisonScale: Float = 1.0,
        partial: Int = 0,
        partialCount: Int = 1,
        phaseMode: OscPhaseMode = .reset
    ) {
        self.isActive = true
        self.midiNote = midiNote
        self.velocity = velocity
        let keptPhase = phase
        let keptPhase2 = phase2
        let keptSubPhase = subPhase
        let start = AudioMath.voiceStartPhases(
            midiNote: midiNote,
            partial: partial,
            partialCount: partialCount
        )
        self.phase = start.0
        self.phase2 = start.1
        self.subPhase = start.0
        if phaseMode == .free {
            phase = keptPhase
            phase2 = keptPhase2
            subPhase = keptSubPhase
        } else if phaseMode == .random {
            var h = UInt32(truncatingIfNeeded: midiNote &* 374761393)
            h &+= UInt32(truncatingIfNeeded: partial &* 668265263)
            h &+= UInt32(truncatingIfNeeded: partialCount &* 1442695041)
            h ^= h >> 16
            h &*= 2246822519
            h ^= h >> 13
            h &*= 3266489917
            h ^= h >> 16
            phase = Double(h) / Double(UInt32.max) * AudioMath.twoPi
            h &*= 0x85ebca6b
            h ^= h >> 13
            phase2 = Double(h) / Double(UInt32.max) * AudioMath.twoPi
            h &*= 0xc2b2ae35
            h ^= h >> 16
            subPhase = Double(h) / Double(UInt32.max) * AudioMath.twoPi
        }
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
        self.modEnvelopePhase = .attack
        self.modEnvelopeValue = 0
        self.modEnvelopeTime = 0
        self.modReleaseStartLevel = 0
        self.randomValue = 0
        self.glideIntervalSemitones = 0
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
        self.ladder.reset()
        self.filterControlTick = 0
        self.polyAftertouch = 0.0
        self.partial = partial
        self.partialCount = partialCount
    }

    /// Soft end: enter short release instead of hard cut (avoids clicks).
    public mutating func beginFastRelease() {
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
        modReleaseStartLevel = modEnvelopeValue
        modEnvelopeTime = 0
        if modEnvelopePhase != .release && modEnvelopePhase != .finished {
            modEnvelopePhase = .release
        }
    }

    /// Shorten a tail that is already in release. Time must restart: the envelope
    /// finishes when time exceeds the release length, so an old tail would
    /// otherwise drop to zero on the next sample.
    public mutating func accelerateRelease() {
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
        modReleaseStartLevel = modEnvelopeValue
        modEnvelopeTime = 0
        modEnvelopePhase = .release
    }

    public mutating func deactivate() {
        isActive = false
        envelopeValue = 0
        envelopePhase = .finished
        filterEnvelopeValue = 0
        filterEnvelopePhase = .finished
        filterReleaseStartLevel = 0
        modEnvelopeValue = 0
        modEnvelopePhase = .finished
        modReleaseStartLevel = 0
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
        ladder.reset()
    }
}

public enum EnvelopePhase {
    case attack
    case decay
    case sustain
    case release
    case finished
}
