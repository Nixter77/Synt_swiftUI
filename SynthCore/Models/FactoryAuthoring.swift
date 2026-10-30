//
//  FactoryAuthoring.swift
//  Shared builder for the SYNT_30 factory, expansion, and MPE banks.
//  Init is never built here.
//

import Foundation

// SYNT_32 dead paths — never target these in factory presets:
// 1. Env2 / Mod Env / Random / S&H as a matrix source into a global destination
//    (cutoff, resonance, WT morph, vowel, FX mix, LFO rate/depth): the engine ignores it.
//    Use LFO1 / LFO2 / MSEG / velocity / aftertouch / mod wheel instead.
// 2. Formant filter ignores cutoff, resonance and filter env. Modulate `.vowel` only.
// 3. `dspReverbEnabled` is never set by default, so reverb in fxOrder / matrix is weak.
//    Set it to true on every preset where reverb should take part.
enum FactoryAuthoring {
    static let orderDelayFirst: [FXSlotID] = [.delay, .chorus, .eq, .distortion, .phaser, .reverb]
    static let orderDirtLast: [FXSlotID] = [.eq, .phaser, .chorus, .delay, .reverb, .distortion]
    static let orderVerbEarly: [FXSlotID] = [.reverb, .eq, .distortion, .phaser, .chorus, .delay]

    static func mod(_ source: ModSource, _ destination: ModDestination, _ amount: Float) -> ModMatrixEntry {
        ModMatrixEntry(source: source, destination: destination, amount: amount)
    }

    /// Three-point MSEG. Empty points would leave the generator idle.
    static func shape(rate: Float, _ start: Float, _ mid: Float, _ end: Float) -> MSEGPreset {
        var shape = MSEGPreset()
        shape.points = [
            DSPMSEGPoint(time: 0, value: start),
            DSPMSEGPoint(time: 0.42, value: mid, curve: -0.22),
            DSPMSEGPoint(time: 1, value: end, curve: 0.18)
        ]
        shape.rateHz = rate
        shape.sustainIndex = nil
        shape.triggerMode = .retrigger
        return shape
    }

    /// Tie, ratchet, and probability so the step is Sequencer Pro, not a plain gate.
    static func proSequence() -> [SequencerStep] {
        let notes = [0, 0, 3, 7, 7, 10, 12, 7, 3, 0, -5, 7, 12, 10, 7, 0]
        return (0..<16).map { index in
            SequencerStep(
                isActive: index % 2 == 0 || index == 9,
                noteOffset: notes[index],
                velocity: index % 4 == 0 ? 0.9 : 0.72,
                octave: index == 14 ? 1 : 0,
                tie: index == 4 || index == 10,
                gate: 0.62,
                ratchet: index == 8 ? 2 : 1,
                probability: index == 12 ? 0.75 : 1
            )
        }
    }

    /// Starts from `SynthPreset(name:category:)`, then applies the factory
    /// authoring defaults (osc 2 off, darker filter, quieter master). The body
    /// overrides only the fields that patch needs. Init is never built here.
    static func make(
        _ name: String,
        _ category: PresetCategory,
        _ body: (inout SynthPreset) -> Void
    ) -> SynthPreset {
        var preset = SynthPreset(name: name, category: category)
        preset.osc1Volume = 0.58
        preset.osc2Enabled = false
        preset.osc2Volume = 0.28
        preset.osc2Detune = 5
        preset.attack = 0.012
        preset.decay = 0.24
        preset.sustain = 0.72
        preset.release = 0.28
        preset.filterCutoff = 1600
        preset.filterResonance = 0.16
        preset.filterAttack = 0.008
        preset.filterDecay = 0.26
        preset.filterSustain = 0.4
        preset.filterRelease = 0.24
        preset.lfoRate = 0.4
        preset.lfoDepth = 0.2
        preset.lfoTarget = .none
        preset.lfo2Rate = 0.15
        preset.lfo2Depth = 0.2
        preset.reverbMix = 0.06
        preset.reverbRoomSize = 0.34
        preset.delayTime = 0.28
        preset.delayFeedback = 0.16
        preset.masterVolume = 0.46
        preset.arpRate = .eighth
        preset.phaserRate = 0.25
        preset.phaserMix = 0.22
        preset.distortionDrive = 0.14
        preset.distortionMix = 0.08
        preset.filter2Type = .bandPass
        preset.filter2Cutoff = 1400
        preset.filter2Resonance = 0.22
        preset.filter2Balance = 0.58
        body(&preset)
        if preset.unisonVoices <= 1 {
            preset.unisonDetune = 0
            preset.unisonSpread = 0
        }
        return preset
    }
}

// MARK: - SYNT_32 character pass

/// Pushes factory values into the upper part of the PRESET_TASTE bands and
/// enforces the SYNT_32 floors (docs/PRESET_TASTE.md, rule blocks A–E).
/// Values only: it edits preset fields, never the engine. Init is never passed in.
extension FactoryAuthoring {
    /// Categories the pass touches.
    static let characterCategories: Set<PresetCategory> = [.bass, .lead, .brass]

    static let deadSources: Set<ModSource> = [.env2, .modEnv, .random, .sampleAndHold]
    /// Destinations read once per sample from the global matrix scan.
    static let globalDestinations: Set<ModDestination> = [
        .cutoff, .resonance, .wtMorph1, .wtMorph2, .vowel, .chorusMix, .delayMix, .reverbMix, .lfoRate, .lfoDepth
    ]
    static let pitchDestinations: Set<ModDestination> = [.pitch1, .pitch2, .finePitch]
    /// Sources that move without a performer touching a controller.
    static let liveSources: Set<ModSource> = [
        .lfo1, .lfo2, .velocity, .env1, .keyTrack, .mseg, .mseg2, .smoothRandom, .envelopeFollower, .env2, .modEnv
    ]

    static func isDeadRow(_ entry: ModMatrixEntry) -> Bool {
        deadSources.contains(entry.source) && globalDestinations.contains(entry.destination)
    }

    /// Formant ignores cutoff, resonance and filter env, so those rows are not motion.
    static func isFormantDeadRow(_ entry: ModMatrixEntry, _ p: SynthPreset) -> Bool {
        p.filterType == .formant && (entry.destination == .cutoff || entry.destination == .resonance)
    }

    /// Strongest audible-by-default modulator (matrix row or enabled LFO direct target).
    static func strongestMotion(_ p: SynthPreset) -> Float {
        var best: Float = 0
        for e in p.modMatrix where liveSources.contains(e.source) && !isDeadRow(e) && !isFormantDeadRow(e, p) {
            if (e.source == .mseg && p.mseg.points.isEmpty) || (e.source == .mseg2 && p.mseg2.points.isEmpty) { continue }
            best = max(best, abs(e.amount))
        }
        if p.lfoEnabled && p.lfoTarget != .none && !(p.filterType == .formant && p.lfoTarget == .filter) {
            best = max(best, p.lfoDepth)
        }
        if p.lfo2Enabled && p.lfo2Target != .none && !(p.filterType == .formant && p.lfo2Target == .filter) {
            best = max(best, p.lfo2Depth)
        }
        return best
    }

    static func resonanceBand(_ c: PresetCategory) -> (lo: Float, hi: Float) {
        switch c {
        case .pad, .strings: return (0.10, 0.45)
        case .keys, .pluck: return (0.15, 0.55)
        default: return (0.20, 0.70)
        }
    }

    static func widthBand(_ c: PresetCategory) -> (lo: Float, hi: Float) {
        switch c {
        case .bass: return (0.90, 1.30)
        case .lead: return (1.00, 1.50)
        case .pad: return (1.20, 1.80)
        case .strings: return (1.15, 1.70)
        case .keys: return (1.00, 1.45)
        case .pluck: return (1.05, 1.55)
        case .brass: return (1.00, 1.40)
        case .arp: return (1.05, 1.60)
        case .fx: return (1.15, 1.85)
        }
    }

    /// `salt` keeps width sequences of different banks apart.
    static func characterPass(_ bank: [SynthPreset], salt: Int = 0) -> [SynthPreset] {
        var counters: [PresetCategory: Int] = [:]
        return bank.map { preset in
            let index = counters[preset.category, default: 0]
            counters[preset.category] = index + 1
            guard characterCategories.contains(preset.category), preset.name != "Init" else { return preset }
            var p = preset
            character(&p, index: index, salt: salt)
            return p
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    static func character(_ p: inout SynthPreset, index i: Int, salt: Int) {
        let c = p.category
        let acid = p.name.localizedCaseInsensitiveContains("acid")
        let upper = i % 5 < 2 || acid
        let formant = p.filterType == .formant
        let dirtCategory = c == .bass || c == .lead || c == .brass

        // A — resonance and filter env into the upper part of the band.
        if !formant {
            let band = resonanceBand(c)
            let upperFloor = band.lo + (band.hi - band.lo) * 2 / 3
            let floor = band.lo + (band.hi - band.lo) * 0.35
            p.filterResonance = min(band.hi, max(p.filterResonance, upper ? upperFloor + 0.03 : floor))
            let envFloor: Float
            switch c {
            case .brass: envFloor = 0.42
            case .bass, .lead, .pluck, .arp: envFloor = 0.35
            case .keys: envFloor = 0.28
            case .fx: envFloor = 0.25
            case .pad, .strings: envFloor = 0.18
            }
            if p.filterEnvelopeAmount >= 0 {
                p.filterEnvelopeAmount = min(0.70, max(p.filterEnvelopeAmount, upper ? 0.52 : envFloor))
            }
        }
        if acid {
            p.filterResonance = min(0.70, max(p.filterResonance, 0.63))
            p.filterEnvelopeAmount = min(0.70, max(p.filterEnvelopeAmount, 0.58))
            p.portamento = p.portamento < 0.02 || p.portamento > 0.08 ? 0.045 : p.portamento
        }
        if c == .brass {
            p.filterAttack = min(p.filterAttack, 0.03)
        }

        // B — dirt.
        if dirtCategory && (i % 5 < 4 || acid) {
            p.distortionEnabled = true
            let cap: Float = c == .brass ? 0.30 : 0.35
            p.distortionMix = min(cap, max(p.distortionMix, upper ? 0.30 : 0.20, acid ? 0.24 : 0))
            p.distortionDrive = max(p.distortionDrive, 0.22)
        }
        if p.distortionEnabled && p.distortionMix < 0.12 {
            if c == .pad || c == .strings {
                p.distortionEnabled = false
            } else {
                p.distortionMix = 0.14
            }
        }

        // C — matrix hygiene: no dead paths, no rows under 0.15.
        var rows: [ModMatrixEntry] = []
        var droppedLFO1Vibrato = false
        for var e in p.modMatrix {
            if isDeadRow(e) {
                if e.source == .random || e.source == .sampleAndHold {
                    e.source = .smoothRandom
                } else {
                    if e.destination == .cutoff && !formant && e.amount > 0 {
                        p.filterEnvelopeAmount = min(0.70, max(p.filterEnvelopeAmount, e.amount))
                    }
                    continue
                }
            }
            if abs(e.amount) < 0.15 {
                if e.amount == 0 || pitchDestinations.contains(e.destination) {
                    if e.source == .lfo1 && e.amount != 0 { droppedLFO1Vibrato = true }
                    continue
                }
                e.amount = e.amount < 0 ? -0.15 : 0.15
            }
            rows.append(e)
        }
        if droppedLFO1Vibrato && !p.lfoEnabled && !rows.contains(where: { $0.source == .lfo1 }) {
            p.lfoEnabled = true
            p.lfoTarget = .pitch
            p.lfoTempoSync = false
            p.lfoRate = min(6.0, max(4.5, p.lfoRate))
            p.lfoDepth = 0.10
        }
        if c == .lead && p.lfoEnabled && p.lfoTarget == .pitch {
            p.lfoDepth = max(p.lfoDepth, 0.10)
        }
        if c == .lead && p.lfo2Enabled && p.lfo2Target == .pitch {
            p.lfo2Depth = max(p.lfo2Depth, 0.10)
        }

        // Wobble bass: LFO1 → cutoff ≥ 0.30 (never Env2 → matrix).
        if p.name.localizedCaseInsensitiveContains("wobble") && !formant {
            if let k = rows.firstIndex(where: { $0.source == .lfo1 && $0.destination == .cutoff }) {
                rows[k].amount = (rows[k].amount < 0 ? -1 : 1) * max(abs(rows[k].amount), 0.34)
            } else if p.lfoEnabled && p.lfoTarget == .filter {
                p.lfoDepth = max(p.lfoDepth, 0.34)
            } else if rows.count < 16 {
                rows.append(mod(.lfo1, .cutoff, 0.34))
            }
        }

        // Pads / strings: slow LFO or MSEG ≥ 0.30 on cutoff, WT morph, or vowel.
        if c == .pad || c == .strings {
            let dest: ModDestination = formant ? .vowel : (p.osc1Waveform == .wavetable ? .wtMorph1 : .cutoff)
            let amount: Float = upper ? 0.42 : 0.32
            func slow(_ r: Float) -> Float { min(0.30, max(0.05, r)) }
            if let k = rows.firstIndex(where: { $0.source == .lfo2 && $0.destination == dest }) {
                rows[k].amount = (rows[k].amount < 0 ? -1 : 1) * max(abs(rows[k].amount), amount)
                p.lfo2TempoSync = false
                p.lfo2Rate = slow(p.lfo2Rate)
            } else if !p.lfoEnabled, let k = rows.firstIndex(where: { $0.source == .lfo1 && $0.destination == dest }) {
                rows[k].amount = (rows[k].amount < 0 ? -1 : 1) * max(abs(rows[k].amount), amount)
                p.lfoTempoSync = false
                p.lfoRate = slow(p.lfoRate)
            } else if rows.count < 16 {
                rows.append(mod(.lfo2, dest, amount))
                p.lfo2TempoSync = false
                p.lfo2Rate = slow(p.lfo2Rate)
            }
        }

        // Formant upper presets: the vowel carries the character.
        if formant && upper {
            if let k = rows.firstIndex(where: { $0.destination == .vowel && liveSources.contains($0.source) }) {
                rows[k].amount = (rows[k].amount < 0 ? -1 : 1) * max(abs(rows[k].amount), 0.42)
            } else if rows.count < 16 {
                rows.append(mod(.lfo2, .vowel, 0.42))
            }
            p.reverbMix = max(p.reverbMix, 0.27)
            p.dspReverbEnabled = true
        }

        // Keys: velocity into amp and cutoff.
        if c == .keys {
            p.velocityToCutoff = max(p.velocityToCutoff, upper ? 0.40 : 0.30)
            if !rows.contains(where: { $0.source == .velocity && $0.destination == .amp }) && rows.count < 16 {
                rows.append(mod(.velocity, .amp, 0.22))
            }
        }
        if c == .pluck {
            p.sustain = min(p.sustain, 0.25)
            p.velocityToCutoff = max(p.velocityToCutoff, 0.42)
        }

        p.modMatrix = rows
        // Every preset: ≥1 live modulator ≥ 0.30.
        if strongestMotion(p) < 0.30 {
            let bumpable = p.modMatrix.indices.filter { k in
                let e = p.modMatrix[k]
                return liveSources.contains(e.source) && !pitchDestinations.contains(e.destination)
                    && e.destination != .fm && !isFormantDeadRow(e, p)
                    && !(e.source == .mseg && p.mseg.points.isEmpty) && !(e.source == .mseg2 && p.mseg2.points.isEmpty)
            }
            if let k = bumpable.max(by: { abs(p.modMatrix[$0].amount) < abs(p.modMatrix[$1].amount) }) {
                p.modMatrix[k].amount = (p.modMatrix[k].amount < 0 ? -1 : 1) * 0.30
            } else if p.modMatrix.count < 16 {
                if formant {
                    p.modMatrix.append(mod(.lfo2, .vowel, 0.35))
                } else if p.osc1Waveform == .wavetable {
                    p.modMatrix.append(mod(.lfo2, .wtMorph1, 0.32))
                } else {
                    p.modMatrix.append(mod(.velocity, .cutoff, 0.30))
                }
            }
        }
        if upper && strongestMotion(p) < 0.40 {
            if let k = p.modMatrix.firstIndex(where: {
                ($0.source == .lfo1 || $0.source == .lfo2 || $0.source == .velocity)
                    && ($0.destination == .cutoff || $0.destination == .wtMorph1 || $0.destination == .vowel)
                    && !isFormantDeadRow($0, p)
            }) {
                p.modMatrix[k].amount = (p.modMatrix[k].amount < 0 ? -1 : 1) * max(abs(p.modMatrix[k].amount), 0.40)
            }
        }

        // D — FX.
        let everydayCap: Float = 0.22
        if c == .lead || c == .arp || (c == .pluck && p.delayMix > 0) {
            if p.delayMix < 0.12 {
                if p.delayMix == 0 { p.delayFeedback = max(p.delayFeedback, 0.20) }
                p.delayMix = upper ? 0.18 : 0.14
            }
            if c == .lead && !p.delayTempoSync {
                p.delayTempoSync = true
                p.delaySyncDivision = .eighth
            }
            p.delayMix = min(c == .fx ? 0.30 : everydayCap, p.delayMix)
        }
        if c == .pad || c == .strings || c == .keys {
            p.chorusMix = min(everydayCap, max(p.chorusMix, upper ? 0.20 : 0.15))
        }
        if c == .pad || c == .strings {
            p.reverbMix = min(0.30, max(p.reverbMix, upper ? 0.27 : 0.21))
            p.dspReverbEnabled = true
        }
        if c == .fx && max(p.reverbMix, p.delayMix, p.chorusMix) < 0.30 {
            p.reverbMix = max(p.reverbMix, 0.32)
            p.dspReverbEnabled = true
        }
        if c == .arp {
            p.arpGateLength = min(0.6, max(0.3, p.arpGateLength))
        }
        if p.reverbMix > 0 && (p.fxOrder != FXSlotID.defaultOrder || p.modMatrix.contains { $0.destination == .reverbMix }) {
            p.dspReverbEnabled = true
        }

        // E — voices, width, FM.
        // Unison stays off chord categories (pad/strings): the engine collapses it on the second key.
        if (c == .bass || c == .lead) && i % 2 == 0 && p.unisonVoices < 2 && !p.phaserEnabled {
            p.unisonVoices = 2
            p.unisonDetune = c == .bass ? 6 : 8
            p.unisonSpread = c == .bass ? 0.20 : 0.36
        }
        if (c == .keys || p.name.localizedCaseInsensitiveContains("bell")) && p.fmAmount > 0 {
            p.fmAmount = max(p.fmAmount, 0.15)
        }
        let band = widthBand(c)
        let frac = (Double(i + salt + 1) * 0.618_033_988_75).truncatingRemainder(dividingBy: 1)
        p.stereoEnabled = true
        p.stereoWidth = ((band.lo + (band.hi - band.lo) * Float(frac)) * 100).rounded() / 100
        if c == .bass && p.stereoMonoBassHz == 0 {
            p.stereoMonoBassHz = 120
        }

        // Engine carry limits: delay feedback ≤ 0.22, at most two wet FX after the clipper.
        if p.delayMix > 0.001 { p.delayFeedback = min(p.delayFeedback, 0.22) }
        func wetCount() -> Int {
            (p.reverbMix > 0.05 ? 1 : 0) + (p.chorusMix > 0.05 ? 1 : 0)
                + (p.delayMix > 0.05 ? 1 : 0) + (p.phaserEnabled ? 1 : 0)
        }
        if wetCount() > 2 {
            switch c {
            case .pad, .strings, .keys: if p.delayMix > 0.05 { p.delayMix = 0 }
            default: if p.chorusMix > 0.05 { p.chorusMix = 0 }
            }
        }
        if wetCount() > 2 && p.phaserEnabled { p.phaserEnabled = false }
    }
}
