//
//  AudioEngine+Voices.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

public struct MonoNoteStack {
    public static let capacity = 16
    private var b0: (Int, Float) = (0, 0)
    private var b1: (Int, Float) = (0, 0)
    private var b2: (Int, Float) = (0, 0)
    private var b3: (Int, Float) = (0, 0)
    private var b4: (Int, Float) = (0, 0)
    private var b5: (Int, Float) = (0, 0)
    private var b6: (Int, Float) = (0, 0)
    private var b7: (Int, Float) = (0, 0)
    private var b8: (Int, Float) = (0, 0)
    private var b9: (Int, Float) = (0, 0)
    private var b10: (Int, Float) = (0, 0)
    private var b11: (Int, Float) = (0, 0)
    private var b12: (Int, Float) = (0, 0)
    private var b13: (Int, Float) = (0, 0)
    private var b14: (Int, Float) = (0, 0)
    private var b15: (Int, Float) = (0, 0)
    private(set) var count: Int = 0

    public var isEmpty: Bool { count == 0 }

    public mutating func clear() {
        count = 0
    }

    public var top: (note: Int, velocity: Float)? {
        guard count > 0 else { return nil }
        return get(count - 1)
    }

    public func activeNote(priority: MonoPriority) -> (note: Int, velocity: Float)? {
        guard count > 0 else { return nil }
        switch priority {
        case .last:
            return get(count - 1)
        case .low:
            var lowest = get(0)
            for i in 1..<count {
                let item = get(i)
                if item.0 < lowest.0 {
                    lowest = item
                }
            }
            return lowest
        case .high:
            var highest = get(0)
            for i in 1..<count {
                let item = get(i)
                if item.0 > highest.0 {
                    highest = item
                }
            }
            return highest
        }
    }

    public func get(_ index: Int) -> (note: Int, velocity: Float) {
        switch index {
        case 0: return b0
        case 1: return b1
        case 2: return b2
        case 3: return b3
        case 4: return b4
        case 5: return b5
        case 6: return b6
        case 7: return b7
        case 8: return b8
        case 9: return b9
        case 10: return b10
        case 11: return b11
        case 12: return b12
        case 13: return b13
        case 14: return b14
        case 15: return b15
        default: return (0, 0)
        }
    }

    public mutating func set(_ index: Int, _ value: (Int, Float)) {
        switch index {
        case 0: b0 = value
        case 1: b1 = value
        case 2: b2 = value
        case 3: b3 = value
        case 4: b4 = value
        case 5: b5 = value
        case 6: b6 = value
        case 7: b7 = value
        case 8: b8 = value
        case 9: b9 = value
        case 10: b10 = value
        case 11: b11 = value
        case 12: b12 = value
        case 13: b13 = value
        case 14: b14 = value
        case 15: b15 = value
        default: break
        }
    }

    public mutating func push(note: Int, velocity: Float) {
        remove(note: note)
        if count < Self.capacity {
            set(count, (note, velocity))
            count += 1
        } else {
            for i in 0..<(Self.capacity - 1) {
                set(i, get(i + 1))
            }
            set(Self.capacity - 1, (note, velocity))
        }
    }

    @discardableResult
    public mutating func remove(note: Int) -> Bool {
        guard count > 0 else { return false }
        var foundIndex: Int?
        for i in 0..<count {
            if get(i).0 == note {
                foundIndex = i
                break
            }
        }
        guard let idx = foundIndex else { return false }
        for i in idx..<(count - 1) {
            set(i, get(i + 1))
        }
        count -= 1
        return true
    }
}

public extension AudioEngine {
    // MARK: - Voices (fixed pool; audio thread)

    func clearAllVoices() {
        for i in 0..<AudioEngine.maxVoices {
            voices[i].deactivate()
            resetVoiceToneBanks(at: i)
        }
        activeVoiceCountRT = 0
        lastPlayedFrequency = nil
        releaseSerialRT = 1
        sustainedLo = 0
        sustainedHi = 0
        monoNoteStack.clear()
        cleanBus.reset()
    }

    /// Fixed-pool allocation (audio thread). No Dictionary / heap ids.
    func createVoice(midiNote: Int, velocity: Float, hadHeldNotes: Bool = false, channel: UInt8 = 0) {
        clearSustainBit(midiNote)
        // Soft re-trigger: fade previous partials of this MIDI note (hard kill = click).
        for i in 0..<AudioEngine.maxVoices {
            let channelMatch = !cachedMpeEnabled || channel < 1 || voices[i].midiChannel == channel
            if voices[i].isActive && voices[i].midiNote == midiNote && channelMatch && !voices[i].isReleasing {
                voices[i].beginFastRelease()
            }
        }

        let baseFreq = noteToFrequency(midiNote)
        let startFreq: Double
        if activeVoiceCountRT == 0 || cachedPortamento <= 0.001 || (cachedGlideLegatoOnly && !hadHeldNotes) {
            startFreq = baseFreq
        } else {
            startFreq = lastPlayedFrequency ?? baseFreq
        }
        lastPlayedFrequency = baseFreq

        let semitoneInterval: Float
        if startFreq > 0 {
            semitoneInterval = abs(Float(12.0 * log2(baseFreq / startFreq)))
        } else {
            semitoneInterval = 0
        }

        // Unison only for a single held note. Any second key collapses to 1 partial
        // per note so a 3–4 note chord does not spawn extra oscillators.
        let otherNotes = uniqueActiveMIDINoteCountExcluding(midiNote: midiNote)
        if otherNotes >= 1 {
            collapseExtraUnisonPartials()
        }
        let minPartials = cachedChordMode != .off ? 3 : 1
        let requested = max(minPartials, min(5, cachedUnisonVoices))
        let unisonCount = otherNotes >= 1 ? 1 : requested

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
                let chordSemitones = cachedChordMode.semitoneOffset(for: u, totalPartials: unisonCount)
                let totalCents = detuneCents + chordSemitones * 100.0

                targetFreq = AudioMath.detuneFrequency(baseFreq, cents: totalCents)
                curFreq = AudioMath.detuneFrequency(startFreq, cents: totalCents)
                let panPos = (Float(u) / Float(unisonCount - 1)) * 2.0 - 1.0
                pan = panPos * spreadAmount
            }

            var seed = randomSeed
            if seed == 0 { seed = 0x12345678 }
            seed ^= seed << 13
            seed ^= seed >> 17
            seed ^= seed << 5
            randomSeed = seed

            voices[slot].activate(
                midiNote: midiNote,
                velocity: velocity,
                frequency: curFreq,
                pan: pan,
                unisonScale: partialScale,
                partial: u,
                partialCount: unisonCount,
                phaseMode: cachedOscPhaseMode,
                randomSeed: seed
            )
            voices[slot].targetFrequency = targetFreq
            voices[slot].currentFrequency = curFreq
            voices[slot].glideIntervalSemitones = semitoneInterval
            if cachedMpeEnabled && channel >= 1 {
                let ch = Int(channel & 15)
                voices[slot].midiChannel = channel
                voices[slot].mpePitchBend = mpeChannelStates[ch].pitchBend
                voices[slot].mpePitchBendMultiplier = mpeChannelStates[ch].pitchBendMultiplier
                voices[slot].mpePressure = mpeChannelStates[ch].pressure
                voices[slot].mpeTimbre = mpeChannelStates[ch].timbre
                voices[slot].smoothedMpePitchBend = mpeChannelStates[ch].pitchBend
                voices[slot].smoothedMpePressure = mpeChannelStates[ch].pressure
                voices[slot].smoothedMpeTimbre = mpeChannelStates[ch].timbre
            }
            resetVoiceToneBanks(at: slot)

            let randVal = Float(seed) / Float(UInt32.max) * 2.0 - 1.0
            voices[slot].randomValue = randVal

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
        let upper: Int
        if cachedPolyphonyLimit >= AudioEngine.maxVoices || cachedPolyphonyLimit <= 0 {
            upper = AudioEngine.maxVoices
        } else {
            upper = cachedPolyphonyLimit
        }
        for i in 0..<upper {
            if !voices[i].isActive { return i }
        }
        // Prefer reclaiming almost-silent / fast-releasing voices
        var quietRelease: Int?
        var quietEnv: Float = 0.05
        var bestSteal: Int?
        var bestStealEnv: Float = Float.greatestFiniteMagnitude
        for i in 0..<upper {
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
            resetVoiceToneBanks(at: quietRelease)
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return quietRelease
        }
        // Soft-steal: start 6 ms fade; try to find another free after... we need a slot now.
        // Deactivate only if already very quiet; otherwise force-fade and take quietest.
        if let bestSteal, bestStealEnv < 0.08 {
            voices[bestSteal].deactivate()
            resetVoiceToneBanks(at: bestSteal)
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return bestSteal
        }
        if let bestSteal {
            // Last resort hard take after starting fade was not enough — take quietest
            voices[bestSteal].deactivate()
            resetVoiceToneBanks(at: bestSteal)
            activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            return bestSteal
        }
        return nil
    }

    func internalNoteOff(midiNote: Int, channel: UInt8 = 0) {
        if sustainPedalDown {
            setSustainBit(midiNote)
            return
        }
        releaseHeldNote(midiNote, channel: channel)
    }

    func retuneActiveVoicesLegato(to midiNote: Int, velocity: Float) {
        let baseFreq = noteToFrequency(midiNote)
        var anyFound = false

        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive, !voices[i].isReleasing else { continue }
            anyFound = true

            let unisonCount = max(1, voices[i].partialCount)
            let u = voices[i].partial
            let targetFreq: Double

            if unisonCount <= 1 {
                targetFreq = baseFreq
            } else {
                let centerOffset = Float(u) - Float(unisonCount - 1) / 2.0
                let detuneCents = centerOffset * cachedUnisonDetune
                let chordSemitones = cachedChordMode.semitoneOffset(for: u, totalPartials: unisonCount)
                let totalCents = detuneCents + chordSemitones * 100.0
                targetFreq = AudioMath.detuneFrequency(baseFreq, cents: totalCents)
            }

            voices[i].midiNote = midiNote
            voices[i].targetFrequency = targetFreq
            let semitoneInterval: Float
            if voices[i].currentFrequency > 0 {
                semitoneInterval = abs(Float(12.0 * log2(targetFreq / voices[i].currentFrequency)))
            } else {
                semitoneInterval = 0
            }
            voices[i].glideIntervalSemitones = semitoneInterval
            if cachedPortamento <= 0.001 {
                voices[i].currentFrequency = targetFreq
            }
        }

        lastPlayedFrequency = baseFreq

        if !anyFound {
            createVoice(midiNote: midiNote, velocity: velocity)
        }
    }

    func handleNoteOn(midiNote: Int, velocity: Float, channel: UInt8 = 0) {
        mseg.trigger()
        mseg2.trigger()
        if lfo.mode != .free {
            lfo.trigger()
        }
        if lfo2.mode != .free {
            lfo2.trigger()
        }
        switch cachedVoiceMode {
        case .poly:
            createVoice(midiNote: midiNote, velocity: velocity, channel: channel)

        case .mono:
            let hadHeldNotes = !monoNoteStack.isEmpty
            let noteBefore = monoNoteStack.activeNote(priority: cachedMonoPriority)?.note
            monoNoteStack.push(note: midiNote, velocity: velocity)
            let active = monoNoteStack.activeNote(priority: cachedMonoPriority)

            if !hadHeldNotes || active?.note != noteBefore {
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiNote != (active?.note ?? midiNote) && !voices[i].isReleasing {
                        voices[i].beginFastRelease()
                    }
                }
                if let target = active {
                    createVoice(midiNote: target.note, velocity: target.velocity, hadHeldNotes: hadHeldNotes, channel: channel)
                }
            }

        case .legato:
            let hadHeldNotes = !monoNoteStack.isEmpty
            let noteBefore = monoNoteStack.activeNote(priority: cachedMonoPriority)?.note
            monoNoteStack.push(note: midiNote, velocity: velocity)
            let active = monoNoteStack.activeNote(priority: cachedMonoPriority)

            if !hadHeldNotes {
                let savedPort = cachedPortamento
                cachedPortamento = 0.0
                createVoice(midiNote: midiNote, velocity: velocity, hadHeldNotes: false, channel: channel)
                cachedPortamento = savedPort
                lastPlayedFrequency = noteToFrequency(midiNote)
            } else if active?.note != noteBefore, let target = active {
                retuneActiveVoicesLegato(to: target.note, velocity: target.velocity)
            }
        }
    }

    func handleNoteOff(midiNote: Int, channel: UInt8 = 0) {
        switch cachedVoiceMode {
        case .poly:
            internalNoteOff(midiNote: midiNote, channel: channel)

        case .mono:
            if !monoNoteStackContains(midiNote) {
                // Key went down in another mode (e.g. Poly): plain release.
                internalNoteOff(midiNote: midiNote, channel: channel)
                return
            }
            if sustainPedalDown {
                setSustainBit(midiNote)
                return
            }
            clearSustainBit(midiNote)
            let activeBefore = monoNoteStack.activeNote(priority: cachedMonoPriority)?.note
            monoNoteStack.remove(note: midiNote)
            let activeAfter = monoNoteStack.activeNote(priority: cachedMonoPriority)

            if activeBefore == midiNote || (activeBefore != nil && activeAfter?.note != activeBefore) {
                if let prev = activeAfter {
                    for i in 0..<AudioEngine.maxVoices {
                        if voices[i].isActive && !voices[i].isReleasing {
                            voices[i].beginFastRelease()
                        }
                    }
                    createVoice(midiNote: prev.note, velocity: prev.velocity, hadHeldNotes: true, channel: channel)
                } else {
                    releaseHeldNote(midiNote, channel: channel)
                }
            }

        case .legato:
            if !monoNoteStackContains(midiNote) {
                // Key went down in another mode (e.g. Poly): plain release.
                internalNoteOff(midiNote: midiNote, channel: channel)
                return
            }
            if sustainPedalDown {
                setSustainBit(midiNote)
                return
            }
            clearSustainBit(midiNote)
            let activeBefore = monoNoteStack.activeNote(priority: cachedMonoPriority)?.note
            monoNoteStack.remove(note: midiNote)
            let activeAfter = monoNoteStack.activeNote(priority: cachedMonoPriority)

            if activeBefore == midiNote || (activeBefore != nil && activeAfter?.note != activeBefore) {
                if let prev = activeAfter {
                    retuneActiveVoicesLegato(to: prev.note, velocity: prev.velocity)
                } else {
                    releaseHeldNote(midiNote, channel: channel)
                }
            }
        }
    }

    func monoNoteStackContains(_ note: Int) -> Bool {
        for i in 0..<monoNoteStack.count where monoNoteStack.get(i).note == note { return true }
        return false
    }

    func setSustainPedal(down: Bool) {
        if sustainPedalDown && !down {
            sustainPedalDown = false
            releaseAllSustained()
            return
        }
        sustainPedalDown = down
    }

    func setSustainBit(_ note: Int) {
        guard note >= 0, note < 128 else { return }
        if note < 64 {
            sustainedLo |= UInt64(1) << note
        } else {
            sustainedHi |= UInt64(1) << (note - 64)
        }
    }

    func clearSustainBit(_ note: Int) {
        guard note >= 0, note < 128 else { return }
        if note < 64 {
            sustainedLo &= ~(UInt64(1) << note)
        } else {
            sustainedHi &= ~(UInt64(1) << (note - 64))
        }
    }

    func releaseAllSustained() {
        let lo = sustainedLo
        let hi = sustainedHi
        sustainedLo = 0
        sustainedHi = 0
        if lo == 0 && hi == 0 { return }
        if cachedVoiceMode == .poly {
            monoNoteStack.clear()
            for i in 0..<64 {
                let bit = UInt64(1) << i
                if lo & bit != 0 { releaseHeldNote(i) }
                if hi & bit != 0 { releaseHeldNote(i + 64) }
            }
            return
        }
        // Mono/Legato: drop only the pedal-held keys from the stack. Keys still
        // physically held stay, so their own note-off releases them later.
        let topBefore = monoNoteStack.top?.note
        for i in 0..<64 {
            let bit = UInt64(1) << i
            if lo & bit != 0 { monoNoteStack.remove(note: i) }
            if hi & bit != 0 { monoNoteStack.remove(note: i + 64) }
        }
        let top = monoNoteStack.top
        for i in 0..<64 {
            let bit = UInt64(1) << i
            if lo & bit != 0, i != top?.note { releaseHeldNote(i) }
            if hi & bit != 0, i + 64 != top?.note { releaseHeldNote(i + 64) }
        }
        if let top, top.note != topBefore {
            if cachedVoiceMode == .mono {
                for i in 0..<AudioEngine.maxVoices where voices[i].isActive && !voices[i].isReleasing {
                    voices[i].beginFastRelease()
                }
                createVoice(midiNote: top.note, velocity: top.velocity)
            } else {
                retuneActiveVoicesLegato(to: top.note, velocity: top.velocity)
            }
        }
    }

    /// Device gone (audio thread): pedal up, bend centred, every key released.
    func applyMIDIResetRT() {
        sustainPedalDown = false
        pitchBendTarget = 0
        aftertouchTarget = 0
        aftertouchSmoothed = 0
        cachedMacro1 = 0
        cachedMacro2 = 0
        cachedMacro3 = 0
        cachedMacro4 = 0
        monoNoteStack.clear()
        for i in 0..<16 {
            mpeChannelStates[i] = MPEChannelState()
        }
        releaseAllHeldNotesRT()
    }

    /// MIDI CC123 (audio thread). MIDI 1.0: All Notes Off is a note-off for
    /// every key, so with the sustain pedal down the voices keep sounding (they
    /// become pedal-held) until the pedal lifts. Pedal up: every voice enters
    /// its release. Arp keys are dropped either way. Pedal state is left as is.
    func releaseAllHeldNotesRT() {
        if sustainPedalDown {
            for i in 0..<AudioEngine.maxVoices where voices[i].isActive && !voices[i].isReleasing {
                setSustainBit(voices[i].midiNote)
            }
        } else {
            sustainedLo = 0
            sustainedHi = 0
            monoNoteStack.clear()
            for i in 0..<AudioEngine.maxVoices where voices[i].isActive && !voices[i].isReleasing {
                releaseHeldNote(voices[i].midiNote)
            }
        }
        if !heldKeysForArp.isEmpty || !latchedKeysForArp.isEmpty {
            heldKeysForArp.removeAll()
            latchedKeysForArp.removeAll()
            playedKeysForArp.removeAll(keepingCapacity: true)
            arp.mode = cachedArpMode
            arp.setHeldKeys(heldKeysForArp, playedOrder: playedKeysForArp)
        }
    }

    func releaseHeldNote(_ midiNote: Int, channel: UInt8 = 0) {
        let serial = releaseSerialRT
        var released = false
        for i in 0..<AudioEngine.maxVoices {
            let channelMatch = !cachedMpeEnabled || channel < 1 || voices[i].midiChannel == channel
            if voices[i].isActive && voices[i].midiNote == midiNote && channelMatch && !voices[i].isReleasing {
                voices[i].isReleasing = true
                voices[i].releaseSerial = serial
                voices[i].releaseStartValue = voices[i].envelopeValue
                voices[i].envelopePhase = .release
                voices[i].envelopeTime = 0
                voices[i].filterReleaseStartLevel = voices[i].filterEnvelopeValue
                voices[i].filterEnvelopePhase = .release
                voices[i].filterEnvelopeTime = 0
                voices[i].modReleaseStartLevel = voices[i].modEnvelopeValue
                voices[i].modEnvelopePhase = .release
                voices[i].modEnvelopeTime = 0
                released = true
            }
        }
        if released {
            releaseSerialRT &+= 1
        }
    }

    /// While some notes stay held, only the newest released tails keep the
    /// authored release. Older leftovers fade in 6 ms so a new chord is not
    /// summed with the previous one. Nothing held: the last gesture rings out.
    /// A short preset release is the pluck and is not shortened further.
    func trimAbandonedTails() {
        if envelope.release <= AudioEngine.tailTrimSkipsReleaseAtOrBelow { return }

        var held = 0
        var musicalCount = 0
        var newest = Int.min
        var second = Int.min
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            if !voices[i].isReleasing {
                held += 1
                continue
            }
            if voices[i].fastRelease { continue }
            musicalCount += 1
            let serial = voices[i].releaseSerial
            if serial >= newest {
                second = newest
                newest = serial
            } else if serial > second {
                second = serial
            }
        }
        guard held > 0, musicalCount > AudioEngine.keptReleaseTails else { return }

        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive, voices[i].isReleasing, !voices[i].fastRelease else { continue }
            if voices[i].releaseSerial < second {
                voices[i].accelerateRelease()
            }
        }
    }
}
