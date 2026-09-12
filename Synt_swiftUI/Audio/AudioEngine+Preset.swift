//
//  AudioEngine+Preset.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

extension AudioEngine {
    // MARK: - Preset

    func applyPreset() {
        oscillator1.waveform = preset.osc1Waveform
        oscillator1.volume = preset.osc1Volume
        oscillator1.octave = preset.osc1Octave
        oscillator1.detune = preset.osc1Detune
        oscillator1.pulseWidth = preset.osc1PulseWidth
        oscillator1.wavetableMorph = max(0, min(1, preset.osc1WavetableMorph))

        oscillator2.waveform = preset.osc2Waveform
        oscillator2.volume = preset.osc2Volume
        oscillator2.octave = preset.osc2Octave
        oscillator2.detune = preset.osc2Detune
        oscillator2.pulseWidth = preset.osc2PulseWidth
        oscillator2.wavetableMorph = max(0, min(1, preset.osc2WavetableMorph))

        envelope.attack = preset.attack
        envelope.decay = preset.decay
        envelope.sustain = preset.sustain
        envelope.release = preset.release

        filterL.type = preset.filterType
        filterR.type = preset.filterType
        filterL.cutoff = preset.filterCutoff
        filterR.cutoff = preset.filterCutoff
        filterL.resonance = preset.filterResonance
        filterR.resonance = preset.filterResonance

        lfo.enabled = preset.lfoEnabled
        lfo.rate = preset.lfoRate
        lfo.depth = preset.lfoDepth
        lfo.waveform = preset.lfoWaveform
        lfo.target = preset.lfoTarget

        reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
        reverb.setRoomSize(preset.reverbRoomSize)

        dspChorus.rate = preset.chorusRate
        dspChorus.depth = preset.chorusDepth
        dspChorus.mix = preset.chorusMix

        delay.delayTime = preset.delayTime
        // Preset / knob are 0…1. DelayEffect converts to AU percent.
        // The old `* 100` wrote 28 into a 0…1 wrapper → AU 2800% → clamp 100%
        // → Crystal Lead (and any wet delay) never decayed after noteOff.
        delay.feedback = max(0, min(1, preset.delayFeedback))
        delay.wetDryMix = AudioMath.appleFXWetPercent(preset.delayMix)

        // Advanced FX (Stage 4) — loadable with factory / user presets
        distortion.enabled = preset.distortionEnabled
        distortion.type = preset.distortionType
        distortion.drive = preset.distortionDrive
        distortion.tone = preset.distortionTone
        distortion.mix = preset.distortionMix

        parametricEQL.enabled = preset.eqEnabled
        parametricEQR.enabled = preset.eqEnabled
        parametricEQL.lowGain = preset.eqLowGain
        parametricEQR.lowGain = preset.eqLowGain
        parametricEQL.lowFreq = preset.eqLowFreq
        parametricEQR.lowFreq = preset.eqLowFreq
        parametricEQL.midGain = preset.eqMidGain
        parametricEQR.midGain = preset.eqMidGain
        parametricEQL.midFreq = preset.eqMidFreq
        parametricEQR.midFreq = preset.eqMidFreq
        parametricEQL.midQ = preset.eqMidQ
        parametricEQR.midQ = preset.eqMidQ
        parametricEQL.highGain = preset.eqHighGain
        parametricEQR.highGain = preset.eqHighGain
        parametricEQL.highFreq = preset.eqHighFreq
        parametricEQR.highFreq = preset.eqHighFreq

        phaser.bypass = !preset.phaserEnabled
        phaser.mode = preset.phaserMode
        phaser.rate = preset.phaserRate
        phaser.depth = preset.phaserDepth
        phaser.feedback = preset.phaserFeedback
        phaser.centerFrequency = preset.phaserCenterFrequency
        phaser.stereoSpread = preset.phaserStereoSpread
        phaser.mix = preset.phaserMix

        // Snapshot all parameters the audio path needs
        cachedPortamento = preset.portamento
        cachedUnisonVoices = preset.unisonVoices
        cachedUnisonDetune = preset.unisonDetune
        cachedUnisonSpread = preset.unisonSpread
        cachedModMatrix = preset.modMatrix
        cachedOsc2Enabled = preset.osc2Enabled
        cachedFilterCutoff = preset.filterCutoff
        cachedMasterVolume = preset.masterVolume
        cachedBPM = preset.bpm
        cachedArpMode = preset.arpMode
        // Do NOT touch `arp` here — it is audio-thread state.
        // generateSample / processCommandQueue apply cachedArpMode on the audio path.

        let switchedPatch = lastAppliedPresetID != nil
            && (lastAppliedPresetID != preset.id || lastAppliedPresetName != preset.name)
        lastAppliedPresetID = preset.id
        lastAppliedPresetName = preset.name
        if switchedPatch {
            silenceForPresetChange()
        }
    }

    func loadPreset(_ preset: SynthPreset) {
        self.preset = preset
    }

    /// New factory/user patch: stop leftover voices and wipe Delay/Reverb tails.
    /// Knob edits keep the same id/name and must not cut the note.
    func silenceForPresetChange() {
        clearAllNotes()
        filterL.reset()
        filterR.reset()
        dspChorus.reset()
        distortion.reset()
        parametricEQL.reset()
        parametricEQR.reset()
        phaser.reset()
        lfo.reset()
        delay.reset()
        reverb.reset()
        smoothedFilterCutoff = cachedFilterCutoff
        smoothedMasterVolume = cachedMasterVolume
        lastPlayedFrequency = nil
    }

    /// Mutate the published preset as a whole so `didSet` → `applyPreset()` always runs.
    /// UI must use this (or assign `preset = …`) for advanced FX / morph — never write
    /// only to live `distortion` / `phaser` / oscillator morph and leave `preset` stale.
    func updatePreset(_ body: (inout SynthPreset) -> Void) {
        var next = preset
        body(&next)
        preset = next
    }
}
