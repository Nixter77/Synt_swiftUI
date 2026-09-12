//
//  AudioEngine+Render.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

extension AudioEngine {
    // MARK: - Audio thread render path

    /// One sample of synthesis. Commands must already be drained for this buffer.
    func renderOneSample() -> (Float, Float) {
        var mixedSampleL: Float = 0.0
        var mixedSampleR: Float = 0.0

        // --- CLOCK & ARP ---
        let bpm = cachedBPM
        let samplesPerBeat = sampleRate * 60.0 / Double(max(20, bpm))
        samplesPerTick = samplesPerBeat / 4.0

        if cachedArpMode != .off {
            arp.mode = cachedArpMode
            clockPhase += 1.0
            if clockPhase >= samplesPerTick {
                clockPhase -= samplesPerTick
                handleArpTick()
            }
        } else if let n = arp.currentNote {
            internalNoteOff(midiNote: n)
            arp.currentNote = nil
        }

        let lfoValue = lfo.getValue(sampleRate: sampleRate)
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let modMatrix = cachedModMatrix

        noiseSeed = noiseSeed &* 1664525 &+ 1013904223
        let noiseValue = Float(noiseSeed) / Float(UInt32.max) * 2.0 - 1.0

        if oscillator1.waveform == .wavetable {
            wavetableEngine1.targetFramePosition = max(0, min(1, oscillator1.wavetableMorph))
            wavetableEngine1.advanceMorph()
        }
        if oscillator2.waveform == .wavetable {
            wavetableEngine2.targetFramePosition = max(0, min(1, oscillator2.wavetableMorph))
            wavetableEngine2.advanceMorph()
        }

        smoothedFilterCutoff = smoothedFilterCutoff * smoothingCoeff + cachedFilterCutoff * (1 - smoothingCoeff)
        smoothedMasterVolume = smoothedMasterVolume * smoothingCoeff + cachedMasterVolume * (1 - smoothingCoeff)
        var cutoff = smoothedFilterCutoff
        if lfoEnabled && lfoTarget == .filter {
            cutoff = lfo.modulateFilter(cutoff, lfoValue: lfoValue)
        }
        filterL.cutoff = cutoff
        let filterCoeffs = filterL.currentCoefficients(sampleRate: Float(sampleRate))

        // Fixed pool scan — work on a local copy to satisfy exclusivity + keep RT simple.
        for i in 0..<AudioEngine.maxVoices {
            guard voices[i].isActive else { continue }
            var v = voices[i]

            if cachedPortamento > 0.001 {
                let glideRate = 1.0 - exp(-5.0 / (Double(cachedPortamento) * sampleRate))
                v.currentFrequency += (v.targetFrequency - v.currentFrequency) * glideRate
                if abs(v.currentFrequency - v.targetFrequency) < 0.1 {
                    v.currentFrequency = v.targetFrequency
                }
            } else {
                v.currentFrequency = v.targetFrequency
            }

            let baseFrequency = v.currentFrequency
            var osc1Freq = oscillator1.frequencyWithModifiers(baseFrequency)
            var osc2Freq = oscillator2.frequencyWithModifiers(baseFrequency)
            let velValue = v.velocity

            let releaseOverride: Float? = v.fastRelease ? ADSREnvelope.fastReleaseSeconds : nil
            let envelopeValue = envelope.process(
                currentValue: v.envelopeValue,
                phase: &v.envelopePhase,
                time: &v.envelopeTime,
                releaseStartValue: v.releaseStartValue,
                isReleasing: v.isReleasing,
                sampleRate: sampleRate,
                releaseOverride: releaseOverride
            )
            v.envelopeValue = envelopeValue

            var pitchMod1: Float = 0
            var pitchMod2: Float = 0
            var ampMod: Float = 0
            var panMod: Float = 0

            if !modMatrix.isEmpty {
                for entry in modMatrix {
                    let sourceVal: Float
                    switch entry.source {
                    case .lfo1: sourceVal = lfoValue
                    case .env1: sourceVal = envelopeValue
                    case .velocity: sourceVal = velValue
                    }
                    let modVal = sourceVal * entry.amount
                    switch entry.destination {
                    case .pitch1: pitchMod1 += modVal
                    case .pitch2: pitchMod2 += modVal
                    case .amp: ampMod += modVal
                    case .pan: panMod += modVal
                    default: break
                    }
                }
            }

            if pitchMod1 != 0 {
                osc1Freq *= pow(2.0, Double(max(-2, min(2, pitchMod1))))
            }
            if pitchMod2 != 0 {
                osc2Freq *= pow(2.0, Double(max(-2, min(2, pitchMod2))))
            }

            if lfoEnabled && lfoTarget == .pitch {
                let mod = Double(max(-1, min(1, lfoValue)))
                if mod != 0 {
                    let mul = pow(2.0, mod)
                    osc1Freq *= mul
                    osc2Freq *= mul
                }
            }

            osc1Freq = max(20.0, min(sampleRate * 0.45, osc1Freq))
            osc2Freq = max(20.0, min(sampleRate * 0.45, osc2Freq))

            let phaseInc1 = AudioMath.twoPi * osc1Freq / sampleRate
            let phaseInc2 = AudioMath.twoPi * osc2Freq / sampleRate

            var sample = oscillator1.generateSample(
                phase: v.phase,
                phaseIncrement: phaseInc1,
                noiseValue: noiseValue
            )
            if cachedOsc2Enabled {
                let s2 = oscillator2.generateSample(
                    phase: v.phase2,
                    phaseIncrement: phaseInc2,
                    noiseValue: noiseValue
                )
                sample = (sample + s2) * 0.5
            }

            v.phase += phaseInc1
            v.phase2 += phaseInc2
            if v.phase >= AudioMath.twoPi { v.phase -= AudioMath.twoPi }
            if v.phase < 0 { v.phase += AudioMath.twoPi }
            if v.phase2 >= AudioMath.twoPi { v.phase2 -= AudioMath.twoPi }
            if v.phase2 < 0 { v.phase2 += AudioMath.twoPi }

            var amplitude = sample * envelopeValue * max(0.15, min(1.0, velValue))
            amplitude *= max(0.0, 1.0 + ampMod)
            amplitude *= AudioMath.voiceGain * v.unisonScale
            if lfoEnabled && lfoTarget == .amplitude {
                amplitude = lfo.modulateAmplitude(amplitude, lfoValue: lfoValue)
            }
            if !amplitude.isFinite { amplitude = 0 }
            amplitude = v.filter.process(amplitude, coeffs: filterCoeffs)
            if !amplitude.isFinite { amplitude = 0 }

            var pan = v.pan + panMod
            if lfoEnabled && lfoTarget == .pan { pan += lfoValue }
            pan = max(-1, min(1, pan))
            let angle = (pan + 1.0) * Float.pi / 4.0

            mixedSampleL += amplitude * cos(angle)
            mixedSampleR += amplitude * sin(angle)

            if v.envelopePhase == .finished {
                v.deactivate()
                activeVoiceCountRT = max(0, activeVoiceCountRT - 1)
            }
            voices[i] = v
        }

        if !mixedSampleL.isFinite { mixedSampleL = 0 }
        if !mixedSampleR.isFinite { mixedSampleR = 0 }

        let headroom: Float = 0.65
        var fxL = mixedSampleL * smoothedMasterVolume * headroom
        var fxR = mixedSampleR * smoothedMasterVolume * headroom

        if distortion.enabled {
            (fxL, fxR) = distortion.processStereo(inputL: fxL, inputR: fxR)
        }
        if parametricEQL.enabled {
            if !parametricEQR.enabled { parametricEQR.enabled = true }
            fxL = parametricEQL.process(fxL)
            fxR = parametricEQR.process(fxR)
        }
        if !phaser.bypass {
            let p = phaser.process(inputL: fxL, inputR: fxR)
            fxL = p.left
            fxR = p.right
        }

        var (outL, outR) = dspChorus.process(inputL: fxL, inputR: fxR)

        if lfoEnabled && lfoTarget == .pan {
            let panVal = max(-1, min(1, lfoValue))
            let a = (panVal + 1) * Float.pi / 4
            outL *= cos(a)
            outR *= sin(a)
        }

        lastPreClipAbs = max(abs(outL), abs(outR))
        outL = AudioMath.softClip(outL, threshold: 0.95)
        outR = AudioMath.softClip(outR, threshold: 0.95)

        let absSample = max(abs(outL), abs(outR))
        currentLevel = max(currentLevel * levelDecay, absSample)
        if absSample > currentPeak { currentPeak = absSample }
        else { currentPeak *= peakDecay }

        sampleCounter += 1
        if sampleCounter >= levelUpdateInterval {
            sampleCounter = 0
            meteringState.setOutputLevel(min(currentLevel * 2, 1))
            meteringState.setPeakLevel(min(currentPeak * 2, 1))
        }

        if isCapturingScope {
            scopeBuffer[scopeIndex] = (outL + outR) * 0.5
            scopeIndex += 1
            if scopeIndex >= scopeBuffer.count {
                scopeIndex = 0
                meteringState.writeScopeBuffer(scopeBuffer)
            }
        }

        if !outL.isFinite { outL = 0 }
        if !outR.isFinite { outR = 0 }
        return (outL, outR)
    }

    func processCommandQueue() {
        commandQueue.drain(limit: 128) { [self] command in
            switch command {
            case .noteOn(let midiNote, let velocity):
                createVoice(midiNote: midiNote, velocity: velocity)
            case .noteOff(let midiNote):
                internalNoteOff(midiNote: midiNote)
            case .clearAll:
                clearAllVoices()
                heldKeysForArp.removeAll()
                arp.reset()
                filterL.reset()
                filterR.reset()
                lfo.reset()
            case .arpKeyDown(let midiNote):
                heldKeysForArp.insert(midiNote)
                arp.mode = cachedArpMode
                arp.setHeldKeys(heldKeysForArp)
            case .arpKeyUp(let midiNote):
                heldKeysForArp.remove(midiNote)
                arp.mode = cachedArpMode
                arp.setHeldKeys(heldKeysForArp)
            }
        }
    }

    func handleArpTick() {
        if let oldNote = arp.currentNote {
            internalNoteOff(midiNote: oldNote)
        }

        guard let newNote = arp.advanceTick(randomSource: &noiseSeed) else {
            return
        }
        createVoice(midiNote: newNote, velocity: 0.8)
    }
}
