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
        for i in 0..<VoiceManager.maxVoices {
            voices[i] = VoiceState()
        }
    }

    /// Add voices for a note with unison.
    /// Re-triggers of the same MIDI note hard-kill prior voices (no double-trigger).
    func addVoices(
        midiNote: Int,
        velocity: Float,
        unisonVoices: Int,
        detuneAmount: Float,
        spreadAmount: Float,
        portamento: Float
    ) {
        // Hard-kill existing voices for this note to avoid double-trigger hang
        killVoices(midiNote: midiNote)

        let baseFrequency = 440.0 * pow(2.0, Double(midiNote - 69) / 12.0)

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
                break
            }

            var voice = VoiceState()
            voice.isActive = true
            voice.midiNote = midiNote
            voice.velocity = velocity
            voice.unisonIndex = i

            if voiceCount > 1 {
                let centerOffset = Float(i) - Float(voiceCount - 1) / 2.0
                let detuneCents = centerOffset * detuneAmount
                let detuneMultiplier = pow(2.0, Double(detuneCents) / 1200.0)

                voice.targetFrequency = baseFrequency * detuneMultiplier
                voice.currentFrequency = startFreq * detuneMultiplier

                let panPos = (Float(i) / Float(voiceCount - 1)) * 2.0 - 1.0
                voice.pan = panPos * spreadAmount
            } else {
                voice.targetFrequency = baseFrequency
                voice.currentFrequency = startFreq
                voice.pan = 0.0
            }

            voice.envelopePhase = .attack
            voice.envelopeValue = 0.0
            voice.envelopeTime = 0.0
            voice.isReleasing = false

            voices[voiceIndex] = voice
            activeVoiceCount += 1
        }
    }

    /// Release all voices for a given MIDI note (enter ADSR release).
    func releaseVoices(midiNote: Int) {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                voices[i].isReleasing = true
                voices[i].releaseStartValue = voices[i].envelopeValue
            }
        }
    }

    /// Immediately deactivate all voices for a MIDI note (re-trigger / kill).
    func killVoices(midiNote: Int) {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                voices[i].isActive = false
                voices[i].envelopeValue = 0.0
                voices[i].envelopePhase = .finished
                activeVoiceCount -= 1
            }
        }
    }

    /// Clear all voices immediately
    func clearAll() {
        for i in 0..<VoiceManager.maxVoices {
            voices[i].isActive = false
            voices[i].envelopeValue = 0.0
            voices[i].envelopePhase = .finished
        }
        activeVoiceCount = 0
        lastPlayedFrequency = nil
    }

    /// Iterate over all active voices.
    /// The closure receives a mutable reference and can return false to deactivate it.
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

    var activeCount: Int {
        activeVoiceCount
    }

    var hasActiveVoices: Bool {
        activeVoiceCount > 0
    }

    /// Find a free voice slot. Prefers inactive, then quietest releasing, then quietest active.
    private func findFreeVoice() -> Int? {
        for i in 0..<VoiceManager.maxVoices {
            if !voices[i].isActive {
                return i
            }
        }

        // Prefer stealing a releasing voice with the lowest envelope (least click risk)
        var stealIndex: Int? = nil
        var lowestEnvelope: Float = Float.greatestFiniteMagnitude
        var preferReleasing = false

        for i in 0..<VoiceManager.maxVoices {
            guard voices[i].isActive else { continue }
            let env = voices[i].envelopeValue
            if voices[i].isReleasing {
                if !preferReleasing || env < lowestEnvelope {
                    preferReleasing = true
                    lowestEnvelope = env
                    stealIndex = i
                }
            } else if !preferReleasing && env < lowestEnvelope {
                lowestEnvelope = env
                stealIndex = i
            }
        }

        if let index = stealIndex {
            // Hard-kill stolen voice (caller starts a fresh envelope at 0)
            voices[index].isActive = false
            voices[index].envelopeValue = 0.0
            voices[index].envelopePhase = .finished
            activeVoiceCount -= 1
            return index
        }

        return nil
    }
}
