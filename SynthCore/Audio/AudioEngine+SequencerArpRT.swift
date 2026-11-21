//
//  AudioEngine+SequencerArpRT.swift
//  Synt_swiftUI
//
//  Real-time step sequencer and arpeggiator timing helpers extracted from
//  AudioEngine+Render.swift.
//

import Foundation

public extension AudioEngine {
    /// Sample-accurate 16th-note clock. Swing delays user-facing even steps
    /// (2, 4, 6… — odd indices) by `swing * step * 0.5` and shortens them so
    /// the bar length stays constant. No allocation.
    func advanceSequencerOneSample() {
        let generationChanged = sequencerTransport.pullIfChanged(into: &seqMirror)
        if usesHostTransport || cachedSyncSource == .midiClock {
            seqMirror.bpm = cachedBPM
        }
        if generationChanged {
            releaseSequencerNote()
            seqMirror.stepIndex = 0
            seqMirror.phase = 0
            seqMirror.armed = seqMirror.playing
            seqMirror.stepSkipped = false
            seqMirror.ratchetIndex = 0
            sequencerTransport.setDisplayStep(0)
        }

        guard seqMirror.playing else { return }

        if seqMirror.length < 1 { seqMirror.length = 1 }
        if seqMirror.stepIndex >= seqMirror.length { seqMirror.stepIndex = 0 }

        if seqMirror.armed {
            seqMirror.armed = false
            triggerSequencerStep()
        } else {
            let step = seqMirror.steps[seqMirror.stepIndex]
            let stepDuration = sequencerStepDuration(stepIndex: seqMirror.stepIndex)
            let ratchet = max(1, Int(step.ratchet))
            let subDuration = stepDuration / Double(ratchet)

            if !seqMirror.stepSkipped && ratchet > 1 {
                let currentSubIndex = min(ratchet - 1, Int(seqMirror.phase / max(1.0, subDuration)))
                if currentSubIndex > seqMirror.ratchetIndex {
                    seqMirror.ratchetIndex = currentSubIndex
                    triggerRatchetSubStep(step: step, subDuration: subDuration)
                }
            }

            if seqMirror.gateSamplesLeft > 0 {
                seqMirror.gateSamplesLeft -= 1
                if seqMirror.gateSamplesLeft == 0 {
                    let nextIndex = (seqMirror.stepIndex + 1) % seqMirror.length
                    let nextStep = seqMirror.steps[nextIndex]
                    if !nextStep.tie || !nextStep.isActive || ratchet > 1 {
                        releaseSequencerNote()
                    }
                }
            }
        }

        let length = sequencerStepDuration(stepIndex: seqMirror.stepIndex)
        seqMirror.phase += 1
        if seqMirror.phase >= length {
            seqMirror.phase -= length
            seqMirror.stepIndex = (seqMirror.stepIndex + 1) % seqMirror.length
            seqMirror.ratchetIndex = 0
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

        let step = seqMirror.steps[index]
        guard step.isActive else {
            seqMirror.stepSkipped = true
            releaseSequencerNote()
            return
        }

        if step.probability < 1.0 {
            seqMirror.prngState ^= seqMirror.prngState << 13
            seqMirror.prngState ^= seqMirror.prngState >> 17
            seqMirror.prngState ^= seqMirror.prngState << 5
            let roll = Float(seqMirror.prngState & 0xFFFF) / 65535.0
            if roll > step.probability {
                seqMirror.stepSkipped = true
                releaseSequencerNote()
                return
            }
        }
        seqMirror.stepSkipped = false

        let raw = seqMirror.rootNote + Int(step.noteOffset) + Int(step.octave) * 12
        let midi = max(0, min(127, raw))

        if step.tie && seqMirror.heldNote >= 0 {
            // Slide / Tie: Retain existing voice, glide target frequency to new pitch
            let newFreq = noteToFrequency(midi)
            for i in 0..<AudioEngine.maxVoices {
                if voices[i].isActive && !voices[i].isReleasing && voices[i].midiNote == seqMirror.heldNote {
                    voices[i].midiNote = midi
                    voices[i].targetFrequency = newFreq
                    if cachedPortamento <= 0.001 {
                        voices[i].currentFrequency = newFreq
                    }
                }
            }
            lastPlayedFrequency = newFreq
            seqMirror.heldNote = midi
        } else {
            releaseSequencerNote()
            createVoice(midiNote: midi, velocity: step.velocity)
            seqMirror.heldNote = midi
        }

        let stepDuration = sequencerStepDuration(stepIndex: index)
        let ratchet = max(1, Int(step.ratchet))
        let subDuration = stepDuration / Double(ratchet)
        let effectiveGate = Double(step.gate)
        seqMirror.gateSamplesLeft = max(1, Int((subDuration * effectiveGate).rounded(.down)))
    }

    func triggerRatchetSubStep(step: SequencerStepRT, subDuration: Double) {
        let raw = seqMirror.rootNote + Int(step.noteOffset) + Int(step.octave) * 12
        let midi = max(0, min(127, raw))
        releaseSequencerNote()
        createVoice(midiNote: midi, velocity: step.velocity)
        seqMirror.heldNote = midi
        let effectiveGate = Double(step.gate)
        seqMirror.gateSamplesLeft = max(1, Int((subDuration * effectiveGate).rounded(.down)))
    }

    func releaseSequencerNote() {
        guard seqMirror.heldNote >= 0 else { return }
        releaseHeldNote(seqMirror.heldNote)
        seqMirror.heldNote = -1
        seqMirror.gateSamplesLeft = 0
    }

    @inline(__always)
    func currentArpStepDuration() -> Double {
        let base = samplesPerTick
        if cachedArpSwing > 0.001 {
            let offset = Double(cachedArpSwing) * base * 0.5
            if arpStepIndex % 2 == 0 {
                return base + offset
            } else {
                return max(1.0, base - offset)
            }
        }
        return base
    }

    func handleArpTick(stepDuration: Double) {
        if let oldNote = arp.currentNote {
            releaseHeldNote(oldNote)
        }

        guard let newNote = arp.advanceTick(randomSource: &noiseSeed) else {
            arp.currentNote = nil
            arpGateSamplesLeft = 0
            trimAbandonedTails()
            return
        }
        createVoice(midiNote: newNote, velocity: arpInputVelocity(for: newNote))
        let gateFrac = Double(max(0.1, min(1.0, cachedArpGateLength)))
        arpGateSamplesLeft = max(1, Int((stepDuration * gateFrac).rounded(.down)))
        trimAbandonedTails()
    }
}
