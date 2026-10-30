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
