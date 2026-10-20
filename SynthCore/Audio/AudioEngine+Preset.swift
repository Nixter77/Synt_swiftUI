//
//  AudioEngine+Preset.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

public extension AudioEngine {
    // MARK: - Preset

    public func applyPreset() {
        applyPresetCallCountForTesting += 1
        rtModMatrix.publish(preset.modMatrix)
        let snap = RTPresetSnapshot(from: preset, rendersAllDelayInDSP: rendersAllDelayInDSP)
        rtPresetBuffer.publish(snap)
        cachedFXOrder = snap.fxOrder
        if !isRenderingActive.load(ordering: .acquiring) {
            applyPresetDSP(snap)
        }

        parameterReverbMix = preset.reverbMix
        parameterReverbRoom = preset.reverbRoomSize
        reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
        reverb.setRoomSize(preset.reverbRoomSize)

        parameterDelayTime = preset.delayTime
        parameterDelayFeedback = preset.delayFeedback
        parameterDelayMix = preset.delayMix
        if !preset.delayPingPong && !rendersAllDelayInDSP {
            delay.delayTime = snap.delayEffectiveTime
            delay.feedback = max(0, min(1, preset.delayFeedback))
            delay.wetDryMix = AudioMath.appleFXWetPercent(preset.delayMix)
        }

        let switchedPatch = lastAppliedPresetID != nil
            && (lastAppliedPresetID != preset.id || lastAppliedPresetName != preset.name)
        lastAppliedPresetID = preset.id
        lastAppliedPresetName = preset.name
        if switchedPatch {
            disarmCCTakeover()
            silenceForPresetChange()
        }
    }

    public func applyPresetDSP(_ snap: RTPresetSnapshot) {
        cachedFXOrder = snap.fxOrder
        oscillator1.waveform = snap.osc1Waveform
        oscillator1.volume = snap.osc1Volume
        oscillator1.octave = snap.osc1Octave
        oscillator1.detune = snap.osc1Detune
        oscillator1.pulseWidth = snap.osc1PulseWidth
        oscillator1.wavetableMorph = snap.osc1WavetableMorph
        if snap.osc1WavetableIndex != loadedWTIndex1 {
            loadedWTIndex1 = snap.osc1WavetableIndex
            wavetableEngine1.loadBuiltin(index: snap.osc1WavetableIndex)
        }

        oscillator2.waveform = snap.osc2Waveform
        oscillator2.volume = snap.osc2Volume
        oscillator2.octave = snap.osc2Octave
        oscillator2.detune = snap.osc2Detune
        oscillator2.pulseWidth = snap.osc2PulseWidth
        oscillator2.wavetableMorph = snap.osc2WavetableMorph
        if snap.osc2WavetableIndex != loadedWTIndex2 {
            loadedWTIndex2 = snap.osc2WavetableIndex
            wavetableEngine2.loadBuiltin(index: snap.osc2WavetableIndex)
        }

        envelope.attack = snap.attack
        envelope.decay = snap.decay
        envelope.sustain = snap.sustain
        envelope.release = snap.release

        filterEnvelope.attack = snap.filterAttack
        filterEnvelope.decay = snap.filterDecay
        filterEnvelope.sustain = snap.filterSustain
        filterEnvelope.release = snap.filterRelease

        filterL.type = snap.filterType
        filterR.type = snap.filterType
        filterL.cutoff = snap.filterCutoff
        filterR.cutoff = snap.filterCutoff
        filterL.resonance = snap.filterResonance
        filterR.resonance = snap.filterResonance

        lfo.enabled = snap.lfoEnabled
        cachedLfoTempoSync = snap.lfoTempoSync
        cachedLfoSyncDivision = snap.lfoSyncDivision
        lfo.rate = snap.lfoRate
        cachedLfoDepth = snap.lfoDepth
        cachedLfoRowsFollowDepth = snap.lfoRowsFollowDepth
        lfo.waveform = snap.lfoWaveform
        lfo.target = snap.lfoTarget

        lfo2.enabled = snap.lfo2Enabled
        cachedLfo2TempoSync = snap.lfo2TempoSync
        cachedLfo2SyncDivision = snap.lfo2SyncDivision
        lfo2.rate = snap.lfo2Rate
        cachedLfo2Depth = snap.lfo2Depth
        lfo2.waveform = snap.lfo2Waveform
        lfo2.target = snap.lfo2Target

        cachedPitchBendRange = snap.pitchBendRange
        cachedReverbShimmer = snap.reverbShimmer
        cachedRingModAmount = snap.ringModAmount
        cachedNoiseColor = snap.noiseColor

        dspChorus.rate = snap.chorusRate
        dspChorus.depth = snap.chorusDepth
        dspChorus.mix = snap.chorusMix
        dspChorus.stereo = snap.chorusStereo
        cachedChorusStereo = snap.chorusStereo

        cachedDelayPingPong = snap.delayPingPong || snap.rendersAllDelayInDSP || snap.rendersAllDelayInDSP
        if snap.delayPingPong || snap.rendersAllDelayInDSP {
            delay.wetDryMix = 0.0
            pingPongDelay.crossFeed = snap.delayPingPong
            pingPongDelay.enabled = true
            pingPongDelay.delayTime = snap.delayEffectiveTime
            pingPongDelay.feedback = snap.delayFeedback
            pingPongDelay.mix = snap.delayMix
        } else {
            pingPongDelay.enabled = false
            pingPongDelay.reset()
        }

        distortion.enabled = snap.distortionEnabled
        distortion.type = snap.distortionType
        distortion.drive = snap.distortionDrive
        distortion.tone = snap.distortionTone
        distortion.mix = snap.distortionMix
        distortion.oversampling = snap.distortionOversampling

        parametricEQL.enabled = snap.eqEnabled
        parametricEQR.enabled = snap.eqEnabled
        parametricEQL.lowGain = snap.eqLowGain
        parametricEQR.lowGain = snap.eqLowGain
        parametricEQL.lowFreq = snap.eqLowFreq
        parametricEQR.lowFreq = snap.eqLowFreq
        parametricEQL.midGain = snap.eqMidGain
        parametricEQR.midGain = snap.eqMidGain
        parametricEQL.midFreq = snap.eqMidFreq
        parametricEQR.midFreq = snap.eqMidFreq
        parametricEQL.midQ = snap.eqMidQ
        parametricEQR.midQ = snap.eqMidQ
        parametricEQL.highGain = snap.eqHighGain
        parametricEQR.highGain = snap.eqHighGain
        parametricEQL.highFreq = snap.eqHighFreq
        parametricEQR.highFreq = snap.eqHighFreq

        phaser.bypass = !snap.phaserEnabled
        phaser.mode = snap.phaserMode
        phaser.rate = snap.phaserRate
        phaser.depth = snap.phaserDepth
        phaser.feedback = snap.phaserFeedback
        phaser.centerFrequency = snap.phaserCenterFrequency
        phaser.stereoSpread = snap.phaserStereoSpread
        phaser.mix = snap.phaserMix

        cachedFXOrder = snap.fxOrder
        cachedPortamento = snap.portamento
        cachedUnisonVoices = snap.unisonVoices
        cachedUnisonDetune = snap.unisonDetune
        cachedUnisonSpread = snap.unisonSpread
        cachedAnalogDrift = snap.analogDrift
        cachedChordMode = snap.chordMode
        cachedVoiceMode = snap.voiceMode
        cachedOsc2Enabled = snap.osc2Enabled
        cachedSubOscVolume = snap.subOscVolume
        cachedSubOscOctave = snap.subOscOctave
        cachedSubOscWaveform = snap.subOscWaveform
        cachedFmAmount = snap.fmAmount
        cachedOscSyncEnabled = snap.oscSyncEnabled
        cachedFilterCutoff = snap.filterCutoff
        cachedFilterDrive = snap.filterDrive
        cachedFilterEnvAmount = snap.filterEnvAmount
        cachedFilterKeyTracking = snap.filterKeyTracking
        cachedFilterEnvUseDedicatedADSR = snap.filterEnvUseDedicatedADSR
        cachedFilterAttack = snap.filterAttack
        cachedFilterDecay = snap.filterDecay
        cachedFilterSustain = snap.filterSustain
        cachedFilterRelease = snap.filterRelease
        cachedVelocityToCutoff = snap.velocityToCutoff
        cachedVelocityToEnvAmount = snap.velocityToEnvAmount
        cachedMasterVolume = snap.masterVolume
        cachedBPM = snap.bpm
        cachedSyncSource = snap.syncSource
        cachedArpMode = snap.arpMode
        cachedArpRate = snap.arpRate
        cachedArpOctaves = snap.arpOctaves
        cachedArpGateLength = snap.arpGateLength
        cachedArpSwing = snap.arpSwing
        cachedDelayPingPong = snap.delayPingPong || snap.rendersAllDelayInDSP
        cachedDelayTempoSync = snap.delayTempoSync
        cachedDelaySyncDivision = snap.delaySyncDivision
        cachedMacro1 = snap.macro1
        cachedMacro2 = snap.macro2
        cachedMacro3 = snap.macro3
        cachedMacro4 = snap.macro4
        ccPanTarget = snap.pan
        ccPanRT = snap.pan
        snapCCTargetsFromLive()
    }

    public func loadPreset(_ preset: SynthPreset) {
        self.preset = preset
    }

    /// New factory/user patch: stop leftover voices and wipe Delay/Reverb tails.
    /// Knob edits keep the same id/name and must not cut the note.
    public func silenceForPresetChange() {
        clearAllNotes()
        // Render-owned state is reset by the render thread, never from here.
        _ = commandQueue.push(.resetPatchState)
        // Apple AUs: AudioUnitReset is the main-thread API.
        delay.reset()
        reverb.reset()
    }

    /// Render thread only (via `.resetPatchState`).
    public func resetPatchStateRT() {
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
    public func updatePreset(_ body: (inout SynthPreset) -> Void) {
        var next = preset
        body(&next)
        preset = next
    }

    /// Reorders the FX chain on the main thread and publishes the fixed table to the RT audio thread.
    public func setFXOrder(_ order: [FXSlotID]) {
        let clean = SynthPreset.sanitizeFXOrder(order)
        if Thread.isMainThread {
            updatePreset { $0.fxOrder = clean }
        } else {
            DispatchQueue.main.sync { [weak self] in
                self?.updatePreset { $0.fxOrder = clean }
            }
        }
        let table = FXOrderTable(order: clean)
        cachedFXOrder = table
        _ = commandQueue.push(.setFXOrder(table: table))
    }

    /// Loads a user wavetable file into the shared user slot and applies it to the specified oscillator.
    public func loadUserWavetable(url: URL, forOscillator oscNumber: Int = 1) throws {
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
    public func applySingleParameterFromMIDI(cc: UInt8, value: UInt8) {
        applyCCBatchFromMIDI([(cc: cc, value: value)])
    }

    /// Main thread, display side of MIDI CC: the `preset` fields the UI shows
    /// (published once per batch, without `applyPreset`) and the Apple AU
    /// effects. DSP state is changed only by the audio thread
    /// (`controlChange` → `applySingleParameterRT`).
    public func applyCCBatchFromMIDI(_ batch: [(cc: UInt8, value: UInt8)]) {
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
            updatePresetDisplayOnly { $0 = next }
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

