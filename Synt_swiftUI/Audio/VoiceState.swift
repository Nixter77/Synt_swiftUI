//
//  VoiceState.swift
//  Synt_swiftUI
//
//  Optimized voice storage and management for the audio thread.
//  Uses flat array instead of dictionary for cache efficiency.
//
//  Stage 2 rules:
//  - Re-trigger of the same MIDI note hard-kills prior voices (no double-trigger).
//  - Voice steal prefers quiet/releasing slots; otherwise starts a 1 ms steal-release
//    before reclaiming under polyphony pressure (reduces clicks vs hard cut).
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
    /// Stolen under polyphony pressure — render uses 1 ms release curve.
    var isStealRelease: Bool = false

    // Stereo panning
    var pan: Float = 0.0

    // Unison voice index (for tracking which unison voice this is)
    var unisonIndex: Int = 0
}

/// Manages a fixed pool of voices for polyphonic synthesis
final class VoiceManager {
    static let maxVoices = 64
    /// Fast release used when a voice is stolen to free a slot (≈1 ms @ any SR).
    static let stealReleaseSeconds: Float = 0.001
    /// Envelope level considered inaudible enough for click-free reclaim.
    static let silentEnvelopeThreshold: Float = 0.02

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

        // Soft-steal quietest victims first so 1 ms release can run when possible;
        // force-reclaim only the deficit still needed for allocation this sample.
        prepareSlots(needed: voiceCount)

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
            voice.isStealRelease = false
            voice.phase = 0.0
            voice.phase2 = 0.0

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
                voices[i].isStealRelease = false
            }
        }
    }

    /// Immediately deactivate all voices for a MIDI note (re-trigger / kill).
    func killVoices(midiNote: Int) {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                freeSlot(i)
            }
        }
    }

    /// Clear all voices immediately
    func clearAll() {
        for i in 0..<VoiceManager.maxVoices {
            voices[i].isActive = false
            voices[i].envelopeValue = 0.0
            voices[i].envelopePhase = .finished
            voices[i].isReleasing = false
            voices[i].isStealRelease = false
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
                    freeSlot(i)
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

    /// Unique MIDI notes that still have at least one active voice (for tests / UI helpers).
    func activeMIDINoteCount() -> Int {
        var seen = Set<Int>()
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive {
                seen.insert(voices[i].midiNote)
            }
        }
        return seen.count
    }

    func isMIDINoteActive(_ midiNote: Int) -> Bool {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                return true
            }
        }
        return false
    }

    /// True if every active voice for this note is releasing (normal or steal).
    func isMIDINoteReleasing(_ midiNote: Int) -> Bool {
        var found = false
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote {
                found = true
                if !voices[i].isReleasing {
                    return false
                }
            }
        }
        return found
    }

    // MARK: - Slot management / soft steal

    /// Ensure at least `needed` free slots: soft-steal then force-reclaim deficit.
    private func prepareSlots(needed: Int) {
        let free = VoiceManager.maxVoices - activeVoiceCount
        guard free < needed else { return }

        let deficit = needed - free
        softStealQuietest(count: deficit)
        forceReclaim(count: deficit)
    }

    /// Put up to `count` loudest-pressure victims into 1 ms steal-release (they stay active).
    private func softStealQuietest(count: Int) {
        var remaining = count
        while remaining > 0 {
            guard let idx = bestStealCandidate(preferAlreadyReleasing: true, requireNotStealRelease: true) else {
                break
            }
            beginStealRelease(idx)
            remaining -= 1
        }
    }

    /// Hard-free up to `count` slots, preferring silent / steal-release / lowest envelope.
    private func forceReclaim(count: Int) {
        var remaining = count
        while remaining > 0, activeVoiceCount > 0 {
            // Prefer already-silent
            if let silent = findSilentActiveIndex() {
                freeSlot(silent)
                remaining -= 1
                continue
            }
            // Prefer steal-release (started 1 ms fade this or a prior frame)
            if let steal = bestStealCandidate(preferAlreadyReleasing: true, requireStealRelease: true) {
                freeSlot(steal)
                remaining -= 1
                continue
            }
            // Last resort: quietest active voice
            if let any = bestStealCandidate(preferAlreadyReleasing: true, requireNotStealRelease: false) {
                freeSlot(any)
                remaining -= 1
                continue
            }
            break
        }
    }

    private func findFreeVoice() -> Int? {
        for i in 0..<VoiceManager.maxVoices {
            if !voices[i].isActive {
                return i
            }
        }
        // Reclaim silent actives (finished envelope that was not cleaned)
        if let silent = findSilentActiveIndex() {
            freeSlot(silent)
            return silent
        }
        return nil
    }

    private func findSilentActiveIndex() -> Int? {
        var best: Int? = nil
        var bestEnv = Float.greatestFiniteMagnitude
        for i in 0..<VoiceManager.maxVoices {
            guard voices[i].isActive else { continue }
            if voices[i].envelopePhase == .finished || voices[i].envelopeValue < VoiceManager.silentEnvelopeThreshold {
                if voices[i].envelopeValue < bestEnv {
                    bestEnv = voices[i].envelopeValue
                    best = i
                }
            }
        }
        return best
    }

    private func beginStealRelease(_ index: Int) {
        guard voices[index].isActive else { return }
        if !voices[index].isReleasing {
            voices[index].releaseStartValue = voices[index].envelopeValue
            voices[index].envelopeTime = 0.0
        }
        voices[index].isReleasing = true
        voices[index].isStealRelease = true
        if voices[index].envelopePhase != .release && voices[index].envelopePhase != .finished {
            voices[index].envelopePhase = .release
            voices[index].envelopeTime = 0.0
        }
    }

    /// Pick a steal candidate: prefer releasing / steal-release, then lowest envelope.
    private func bestStealCandidate(
        preferAlreadyReleasing: Bool,
        requireStealRelease: Bool = false,
        requireNotStealRelease: Bool = false
    ) -> Int? {
        var stealIndex: Int? = nil
        var lowestEnvelope: Float = Float.greatestFiniteMagnitude
        var bestRank = -1 // higher is better: 2 = steal-release, 1 = releasing, 0 = active

        for i in 0..<VoiceManager.maxVoices {
            guard voices[i].isActive else { continue }
            if requireStealRelease && !voices[i].isStealRelease { continue }
            if requireNotStealRelease && voices[i].isStealRelease { continue }

            let env = voices[i].envelopeValue
            let rank: Int
            if voices[i].isStealRelease {
                rank = 2
            } else if voices[i].isReleasing {
                rank = preferAlreadyReleasing ? 1 : 0
            } else {
                rank = 0
            }

            if rank > bestRank || (rank == bestRank && env < lowestEnvelope) {
                bestRank = rank
                lowestEnvelope = env
                stealIndex = i
            }
        }
        return stealIndex
    }

    private func freeSlot(_ index: Int) {
        guard voices[index].isActive else { return }
        voices[index].isActive = false
        voices[index].envelopeValue = 0.0
        voices[index].envelopePhase = .finished
        voices[index].isReleasing = false
        voices[index].isStealRelease = false
        activeVoiceCount -= 1
    }

    // MARK: - Test helpers

    /// Count voices currently in steal-release (for unit tests).
    func stealReleaseCountForTesting() -> Int {
        var n = 0
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive && voices[i].isStealRelease {
                n += 1
            }
        }
        return n
    }

    /// Force a high sustain-like envelope on all active voices (simulates held notes for steal tests).
    func forceActiveEnvelopesForTesting(_ value: Float) {
        for i in 0..<VoiceManager.maxVoices {
            if voices[i].isActive {
                voices[i].envelopeValue = value
                voices[i].envelopePhase = .sustain
                voices[i].isReleasing = false
                voices[i].isStealRelease = false
            }
        }
    }
}
