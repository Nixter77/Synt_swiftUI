//
//  AudioEngine+Render.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

/// Lookahead peak rider. Multiplies the whole waveform by a slow gain so a chord
/// that would have entered the tanh clipper stays linear. Gain does not track
/// individual waveform cycles (that would be another waveshaper).
final class CleanBus {
    static let capacity = 512
    static let lookahead = 256
    static let threshold = AudioMath.cleanBusThreshold

    private var bufL = [Float](repeating: 0, count: CleanBus.capacity)
    private var bufR = [Float](repeating: 0, count: CleanBus.capacity)
    private var write = 0
    private var env: Float = 0
    private var gain: Float = 1
    private var hold = 0
    private var envCoeff: Float = 1
    private var attCoeff: Float = 1
    private var relCoeff: Float = 0
    private var holdMax = 1
    private var coeffRate: Float = 0
    private var dcPole: Float = 0.9983
    private var dcXL: Float = 0
    private var dcXR: Float = 0
    private var dcYL: Float = 0
    private var dcYR: Float = 0

    init(sampleRate: Float = 44100) {
        updateCoefficients(sampleRate: sampleRate)
    }

    func setSampleRate(_ sampleRate: Float) {
        updateCoefficients(sampleRate: max(8_000, sampleRate))
    }

    func reset() {
        for i in 0..<bufL.count {
            bufL[i] = 0
            bufR[i] = 0
        }
        write = 0
        env = 0
        gain = 1
        hold = 0
        dcXL = 0
        dcXR = 0
        dcYL = 0
        dcYR = 0
    }

    func process(left: Float, right: Float, sampleRate: Float) -> (Float, Float) {
        let sr = sampleRate > 1000 ? sampleRate : coeffRate
        if sr != coeffRate { updateCoefficients(sampleRate: sr) }

        let xL = dcBlock(left.isFinite ? left : 0, x1: &dcXL, y1: &dcYL)
        let xR = dcBlock(right.isFinite ? right : 0, x1: &dcXR, y1: &dcYR)

        bufL[write] = xL
        bufR[write] = xR

        let peak = max(abs(xL), abs(xR))
        if peak >= env {
            env = peak
            hold = holdMax
        } else if hold > 0 {
            hold -= 1
        } else {
            env = max(peak, env * envCoeff)
        }

        let desired: Float = env > Self.threshold ? Self.threshold / env : 1
        let coeff: Float
        if desired < gain * 0.985 {
            coeff = attCoeff
        } else if desired > gain {
            coeff = relCoeff
        } else {
            coeff = 0
        }
        if coeff > 0 {
            gain += (desired - gain) * coeff
        }
        if !gain.isFinite || gain < 0 { gain = 1 }
        if gain > 1 { gain = 1 }

        let read = (write + Self.capacity - Self.lookahead) & (Self.capacity - 1)
        write = (write + 1) & (Self.capacity - 1)
        return (bufL[read] * gain, bufR[read] * gain)
    }

    private func updateCoefficients(sampleRate: Float) {
        coeffRate = sampleRate
        let sr = Double(sampleRate)
        envCoeff = Float(exp(-1.0 / (sr * 0.200)))
        attCoeff = Float(1.0 - exp(-1.0 / (sr * 0.0015)))
        relCoeff = Float(1.0 - exp(-1.0 / (sr * 0.150)))
        holdMax = max(1, Int(sampleRate * 0.040))
        dcPole = Float(exp(-2.0 * Double.pi * 12.0 / sr))
    }

    private func dcBlock(_ x: Float, x1: inout Float, y1: inout Float) -> Float {
        let y = x - x1 + dcPole * y1
        x1 = x
        if !y.isFinite || abs(y) > 16 {
            y1 = 0
            return 0
        }
        y1 = y
        return y
    }
}

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
            // Machine gates ignore the pedal; the pedal holds only played keys.
            releaseHeldNote(n)
            arp.currentNote = nil
        }

        advanceSequencerOneSample()

        // Single writer: preset (main) and CC1 (MIDI) only feed the inputs.
        lfo.depth = cachedLfoDepth + (1 - cachedLfoDepth) * modWheel
        let pitchBendMultiplier = advancePitchBend()
        let lfoValue = lfo.getValue(sampleRate: sampleRate)
        let lfoEnabled = lfo.enabled
        let lfoTarget = lfo.target
        let (modSlots, modCount) = rtModMatrix.snapshot()

        // One noise draw per sample. Each voice hashes it so noise chords
        // do not stack as N identical copies (that sum is just a loud clip).
        noiseSeed = noiseSeed &* 1664525 &+ 1013904223
        let noiseBase = noiseSeed

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

            let voiceSeed = (noiseBase &+ UInt32(i) &* 747_796_405 &+ 2_891_336_453) &* 1_664_525 &+ 1_013_904_223
            let noiseValue = Float(voiceSeed) / Float(UInt32.max) * 2.0 - 1.0

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

            if modCount > 0 {
                for m in 0..<modCount {
                    let entry = modSlots[m]
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

            if pitchBendMultiplier != 1 {
                osc1Freq *= pitchBendMultiplier
                osc2Freq *= pitchBendMultiplier
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

        // EQ before the rider. A boost after it walked straight into the ceiling
        // and rasped; the rider now holds that extra level with one linear gain.
        if parametricEQL.enabled {
            if !parametricEQR.enabled { parametricEQR.enabled = true }
            fxL = parametricEQL.process(fxL)
            fxR = parametricEQR.process(fxR)
        }

        (fxL, fxR) = cleanBus.process(
            left: fxL,
            right: fxR,
            sampleRate: Float(sampleRate)
        )

        if distortion.enabled {
            (fxL, fxR) = distortion.processStereo(inputL: fxL, inputR: fxR)
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
        outL = AudioMath.cleanCeiling(outL)
        outR = AudioMath.cleanCeiling(outR)

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

    /// ~5 ms one-pole toward the bend target. Idle bend stays exactly 1 and does no work.
    func advancePitchBend() -> Double {
        let target = pitchBendTarget
        if target == 0 && pitchBendSmoothed == 0 {
            return 1
        }
        let coeff = 1 - exp(-1.0 / (0.005 * sampleRate))
        pitchBendSmoothed += (target - pitchBendSmoothed) * Float(coeff)
        if abs(target - pitchBendSmoothed) < 0.00002 {
            pitchBendSmoothed = target
        }
        if pitchBendSmoothed == 0 {
            return 1
        }
        return exp2(Double(pitchBendSmoothed) * Double(cachedPitchBendRange) / 12)
    }

    func processCommandQueue() {
        commandQueue.drain(limit: 128) { [self] command in
            handleCommand(command)
        }
        midiQueue.drain(limit: 128) { [self] command in
            handleCommand(command)
        }
        // After the whole batch, so releasing a chord (held ends at 0) still rings.
        // A new chord in the same batch is already held, and only its oldest tails go.
        trimAbandonedTails()
    }

    func handleCommand(_ command: AudioCommand) {
            switch command {
            case .keyDown(let midiNote, let velocity):
                if cachedArpMode != .off {
                    handleCommand(.arpKeyDown(midiNote: midiNote))
                } else {
                    createVoice(midiNote: midiNote, velocity: velocity)
                }
            case .keyUp(let midiNote):
                // Follow where the key went, so an arp toggle mid-hold cannot strand it.
                if heldKeysForArp.contains(midiNote) {
                    handleCommand(.arpKeyUp(midiNote: midiNote))
                } else {
                    internalNoteOff(midiNote: midiNote)
                }
            case .noteOn(let midiNote, let velocity):
                createVoice(midiNote: midiNote, velocity: velocity)
            case .noteOff(let midiNote):
                internalNoteOff(midiNote: midiNote)
            case .setPitchBend(let amount):
                pitchBendTarget = amount
            case .setModWheel(let amount):
                modWheel = amount
            case .setSustain(let down):
                setSustainPedal(down: down)
            case .clearAll:
                clearAllVoices()
                heldKeysForArp.removeAll()
                arp.reset()
                seqMirror.heldNote = -1
                seqMirror.gateSamplesLeft = 0
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

    /// Sample-accurate 16th-note clock. Swing delays user-facing even steps
    /// (2, 4, 6… — odd indices) by `swing * step * 0.5` and shortens them so
    /// the bar length stays constant. No allocation.
    func advanceSequencerOneSample() {
        let generationChanged = sequencerTransport.pullIfChanged(into: &seqMirror)
        if generationChanged {
            releaseSequencerNote()
            seqMirror.stepIndex = 0
            seqMirror.phase = 0
            seqMirror.armed = seqMirror.playing
            sequencerTransport.setDisplayStep(0)
        }

        guard seqMirror.playing else { return }

        if seqMirror.length < 1 { seqMirror.length = 1 }
        if seqMirror.stepIndex >= seqMirror.length { seqMirror.stepIndex = 0 }

        if seqMirror.armed {
            seqMirror.armed = false
            triggerSequencerStep()
        } else if seqMirror.gateSamplesLeft > 0 {
            seqMirror.gateSamplesLeft -= 1
            if seqMirror.gateSamplesLeft == 0 {
                releaseSequencerNote()
            }
        }

        let length = sequencerStepDuration(stepIndex: seqMirror.stepIndex)
        seqMirror.phase += 1
        if seqMirror.phase >= length {
            seqMirror.phase -= length
            seqMirror.stepIndex = (seqMirror.stepIndex + 1) % seqMirror.length
            sequencerTransport.setDisplayStep(seqMirror.stepIndex)
            triggerSequencerStep()
        }
    }

    func sequencerStepDuration(stepIndex: Int) -> Double {
        let bpm = Double(max(20, seqMirror.bpm))
        let samplesPerStep = sampleRate * 60.0 / bpm / 4.0
        let swing = Double(min(1, max(0, seqMirror.swing)))
        let offset = swing * samplesPerStep * 0.5
        if stepIndex % 2 == 0 {
            return samplesPerStep + offset
        }
        return max(1, samplesPerStep - offset)
    }

    func triggerSequencerStep() {
        let index = seqMirror.stepIndex
        guard index >= 0 && index < SequencerTransport.stepCount else { return }
        releaseSequencerNote()

        let step = seqMirror.steps[index]
        guard step.isActive else { return }

        let raw = seqMirror.rootNote + Int(step.noteOffset) + Int(step.octave) * 12
        let midi = max(0, min(127, raw))
        createVoice(midiNote: midi, velocity: step.velocity)
        seqMirror.heldNote = midi

        let bpm = Double(max(20, seqMirror.bpm))
        let samplesPerStep = sampleRate * 60.0 / bpm / 4.0
        seqMirror.gateSamplesLeft = max(1, Int((samplesPerStep * Double(seqMirror.gate)).rounded(.down)))
    }

    func releaseSequencerNote() {
        guard seqMirror.heldNote >= 0 else { return }
        releaseHeldNote(seqMirror.heldNote)
        seqMirror.heldNote = -1
        seqMirror.gateSamplesLeft = 0
    }

    func handleArpTick() {
        if let oldNote = arp.currentNote {
            releaseHeldNote(oldNote)
        }

        guard let newNote = arp.advanceTick(randomSource: &noiseSeed) else {
            trimAbandonedTails()
            return
        }
        createVoice(midiNote: newNote, velocity: 0.8)
        trimAbandonedTails()
    }
}
