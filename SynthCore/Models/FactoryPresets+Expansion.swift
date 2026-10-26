//
//  FactoryPresets+Expansion.swift
//  Synt_swiftUI
//
//  Sound Expansion Pack: second browser bank (~50), not part of `factoryPresets`.
//
//  Same SYNT_30 authoring policy as FactoryPresets.swift. This pack is the
//  wavetable / FM / formant / MSEG / FX-order heavy bank:
//  - Wavetable sets (Basic, Analog, Digital, PWM, Formant) including dual WT
//  - FM, hard sync, sub, dedicated filter ADSR / Env 2, dual filter, vowel mod
//  - MSEG 1 and MSEG 2, macros into the matrix
//  - Non-default FX order, rotary, frequency shifter, transient, trance gate
//  - Sequencer Pro (tie, ratchet, probability) and tempo-synced arp
//  - masterVolume ≤ 0.75, sends at the factory caps unless the patch is FX
//  - Init is not in this list
//

import Foundation

public extension SynthPreset {

    static let expansionPresets: [SynthPreset] = (
        vocalFormantPresets +
        fmMetallicPresets +
        analogSyncAcidPresets +
        cinematicPadPresets +
        modernEdmKeysPresets
    )

    private static func makePreset(
        name: String,
        category: PresetCategory,
        osc1Waveform: WaveformType = .sawtooth,
        osc1Volume: Float = 0.7,
        osc1Octave: Int = 0,
        osc1Detune: Float = 0.0,
        osc1PulseWidth: Float = 0.5,
        osc1WavetableMorph: Float = 0.0,
        osc1WavetableIndex: Int = 0,
        osc2Enabled: Bool = true,
        osc2Waveform: WaveformType = .square,
        osc2Volume: Float = 0.5,
        osc2Octave: Int = 0,
        osc2Detune: Float = 5.0,
        osc2PulseWidth: Float = 0.5,
        osc2WavetableMorph: Float = 0.0,
        osc2WavetableIndex: Int = 0,
        subOscVolume: Float = 0.0,
        subOscOctave: Int = -1,
        subOscWaveform: WaveformType = .sine,
        fmAmount: Float = 0.0,
        oscSyncEnabled: Bool = false,
        attack: Float = 0.01,
        decay: Float = 0.1,
        sustain: Float = 0.7,
        release: Float = 0.3,
        filterType: FilterType = .lowPass,
        filterCutoff: Float = 5000.0,
        filterResonance: Float = 0.5,
        filterEnvelopeAmount: Float = 0.0,
        filterKeyTracking: Float = 0.0,
        lfoEnabled: Bool = false,
        lfoRate: Float = 5.0,
        lfoDepth: Float = 0.5,
        lfoWaveform: WaveformType = .sine,
        lfoTarget: LFOTarget = .pitch,
        lfoTempoSync: Bool = false,
        lfoSyncDivision: TimeDivision = .quarter,
        lfo2Enabled: Bool = false,
        lfo2Rate: Float = 2.0,
        lfo2Depth: Float = 0.5,
        lfo2Waveform: WaveformType = .triangle,
        lfo2Target: LFOTarget = .none,
        lfo2TempoSync: Bool = false,
        lfo2SyncDivision: TimeDivision = .eighth,
        reverbMix: Float = 0.2,
        reverbRoomSize: Float = 0.5,
        chorusRate: Float = 1.5,
        chorusDepth: Float = 0.5,
        chorusMix: Float = 0.0,
        delayTime: Float = 0.3,
        delayFeedback: Float = 0.4,
        delayMix: Float = 0.0,
        delayTempoSync: Bool = false,
        delaySyncDivision: TimeDivision = .eighth,
        delayPingPong: Bool = false,
        distortionEnabled: Bool = false,
        distortionType: DistortionType = .softClip,
        distortionDrive: Float = 0.35,
        distortionTone: Float = 0.5,
        distortionMix: Float = 0.25,
        distortionOversampling: Bool = false,
        phaserEnabled: Bool = false,
        phaserMode: PhaserMode = .phaser4,
        phaserRate: Float = 0.4,
        phaserDepth: Float = 0.55,
        phaserFeedback: Float = 0.25,
        phaserMix: Float = 0.4,
        masterVolume: Float = 0.55,
        portamento: Float = 0.0,
        unisonVoices: Int = 1,
        unisonDetune: Float = 0.0,
        modMatrix: [ModMatrixEntry] = [],
        arpMode: ArpeggiatorMode = .off,
        arpRate: TimeDivision = .sixteenth,
        arpOctaves: Int = 1,
        bpm: Float = 120.0,
        sequencerData: [SequencerStep] = Array(repeating: SequencerStep(), count: 16)
    ) -> SynthPreset {
        var p = SynthPreset(name: name, category: category)
        p.osc1Waveform = osc1Waveform
        p.osc1Volume = osc1Volume
        p.osc1Octave = osc1Octave
        p.osc1Detune = osc1Detune
        p.osc1PulseWidth = osc1PulseWidth
        p.osc1WavetableMorph = osc1WavetableMorph
        p.osc1WavetableIndex = osc1WavetableIndex

        p.osc2Enabled = osc2Enabled
        p.osc2Waveform = osc2Waveform
        p.osc2Volume = osc2Volume
        p.osc2Octave = osc2Octave
        p.osc2Detune = osc2Detune
        p.osc2PulseWidth = osc2PulseWidth
        p.osc2WavetableMorph = osc2WavetableMorph
        p.osc2WavetableIndex = osc2WavetableIndex

        p.subOscVolume = subOscVolume
        p.subOscOctave = subOscOctave
        p.subOscWaveform = subOscWaveform
        p.fmAmount = fmAmount
        p.oscSyncEnabled = oscSyncEnabled

        p.attack = attack
        p.decay = decay
        p.sustain = sustain
        p.release = release

        p.filterType = filterType
        p.filterCutoff = filterCutoff
        p.filterResonance = filterResonance
        p.filterEnvelopeAmount = filterEnvelopeAmount
        p.filterKeyTracking = filterKeyTracking

        p.lfoEnabled = lfoEnabled
        p.lfoRate = lfoRate
        p.lfoDepth = lfoDepth
        p.lfoWaveform = lfoWaveform
        p.lfoTarget = lfoTarget
        p.lfoTempoSync = lfoTempoSync
        p.lfoSyncDivision = lfoSyncDivision

        p.lfo2Enabled = lfo2Enabled
        p.lfo2Rate = lfo2Rate
        p.lfo2Depth = lfo2Depth
        p.lfo2Waveform = lfo2Waveform
        p.lfo2Target = lfo2Target
        p.lfo2TempoSync = lfo2TempoSync
        p.lfo2SyncDivision = lfo2SyncDivision

        p.reverbMix = reverbMix
        p.reverbRoomSize = reverbRoomSize
        p.chorusRate = chorusRate
        p.chorusDepth = chorusDepth
        p.chorusMix = chorusMix
        p.delayTime = delayTime
        p.delayFeedback = delayFeedback
        p.delayMix = delayMix
        p.delayTempoSync = delayTempoSync
        p.delaySyncDivision = delaySyncDivision
        p.delayPingPong = delayPingPong

        p.distortionEnabled = distortionEnabled
        p.distortionType = distortionType
        p.distortionDrive = distortionDrive
        p.distortionTone = distortionTone
        p.distortionMix = distortionMix
        p.distortionOversampling = distortionOversampling

        p.phaserEnabled = phaserEnabled
        p.phaserMode = phaserMode
        p.phaserRate = phaserRate
        p.phaserDepth = phaserDepth
        p.phaserFeedback = phaserFeedback
        p.phaserMix = phaserMix

        p.masterVolume = masterVolume
        p.portamento = portamento
        p.unisonVoices = unisonVoices
        p.unisonDetune = unisonDetune
        p.modMatrix = modMatrix
        p.arpMode = arpMode
        p.arpRate = arpRate
        p.arpOctaves = arpOctaves
        p.bpm = bpm
        p.sequencerData = sequencerData
        return p
    }

    // MARK: - 7.1: Vocal & Formant (8 presets)

    private static let vocalFormantPresets: [SynthPreset] = [
        // 1. Choir of Angels
        makePreset(
            name: "Choir of Angels", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 0, osc1WavetableMorph: 0.25, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 4, osc2WavetableMorph: 0.65, osc2WavetableIndex: 4,
            attack: 0.8, decay: 1.2, sustain: 0.85, release: 1.6,
            filterType: .lowPass, filterCutoff: 4500, filterResonance: 0.25, filterKeyTracking: 0.4,
            lfoEnabled: true, lfoRate: 0.3, lfoDepth: 0.45, lfoWaveform: .sine, lfoTarget: .none,
            reverbMix: 0.22, reverbRoomSize: 0.5,
            chorusRate: 0.8, chorusDepth: 0.4, chorusMix: 0.12,
            masterVolume: 0.50,
            modMatrix: [ModMatrixEntry(source: .lfo1, destination: .wtMorph1, amount: 0.35)]
        ),
        // 2. Cybernetic Talking Bass
        makePreset(
            name: "Cybernetic Talking Bass", category: .bass,
            osc1Waveform: .wavetable, osc1Volume: 0.70, osc1Octave: -1, osc1WavetableMorph: 0.15, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: -1, osc2Detune: 6,
            subOscVolume: 0.45, subOscOctave: -2, subOscWaveform: .sine,
            attack: 0.01, decay: 0.35, sustain: 0.4, release: 0.2,
            filterType: .lowPass, filterCutoff: 2200, filterResonance: 0.55, filterEnvelopeAmount: 0.65, filterKeyTracking: 0.3,
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.35, distortionTone: 0.48, distortionMix: 0.20, distortionOversampling: true,
            masterVolume: 0.52,
            modMatrix: [ModMatrixEntry(source: .env1, destination: .wtMorph1, amount: 0.50)]
        ),
        // 3. Robotic Vowel Lead
        makePreset(
            name: "Robotic Vowel Lead", category: .lead,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 0, osc1WavetableMorph: 0.2, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 8,
            attack: 0.02, decay: 0.4, sustain: 0.7, release: 0.35,
            filterType: .lowPass, filterCutoff: 3800, filterResonance: 0.45, filterEnvelopeAmount: 0.3,
            delayTime: 0.28, delayFeedback: 0.25, delayMix: 0.08, delayPingPong: true,
            masterVolume: 0.52, portamento: 0.04,
            modMatrix: [ModMatrixEntry(source: .velocity, destination: .wtMorph1, amount: 0.60)]
        ),
        // 4. Throat Singing Drone
        makePreset(
            name: "Throat Singing Drone", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.70, osc1Octave: -2, osc1WavetableMorph: 0.1, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.50, osc2Octave: -1, osc2Detune: 2, osc2WavetableMorph: 0.7, osc2WavetableIndex: 4,
            subOscVolume: 0.5, subOscOctave: -2, subOscWaveform: .triangle,
            attack: 1.2, decay: 1.5, sustain: 0.9, release: 2.0,
            filterType: .lowPass, filterCutoff: 1800, filterResonance: 0.6, filterKeyTracking: 0.2,
            lfoEnabled: true, lfoRate: 0.15, lfoDepth: 0.5, lfoWaveform: .triangle, lfoTarget: .none,
            reverbMix: 0.20, reverbRoomSize: 0.5,
            masterVolume: 0.48,
            modMatrix: [ModMatrixEntry(source: .lfo1, destination: .wtMorph1, amount: 0.4)]
        ),
        // 5. Glass Soprano
        makePreset(
            name: "Glass Soprano", category: .lead,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 1, osc1WavetableMorph: 0.5, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.45, osc2Octave: 1, osc2Detune: 5,
            attack: 0.08, decay: 0.5, sustain: 0.8, release: 0.6,
            filterType: .lowPass, filterCutoff: 6500, filterResonance: 0.3, filterKeyTracking: 0.6,
            lfoEnabled: true, lfoRate: 4.5, lfoDepth: 0.12, lfoWaveform: .sine, lfoTarget: .pitch,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            masterVolume: 0.50
        ),
        // 6. Alien Transmission
        makePreset(
            name: "Alien Transmission", category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 0, osc1WavetableMorph: 0.3, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 15, osc2WavetableIndex: 2,
            attack: 0.01, decay: 0.6, sustain: 0.6, release: 0.8,
            filterType: .bandPass, filterCutoff: 2500, filterResonance: 0.7,
            lfoEnabled: true, lfoRate: 7.0, lfoDepth: 0.7, lfoWaveform: .noise, lfoTarget: .none,
            delayTime: 0.35, delayFeedback: 0.45, delayMix: 0.15, delayPingPong: true,
            masterVolume: 0.48,
            modMatrix: [ModMatrixEntry(source: .lfo1, destination: .wtMorph1, amount: 0.65)]
        ),
        // 7. Synth Choir Pad
        makePreset(
            name: "Synth Choir Pad", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableMorph: 0.4, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 7,
            attack: 0.6, decay: 0.8, sustain: 0.8, release: 1.2,
            filterType: .lowPass, filterCutoff: 1800, filterResonance: 0.2, filterKeyTracking: 0.5,
            reverbMix: 0.20, reverbRoomSize: 0.45,
            chorusRate: 1.2, chorusDepth: 0.35, chorusMix: 0.12,
            masterVolume: 0.50
        ),
        // 8. Vocoder RiffSeq
        makePreset(
            name: "Vocoder RiffSeq", category: .arp,
            osc1Waveform: .wavetable, osc1Volume: 0.70, osc1Octave: 0, osc1WavetableMorph: 0.2, osc1WavetableIndex: 4,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 5,
            attack: 0.005, decay: 0.15, sustain: 0.5, release: 0.15,
            filterType: .lowPass, filterCutoff: 3200, filterResonance: 0.5, filterEnvelopeAmount: 0.4,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.25, distortionTone: 0.5, distortionMix: 0.15,
            masterVolume: 0.52,
            modMatrix: [ModMatrixEntry(source: .velocity, destination: .wtMorph1, amount: 0.45)],
            arpMode: .up, arpRate: .sixteenth, bpm: 124,
            sequencerData: (0..<16).map { i in
                SequencerStep(
                    isActive: [true, false, true, true, false, true, true, false, true, true, false, true, true, false, true, true][i],
                    noteOffset: [0, 0, 3, 5, 0, 7, 10, 0, 12, 10, 0, 7, 5, 0, 3, 0][i],
                    velocity: [1.0, 0.5, 0.85, 0.65, 0.5, 0.95, 0.75, 0.5, 1.0, 0.8, 0.5, 0.9, 0.7, 0.5, 0.85, 0.6][i],
                    octave: [0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, -1][i],
                    tie: [false, false, false, true, false, false, true, false, false, true, false, false, true, false, false, false][i],
                    gate: [0.75, 0.5, 0.8, 0.9, 0.5, 0.8, 0.85, 0.5, 0.9, 0.8, 0.5, 0.8, 0.85, 0.5, 0.75, 0.6][i]
                )
            }
        )
    ]

    // MARK: - 7.2: FM & Bell / Metallic (10 presets)

    private static let fmMetallicPresets: [SynthPreset] = [
        // 1. DX Crystal EPiano
        makePreset(
            name: "DX Crystal EPiano", category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.50, osc2Octave: 1, osc2Detune: 0,
            fmAmount: 0.35,
            attack: 0.005, decay: 1.2, sustain: 0.35, release: 0.6,
            filterType: .lowPass, filterCutoff: 8000, filterResonance: 0.15, filterEnvelopeAmount: 0.35, filterKeyTracking: 0.65,
            reverbMix: 0.18, reverbRoomSize: 0.4,
            chorusRate: 1.0, chorusDepth: 0.3, chorusMix: 0.10,
            masterVolume: 0.52
        ),
        // 2. Tokyo Marimba
        makePreset(
            name: "Tokyo Marimba", category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.55, osc2Octave: 2,
            fmAmount: 0.42,
            attack: 0.002, decay: 0.25, sustain: 0.0, release: 0.15,
            filterType: .lowPass, filterCutoff: 5000, filterResonance: 0.35, filterEnvelopeAmount: 0.5, filterKeyTracking: 0.5,
            masterVolume: 0.55
        ),
        // 3. Ice Temple Bell
        makePreset(
            name: "Ice Temple Bell", category: .keys,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 1, osc1WavetableMorph: 0.3, osc1WavetableIndex: 2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: 2, osc2Detune: 14,
            fmAmount: 0.38,
            attack: 0.005, decay: 2.2, sustain: 0.1, release: 2.0,
            filterType: .lowPass, filterCutoff: 7500, filterResonance: 0.4, filterKeyTracking: 0.6,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            delayTime: 0.375, delayFeedback: 0.35, delayMix: 0.10, delayPingPong: true,
            masterVolume: 0.50
        ),
        // 4. Tubular Cathedral
        makePreset(
            name: "Tubular Cathedral", category: .keys,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 0, osc1WavetableIndex: 2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: 1,
            subOscVolume: 0.4, subOscOctave: -1, subOscWaveform: .sine,
            fmAmount: 0.30,
            attack: 0.01, decay: 1.8, sustain: 0.2, release: 1.6,
            filterType: .lowPass, filterCutoff: 6000, filterResonance: 0.3, filterKeyTracking: 0.5,
            reverbMix: 0.22, reverbRoomSize: 0.5,
            masterVolume: 0.50
        ),
        // 5. Kalimba Dream
        makePreset(
            name: "Kalimba Dream", category: .pluck,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.40, osc2Octave: 2,
            fmAmount: 0.28,
            attack: 0.003, decay: 0.4, sustain: 0.05, release: 0.25,
            filterType: .lowPass, filterCutoff: 4200, filterResonance: 0.25, filterEnvelopeAmount: 0.45, filterKeyTracking: 0.6,
            delayTime: 0.25, delayFeedback: 0.20, delayMix: 0.08, delayPingPong: true,
            masterVolume: 0.54
        ),
        // 6. Metallic Bass Pluck
        makePreset(
            name: "Metallic Bass Pluck", category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.45, osc2Octave: 0, osc2WavetableIndex: 2,
            subOscVolume: 0.45, subOscOctave: -2, subOscWaveform: .sine,
            fmAmount: 0.45,
            attack: 0.003, decay: 0.3, sustain: 0.15, release: 0.15,
            filterType: .lowPass, filterCutoff: 2800, filterResonance: 0.4, filterEnvelopeAmount: 0.6, filterKeyTracking: 0.3,
            distortionEnabled: true, distortionType: .hardClip, distortionDrive: 0.4, distortionTone: 0.5, distortionMix: 0.15, distortionOversampling: true,
            masterVolume: 0.52
        ),
        // 7. Music Box Memory
        makePreset(
            name: "Music Box Memory", category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.60, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.50, osc2Octave: 3,
            fmAmount: 0.25,
            attack: 0.002, decay: 0.8, sustain: 0.05, release: 0.5,
            filterType: .lowPass, filterCutoff: 9000, filterResonance: 0.2, filterKeyTracking: 0.7,
            reverbMix: 0.16, reverbRoomSize: 0.4,
            delayTime: 0.33, delayFeedback: 0.25, delayMix: 0.09,
            masterVolume: 0.52
        ),
        // 8. Gamelan Gong
        makePreset(
            name: "Gamelan Gong", category: .fx,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: -1, osc1WavetableIndex: 2,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 25,
            fmAmount: 0.55,
            attack: 0.005, decay: 2.0, sustain: 0.15, release: 2.5,
            filterType: .lowPass, filterCutoff: 3800, filterResonance: 0.45,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.25, phaserDepth: 0.5, phaserFeedback: 0.3, phaserMix: 0.25,
            masterVolume: 0.48
        ),
        // 9. Digital Harp
        makePreset(
            name: "Digital Harp", category: .arp,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.45, osc2Octave: 1, osc2WavetableIndex: 2,
            fmAmount: 0.32,
            attack: 0.003, decay: 0.35, sustain: 0.2, release: 0.25,
            filterType: .lowPass, filterCutoff: 6500, filterResonance: 0.3, filterEnvelopeAmount: 0.4, filterKeyTracking: 0.5,
            delayTime: 0.25, delayFeedback: 0.25, delayMix: 0.08, delayPingPong: true,
            masterVolume: 0.52,
            arpMode: .upDown, arpRate: .sixteenth, bpm: 120
        ),
        // 10. Neon Vibraphone
        makePreset(
            name: "Neon Vibraphone", category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: 2,
            fmAmount: 0.30,
            attack: 0.008, decay: 1.0, sustain: 0.25, release: 0.6,
            filterType: .lowPass, filterCutoff: 7000, filterResonance: 0.2, filterKeyTracking: 0.6,
            lfoEnabled: true, lfoRate: 4.8, lfoDepth: 0.25, lfoWaveform: .sine, lfoTarget: .amplitude,
            chorusRate: 1.2, chorusDepth: 0.25, chorusMix: 0.08,
            masterVolume: 0.52
        )
    ]

    // MARK: - 7.3: Analog Sync & Acid 303 (10 presets)

    private static let analogSyncAcidPresets: [SynthPreset] = [
        // 1. TB-303 Acid Squelch
        makePreset(
            name: "TB-303 Acid Squelch", category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.75, osc1Octave: -1,
            osc2Enabled: false,
            attack: 0.005, decay: 0.28, sustain: 0.15, release: 0.12,
            filterType: .lowPass, filterCutoff: 1200, filterResonance: 0.78, filterEnvelopeAmount: 0.75, filterKeyTracking: 0.45,
            distortionEnabled: true, distortionType: .softClip, distortionDrive: 0.35, distortionTone: 0.55, distortionMix: 0.22, distortionOversampling: true,
            masterVolume: 0.54, portamento: 0.05,
            sequencerData: (0..<16).map { i in
                SequencerStep(isActive: true,
                              noteOffset: [0, 0, 12, 3, 0, 10, 12, 0, -2, 0, 10, 12, 3, 5, 7, 0][i],
                              velocity: [0.9, 0.6, 1.0, 0.7, 0.8, 0.6, 1.0, 0.5, 0.9, 0.6, 0.8, 1.0, 0.7, 0.8, 0.9, 0.5][i],
                              octave: [0, 0, 1, 0, 0, 0, 1, 0, -1, 0, 0, 1, 0, 0, 0, 0][i],
                              tie: [false, false, true, false, false, false, true, false, false, false, false, true, false, false, false, false][i],
                              gate: 0.75)
            }
        ),
        // 2. Hard Sync Screamer
        makePreset(
            name: "Hard Sync Screamer", category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Octave: 1, osc2Detune: 10,
            oscSyncEnabled: true,
            attack: 0.01, decay: 0.5, sustain: 0.7, release: 0.35,
            filterType: .lowPass, filterCutoff: 7000, filterResonance: 0.35, filterEnvelopeAmount: 0.3,
            delayTime: 0.28, delayFeedback: 0.25, delayMix: 0.08, delayPingPong: true,
            masterVolume: 0.50, portamento: 0.03,
            modMatrix: [ModMatrixEntry(source: .env1, destination: .pitch2, amount: 0.65)]
        ),
        // 3. Moog Sub Phatty
        makePreset(
            name: "Moog Sub Phatty", category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.50, osc2Octave: -1, osc2Detune: 6,
            subOscVolume: 0.55, subOscOctave: -1, subOscWaveform: .square,
            attack: 0.005, decay: 0.45, sustain: 0.3, release: 0.2,
            filterType: .lowPass, filterCutoff: 1600, filterResonance: 0.6, filterEnvelopeAmount: 0.65, filterKeyTracking: 0.4,
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.25, distortionTone: 0.45, distortionMix: 0.15,
            masterVolume: 0.54
        ),
        // 4. Prophet Brass Swell
        makePreset(
            name: "Prophet Brass Swell", category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.60, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Octave: 0, osc2Detune: 8,
            attack: 0.12, decay: 0.8, sustain: 0.75, release: 0.5,
            filterType: .lowPass, filterCutoff: 2200, filterResonance: 0.4, filterEnvelopeAmount: 0.55, filterKeyTracking: 0.5,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            chorusRate: 0.9, chorusDepth: 0.25, chorusMix: 0.09,
            masterVolume: 0.50
        ),
        // 5. Cyberpunk Sync Bass
        makePreset(
            name: "Cyberpunk Sync Bass", category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.70, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.50, osc2Octave: 0,
            subOscVolume: 0.45, subOscOctave: -2, subOscWaveform: .sine,
            oscSyncEnabled: true,
            attack: 0.008, decay: 0.35, sustain: 0.3, release: 0.18,
            filterType: .lowPass, filterCutoff: 2500, filterResonance: 0.5, filterEnvelopeAmount: 0.45, filterKeyTracking: 0.35,
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.45, distortionTone: 0.5, distortionMix: 0.22, distortionOversampling: true,
            masterVolume: 0.52,
            modMatrix: [ModMatrixEntry(source: .env1, destination: .pitch2, amount: 0.45)]
        ),
        // 6. Classic Funk Clavinet
        makePreset(
            name: "Classic Funk Clavinet", category: .keys,
            osc1Waveform: .square, osc1Volume: 0.70, osc1Octave: 0, osc1PulseWidth: 0.15,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.40, osc2Octave: 0, osc2Detune: 4,
            attack: 0.002, decay: 0.35, sustain: 0.05, release: 0.12,
            filterType: .lowPass, filterCutoff: 2800, filterResonance: 0.65, filterEnvelopeAmount: 0.7, filterKeyTracking: 0.6,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 1.2, phaserDepth: 0.35, phaserFeedback: 0.2, phaserMix: 0.18,
            masterVolume: 0.54
        ),
        // 7. Oberheim PolyJump
        makePreset(
            name: "Oberheim PolyJump", category: .brass,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.55, osc2Octave: 0, osc2Detune: 7,
            attack: 0.015, decay: 0.55, sustain: 0.45, release: 0.3,
            filterType: .lowPass, filterCutoff: 3000, filterResonance: 0.35, filterEnvelopeAmount: 0.5, filterKeyTracking: 0.5,
            reverbMix: 0.15, reverbRoomSize: 0.35,
            chorusRate: 1.1, chorusDepth: 0.22, chorusMix: 0.08,
            masterVolume: 0.52
        ),
        // 8. Subquake 808 Pro
        makePreset(
            name: "Subquake 808 Pro", category: .bass,
            osc1Waveform: .sine, osc1Volume: 0.75, osc1Octave: -2,
            osc2Enabled: false,
            subOscVolume: 0.6, subOscOctave: -2, subOscWaveform: .sine,
            attack: 0.005, decay: 1.2, sustain: 0.0, release: 0.4,
            filterType: .lowPass, filterCutoff: 1200, filterResonance: 0.15, filterEnvelopeAmount: 0.2,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.3, distortionTone: 0.45, distortionMix: 0.18,
            masterVolume: 0.56,
            modMatrix: [ModMatrixEntry(source: .env1, destination: .pitch1, amount: 0.25)]
        ),
        // 9. Retro Synthwave Arp
        makePreset(
            name: "Retro Synthwave Arp", category: .arp,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.45, osc2Octave: -1, osc2Detune: 5,
            subOscVolume: 0.4, subOscOctave: -2, subOscWaveform: .sine,
            attack: 0.005, decay: 0.2, sustain: 0.35, release: 0.15,
            filterType: .lowPass, filterCutoff: 2000, filterResonance: 0.55, filterEnvelopeAmount: 0.45, filterKeyTracking: 0.5,
            delayTime: 0.24, delayFeedback: 0.25, delayMix: 0.09, delayPingPong: true,
            masterVolume: 0.52,
            arpMode: .up, arpRate: .sixteenth, bpm: 126
        ),
        // 10. Laser Zap FX
        makePreset(
            name: "Laser Zap FX", category: .fx,
            osc1Waveform: .triangle, osc1Volume: 0.75, osc1Octave: 1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: 2,
            attack: 0.001, decay: 0.18, sustain: 0.0, release: 0.1,
            filterType: .lowPass, filterCutoff: 4000, filterResonance: 0.85, filterEnvelopeAmount: 0.9,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            masterVolume: 0.54,
            modMatrix: [ModMatrixEntry(source: .env1, destination: .pitch1, amount: 0.85)]
        )
    ]

    // MARK: - 7.4: Cinematic & Evolving Pads (12 presets)

    private static let cinematicPadPresets: [SynthPreset] = [
        // 1. Interstellar Horizon
        makePreset(
            name: "Interstellar Horizon", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableMorph: 0.2, osc1WavetableIndex: 1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 8,
            subOscVolume: 0.45, subOscOctave: -1, subOscWaveform: .sine,
            attack: 1.5, decay: 2.0, sustain: 0.85, release: 2.5,
            filterType: .lowPass, filterCutoff: 2200, filterResonance: 0.3, filterKeyTracking: 0.4,
            lfoEnabled: true, lfoRate: 0.12, lfoDepth: 0.35, lfoWaveform: .triangle, lfoTarget: .filter,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            masterVolume: 0.48
        ),
        // 2. Solar Wind Sweep
        makePreset(
            name: "Solar Wind Sweep", category: .pad,
            osc1Waveform: .noise, osc1Volume: 0.35, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.55, osc2Octave: 0, osc2WavetableMorph: 0.4, osc2WavetableIndex: 1,
            attack: 2.0, decay: 2.5, sustain: 0.8, release: 3.0,
            filterType: .bandPass, filterCutoff: 1800, filterResonance: 0.65,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            phaserEnabled: true, phaserMode: .phaser6, phaserRate: 0.15, phaserDepth: 0.6, phaserFeedback: 0.35, phaserMix: 0.3,
            masterVolume: 0.46
        ),
        // 3. Aurora Borealis
        makePreset(
            name: "Aurora Borealis", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableMorph: 0.3, osc1WavetableIndex: 1,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 7, osc2WavetableMorph: 0.6, osc2WavetableIndex: 3,
            attack: 1.8, decay: 2.0, sustain: 0.85, release: 2.2,
            filterType: .lowPass, filterCutoff: 3000, filterResonance: 0.35, filterKeyTracking: 0.5,
            lfoEnabled: true, lfoRate: 0.15, lfoDepth: 0.45, lfoWaveform: .sine, lfoTarget: .none,
            lfo2Enabled: true, lfo2Rate: 0.25, lfo2Depth: 0.4, lfo2Waveform: .triangle, lfo2Target: .pan,
            reverbMix: 0.22, reverbRoomSize: 0.5,
            masterVolume: 0.48,
            modMatrix: [ModMatrixEntry(source: .lfo1, destination: .wtMorph1, amount: 0.4)]
        ),
        // 4. Deep Oceanwhale
        makePreset(
            name: "Deep Oceanwhale", category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 5,
            attack: 1.0, decay: 1.8, sustain: 0.8, release: 2.0,
            filterType: .lowPass, filterCutoff: 1500, filterResonance: 0.7, filterKeyTracking: 0.3,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            masterVolume: 0.48, portamento: 0.15,
            modMatrix: [ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.35)]
        ),
        // 5. VHS Tape Nostalgia
        makePreset(
            name: "VHS Tape Nostalgia", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 0, osc1WavetableMorph: 0.3, osc1WavetableIndex: 1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 6,
            attack: 0.5, decay: 1.0, sustain: 0.75, release: 1.4,
            filterType: .lowPass, filterCutoff: 2400, filterResonance: 0.25, filterKeyTracking: 0.4,
            lfoEnabled: true, lfoRate: 0.8, lfoDepth: 0.08, lfoWaveform: .sine, lfoTarget: .pitch,
            distortionEnabled: true, distortionType: .tapeSaturation, distortionDrive: 0.25, distortionTone: 0.42, distortionMix: 0.18,
            masterVolume: 0.50
        ),
        // 6. Floating Cathedral
        makePreset(
            name: "Floating Cathedral", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableIndex: 1,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.45, osc2Octave: 1, osc2Detune: 700,
            attack: 1.2, decay: 1.5, sustain: 0.85, release: 2.0,
            filterType: .lowPass, filterCutoff: 3500, filterResonance: 0.25, filterKeyTracking: 0.5,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            chorusRate: 0.7, chorusDepth: 0.35, chorusMix: 0.12,
            masterVolume: 0.48
        ),
        // 7. PWM String Ensemble
        makePreset(
            name: "PWM String Ensemble", category: .strings,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 0, osc1WavetableMorph: 0.35, osc1WavetableIndex: 3,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 9, osc2WavetableMorph: 0.65, osc2WavetableIndex: 3,
            attack: 0.4, decay: 0.8, sustain: 0.8, release: 1.2,
            filterType: .lowPass, filterCutoff: 4000, filterResonance: 0.2, filterKeyTracking: 0.6,
            lfoEnabled: true, lfoRate: 0.6, lfoDepth: 0.4, lfoWaveform: .triangle, lfoTarget: .none,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            chorusRate: 1.1, chorusDepth: 0.3, chorusMix: 0.12,
            masterVolume: 0.50,
            modMatrix: [ModMatrixEntry(source: .lfo1, destination: .wtMorph1, amount: 0.45)]
        ),
        // 8. Dark Dystopia Drone
        makePreset(
            name: "Dark Dystopia Drone", category: .pad,
            osc1Waveform: .sawtooth, osc1Volume: 0.70, osc1Octave: -2,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.50, osc2Octave: -1, osc2Detune: 12, osc2WavetableIndex: 2,
            subOscVolume: 0.5, subOscOctave: -2, subOscWaveform: .sine,
            attack: 1.5, decay: 2.0, sustain: 0.9, release: 2.5,
            filterType: .lowPass, filterCutoff: 1400, filterResonance: 0.5, filterKeyTracking: 0.3,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            distortionEnabled: true, distortionType: .wavefolder, distortionDrive: 0.4, distortionTone: 0.45, distortionMix: 0.20, distortionOversampling: true,
            masterVolume: 0.46
        ),
        // 9. Starlight Pluck Pad
        makePreset(
            name: "Starlight Pluck Pad", category: .pad,
            osc1Waveform: .triangle, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 1, osc2Detune: 6,
            attack: 0.05, decay: 1.5, sustain: 0.6, release: 1.8,
            filterType: .lowPass, filterCutoff: 3800, filterResonance: 0.3, filterEnvelopeAmount: 0.45, filterKeyTracking: 0.55,
            reverbMix: 0.20, reverbRoomSize: 0.5,
            delayTime: 0.30, delayFeedback: 0.30, delayMix: 0.09, delayPingPong: true,
            masterVolume: 0.50
        ),
        // 10. Celestial Harmonics
        makePreset(
            name: "Celestial Harmonics", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableMorph: 0.4, osc1WavetableIndex: 2,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.45, osc2Octave: 1, osc2Detune: 8, osc2WavetableMorph: 0.7, osc2WavetableIndex: 2,
            attack: 1.4, decay: 1.8, sustain: 0.8, release: 2.0,
            filterType: .bandPass, filterCutoff: 2800, filterResonance: 0.5, filterKeyTracking: 0.6,
            reverbMix: 0.22, reverbRoomSize: 0.5,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.2, phaserDepth: 0.45, phaserFeedback: 0.25, phaserMix: 0.22,
            masterVolume: 0.48
        ),
        // 11. Analog Warmth Bed
        makePreset(
            name: "Analog Warmth Bed", category: .pad,
            osc1Waveform: .wavetable, osc1Volume: 0.60, osc1Octave: 0, osc1WavetableMorph: 0.25, osc1WavetableIndex: 1,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 5,
            attack: 0.8, decay: 1.2, sustain: 0.85, release: 1.6,
            filterType: .lowPass, filterCutoff: 2600, filterResonance: 0.2, filterKeyTracking: 0.45,
            reverbMix: 0.18, reverbRoomSize: 0.45,
            chorusRate: 0.8, chorusDepth: 0.25, chorusMix: 0.10,
            masterVolume: 0.48
        ),
        // 12. Time Warp Riser
        makePreset(
            name: "Time Warp Riser", category: .fx,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.50, osc2Octave: -1, osc2Detune: 10,
            attack: 3.5, decay: 1.0, sustain: 0.9, release: 1.5,
            filterType: .lowPass, filterCutoff: 800, filterResonance: 0.7, filterEnvelopeAmount: 0.85,
            reverbMix: 0.22, reverbRoomSize: 0.55,
            delayTime: 0.35, delayFeedback: 0.35, delayMix: 0.12, delayPingPong: true,
            masterVolume: 0.48,
            modMatrix: [ModMatrixEntry(source: .env1, destination: .pitch1, amount: 0.6)]
        )
    ]

    // MARK: - 7.5: Modern EDM & Future Keys (10 presets)

    private static let modernEdmKeysPresets: [SynthPreset] = [
        // 1. Future Bass SuperChord
        makePreset(
            name: "Future Bass SuperChord", category: .keys,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .wavetable, osc2Volume: 0.55, osc2Octave: 0, osc2Detune: 9, osc2WavetableIndex: 3,
            attack: 0.02, decay: 0.6, sustain: 0.65, release: 0.4,
            filterType: .lowPass, filterCutoff: 3500, filterResonance: 0.4, filterEnvelopeAmount: 0.45, filterKeyTracking: 0.5,
            lfoEnabled: true, lfoRate: 3.0, lfoDepth: 0.5, lfoWaveform: .triangle, lfoTarget: .amplitude, lfoTempoSync: true, lfoSyncDivision: .eighth,
            reverbMix: 0.16, reverbRoomSize: 0.4,
            masterVolume: 0.50
        ),
        // 2. Pluck in the Rain
        makePreset(
            name: "Pluck in the Rain", category: .pluck,
            osc1Waveform: .sawtooth, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.45, osc2Octave: 1, osc2Detune: 4,
            attack: 0.003, decay: 0.35, sustain: 0.1, release: 0.2,
            filterType: .lowPass, filterCutoff: 4500, filterResonance: 0.35, filterEnvelopeAmount: 0.6, filterKeyTracking: 0.55,
            reverbMix: 0.16, reverbRoomSize: 0.4,
            delayTime: 0.25, delayFeedback: 0.30, delayMix: 0.10, delayTempoSync: true, delaySyncDivision: .eighth, delayPingPong: true,
            masterVolume: 0.52
        ),
        // 3. Lo-Fi Chill Keys
        makePreset(
            name: "Lo-Fi Chill Keys", category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.45, osc2Octave: 0, osc2Detune: 4,
            attack: 0.015, decay: 1.0, sustain: 0.3, release: 0.4,
            filterType: .lowPass, filterCutoff: 2600, filterResonance: 0.2, filterKeyTracking: 0.5,
            lfoEnabled: true, lfoRate: 3.5, lfoDepth: 0.08, lfoWaveform: .sine, lfoTarget: .pitch,
            distortionEnabled: true, distortionType: .bitcrusher, distortionDrive: 0.18, distortionTone: 0.45, distortionMix: 0.10,
            masterVolume: 0.52
        ),
        // 4. Techno Rumble Sequence
        makePreset(
            name: "Techno Rumble Sequence", category: .bass,
            osc1Waveform: .sawtooth, osc1Volume: 0.75, osc1Octave: -1,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.45, osc2Octave: -1, osc2Detune: 5,
            subOscVolume: 0.5, subOscOctave: -2, subOscWaveform: .sine,
            attack: 0.005, decay: 0.22, sustain: 0.2, release: 0.15,
            filterType: .lowPass, filterCutoff: 1800, filterResonance: 0.65, filterEnvelopeAmount: 0.55, filterKeyTracking: 0.4,
            distortionEnabled: true, distortionType: .hardClip, distortionDrive: 0.35, distortionTone: 0.5, distortionMix: 0.18, distortionOversampling: true,
            masterVolume: 0.54,
            sequencerData: (0..<16).map { i in
                SequencerStep(isActive: true,
                              noteOffset: [0, -12, 0, -12, 0, -12, 3, 0, -12, 0, -12, 0, 7, 5, 3, 0][i],
                              velocity: [1.0, 0.5, 0.9, 0.5, 1.0, 0.5, 0.8, 0.9, 0.5, 1.0, 0.5, 0.9, 0.8, 0.7, 0.8, 0.5][i],
                              octave: 0,
                              tie: false,
                              gate: 0.6)
            }
        ),
        // 5. Hyperpop Lead
        makePreset(
            name: "Hyperpop Lead", category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.55, osc2Octave: 1, osc2Detune: 12,
            attack: 0.008, decay: 0.4, sustain: 0.7, release: 0.3,
            filterType: .lowPass, filterCutoff: 8000, filterResonance: 0.4, filterEnvelopeAmount: 0.35, filterKeyTracking: 0.6,
            chorusRate: 1.5, chorusDepth: 0.35, chorusMix: 0.12,
            delayTime: 0.25, delayFeedback: 0.25, delayMix: 0.09, delayPingPong: true,
            masterVolume: 0.50, portamento: 0.04
        ),
        // 6. Deep House Organ Chord
        makePreset(
            name: "Deep House Organ Chord", category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sine, osc2Volume: 0.55, osc2Octave: 1,
            attack: 0.003, decay: 0.4, sustain: 0.4, release: 0.2,
            filterType: .lowPass, filterCutoff: 3400, filterResonance: 0.3, filterEnvelopeAmount: 0.45, filterKeyTracking: 0.55,
            distortionEnabled: true, distortionType: .tubeSaturation, distortionDrive: 0.25, distortionTone: 0.5, distortionMix: 0.12,
            masterVolume: 0.54
        ),
        // 7. Trance Gate Runner
        makePreset(
            name: "Trance Gate Runner", category: .arp,
            osc1Waveform: .sawtooth, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .sawtooth, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 8,
            attack: 0.005, decay: 0.18, sustain: 0.4, release: 0.12,
            filterType: .lowPass, filterCutoff: 5000, filterResonance: 0.45, filterEnvelopeAmount: 0.5, filterKeyTracking: 0.5,
            reverbMix: 0.16, reverbRoomSize: 0.4,
            delayTime: 0.217, delayFeedback: 0.28, delayMix: 0.09, delayPingPong: true,
            masterVolume: 0.52,
            arpMode: .up, arpRate: .sixteenth, arpOctaves: 2, bpm: 138,
            sequencerData: (0..<16).map { i in
                SequencerStep(
                    isActive: [true, true, false, true, true, false, true, true, true, true, false, true, true, false, true, true][i],
                    noteOffset: [0, 0, 0, 7, 7, 0, 10, 7, 0, 0, 0, 5, 5, 0, 3, 2][i],
                    velocity: [1.0, 0.7, 0.5, 0.9, 0.7, 0.5, 0.95, 0.8, 1.0, 0.7, 0.5, 0.9, 0.7, 0.5, 0.95, 0.85][i],
                    octave: [0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0][i],
                    tie: [false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false][i],
                    gate: [0.45, 0.85, 0.5, 0.45, 0.85, 0.5, 0.9, 0.7, 0.45, 0.85, 0.5, 0.45, 0.85, 0.5, 0.9, 0.65][i]
                )
            }
        ),
        // 8. Crystal Pluck Bell
        makePreset(
            name: "Crystal Pluck Bell", category: .pluck,
            osc1Waveform: .wavetable, osc1Volume: 0.65, osc1Octave: 1, osc1WavetableIndex: 2,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.45, osc2Octave: 2, osc2Detune: 6,
            attack: 0.002, decay: 0.45, sustain: 0.05, release: 0.3,
            filterType: .lowPass, filterCutoff: 6500, filterResonance: 0.35, filterEnvelopeAmount: 0.5, filterKeyTracking: 0.65,
            delayTime: 0.30, delayFeedback: 0.25, delayMix: 0.08, delayPingPong: true,
            masterVolume: 0.52
        ),
        // 9. Warm Vinyl Rhodes
        makePreset(
            name: "Warm Vinyl Rhodes", category: .keys,
            osc1Waveform: .sine, osc1Volume: 0.70, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .triangle, osc2Volume: 0.40, osc2Octave: 1,
            attack: 0.01, decay: 1.1, sustain: 0.3, release: 0.35,
            filterType: .lowPass, filterCutoff: 3200, filterResonance: 0.2, filterKeyTracking: 0.6,
            reverbMix: 0.15, reverbRoomSize: 0.35,
            chorusRate: 0.8, chorusDepth: 0.25, chorusMix: 0.08,
            masterVolume: 0.52,
            modMatrix: [ModMatrixEntry(source: .velocity, destination: .cutoff, amount: 0.45)]
        ),
        // 10. Galactic Funk Lead
        makePreset(
            name: "Galactic Funk Lead", category: .lead,
            osc1Waveform: .sawtooth, osc1Volume: 0.65, osc1Octave: 0,
            osc2Enabled: true, osc2Waveform: .square, osc2Volume: 0.50, osc2Octave: 0, osc2Detune: 7,
            attack: 0.01, decay: 0.4, sustain: 0.6, release: 0.25,
            filterType: .lowPass, filterCutoff: 2500, filterResonance: 0.6, filterEnvelopeAmount: 0.65, filterKeyTracking: 0.5,
            phaserEnabled: true, phaserMode: .phaser4, phaserRate: 0.4, phaserDepth: 0.4, phaserFeedback: 0.2, phaserMix: 0.18,
            masterVolume: 0.52, portamento: 0.035
        )
    ]
}
