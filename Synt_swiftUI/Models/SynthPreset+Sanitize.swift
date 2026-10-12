//
//  SynthPreset+Sanitize.swift
//  Synt_swiftUI
//
//  Imported / restored JSON is untrusted. Clamp to safe engine bounds
//  (wide: no factory or saved-in-app value is changed) and drop NaN/Inf.
//

import Foundation

enum PresetImportError: LocalizedError {
    case unreadable
    case tooLarge(Int)
    case notAPreset(String)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "The file could not be read."
        case .tooLarge(let bytes):
            return "The file is too large to be a preset (\(bytes / 1024) KB)."
        case .notAPreset(let detail):
            return "This file is not a valid Synt preset. \(detail)"
        }
    }
}

extension SynthPreset {
    static let maxImportBytes = 256 * 1024
    static let maxModSlots = 16

    func sanitized() -> SynthPreset {
        let d = SynthPreset(name: name, category: category)
        var p = self

        func f(_ v: Float, _ lo: Float, _ hi: Float, _ fallback: Float) -> Float {
            guard v.isFinite else { return fallback }
            return min(hi, max(lo, v))
        }
        func i(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(hi, max(lo, v)) }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        p.name = trimmed.isEmpty ? "Imported" : String(trimmed.prefix(80))

        p.osc1Volume = f(p.osc1Volume, 0, 1, d.osc1Volume)
        p.osc1Octave = i(p.osc1Octave, -4, 4)
        p.osc1Detune = f(p.osc1Detune, -1200, 1200, d.osc1Detune)
        p.osc1PulseWidth = f(p.osc1PulseWidth, 0.01, 0.99, d.osc1PulseWidth)
        p.osc1WavetableMorph = f(p.osc1WavetableMorph, 0, 1, d.osc1WavetableMorph)
        p.osc2Volume = f(p.osc2Volume, 0, 1, d.osc2Volume)
        p.osc2Octave = i(p.osc2Octave, -4, 4)
        p.osc2Detune = f(p.osc2Detune, -1200, 1200, d.osc2Detune)
        p.osc2PulseWidth = f(p.osc2PulseWidth, 0.01, 0.99, d.osc2PulseWidth)
        p.osc2WavetableMorph = f(p.osc2WavetableMorph, 0, 1, d.osc2WavetableMorph)

        p.attack = f(p.attack, 0.0005, 30, d.attack)
        p.decay = f(p.decay, 0.0005, 30, d.decay)
        p.sustain = f(p.sustain, 0, 1, d.sustain)
        p.release = f(p.release, 0.0005, 30, d.release)

        p.filterCutoff = f(p.filterCutoff, 20, 22_000, d.filterCutoff)
        p.filterResonance = f(p.filterResonance, 0, 1, d.filterResonance)
        p.filterEnvelopeAmount = f(p.filterEnvelopeAmount, -1, 1, d.filterEnvelopeAmount)

        p.lfoRate = f(p.lfoRate, 0.01, 50, d.lfoRate)
        p.lfoDepth = f(p.lfoDepth, 0, 1, d.lfoDepth)

        p.reverbMix = f(p.reverbMix, 0, 1, d.reverbMix)
        p.reverbRoomSize = f(p.reverbRoomSize, 0, 1, d.reverbRoomSize)
        p.chorusRate = f(p.chorusRate, 0.01, 20, d.chorusRate)
        p.chorusDepth = f(p.chorusDepth, 0, 1, d.chorusDepth)
        p.chorusMix = f(p.chorusMix, 0, 1, d.chorusMix)
        p.delayTime = f(p.delayTime, 0.001, 2, d.delayTime)
        p.delayFeedback = f(p.delayFeedback, 0, 0.95, d.delayFeedback)
        p.delayMix = f(p.delayMix, 0, 1, d.delayMix)

        p.masterVolume = f(p.masterVolume, 0, 1, d.masterVolume)
        p.portamento = f(p.portamento, 0, 5, d.portamento)
        p.unisonVoices = i(p.unisonVoices, 1, 5)
        p.unisonDetune = f(p.unisonDetune, 0, 100, d.unisonDetune)
        p.unisonSpread = f(p.unisonSpread, 0, 1, d.unisonSpread)

        p.modMatrix = Array(p.modMatrix.prefix(Self.maxModSlots)).map { e in
            var e = e
            e.amount = f(e.amount, -4, 4, 0)
            return e
        }

        p.bpm = f(p.bpm, 20, 300, d.bpm)
        var steps = Array(p.sequencerData.prefix(16)).map { s in
            var s = s
            // Int16/Int8 conversions downstream trap on huge values.
            s.noteOffset = i(s.noteOffset, -48, 48)
            s.octave = i(s.octave, -4, 4)
            s.velocity = f(s.velocity, 0, 1, 0.8)
            return s
        }
        while steps.count < 16 { steps.append(SequencerStep()) }
        p.sequencerData = steps

        p.distortionDrive = f(p.distortionDrive, 0, 1, d.distortionDrive)
        p.distortionTone = f(p.distortionTone, 0, 1, d.distortionTone)
        p.distortionMix = f(p.distortionMix, 0, 1, d.distortionMix)

        p.eqLowGain = f(p.eqLowGain, -24, 24, d.eqLowGain)
        p.eqLowFreq = f(p.eqLowFreq, 20, 2_000, d.eqLowFreq)
        p.eqMidGain = f(p.eqMidGain, -24, 24, d.eqMidGain)
        p.eqMidFreq = f(p.eqMidFreq, 100, 10_000, d.eqMidFreq)
        p.eqMidQ = f(p.eqMidQ, 0.1, 10, d.eqMidQ)
        p.eqHighGain = f(p.eqHighGain, -24, 24, d.eqHighGain)
        p.eqHighFreq = f(p.eqHighFreq, 1_000, 20_000, d.eqHighFreq)

        p.phaserRate = f(p.phaserRate, 0.01, 20, d.phaserRate)
        p.phaserDepth = f(p.phaserDepth, 0, 1, d.phaserDepth)
        p.phaserFeedback = f(p.phaserFeedback, -0.95, 0.95, d.phaserFeedback)
        p.phaserCenterFrequency = f(p.phaserCenterFrequency, 50, 10_000, d.phaserCenterFrequency)
        p.phaserStereoSpread = f(p.phaserStereoSpread, 0, 1, d.phaserStereoSpread)
        p.phaserMix = f(p.phaserMix, 0, 1, d.phaserMix)
        p.pitchBendRange = f(p.pitchBendRange, 0, 24, d.pitchBendRange)
        return p
    }
}
