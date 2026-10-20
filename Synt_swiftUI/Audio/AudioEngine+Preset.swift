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
        applyPresetCallCountForTesting += 1
        oscillator1.waveform = preset.osc1Waveform
        oscillator1.volume = preset.osc1Volume
        oscillator1.octave = preset.osc1Octave
        oscillator1.detune = preset.osc1Detune
        oscillator1.pulseWidth = preset.osc1PulseWidth
        oscillator1.wavetableMorph = max(0, min(1, preset.osc1WavetableMorph))
        if preset.osc1WavetableIndex != loadedWTIndex1 {
            loadedWTIndex1 = preset.osc1WavetableIndex
            wavetableEngine1.loadBuiltin(index: preset.osc1WavetableIndex)
        }

        oscillator2.waveform = preset.osc2Waveform
        oscillator2.volume = preset.osc2Volume
        oscillator2.octave = preset.osc2Octave
        oscillator2.detune = preset.osc2Detune
        oscillator2.pulseWidth = preset.osc2PulseWidth
        oscillator2.wavetableMorph = max(0, min(1, preset.osc2WavetableMorph))
        if preset.osc2WavetableIndex != loadedWTIndex2 {
            loadedWTIndex2 = preset.osc2WavetableIndex
            wavetableEngine2.loadBuiltin(index: preset.osc2WavetableIndex)
        }

        envelope.attack = preset.attack
        envelope.decay = preset.decay
        envelope.sustain = preset.sustain
        envelope.release = preset.release

        filterEnvelope.attack = preset.filterAttack
        filterEnvelope.decay = preset.filterDecay
        filterEnvelope.sustain = preset.filterSustain
        filterEnvelope.release = preset.filterRelease

        filterL.type = preset.filterType
        filterR.type = preset.filterType
        filterL.cutoff = preset.filterCutoff
        filterR.cutoff = preset.filterCutoff
        filterL.resonance = preset.filterResonance
        filterR.resonance = preset.filterResonance

        lfo.enabled = preset.lfoEnabled
        if preset.lfoTempoSync {
            lfo.rate = preset.lfoSyncDivision.frequency(bpm: preset.bpm)
        } else {
            lfo.rate = preset.lfoRate
        }
        // lfo.depth itself is written only by the render thread (renderOneSample).
        cachedLfoDepth = preset.lfoDepth
        cachedLfoRowsFollowDepth = preset.lfoRowsFollowDepth
        lfo.waveform = preset.lfoWaveform
        lfo.target = preset.lfoTarget

        // LFO 2
        lfo2.enabled = preset.lfo2Enabled
        if preset.lfo2TempoSync {
            lfo2.rate = preset.lfo2SyncDivision.frequency(bpm: preset.bpm)
        } else {
            lfo2.rate = preset.lfo2Rate
        }
        cachedLfo2Depth = preset.lfo2Depth
        lfo2.waveform = preset.lfo2Waveform
        lfo2.target = preset.lfo2Target

        cachedPitchBendRange = max(0, preset.pitchBendRange)

        reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
        reverb.setRoomSize(preset.reverbRoomSize)
        cachedReverbShimmer = preset.reverbShimmer
        cachedRingModAmount = max(0, min(1, preset.ringModAmount))
        cachedNoiseColor = preset.noiseColor

        dspChorus.rate = preset.chorusRate
        dspChorus.depth = preset.chorusDepth
        dspChorus.mix = preset.chorusMix
        dspChorus.stereo = preset.chorusStereo
        cachedChorusStereo = preset.chorusStereo

        let delayEffectiveTime: Float
        if preset.delayTempoSync {
            let dur = preset.delaySyncDivision.duration(bpm: preset.bpm)
            delayEffectiveTime = max(0.001, min(2.0, dur))
        } else {
            delayEffectiveTime = preset.delayTime
        }

        if preset.delayPingPong {
            delay.wetDryMix = 0.0
            pingPongDelay.enabled = true
            pingPongDelay.delayTime = delayEffectiveTime
            pingPongDelay.feedback = preset.delayFeedback
            pingPongDelay.mix = preset.delayMix
        } else {
            pingPongDelay.enabled = false
            pingPongDelay.reset()
            delay.delayTime = delayEffectiveTime
            delay.feedback = max(0, min(1, preset.delayFeedback))
            delay.wetDryMix = AudioMath.appleFXWetPercent(preset.delayMix)
        }

        // Advanced FX (Stage 4) — loadable with factory / user presets
        distortion.enabled = preset.distortionEnabled
        distortion.type = preset.distortionType
        distortion.drive = preset.distortionDrive
        distortion.tone = preset.distortionTone
        distortion.mix = preset.distortionMix
        distortion.oversampling = preset.distortionOversampling

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
        cachedAnalogDrift = max(0, min(1, preset.analogDrift))
        cachedChordMode = preset.chordMode
        cachedVoiceMode = preset.voiceMode
        rtModMatrix.publish(preset.modMatrix)
        cachedOsc2Enabled = preset.osc2Enabled
        cachedSubOscVolume = max(0, min(1, preset.subOscVolume))
        cachedSubOscOctave = preset.subOscOctave == -2 ? -2 : -1
        cachedSubOscWaveform = preset.subOscWaveform
        cachedFmAmount = max(0, min(1, preset.fmAmount))
        cachedOscSyncEnabled = preset.oscSyncEnabled
        cachedFilterCutoff = preset.filterCutoff
        cachedFilterEnvAmount = max(-1, min(1, preset.filterEnvelopeAmount))
        cachedFilterKeyTracking = max(0, min(1, preset.filterKeyTracking))
        cachedFilterEnvUseDedicatedADSR = preset.filterEnvUseDedicatedADSR
        cachedFilterAttack = preset.filterAttack
        cachedFilterDecay = preset.filterDecay
        cachedFilterSustain = preset.filterSustain
        cachedFilterRelease = preset.filterRelease
        cachedVelocityToCutoff = max(0, min(1, preset.velocityToCutoff))
        cachedVelocityToEnvAmount = max(-1, min(1, preset.velocityToEnvAmount))
        cachedMasterVolume = preset.masterVolume
        cachedBPM = preset.bpm
        cachedArpMode = preset.arpMode
        cachedArpRate = preset.arpRate
        cachedArpOctaves = max(1, min(3, preset.arpOctaves))
        cachedArpGateLength = max(0.1, min(1.0, preset.arpGateLength))
        cachedArpSwing = max(0.0, min(0.75, preset.arpSwing))
        cachedDelayPingPong = preset.delayPingPong
        cachedMacro1 = preset.macro1
        cachedMacro2 = preset.macro2
        cachedMacro3 = preset.macro3
        cachedMacro4 = preset.macro4
        snapCCTargetsFromLive()
        // Do NOT touch `arp` here — it is audio-thread state.
        // generateSample / processCommandQueue apply cachedArpMode on the audio path.

        let switchedPatch = lastAppliedPresetID != nil
            && (lastAppliedPresetID != preset.id || lastAppliedPresetName != preset.name)
        lastAppliedPresetID = preset.id
        lastAppliedPresetName = preset.name
        if switchedPatch {
            disarmCCTakeover()
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
        // Render-owned state is reset by the render thread, never from here.
        _ = commandQueue.push(.resetPatchState)
        // Apple AUs: AudioUnitReset is the main-thread API.
        delay.reset()
        reverb.reset()
    }

    /// Render thread only (via `.resetPatchState`).
    func resetPatchStateRT() {
        ccResonanceRT = -1
        ccPanRT = 0
        ccPanTarget = 0
        filterL.reset()
        filterR.reset()
        dspChorus.reset()
        shimmer.reset()
        distortion.reset()
        parametricEQL.reset()
        parametricEQR.reset()
        phaser.reset()
        lfo.reset()
        lfo2.reset()
        lastMatrixLFO = 0
        lastMatrixLFO2 = 0
        smoothedFilterCutoff = cachedFilterCutoff
        smoothedMasterVolume = cachedMasterVolume
        lastPlayedFrequency = nil
        snapCCTargetsFromLive()
    }

    /// Mutate the published preset as a whole so `didSet` → `applyPreset()` always runs.
    /// UI must use this (or assign `preset = …`) for advanced FX / morph — never write
    /// only to live `distortion` / `phaser` / oscillator morph and leave `preset` stale.
    func updatePreset(_ body: (inout SynthPreset) -> Void) {
        var next = preset
        body(&next)
        preset = next
    }

    /// Loads a user wavetable file into the shared user slot and applies it to the specified oscillator.
    func loadUserWavetable(url: URL, forOscillator oscNumber: Int = 1) throws {
        let table = try WavetableOscillator.parseAudioFile(url: url)
        WavetableOscillator.userWavetable = table
        if oscNumber == 1 || preset.osc1WavetableIndex == 5 {
            loadedWTIndex1 = 5
            wavetableEngine1.loadWavetable(table)
        }
        if oscNumber == 2 || preset.osc2WavetableIndex == 5 {
            loadedWTIndex2 = 5
            wavetableEngine2.loadWavetable(table)
        }
        updatePreset { p in
            if oscNumber == 1 {
                p.osc1Waveform = .wavetable
                p.osc1WavetableIndex = 5
            } else {
                p.osc2Waveform = .wavetable
                p.osc2WavetableIndex = 5
            }
        }
    }

    // MARK: - Direct Parameter Modulation from MIDI CC (No applyPreset overhead)

    /// Main thread, one CC. See `applyCCBatchFromMIDI`.
    func applySingleParameterFromMIDI(cc: UInt8, value: UInt8) {
        applyCCBatchFromMIDI([(cc: cc, value: value)])
    }

    /// Main thread, display side of MIDI CC: the `preset` fields the UI shows
    /// (published once per batch, without `applyPreset`) and the Apple AU
    /// effects. DSP state is changed only by the audio thread
    /// (`controlChange` → `applySingleParameterRT`).
    func applyCCBatchFromMIDI(_ batch: [(cc: UInt8, value: UInt8)]) {
        let store = MIDICCLearnStore.shared
        var next = preset
        var touched: [MIDIControlTarget] = []
        for (cc, value) in batch {
            let target: MIDIControlTarget
            if let learning = store.learningTarget {
                store.map(cc: cc, to: learning)
                store.learningTarget = nil
                target = learning
                // The CC reached the render before it was mapped; replay it there.
                _ = commandQueue.push(.controlChange(cc: cc, value: value))
            } else if let mapped = store.mappings[cc] {
                target = mapped
                if target != .pan && !ccTakeoverShouldApply(cc: cc, raw: value, current: target.unit(in: next, pan: ccPanRT), target: target) {
                    continue
                }
            } else {
                continue
            }
            store.applyValue(value, to: target, preset: &next)
            touched.append(target)
        }
        guard !touched.isEmpty else { return }
        if next != preset {
            isUpdatingSingleParamFromMIDI = true
            preset = next
            isUpdatingSingleParamFromMIDI = false
        }
        for target in touched {
            applyAppleFXFromMIDI(target)
        }
    }

    /// Apple AU effects live on main (AU parameter API), not in the render.
    private func applyAppleFXFromMIDI(_ target: MIDIControlTarget) {
        switch target {
        case .reverbMix:
            reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
        case .reverbRoomSize:
            reverb.setRoomSize(preset.reverbRoomSize)
        case .delayMix:
            if !preset.delayPingPong {
                delay.wetDryMix = AudioMath.appleFXWetPercent(preset.delayMix)
            }
        case .delayTime:
            if !preset.delayPingPong {
                delay.delayTime = preset.delayTime
            }
        case .delayFeedback:
            if !preset.delayPingPong {
                delay.feedback = preset.delayFeedback
            }
        default:
            break
        }
    }
}

