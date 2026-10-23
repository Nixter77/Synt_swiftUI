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
        // SYNT_16 R13-1: mirror pending controller MPE config first, so the snapshot built
        // below carries it (closes the standalone poll window).
        pollMPEConfigMailbox()
        if let data = preset.userWavetableData {
            let sampleRate = self.sampleRate
            let name = preset.userWavetableName ?? "User"
            // SYNT_16 R13-5: same retained Data buffer + same SR as the last resolved blob means
            // the same bytes (Data is immutable and we hold it), so skip the ~512 KB hash on main.
            let fast: CompiledMipData? = {
                guard let last = lastUserWTData, let compiled = lastUserWTCompiled,
                      lastUserWTSampleRate == sampleRate,
                      AudioEngine.sameDataBuffer(last, data) else { return nil }
                return compiled
            }()
            if let fast { userWTFastPathCountForTesting += 1 }
            if let cached = fast ?? WavetableOscillator.compileUserWavetableAsyncIfNeeded(
                data: data,
                name: name,
                sampleRate: sampleRate,
                completion: { [weak self] compiled in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if self.preset.userWavetableData == data {
                            self.lastUserWTData = data
                            self.lastUserWTSampleRate = sampleRate
                            self.lastUserWTCompiled = compiled
                        }
                        self.userWavetable = compiled.wavetable
                        self.userCompiledWavetable = compiled
                        self.wavetableEngine1.instanceUserWavetable = compiled.wavetable
                        self.wavetableEngine1.instanceUserCompiled = compiled
                        self.wavetableEngine2.instanceUserWavetable = compiled.wavetable
                        self.wavetableEngine2.instanceUserCompiled = compiled
                        WavetableOscillator.userWavetable = compiled.wavetable
                        WavetableOscillator.userCompiledWavetable = compiled

                        // R11-4: Check CURRENT state, not stale captured variables
                        if self.preset.osc1Waveform == .wavetable && self.preset.osc1WavetableIndex == 5 && self.wavetableEngine1.activeCompiled !== compiled {
                            self.loadedWTIndex1 = 5
                            self.wavetableEngine1.loadCompiledWavetable(compiled)
                        }
                        if self.preset.osc2Waveform == .wavetable && self.preset.osc2WavetableIndex == 5 && self.wavetableEngine2.activeCompiled !== compiled {
                            self.loadedWTIndex2 = 5
                            self.wavetableEngine2.loadCompiledWavetable(compiled)
                        }
                    }
                }
            ) {
                lastUserWTData = data
                lastUserWTSampleRate = sampleRate
                lastUserWTCompiled = cached
                self.userWavetable = cached.wavetable
                self.userCompiledWavetable = cached
                self.wavetableEngine1.instanceUserWavetable = cached.wavetable
                self.wavetableEngine1.instanceUserCompiled = cached
                self.wavetableEngine2.instanceUserWavetable = cached.wavetable
                self.wavetableEngine2.instanceUserCompiled = cached
                if WavetableOscillator.userCompiledWavetable !== cached {
                    WavetableOscillator.userWavetable = cached.wavetable
                    WavetableOscillator.userCompiledWavetable = cached
                }
                if preset.osc1Waveform == .wavetable && preset.osc1WavetableIndex == 5 && wavetableEngine1.activeCompiled !== cached {
                    loadedWTIndex1 = 5
                    wavetableEngine1.loadCompiledWavetable(cached)
                }
                if preset.osc2Waveform == .wavetable && preset.osc2WavetableIndex == 5 && wavetableEngine2.activeCompiled !== cached {
                    loadedWTIndex2 = 5
                    wavetableEngine2.loadCompiledWavetable(cached)
                }
            }
        }
        // Bank first, then the row that reads it. A buffer must not see `.mseg`
        // against the previous curve.
        publishMSEG(preset.mseg)
        publishMSEG2(preset.mseg2)
        rtModMatrix.publish(preset.modMatrix)
        let snap = RTPresetSnapshot(from: preset, rendersAllDelayInDSP: rendersAllDelayInDSP)
        // SYNT_17 R14-1: main-side routing mirror = controller override ?? user value (last change wins).
        mpeEnabled = controllerMPEMain.adoptEnabled(preset.mpeEnabled)
        mpePitchBendRange = controllerMPEMain.adoptMemberRange(preset.mpePitchBendRange)
        mpeZone = controllerMPEMain.adoptZone(preset.mpeZone)
        mpeMemberChannelCount = controllerMPEMain.adoptMemberCount(preset.mpeMemberChannelCount)
        rtPresetBuffer.publish(snap)
        if !isRenderingActive.load(ordering: .acquiring) {
            cachedFXOrder = snap.fxOrder
            applyPresetDSP(snap)
        }

        parameterReverbMix = preset.reverbMix
        parameterReverbRoom = preset.reverbRoomSize
        if preset.dspReverbEnabled {
            reverb.reverb.bypass = true
            reverb.wetDryMix = 0
        } else {
            reverb.reverb.bypass = false
            reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
            reverb.setRoomSize(preset.reverbRoomSize)
        }

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

    /// Main thread. An empty list publishes a zero-length bank. A finished model is swapped in.
    func publishMSEG(_ spec: MSEGPreset) {
        guard !spec.points.isEmpty else {
            mseg.publishEmpty()
            return
        }
        mseg.publish(DSPMSEGModel(
            points: spec.points,
            isOneShot: spec.isOneShot,
            syncMode: spec.syncMode,
            rateHz: spec.rateHz,
            syncBeats: spec.syncBeats,
            triggerMode: spec.triggerMode,
            loopStartIndex: spec.loopStartIndex,
            loopEndIndex: spec.loopEndIndex,
            sustainIndex: spec.sustainIndex
        ))
    }

    /// Main thread. An empty list publishes a zero-length bank for MSEG 2.
    func publishMSEG2(_ spec: MSEGPreset) {
        guard !spec.points.isEmpty else {
            mseg2.publishEmpty()
            return
        }
        mseg2.publish(DSPMSEGModel(
            points: spec.points,
            isOneShot: spec.isOneShot,
            syncMode: spec.syncMode,
            rateHz: spec.rateHz,
            syncBeats: spec.syncBeats,
            triggerMode: spec.triggerMode,
            loopStartIndex: spec.loopStartIndex,
            loopEndIndex: spec.loopEndIndex,
            sustainIndex: spec.sustainIndex
        ))
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
        envelope.attackCurve = snap.attackCurve
        envelope.decayCurve = snap.decayCurve
        envelope.releaseCurve = snap.releaseCurve

        filterEnvelope.attack = snap.filterAttack
        filterEnvelope.decay = snap.filterDecay
        filterEnvelope.sustain = snap.filterSustain
        filterEnvelope.release = snap.filterRelease

        modEnvelope.attack = snap.modEnvAttack
        modEnvelope.decay = snap.modEnvDecay
        modEnvelope.sustain = snap.modEnvSustain
        modEnvelope.release = snap.modEnvRelease

        filterL.type = snap.filterType
        filterR.type = snap.filterType
        filterL.cutoff = snap.filterCutoff
        filterR.cutoff = snap.filterCutoff
        filterL.resonance = snap.filterResonance
        filterR.resonance = snap.filterResonance

        lfo.enabled = snap.lfoEnabled
        lfo.mode = snap.lfoMode
        lfo.startPhaseDegrees = snap.lfoStartPhase
        cachedLfoTempoSync = snap.lfoTempoSync
        cachedLfoSyncDivision = snap.lfoSyncDivision
        lfo.rate = snap.lfoRate
        cachedLfoDepth = snap.lfoDepth
        cachedLfoRowsFollowDepth = snap.lfoRowsFollowDepth
        lfo.waveform = snap.lfoWaveform
        lfo.target = snap.lfoTarget
        lfo.stereoPhaseOffsetDegrees = snap.lfoStereoPhase

        lfo2.enabled = snap.lfo2Enabled
        lfo2.mode = snap.lfo2Mode
        lfo2.startPhaseDegrees = snap.lfo2StartPhase
        lfo2.stereoPhaseOffsetDegrees = snap.lfo2StereoPhase
        cachedLfo2TempoSync = snap.lfo2TempoSync
        cachedLfo2SyncDivision = snap.lfo2SyncDivision
        lfo2.rate = snap.lfo2Rate
        cachedLfo2Depth = snap.lfo2Depth
        lfo2.waveform = snap.lfo2Waveform
        lfo2.target = snap.lfo2Target

        adoptHostMasterBendRange(snap.pitchBendRange)
        cachedReverbShimmer = snap.reverbShimmer
        cachedRingModAmount = snap.ringModAmount
        cachedNoiseColor = snap.noiseColor

        dspChorus.feedback = snap.chorusFeedback
        dspChorus.depth = snap.chorusDepth
        dspChorus.mix = snap.chorusMix
        dspChorus.stereo = snap.chorusStereo
        cachedChorusStereo = snap.chorusStereo
        cachedChorusFlanger = snap.chorusFlanger
        cachedChorusFlangerSync = snap.chorusFlangerSync
        cachedChorusFlangerDivision = snap.chorusFlangerDivision
        if snap.chorusFlanger && snap.chorusFlangerSync {
            dspChorus.rate = snap.flangerRateHz
        } else {
            dspChorus.rate = snap.chorusRate
        }
        cachedFilterFeedback = snap.filterFeedback
        let reverbWasOn = cachedDSPReverb
        cachedDSPReverb = snap.dspReverbEnabled
        cachedReverbMix = max(0, min(1, snap.reverbMix))
        cachedReverbRoom = max(0, min(1, snap.reverbRoomSize))
        cachedReverbDamping = snap.reverbDamping
        if reverbWasOn && !cachedDSPReverb {
            dspReverb.reset()
        }
        cachedOsc2Fixed = snap.osc2FixedFrequency
        cachedOsc2Hz = snap.osc2FrequencyHz
        let hpfWasOn = cachedSceneHPF
        cachedSceneHPF = snap.sceneHPFEnabled
        cachedSceneHPFHz = snap.sceneHPFFrequency
        if hpfWasOn && !cachedSceneHPF {
            sceneHPF.reset()
        }
        dspChorus.ensemble = snap.chorusMode == .ensemble
        dspChorus.flanger = snap.chorusMode != .ensemble && (snap.chorusMode == .flanger || snap.chorusFlanger)
        cachedFMRatio = snap.fmRatioEnabled
        cachedFMCoarse = snap.fmCoarse
        cachedFMFine = snap.fmFine
        cachedFMRoute = snap.fmRoute
        cachedFilter2Routing = snap.filter2Routing
        cachedFilter2Type = snap.filter2Type
        cachedFilter2Cutoff = snap.filter2Cutoff
        cachedFilter2Resonance = snap.filter2Resonance
        cachedFilter2Balance = snap.filter2Balance
        cachedFilterVowel = snap.filterVowel

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
        cachedArpLatch = snap.arpLatch
        cachedVelocityCurve = snap.velocityCurve
        cachedVelocityToVolume = snap.velocityToVolume
        cachedGlideMode = snap.glideMode
        cachedGlideLegatoOnly = snap.glideLegatoOnly
        cachedMonoPriority = snap.monoPriority
        let stereoWasOn = cachedStereoEnabled
        cachedStereoEnabled = snap.stereoEnabled
        cachedStereoWidth = snap.stereoWidth
        cachedStereoMidSide = snap.stereoMidSide
        cachedStereoHaasMs = snap.stereoHaasMs
        cachedStereoMonoBassHz = snap.stereoMonoBassHz
        if stereoWasOn && !cachedStereoEnabled {
            stereoTool.reset()
        }
        cachedEnvFollowerAttack = snap.envFollowerAttack
        cachedEnvFollowerRelease = snap.envFollowerRelease
        cachedSendA = snap.sendA
        cachedSendB = snap.sendB
        cachedSendPostInsert = snap.sendPostInsert
        cachedSendDelayTime = snap.delayEffectiveTime
        cachedSendDelayFeedback = snap.delayFeedback
        cachedRotaryEnabled = snap.rotaryEnabled
        cachedRotaryFast = snap.rotaryFast
        cachedRotaryHornSlow = snap.rotaryHornSlow
        cachedRotaryHornFast = snap.rotaryHornFast
        cachedRotaryDrumSlow = snap.rotaryDrumSlow
        cachedRotaryDrumFast = snap.rotaryDrumFast
        cachedRotaryDrive = snap.rotaryDrive
        cachedRotaryMix = snap.rotaryMix
        cachedRotaryAccel = snap.rotaryAccel
        cachedTransientEnabled = snap.transientEnabled
        cachedTransientAttack = snap.transientAttack
        cachedTransientSustain = snap.transientSustain
        cachedTransientOutput = snap.transientOutput
        cachedTransientMix = snap.transientMix
        // SYNT_16 R13-1: controller RPN/MCM values survive a snapshot that repeats the host values.
        adoptHostMPEEnabled(snap.mpeEnabled)
        adoptHostMPEMemberRange(snap.mpePitchBendRange)
        adoptHostMPEZone(snap.mpeZone)
        adoptHostMPEMemberCount(snap.mpeMemberChannelCount)
        cachedOscPhaseMode = snap.oscPhaseMode
        cachedPolyphonyLimit = snap.polyphonyLimit
        cachedTranceEnabled = snap.tranceGateEnabled
        cachedTranceSteps = snap.tranceGatePattern
        cachedTranceDepth = snap.tranceGateDepth
        cachedTranceSmooth = snap.tranceGateSmooth
        cachedTranceDivision = snap.tranceGateDivision
        cachedPerlinTempoSync = snap.perlinTempoSync
        cachedPerlinDivision = snap.perlinSyncDivision
        cachedPerlinHz = snap.perlinRate
        if cachedPolyphonyLimit > 0 && cachedPolyphonyLimit < AudioEngine.maxVoices {
            for i in cachedPolyphonyLimit..<AudioEngine.maxVoices {
                if voices[i].isActive && !voices[i].isReleasing {
                    voices[i].beginFastRelease()
                }
            }
        }
        arp.mode = snap.arpMode
        arp.octaves = snap.arpOctaves
        arp.latch = snap.arpLatch
        cachedDelayPingPong = snap.delayPingPong || snap.rendersAllDelayInDSP
        cachedDelayTempoSync = snap.delayTempoSync
        cachedDelaySyncDivision = snap.delaySyncDivision
        cachedMacro1 = snap.macro1
        cachedMacro2 = snap.macro2
        cachedMacro3 = snap.macro3
        cachedMacro4 = snap.macro4
        cachedMacro5 = snap.macro5
        cachedMacro6 = snap.macro6
        cachedMacro7 = snap.macro7
        cachedMacro8 = snap.macro8
        cachedRandomSeed = snap.randomSeed
        cachedAttackCurve = snap.attackCurve
        cachedDecayCurve = snap.decayCurve
        cachedReleaseCurve = snap.releaseCurve
        cachedLfoStereoPhase = snap.lfoStereoPhase
        cachedLfo2StereoPhase = snap.lfo2StereoPhase
        cachedFrequencyShifterEnabled = snap.frequencyShifterEnabled
        cachedFrequencyShifterShiftHz = snap.frequencyShifterShiftHz
        cachedFrequencyShifterMix = snap.frequencyShifterMix
        cachedFrequencyShifterFeedback = snap.frequencyShifterFeedback
        cachedCharacter = snap.character
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
        stereoTool.reset()
        shimmer.reset()
        dspReverb.reset()
        sceneHPF.reset()
        tranceStep = 0
        tranceCursor = 0
        tranceGain = 1
        smoothRandom.reset()
        distortion.reset()
        parametricEQL.reset()
        parametricEQR.reset()
        phaser.reset()
        transientShaper.reset()
        lfo.reset()
        lfo2.reset()
        rotary.snapSpeeds(
            hornSlow: cachedRotaryHornSlow,
            hornFast: cachedRotaryHornFast,
            drumSlow: cachedRotaryDrumSlow,
            drumFast: cachedRotaryDrumFast,
            fast: cachedRotaryFast
        )
        lastMatrixLFO = 0
        lastMatrixLFO2 = 0
        smoothedFilterCutoff = cachedFilterCutoff
        smoothedMasterVolume = cachedMasterVolume
        lastPlayedFrequency = nil
        snapCCTargetsFromLive()
        if let seed = cachedRandomSeed {
            let effectiveSeed = seed == 0 ? 0x12345678 : seed
            randomSeed = effectiveSeed
            lfo.setRandomSeed(effectiveSeed)
            lfo2.setRandomSeed(effectiveSeed ^ 0x5555_5555)
            smoothRandom.reset(seed: effectiveSeed)
        } else {
            let defaultSeed: UInt32 = 0x12345678
            randomSeed = defaultSeed
            lfo.setRandomSeed(defaultSeed)
            lfo2.setRandomSeed(defaultSeed ^ 0x5555_5555)
            smoothRandom.reset()
        }
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
        if !isRenderingActive.load(ordering: .acquiring) {
            cachedFXOrder = table
        }
        _ = commandQueue.push(.setFXOrder(table: table))
    }

    /// Loads a user wavetable file into the shared user slot and applies it to the specified oscillator.
    public func loadUserWavetable(url: URL, forOscillator oscNumber: Int = 1) throws {
        let table = try WavetableOscillator.parseAudioFile(url: url)
        let key = WavetableCacheKey(contentHash: table.contentHash, sampleRate: sampleRate)
        let compiled: CompiledMipData
        if let cached = WavetableOscillator.getCachedCompiled(for: key) {
            compiled = cached
        } else {
            compiled = WavetableOscillator.compile(wavetable: table, sampleRate: sampleRate)
            WavetableOscillator.setCachedCompiled(compiled, for: key)
        }
        userWavetable = table
        userCompiledWavetable = compiled
        WavetableOscillator.userWavetable = table
        WavetableOscillator.userCompiledWavetable = compiled

        // R11-4: Target ONLY the requesting oscillator!
        if oscNumber == 1 {
            loadedWTIndex1 = 5
            wavetableEngine1.instanceUserWavetable = table
            wavetableEngine1.instanceUserCompiled = compiled
            wavetableEngine1.loadCompiledWavetable(compiled)
            updatePreset { p in
                p.userWavetableName = table.name
                p.userWavetableData = table.compressedSerializedData()
                p.osc1Waveform = .wavetable
                p.osc1WavetableIndex = 5
            }
        } else if oscNumber == 2 {
            loadedWTIndex2 = 5
            wavetableEngine2.instanceUserWavetable = table
            wavetableEngine2.instanceUserCompiled = compiled
            wavetableEngine2.loadCompiledWavetable(compiled)
            updatePreset { p in
                p.userWavetableName = table.name
                p.userWavetableData = table.compressedSerializedData()
                p.osc2Waveform = .wavetable
                p.osc2WavetableIndex = 5
            }
        }
    }

    /// Loads user wavetable from raw float samples.
    public func loadUserWavetable(samples: [Float], name: String = "Imported", forOscillator oscNumber: Int = 1) throws {
        let table = try WavetableOscillator.importAudioBuffer(samples: samples, name: name)
        let key = WavetableCacheKey(contentHash: table.contentHash, sampleRate: sampleRate)
        let compiled: CompiledMipData
        if let cached = WavetableOscillator.getCachedCompiled(for: key) {
            compiled = cached
        } else {
            compiled = WavetableOscillator.compile(wavetable: table, sampleRate: sampleRate)
            WavetableOscillator.setCachedCompiled(compiled, for: key)
        }
        userWavetable = table
        userCompiledWavetable = compiled
        WavetableOscillator.userWavetable = table
        WavetableOscillator.userCompiledWavetable = compiled

        // R11-4: Target ONLY the requesting oscillator!
        if oscNumber == 1 {
            loadedWTIndex1 = 5
            wavetableEngine1.instanceUserWavetable = table
            wavetableEngine1.instanceUserCompiled = compiled
            wavetableEngine1.loadCompiledWavetable(compiled)
            updatePreset { p in
                p.userWavetableName = table.name
                p.userWavetableData = table.compressedSerializedData()
                p.osc1Waveform = .wavetable
                p.osc1WavetableIndex = 5
            }
        } else if oscNumber == 2 {
            loadedWTIndex2 = 5
            wavetableEngine2.instanceUserWavetable = table
            wavetableEngine2.instanceUserCompiled = compiled
            wavetableEngine2.loadCompiledWavetable(compiled)
            updatePreset { p in
                p.userWavetableName = table.name
                p.userWavetableData = table.compressedSerializedData()
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
            if !preset.dspReverbEnabled {
                reverb.wetDryMix = AudioMath.appleFXWetPercent(preset.reverbMix)
            }
        case .reverbRoomSize:
            if !preset.dspReverbEnabled {
                reverb.setRoomSize(preset.reverbRoomSize)
            }
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

    /// SYNT_16 R13-5: true only when both values share one heap buffer (large Data is
    /// reference-backed; small inline Data never matches, so it just takes the slow path).
    static func sameDataBuffer(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count, a.count > 64 else { return false }
        let pa = a.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        let pb = b.withUnsafeBytes { UInt(bitPattern: $0.baseAddress) }
        return pa != 0 && pa == pb
    }
}
