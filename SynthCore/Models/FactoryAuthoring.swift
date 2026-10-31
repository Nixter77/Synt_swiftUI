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
    static let characterCategories: Set<PresetCategory> = Set(PresetCategory.allCases)

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

        // SYNT_33 — the name decides the sound.
        contrast(&p, index: i, salt: salt, upper: upper, acid: acid)
        weakSpots(&p, index: i, upper: upper)
        identity(&p, index: i, salt: salt, acid: acid)
        velocity(&p, index: i, salt: salt)
        loudness(&p)
        categoryGesture(&p)
        antiDull(&p)
        periodicMotion(&p, index: i)

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

// MARK: - SYNT_33 identity pass

/// Name keywords pull a preset toward what its name promises (docs/PRESET_TASTE.md,
/// "SYNT_33 identity"). Runs after the SYNT_32 floors; it never goes below them.
extension FactoryAuthoring {
    static let softWords = ["soft", "velvet", "warm", "whisper", "silk", "round", "mellow"]
    static let darkWords = ["dark", "noir", "muted"]
    static let brightWords = ["bright", "crystal", "glass", "air"]
    static let wideWords = ["wide", "super", "cloud", "horizon"]
    static let hardWords = ["hard", "growl", "screamer", "grit", "dirty", "overdrive"]
    static let motionWords = ["drift", "motion", "morph", "wobble"]

    static func has(_ p: SynthPreset, _ words: [String]) -> Bool {
        let n = p.name.lowercased()
        return words.contains { n.contains($0) }
    }

    static func isDirtCategory(_ c: PresetCategory) -> Bool { c == .bass || c == .lead || c == .brass }

    static func identity(_ p: inout SynthPreset, index i: Int, salt: Int, acid: Bool) {
        let c = p.category
        let formant = p.filterType == .formant
        let band = resonanceBand(c)
        let mid = (band.lo + band.hi) / 2
        let width = widthBand(c)
        let frac = Float((Double(i + salt + 1) * 0.618_033_988_75).truncatingRemainder(dividingBy: 1))

        if has(p, softWords) {
            if p.distortionEnabled {
                p.distortionMix = min(p.distortionMix, 0.22)
                p.distortionDrive = min(p.distortionDrive, 0.22)
            }
            if !formant && !acid {
                p.filterResonance = min(p.filterResonance, ((mid - 0.01) * 100).rounded() / 100)
            }
            let wMid = (width.lo + width.hi) / 2
            p.stereoWidth = ((width.lo + (wMid - width.lo) * frac) * 100).rounded() / 100
        }
        if has(p, darkWords) && !formant {
            p.filterCutoff = min(p.filterCutoff, 1400)
        }
        if has(p, brightWords) && !formant && c != .bass {
            p.filterCutoff = max(p.filterCutoff, 2200)
            p.filterResonance = min(band.hi, max(p.filterResonance, ((mid + 0.01) * 100).rounded() / 100))
        }
        if has(p, wideWords) {
            let lo = width.lo + (width.hi - width.lo) * 2 / 3
            p.stereoWidth = ((lo + 0.01 + (width.hi - lo - 0.01) * frac) * 100).rounded() / 100
        }
        if has(p, hardWords) {
            if isDirtCategory(c) {
                p.distortionEnabled = true
                p.distortionMix = min(0.35, max(p.distortionMix, 0.30))
                p.distortionDrive = max(p.distortionDrive, 0.26)
            } else if p.distortionEnabled {
                p.distortionDrive = max(p.distortionDrive, 0.30)
            }
        }
        if has(p, motionWords) && strongestMotion(p) < 0.40 {
            if let k = p.modMatrix.indices.filter({ k in
                let e = p.modMatrix[k]
                return liveSources.contains(e.source) && !pitchDestinations.contains(e.destination)
                    && e.destination != .fm && !isDeadRow(e) && !isFormantDeadRow(e, p)
                    && !(e.source == .mseg && p.mseg.points.isEmpty) && !(e.source == .mseg2 && p.mseg2.points.isEmpty)
            }).max(by: { abs(p.modMatrix[$0].amount) < abs(p.modMatrix[$1].amount) }) {
                p.modMatrix[k].amount = (p.modMatrix[k].amount < 0 ? -1 : 1) * 0.40
            }
        }
    }
}

// MARK: - SYNT_33 category weak spots

extension FactoryAuthoring {
    static func weakSpots(_ p: inout SynthPreset, index i: Int, upper: Bool) {
        switch p.category {
        // Brass unison dropped: chord-safety rule (unison only bass/lead/fx).
        case .arp:
            // Bite on the lower-band arps: light dirt the upper ones get from filter env.
            if !upper && !p.distortionEnabled {
                p.distortionEnabled = true
                p.distortionMix = 0.16
                p.distortionDrive = max(p.distortionDrive, 0.20)
            }
        case .pluck:
            // Dry plucks get a short room so they don't sit in a vacuum.
            if p.delayMix <= 0.05 && p.reverbMix < 0.15 {
                p.reverbMix = 0.16
            }
        default:
            break
        }
    }
}

// MARK: - SYNT_33 contrast

/// SYNT_32 put every preset on one of two floor values per band, so neighbours
/// in a category came out as clones. Stagger res, filter env and dirt by index
/// inside the same sub-band (lower or upper third), never below the floors.
extension FactoryAuthoring {
    static func stagger(_ i: Int, _ salt: Int, _ k: Double) -> Float {
        Float((Double(i + salt + 1) * k).truncatingRemainder(dividingBy: 1))
    }

    static func contrast(_ p: inout SynthPreset, index i: Int, salt: Int, upper: Bool, acid: Bool) {
        let c = p.category
        guard !acid else { return }
        func r2(_ x: Float) -> Float { (x * 100).rounded() / 100 }
        if p.filterType != .formant {
            let band = resonanceBand(c)
            let upperFloor = band.lo + (band.hi - band.lo) * 2 / 3
            let floor = band.lo + (band.hi - band.lo) * 0.35
            let (lo, hi) = upper ? (upperFloor + 0.01, band.hi - 0.02) : (floor, upperFloor - 0.02)
            if p.filterResonance >= lo - 0.001 && p.filterResonance <= hi + 0.04 {
                p.filterResonance = r2(lo + (hi - lo) * stagger(i, salt, 0.414_213_562))
            }
            if p.filterEnvelopeAmount > 0 {
                let envLo = max(p.filterEnvelopeAmount, 0)
                let envHi: Float = upper ? 0.68 : 0.49
                if envHi > envLo {
                    p.filterEnvelopeAmount = r2(envLo + (envHi - envLo) * stagger(i, salt, 0.732_050_808))
                }
            }
        }
        // Space: spread wet amounts across the allowed band instead of two fixed values.
        let w = stagger(i, salt, 0.302_775_638)
        switch c {
        case .pad, .strings:
            p.reverbMix = r2(0.20 + 0.10 * w)
            p.chorusMix = r2(0.14 + 0.08 * stagger(i, salt, 0.561_552_813))
        case .keys:
            p.chorusMix = r2(0.14 + 0.08 * w)
        case .lead, .arp:
            p.delayMix = r2(0.12 + 0.10 * w)
        case .pluck where p.delayMix > 0.05:
            p.delayMix = r2(0.12 + 0.10 * w)
        case .fx where p.reverbMix >= 0.30:
            p.reverbMix = r2(0.30 + 0.05 * w)
        default:
            break
        }
        if isDirtCategory(c) && p.distortionEnabled && p.distortionMix >= 0.18 {
            let (lo, hi): (Float, Float) = p.distortionMix >= 0.29 ? (0.29, 0.35) : (0.18, 0.28)
            p.distortionMix = r2(lo + (hi - lo) * stagger(i, salt, 0.236_067_977))
        }
    }
}

// MARK: - SYNT_35 velocity floors

extension FactoryAuthoring {
    static let velocitySoftWords = ["soft", "velvet", "whisper"]

    /// Soft vs hard must read: adds velocity→cutoff / →amp only where a preset has none.
    /// Runs after `identity`; never lowers an existing amount and adds no dirt.
    static func velocity(_ p: inout SynthPreset, index i: Int, salt: Int) {
        let c = p.category
        let formant = p.filterType == .formant
        func r2(_ x: Float) -> Float { (x * 100).rounded() / 100 }
        let soft = has(p, velocitySoftWords)
        let t = stagger(i, salt, 0.381_966_011) * (soft ? 0.5 : 1)
        func ampRow() -> Float {
            p.modMatrix.filter { $0.source == .velocity && $0.destination == .amp }.map { abs($0.amount) }.max() ?? 0
        }
        func cutRow() -> Float {
            p.modMatrix.filter { $0.source == .velocity && $0.destination == .cutoff }.map { abs($0.amount) }.max() ?? 0
        }
        func addAmp(_ lo: Float, _ hi: Float) {
            guard p.modMatrix.count < 16 else { return }
            p.modMatrix.append(mod(.velocity, .amp, r2(lo + (hi - lo) * t)))
        }
        switch c {
        case .bass, .lead:
            let cut = formant ? 0 : max(p.velocityToCutoff, cutRow())
            guard max(cut, ampRow()) < 0.15 else { return }
            if formant { addAmp(0.20, 0.45) } else { p.velocityToCutoff = r2(0.18 + 0.22 * t) }
        case .keys, .pluck:
            if ampRow() < 0.15 { addAmp(0.25, 0.50) }
            if !formant && max(p.velocityToCutoff, cutRow()) < 0.12 { p.velocityToCutoff = r2(0.12 + 0.18 * t) }
        case .pad, .strings:
            if ampRow() < 0.10 { addAmp(0.15, 0.28) }
        default:
            break
        }
    }
}

// MARK: - SYNT_36 loudness hierarchy

extension FactoryAuthoring {
    /// PRESET_TASTE master bands. SYNT_37 S3: brass / arp 0.40–0.55.
    static func loudnessBand(_ c: PresetCategory) -> (lo: Float, hi: Float)? {
        switch c {
        case .bass: return (0.58, 0.65)
        case .lead: return (0.52, 0.62)
        case .keys, .pluck: return (0.45, 0.55)
        case .pad, .strings: return (0.32, 0.40)
        case .fx: return (0.30, 0.55)
        case .brass, .arp: return (0.40, 0.55)
        }
    }

    static let loudnessSoftWords = ["soft", "velvet", "whisper", "silk", "round"]

    static func isLoudnessSoft(_ p: SynthPreset) -> Bool { has(p, loudnessSoftWords) }

    /// SYNT_36: runs after `velocity`. Nudges masterVolume into the category band (soft names in
    /// the lower half, cap 0.75); on non-FX trims the loudest wet mix by ≤0.05 when the wet sum
    /// exceeds 0.45, never below the SYNT_32 FX floors. Never touches dirt / res / cutoff.
    static func loudness(_ p: inout SynthPreset) {
        guard !["Init", "Default", "Template"].contains(p.name) else { return }
        func r2(_ x: Float) -> Float { (x * 100).rounded() / 100 }
        var m = min(p.masterVolume, 0.75)
        if let band = loudnessBand(p.category) {
            var hi = band.hi
            if isLoudnessSoft(p) { hi = ((band.lo + band.hi) / 2 * 100).rounded(.down) / 100 }
            m = min(hi, max(band.lo, m))
        }
        p.masterVolume = r2(m)

        guard p.category != .fx else { return }
        let over = p.reverbMix + p.delayMix + p.chorusMix - 0.45
        guard over > 1e-4 else { return }
        let c = p.category
        let padLike = c == .pad || c == .strings
        let revFloor: Float = padLike ? 0.20 : 0.12
        let choFloor: Float = (padLike || c == .keys) ? 0.14 : 0.12
        let dlyFloor: Float = 0.12
        let cut = min(0.05, over)
        if p.reverbMix >= p.chorusMix && p.reverbMix >= p.delayMix {
            p.reverbMix = r2(max(revFloor, p.reverbMix - cut))
        } else if p.chorusMix >= p.delayMix {
            p.chorusMix = r2(max(choFloor, p.chorusMix - cut))
        } else {
            p.delayMix = r2(max(dlyFloor, p.delayMix - cut))
        }
    }
}

// MARK: - SYNT_37 category gesture

extension FactoryAuthoring {
    /// SYNT_37: runs after `loudness`. Fills missing category must-haves (docs/PRESET_TASTE.md):
    /// bass mono+sub, lead fast, pad/strings slow and clean, keys short, pluck short.
    /// Only moves a value that misses its rule; never touches unison, master, res or cutoff.
    /// Pizzicato strings keep their plucked gesture.
    static func categoryGesture(_ p: inout SynthPreset) {
        guard !["Init", "Default", "Template"].contains(p.name) else { return }
        func r3(_ x: Float) -> Float { (x * 1000).rounded() / 1000 }
        let soft = has(p, softWords)
        switch p.category {
        case .bass:
            if p.voiceMode == .poly { p.voiceMode = .mono }
            if !has(p, ["slap", "pluck"]) && !(0.02...0.12).contains(p.portamento) {
                p.portamento = min(0.12, max(0.02, p.portamento))
            }
            if p.subOscVolume < 0.08 && p.osc1Octave > -1 && p.osc2Octave > -1 { p.subOscVolume = 0.10 }
        case .lead:
            if p.attack > 0.08 && !(0.02...0.15).contains(p.portamento) {
                p.attack = soft ? 0.08 : 0.05
            }
            if p.attack > 0.25 && p.portamento > 0.20 { p.portamento = 0.15 }
        case .pad, .strings:
            if has(p, ["pizz"]) { return }
            if p.attack < 0.15 { p.attack = 0.15 }
            if p.release < 0.60 { p.release = 0.60 }
            if p.distortionEnabled && p.distortionMix > 0.10 { p.distortionEnabled = false }
        case .keys:
            if p.attack > 0.05 { p.attack = 0.05 }
            p.release = r3(min(0.55, max(0.15, p.release)))
            if p.sustain > 0.75 { p.sustain = 0.75 }
        case .pluck:
            if p.attack > 0.01 { p.attack = 0.01 }
            if p.sustain > 0.25 { p.sustain = 0.25 }
            if p.release > 0.55 { p.release = 0.55 }
        case .brass:
            // SYNT_38: dirt cap (no unison force — chord-safety).
            let cap: Float = has(p, ["soft", "velvet"]) ? 0.22 : 0.30
            if p.distortionEnabled && p.distortionMix > cap { p.distortionMix = cap }
            if !(p.attack <= 0.12 || p.filterEnvelopeAmount >= 0.40) { p.attack = soft ? 0.12 : 0.08 }
        case .arp:
            if p.attack > 0.08 { p.attack = 0.08 }
            if p.sustain > 0.55 { p.sustain = 0.55 }
        case .fx:
            // SYNT_38: pad-like FX (slow attack + long tail) → shorter tail unless the name is a drone/shimmer bed.
            if p.attack >= 0.15 && p.release >= 0.60 && !has(p, ["shimmer", "drone"]) { p.release = 0.55 }
        }
    }
}

// MARK: - SYNT_41 anti-dull / lead vibrato

extension FactoryAuthoring {
    /// SYNT_41: runs after `categoryGesture`. Leads without pitch vibrato get a gentle
    /// free-running sine LFO → pitch (depth 0.10–0.12, ~5 Hz) on a free LFO slot.
    /// Never touches unison, dirt, res, width or master. Soft names stay at 0.10.
    static func antiDull(_ p: inout SynthPreset) {
        guard !["Init", "Default", "Template"].contains(p.name), p.category == .lead else { return }
        let lfoPitch = p.modMatrix.contains { ($0.source == .lfo1 || $0.source == .lfo2)
            && pitchDestinations.contains($0.destination) && abs($0.amount) >= 0.10 }
        if lfoPitch { return }
        if (p.lfoEnabled && p.lfoTarget == .pitch && p.lfoDepth >= 0.10)
            || (p.lfo2Enabled && p.lfo2Target == .pitch && p.lfo2Depth >= 0.10) { return }
        let depth: Float = has(p, softWords) ? 0.10 : 0.12
        let lfo1Used = p.modMatrix.contains { $0.source == .lfo1 }
        let lfo2Used = p.modMatrix.contains { $0.source == .lfo2 }
        if !lfo1Used && (!p.lfoEnabled || p.lfoTarget == .none || p.lfoTarget == .pitch) {
            p.lfoEnabled = true
            p.lfoTarget = .pitch
            p.lfoTempoSync = false
            p.lfoWaveform = .sine
            p.lfoRate = 5.2
            p.lfoDepth = max(depth, p.lfoTarget == .pitch ? min(p.lfoDepth, 0.14) : depth)
        } else if !lfo2Used && (!p.lfo2Enabled || p.lfo2Target == .none || p.lfo2Target == .pitch) {
            p.lfo2Enabled = true
            p.lfo2Target = .pitch
            p.lfo2TempoSync = false
            p.lfo2Waveform = .sine
            p.lfo2Rate = 5.2
            p.lfo2Depth = depth
        }
    }
}

// MARK: - SYNT_43 periodic motion

extension FactoryAuthoring {
    static let periodicSources: Set<ModSource> = [.lfo1, .lfo2, .mseg, .mseg2, .smoothRandom]

    /// LFO/MSEG/smoothRandom ≥0.30 on a non-pitch, live destination (velocity/env/key do not count).
    static func hasPeriodicMotion(_ p: SynthPreset) -> Bool {
        for e in p.modMatrix where periodicSources.contains(e.source) && abs(e.amount) >= 0.30 {
            if isDeadRow(e) || isFormantDeadRow(e, p) || pitchDestinations.contains(e.destination) { continue }
            if (e.source == .mseg && p.mseg.points.isEmpty) || (e.source == .mseg2 && p.mseg2.points.isEmpty) { continue }
            return true
        }
        func direct(_ on: Bool, _ t: LFOTarget, _ d: Float) -> Bool {
            on && t != .none && t != .pitch && d >= 0.30 && !(p.filterType == .formant && t == .filter)
        }
        return direct(p.lfoEnabled, p.lfoTarget, p.lfoDepth) || direct(p.lfo2Enabled, p.lfo2Target, p.lfo2Depth)
    }

    /// SYNT_43: runs after `antiDull`. Misses get a free LFO (LFO2 first, so lead vibrato on LFO1 stays)
    /// moving timbre: formant → vowel, wavetable → WT morph 1, keys alternate cutoff / tremolo, else cutoff.
    /// Pad/strings are already covered by the slow pad motion; never touches unison, dirt, res, width.
    static func periodicMotion(_ p: inout SynthPreset, index i: Int) {
        guard !["Init", "Default", "Template"].contains(p.name) else { return }
        let c = p.category
        guard c != .pad && c != .strings && c != .fx, !hasPeriodicMotion(p) else { return }
        let depth: Float = 0.32
        let formant = p.filterType == .formant
        let wavetable = p.osc1Waveform == .wavetable
        let tremolo = c == .keys && i % 2 == 1 && !formant
        let rate: Float = tremolo ? 3.5 : (c == .brass ? 0.5 : [0.6, 0.9, 1.3, 1.8][i % 4])
        let matrixDest: ModDestination? = formant ? .vowel : (wavetable ? .wtMorph1 : nil)
        let target: LFOTarget = matrixDest != nil ? .none : (tremolo ? .amplitude : .filter)
        let lfo2Free = !p.modMatrix.contains { $0.source == .lfo2 } && (!p.lfo2Enabled || p.lfo2Target == .none)
        let lfo1Free = !p.modMatrix.contains { $0.source == .lfo1 } && (!p.lfoEnabled || p.lfoTarget == .none)
        var source: ModSource?
        if lfo2Free {
            p.lfo2Enabled = true; p.lfo2Target = target; p.lfo2TempoSync = false
            p.lfo2Waveform = .sine; p.lfo2Rate = rate; p.lfo2Depth = depth
            source = .lfo2
        } else if lfo1Free {
            p.lfoEnabled = true; p.lfoTarget = target; p.lfoTempoSync = false
            p.lfoWaveform = .sine; p.lfoRate = rate; p.lfoDepth = depth
            source = .lfo1
        } else if p.modMatrix.count < 16 {
            p.modMatrix.append(mod(.lfo2, matrixDest ?? .cutoff, depth))
            return
        }
        if let d = matrixDest, let s = source, p.modMatrix.count < 16 {
            p.modMatrix.append(mod(s, d, depth))
        }
    }
}
