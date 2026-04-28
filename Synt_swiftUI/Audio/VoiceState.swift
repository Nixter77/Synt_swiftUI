//
//  VoiceState.swift
//  Synt_swiftUI
//
//  Optimized voice storage and management for the audio thread.
//  Uses flat array instead of dictionary for cache efficiency.
//

import Foundation

/// Voice state stored in a flat array for cache-efficient processing
struct VoiceState {
    var isActive: Bool = false
    var midiNote: Int = 0
    var velocity: Float = 0.0

    // Oscillator phases
    var phase: Double = 0.0
    var phase2: Double = 0.0

    // Frequency (with portamento)
    var currentFrequency: Double = 0.0
    var targetFrequency: Double = 0.0

    // Envelope state
    var envelopePhase: EnvelopePhase = .attack
    var envelopeValue: Float = 0.0
    var envelopeTime: Double = 0.0
    var releaseStartValue: Float = 0.0
    var isReleasing: Bool = false

    // Stereo panning
    var pan: Float = 0.0

    // Unison voice index (for tracking which unison voice this is)
    var unisonIndex: Int = 0
}

/// Manages a fixed pool of voices for polyphonic synthesis
final class VoiceManager {
    static let maxVoices = 64

    private var voices: [VoiceState] = Array(repeating: VoiceState(), count: maxVoices)
    private var activeVoiceCount: Int = 0

    // For tracking portamento
    var lastPlayedFrequency: Double? = nil

    init() {
        // Pre-allocate all voices
        for i in 0..<VoiceManager.maxVoices {
            voices[i] = VoiceState()
        }
    }

    /// Add voices for a note with unison
    /// - Parameters:
    ///   - midiNote: MIDI note number
    ///   - velocity: Note velocity
    ///   - unisonVoices: Number of unison voices
    ///   - detuneAmount: Detune amount in cents
    ///   - spreadAmount: Stereo spread amount
    ///   - portamento: Portamento time
    func addVoices(
        midiNote: Int,
        velocity: Float,
        unisonVoices: Int,
        detuneAmount: Float,
        spreadAmount: Float,
        portamento: Float
    ) {
        // First, release any existing voices for this note
        releaseVoices(midiNote: midiNote)

        let baseFrequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)

        // Determine start frequency for portamento
        let startFreq: Double
        if portamento > 0.001, let lastFreq = lastPlayedFrequency {
            startFreq = lastFreq
        } else {
            startFreq = baseFrequency
        }
        lastPlayedFrequency = baseFrequency

        let voiceCount = max(1, unisonVoices)

        for i in 0..<voiceCount {
            guard let voiceIndex = findFreeVoice() else {
                break // No free voices
            }

            var voice = VoiceState()
            voice.isActive = true
            voice.midiNote = midiNote
            voice.velocity = velocity
            voice.unisonIndex = i

            // Calculate detune for this unison voice
            if voiceCount > 1 {
                let centerOffset = Float(i) - Float(voiceCount - 1) / 2.0
                let detuneCents = centerOffset * detuneAmount
                let detuneMultiplier = pow(2.0, Double(detuneCents) / 1200.0)

                voice.targetFrequency = baseFrequency * detuneMultiplier
                voice.currentFrequency = startFreq * detuneMultiplier

                // Calculate pan spread
                let panPos = (Float(i) / Float(voiceCount - 1)) * 2.0 - 1.0
                voice.pan = panPos * spreadAmount
            } else {
                voice.targetFrequency = baseFrequency
                voice.currentFrequency = startFreq
                voice.pan = 0.0
            }

            // Initialize envelope
            voice.envelopePhase = .attack
            voice.envelopeValue = 0.0
            voice.envelopeTime = 0.0
            voice.isReleasing = false

            voices[voiceIndex] = voice
            activeVoiceCount += 1
        }
    }

    /// Release all voices for a given MIDI note
    func releaseVoices(midiNote: Int) {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                voices[i].isReleasing = true
                voices[i].releaseStartValue = voices[i].envelopeValue
            }
        }
    }

    /// Clear all voices immediately
    func clearAll() {
        for i in 0..<VoiceManager.maxVoices {
            voices[i].isActive = false
        }
        activeVoiceCount = 0
        lastPlayedFrequency = nil
    }

    /// Iterate over all active voices
    /// The closure receives a mutable reference to the voice and can return false to deactivate it
    @inline(__always)
    func forEachActiveVoice(_ body: (inout VoiceState) -> Bool) {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive {
                let shouldKeep = body(&voices[i])
                if !shouldKeep {
                    voices[i].isActive = false
                    activeVoiceCount -= 1
                }
            }
        }
    }

    /// Get the number of active voices
    var activeCount: Int {
        activeVoiceCount
    }

    /// Check if there are any active voices
    var hasActiveVoices: Bool {
        activeVoiceCount > 0
    }

    /// Find a free voice slot
    private func findFreeVoice() -> Int? {
        // First, try to find a completely inactive voice
        for i in 0..<VoiceManager.maxVoices {
            if !voices[i].isActive {
                return i
            }
        }

        // Voice stealing: find the oldest releasing voice
        var oldestReleasingIndex: Int? = nil
        var lowestEnvelope: Float = Float.greatestFiniteMagnitude

        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isReleasing && voices[i].envelopeValue < lowestEnvelope {
                lowestEnvelope = voices[i].envelopeValue
                oldestReleasingIndex = i
            }
        }

        if let index = oldestReleasingIndex {
            voices[index].isActive = false
            activeVoiceCount -= 1
            return index
        }

        return nil // No voices available
    }
}
