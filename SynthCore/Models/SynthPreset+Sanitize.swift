//
//  SynthPreset+Sanitize.swift
//  Synt_swiftUI
//
//  Imported / restored JSON is untrusted. Clamp to safe engine bounds
//  (wide: no factory or saved-in-app value is changed) and drop NaN/Inf.
//

import Foundation

public enum PresetImportError: LocalizedError {
    case unreadable
    case tooLarge(Int)
    case notAPreset(String)

    public var errorDescription: String? {
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

public extension SynthPreset {
    public static let maxImportBytes = 256 * 1024
    public static let maxModSlots = 16

    public func sanitized() -> SynthPreset {
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
        p.osc1WavetableIndex = i(p.osc1WavetableIndex, 0, 5)
        p.osc2Volume = f(p.osc2Volume, 0, 1, d.osc2Volume)
        p.osc2Octave = i(p.osc2Octave, -4, 4)
        p.osc2Detune = f(p.osc2Detune, -1200, 1200, d.osc2Detune)
        p.osc2PulseWidth = f(p.osc2PulseWidth, 0.01, 0.99, d.osc2PulseWidth)
        p.osc2WavetableMorph = f(p.osc2WavetableMorph, 0, 1, d.osc2WavetableMorph)
        p.osc2WavetableIndex = i(p.osc2WavetableIndex, 0, 5)

        p.subOscVolume = f(p.subOscVolume, 0, 1, 0)
        p.subOscOctave = p.subOscOctave == -2 ? -2 : -1
        if p.subOscWaveform != .sine && p.subOscWaveform != .triangle && p.subOscWaveform != .square {
            p.subOscWaveform = .sine
        }
        p.fmAmount = f(p.fmAmount, 0, 1, 0)

        p.attack = f(p.attack, 0.0005, 30, d.attack)
        p.decay = f(p.decay, 0.0005, 30, d.decay)
        p.sustain = f(p.sustain, 0, 1, d.sustain)
        p.release = f(p.release, 0.0005, 30, d.release)

        p.filterCutoff = f(p.filterCutoff, 20, 22_000, d.filterCutoff)
        p.filterResonance = f(p.filterResonance, 0, 1, d.filterResonance)
        p.filterEnvelopeAmount = f(p.filterEnvelopeAmount, -1, 1, d.filterEnvelopeAmount)
        p.filterKeyTracking = f(p.filterKeyTracking, 0, 1, d.filterKeyTracking)
        p.filterAttack = f(p.filterAttack, 0.0005, 30, d.filterAttack)
        p.filterDecay = f(p.filterDecay, 0.0005, 30, d.filterDecay)
        p.filterSustain = f(p.filterSustain, 0, 1, d.filterSustain)
        p.filterRelease = f(p.filterRelease, 0.0005, 30, d.filterRelease)
        p.velocityToCutoff = f(p.velocityToCutoff, 0, 1, 0.0)
        p.velocityToEnvAmount = f(p.velocityToEnvAmount, -1, 1, 0.0)

        p.lfoRate = f(p.lfoRate, 0.01, 50, d.lfoRate)
        p.lfoDepth = f(p.lfoDepth, 0, 1, d.lfoDepth)
        p.lfo2Rate = f(p.lfo2Rate, 0.01, 50, d.lfo2Rate)
        p.lfo2Depth = f(p.lfo2Depth, 0, 1, d.lfo2Depth)

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
        p.analogDrift = f(p.analogDrift, 0, 1, 0.0)
        p.reverbShimmer = f(p.reverbShimmer, 0, 1, 0.0)
        p.ringModAmount = f(p.ringModAmount, 0, 1, 0.0)
        if !ChordMode.allCases.contains(p.chordMode) {
            p.chordMode = .off
        }

        p.modMatrix = Array(p.modMatrix.prefix(Self.maxModSlots)).map { e in
            var e = e
            e.amount = f(e.amount, -4, 4, 0)
            if !ModCurve.allCases.contains(e.curve) { e.curve = .linear }
            return e
        }

        p.bpm = f(p.bpm, 20, 300, d.bpm)
        p.arpOctaves = i(p.arpOctaves, 1, 3)
        p.arpGateLength = f(p.arpGateLength, 0.1, 1.0, 0.8)
        p.arpSwing = f(p.arpSwing, 0.0, 0.75, 0.0)
        var steps = Array(p.sequencerData.prefix(16)).map { s in
            var s = s
            // Int16/Int8 conversions downstream trap on huge values.
            s.noteOffset = i(s.noteOffset, -48, 48)
            s.octave = i(s.octave, -4, 4)
            s.velocity = f(s.velocity, 0, 1, 0.8)
            s.gate = f(s.gate, 0.05, 1.0, 0.8)
            s.ratchet = i(s.ratchet, 1, 4)
            s.probability = f(s.probability, 0, 1, 1.0)
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
        p.macro1 = f(p.macro1, -1, 1, 0.0)
        p.macro2 = f(p.macro2, -1, 1, 0.0)
        p.macro3 = f(p.macro3, -1, 1, 0.0)
        p.macro4 = f(p.macro4, -1, 1, 0.0)
        p.macro5 = f(p.macro5, -1, 1, 0.0)
        p.macro6 = f(p.macro6, -1, 1, 0.0)
        p.macro7 = f(p.macro7, -1, 1, 0.0)
        p.macro8 = f(p.macro8, -1, 1, 0.0)
        if !VoiceMode.allCases.contains(p.voiceMode) {
            p.voiceMode = .poly
        }
        if !SyncSource.allCases.contains(p.syncSource) {
            p.syncSource = .`internal`
        }
        p.filterDrive = f(p.filterDrive, 0, 1, 0)
        p.pan = f(p.pan, -1.0, 1.0, 0.0)
        p.fxOrder = Self.sanitizeFXOrder(p.fxOrder)
        if !LFOMode.allCases.contains(p.lfoMode) { p.lfoMode = .free }
        p.lfoStartPhase = f(p.lfoStartPhase, 0.0, 360.0, 0.0)
        if !LFOMode.allCases.contains(p.lfo2Mode) { p.lfo2Mode = .free }
        p.lfo2StartPhase = f(p.lfo2StartPhase, 0.0, 360.0, 0.0)
        if !ArpeggiatorMode.allCases.contains(p.arpMode) { p.arpMode = .off }
        if !VelocityCurve.allCases.contains(p.velocityCurve) { p.velocityCurve = .linear }
        p.velocityToVolume = f(p.velocityToVolume, 0.0, 1.0, 1.0)
        p.modEnvAttack = f(p.modEnvAttack, 0.001, 10.0, 0.01)
        p.modEnvDecay = f(p.modEnvDecay, 0.001, 10.0, 0.2)
        p.modEnvSustain = f(p.modEnvSustain, 0.0, 1.0, 0.0)
        p.modEnvRelease = f(p.modEnvRelease, 0.001, 10.0, 0.1)
        if !GlideMode.allCases.contains(p.glideMode) { p.glideMode = .time }
        if !MonoPriority.allCases.contains(p.monoPriority) { p.monoPriority = .last }
        p.stereoWidth = f(p.stereoWidth, 0, 2, 1)
        p.stereoMidSide = f(p.stereoMidSide, -1, 1, 0)
        p.stereoHaasMs = f(p.stereoHaasMs, 0, 30, 0)
        p.stereoMonoBassHz = f(p.stereoMonoBassHz, 0, 400, 0)
        if !OscPhaseMode.allCases.contains(p.oscPhaseMode) { p.oscPhaseMode = .reset }
        p.polyphonyLimit = i(p.polyphonyLimit, 1, 32)
        p.tranceGateDepth = f(p.tranceGateDepth, 0, 1, 1)
        p.tranceGateSmooth = f(p.tranceGateSmooth, 0, 1, 0)
        if !TimeDivision.allCases.contains(p.tranceGateDivision) { p.tranceGateDivision = .sixteenth }
        p.perlinRate = f(p.perlinRate, 0.05, 40, 1)
        if !TimeDivision.allCases.contains(p.perlinSyncDivision) { p.perlinSyncDivision = .quarter }
        p.chorusFeedback = f(p.chorusFeedback, -0.95, 0.95, 0)
        if !TimeDivision.allCases.contains(p.chorusFlangerDivision) { p.chorusFlangerDivision = .quarter }
        p.filterFeedback = f(p.filterFeedback, -1, 1, 0)
        p.reverbDamping = f(p.reverbDamping, 0, 1, 0.4)
        p.osc2FrequencyHz = f(p.osc2FrequencyHz, 20, 8000, 440)
        p.sceneHPFFrequency = f(p.sceneHPFFrequency, 20, 4000, 120)
        if !ChorusMode.allCases.contains(p.chorusMode) { p.chorusMode = .standard }
        p.fmCoarse = i(p.fmCoarse, 1, 16)
        p.fmFine = f(p.fmFine, -1, 1, 0)
        if !FMRoute.allCases.contains(p.fmRoute) { p.fmRoute = .osc2ToOsc1 }
        if !DualFilterRouting.allCases.contains(p.filter2Routing) { p.filter2Routing = .off }
        if !FilterType.allCases.contains(p.filter2Type) { p.filter2Type = .lowPass }
        p.filter2Cutoff = f(p.filter2Cutoff, 20, 20000, 2000)
        p.filter2Resonance = f(p.filter2Resonance, 0, 1, 0.2)
        p.filter2Balance = f(p.filter2Balance, 0, 1, 0.5)
        p.filterVowel = f(p.filterVowel, 0, 4, 0)
        func cleanMSEG(_ mseg: inout MSEGPreset) {
            mseg.rateHz = f(mseg.rateHz, 0.01, 100, 1)
            mseg.syncBeats = f(mseg.syncBeats, 0.0625, 32, 1)
            if mseg.points.count > DSPMSEGModel.maxPoints {
                mseg.points = Array(mseg.points.prefix(DSPMSEGModel.maxPoints))
            }
            mseg.points = mseg.points
                .map { DSPMSEGPoint(time: $0.time, value: $0.value, curve: $0.curve) }
                .sorted { $0.time < $1.time }
            let lastPoint = mseg.points.count - 1
            if lastPoint < 0 {
                mseg.loopStartIndex = nil
                mseg.loopEndIndex = nil
                mseg.sustainIndex = nil
            } else {
                if let index = mseg.loopStartIndex {
                    mseg.loopStartIndex = min(max(0, index), lastPoint)
                }
                if let index = mseg.loopEndIndex {
                    mseg.loopEndIndex = min(max(0, index), lastPoint)
                }
                if let index = mseg.sustainIndex {
                    mseg.sustainIndex = min(max(0, index), lastPoint)
                }
            }
        }
        cleanMSEG(&p.mseg)
        cleanMSEG(&p.mseg2)
        p.attackCurve = f(p.attackCurve, -1, 1, 0)
        p.decayCurve = f(p.decayCurve, -1, 1, 0)
        p.releaseCurve = f(p.releaseCurve, -1, 1, 0)
        p.lfoStereoPhase = f(p.lfoStereoPhase, 0, 360, 0)
        p.lfo2StereoPhase = f(p.lfo2StereoPhase, 0, 360, 0)
        p.frequencyShifterShiftHz = f(p.frequencyShifterShiftHz, -1000, 1000, 0)
        p.frequencyShifterMix = f(p.frequencyShifterMix, 0, 1, 0.5)
        p.frequencyShifterFeedback = f(p.frequencyShifterFeedback, -0.95, 0.95, 0)
        if !CharacterMode.allCases.contains(p.character) { p.character = .off }
        p.envFollowerAttack = f(p.envFollowerAttack, 0.001, 2.0, 0.01)
        p.envFollowerRelease = f(p.envFollowerRelease, 0.001, 2.0, 0.05)
        p.sendA = f(p.sendA, 0, 1, 0)
        p.sendB = f(p.sendB, 0, 1, 0)
        p.rotaryHornSlow = f(p.rotaryHornSlow, 0.2, 3, 0.7)
        p.rotaryHornFast = f(p.rotaryHornFast, 1, 12, 6.8)
        p.rotaryDrumSlow = f(p.rotaryDrumSlow, 0.15, 2.5, 0.55)
        p.rotaryDrumFast = f(p.rotaryDrumFast, 1, 10, 5.2)
        p.rotaryDrive = f(p.rotaryDrive, 0, 1, 0)
        p.rotaryMix = f(p.rotaryMix, 0, 1, 1)
        p.rotaryAccel = f(p.rotaryAccel, 0.2, 20, 2)
        p.transientAttack = f(p.transientAttack, -1, 1, 0)
        p.transientSustain = f(p.transientSustain, -1, 1, 0)
        p.transientOutput = f(p.transientOutput, 0, 2, 1)
        p.transientMix = f(p.transientMix, 0, 1, 1)
        return p
    }

    /// Cleans duplicate, missing, or corrupted slots so that exactly all `FXSlotID.allCases` are present once.
    static func sanitizeFXOrder(_ order: [FXSlotID]?) -> [FXSlotID] {
        guard let order, !order.isEmpty else { return FXSlotID.defaultOrder }
        var result: [FXSlotID] = []
        var seen = Set<FXSlotID>()
        for slot in order {
            if FXSlotID.allCases.contains(slot) && !seen.contains(slot) {
                seen.insert(slot)
                result.append(slot)
            }
        }
        for slot in FXSlotID.defaultOrder {
            if !seen.contains(slot) {
                seen.insert(slot)
                result.append(slot)
            }
        }
        return result
    }
}
