//
//  AudioEngine+Voices.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

extension AudioEngine {
    // MARK: - Voices (fixed pool; audio thread)

    func clearAllVoices() {
        for i in 0..<AudioEngine.maxVoices {
            voices[i].deactivate()
        }
        activeVoiceCountRT = 0
        lastPlayedFrequency = nil
    }

    /// Fixed-pool allocation (audio thread). No Dictionary / heap ids.
    func createVoice(midiNote: Int, velocity: Float) {
        // Soft re-trigger: fade previous partials of this MIDI note (hard kill = click).
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                voices[i].beginFastRelease()
            }
        }

        let baseFreq = AudioMath.midiToFrequency(midiNote)
        let startFreq: Double
        if activeVoiceCountRT == 0 || cachedPortamento <= 0.001 {
            startFreq = baseFreq
        } else {
            startFreq = lastPlayedFrequency ?? baseFreq
        }
        lastPlayedFrequency = baseFreq

        // Unison only for a single held note. Any second key collapses to 1 partial
        // per note so a 3–4 note chord does not spawn extra oscillators.
        let otherNotes = uniqueActiveMIDINoteCountExcluding(midiNote: midiNote)
        if otherNotes >= 1 {
            collapseExtraUnisonPartials()
        }
        let requested = max(1, min(5, cachedUnisonVoices))
        let unisonCount = otherNotes >= 1 ? 1 : min(3, requested)

        let detuneAmount = cachedUnisonDetune
        let spreadAmount = cachedUnisonSpread
        let partialScale = AudioMath.unisonScale(partials: unisonCount)

        for u in 0..<unisonCount {
            guard let slot = findFreeVoiceSlot() else { break }

            let targetFreq: Double
            let curFreq: Double
            let pan: Float
            if unisonCount <= 1 {
                targetFreq = baseFreq
                curFreq = startFreq
                pan = 0
            } else {
                let centerOffset = Float(u) - Float(unisonCount - 1) / 2.0
                let detuneCents = centerOffset * detuneAmount
                targetFreq = AudioMath.detuneFrequency(baseFreq, cents: detuneCents)
                curFreq = AudioMath.detuneFrequency(startFreq, cents: detuneCents)
                let panPos = (Float(u) / Float(unisonCount - 1)) * 2.0 - 1.0
                pan = panPos * spreadAmount
            }

            voices[slot].activate(
                midiNote: midiNote,
                velocity: velocity,
                frequency: curFreq,
                pan: pan,
                unisonScale: partialScale
            )
            voices[slot].targetFrequency = targetFreq
            voices[slot].currentFrequency = curFreq
            activeVoiceCountRT += 1
        }
    }

    /// Fade extra unison partials so each MIDI note keeps one sounding voice.
    func collapseExtraUnisonPartials() {
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive, !voices[i].isReleasing else { continue }
            for j in (i + 1)..<AudioEngine.maxVoices {
                guard voices[j].isActive, !voices[j].isReleasing else { continue }
                guard voices[j].midiNote == voices[i].midiNote else { continue }
                if voices[j].envelopeValue > voices[i].envelopeValue {
                    voices[i].beginFastRelease()
                    voices[j].unisonScale = 1
                } else {
                    voices[j].beginFastRelease()
                    voices[i].unisonScale = 1
                }
            }
        }
    }

    func uniqueActiveMIDINoteCountExcluding(midiNote: Int) -> Int {
        var lo: UInt64 = 0
        var hi: UInt64 = 0
        var count = 0
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            let n = voices[i].midiNote
            if n == midiNote { continue }
            if n >= 0 && n < 64 {
                let bit: UInt64 = 1 << n
                if lo & bit == 0 { lo |= bit; count += 1 }
            } else if n >= 64 && n < 128 {
                let bit: UInt64 = 1 << (n - 64)
                if hi & bit == 0 { hi |= bit; count += 1 }
            }
        }
        return count
    }

    func findFreeVoiceSlot() -> Int? {
        for i in 0..<AudioEngine.maxVoices {
            if !voices[i].isActive { return i }
        }
        // Prefer reclaiming almost-silent / fast-releasing voices
        var quietRelease: Int?
        var quietEnv: Float = 0.05
        var bestSteal: Int?
        var bestStealEnv: Float = Float.greatestFiniteMagnitude
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            let env = voices[i].envelopeValue
            if voices[i].isReleasing && env < quietEnv {
                quietEnv = env
                quietRelease = i
            }
            if env < bestStealEnv {
                bestStealEnv = env
                bestSteal = i
            }
        }
        if let quietRelease {
            voices[quietRelease].deactivate()
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return quietRelease
        }
        // Soft-steal: start 6 ms fade; try to find another free after... we need a slot now.
        // Deactivate only if already very quiet; otherwise force-fade and take quietest.
        if let bestSteal, bestStealEnv < 0.08 {
            voices[bestSteal].deactivate()
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return bestSteal
        }
        if let bestSteal {
            // Last resort hard take after starting fade was not enough — take quietest
            voices[bestSteal].deactivate()
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return bestSteal
        }
        return nil
    }

    func internalNoteOff(midiNote: Int) {
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive && voices[i].midiNote == midiNote && !voices[i].isReleasing {
                voices[i].isReleasing = true
                voices[i].releaseStartValue = voices[i].envelopeValue
                voices[i].envelopePhase = .release
                voices[i].envelopeTime = 0
            }
        }
    }
}
