//
//  Stage9ModulationTests.swift
//  Synt_swiftUITests
//
//  Tests for Stage 2 of GROK_BUILD_TASKS_SYNT_9:
//  - ADSR curves per segment (curve=0 is bit-exact to original)
//  - Envelope follower mod-matrix source
//  - Stereo modulation (L/R phase offset for LFOs)
//

import AudioToolbox
import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage9ModulationTests {

    // MARK: - ADSR Curves Tests

    @Test func adsrCurvesZeroIsIdenticalToOldCalculation() {
        var envDefault = ADSREnvelope(attack: 0.05, decay: 0.1, sustain: 0.5, release: 0.1)
        var envWithZeroCurve = ADSREnvelope(
            attack: 0.05,
            decay: 0.1,
            sustain: 0.5,
            release: 0.1,
            attackCurve: 0.0,
            decayCurve: 0.0,
            releaseCurve: 0.0
        )

        var phase1: EnvelopePhase = .attack
        var phase2: EnvelopePhase = .attack
        var time1: Double = 0.0
        var time2: Double = 0.0
        var val1: Float = 0.0
        var val2: Float = 0.0
        let sampleRate = 44100.0

        for _ in 0..<4000 {
            val1 = envDefault.process(
                currentValue: val1,
                phase: &phase1,
                time: &time1,
                releaseStartValue: 0.5,
                isReleasing: false,
                sampleRate: sampleRate
            )
            val2 = envWithZeroCurve.process(
                currentValue: val2,
                phase: &phase2,
                time: &time2,
                releaseStartValue: 0.5,
                isReleasing: false,
                sampleRate: sampleRate
            )
            #expect(val1.bitPattern == val2.bitPattern, "Zero curve must be bit-exact to default calculation")
            #expect(phase1 == phase2)
        }
    }

    @Test func adsrCurvesChangeTrajectoryAndStayBounded() {
        var envLinear = ADSREnvelope(attack: 0.1, decay: 0.1, sustain: 0.5, release: 0.1, attackCurve: 0.0)
        var envConvex = ADSREnvelope(attack: 0.1, decay: 0.1, sustain: 0.5, release: 0.1, attackCurve: 0.8)
        var envConcave = ADSREnvelope(attack: 0.1, decay: 0.1, sustain: 0.5, release: 0.1, attackCurve: -0.8)

        var phaseLin: EnvelopePhase = .attack; var timeLin: Double = 0.0; var valLin: Float = 0.0
        var phaseCvx: EnvelopePhase = .attack; var timeCvx: Double = 0.0; var valCvx: Float = 0.0
        var phaseCcv: EnvelopePhase = .attack; var timeCcv: Double = 0.0; var valCcv: Float = 0.0
        let sampleRate = 44100.0

        // At midpoint of attack (t = 0.05s, sample ~2205)
        for _ in 0..<2205 {
            valLin = envLinear.process(currentValue: valLin, phase: &phaseLin, time: &timeLin, releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate)
            valCvx = envConvex.process(currentValue: valCvx, phase: &phaseCvx, time: &timeCvx, releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate)
            valCcv = envConcave.process(currentValue: valCcv, phase: &phaseCcv, time: &timeCcv, releaseStartValue: 0, isReleasing: false, sampleRate: sampleRate)
        }

        // Concave starts faster -> higher value at midpoint than convex
        #expect(valCcv > valCvx, "Concave attack should rise faster than convex attack")
        #expect(valLin > 0 && valLin <= 1.0)
        #expect(valCvx > 0 && valCvx <= 1.0)
        #expect(valCcv > 0 && valCcv <= 1.0)
    }

    // MARK: - Envelope Follower Mod Source Tests

    @Test func envelopeFollowerSourceAvailableAndBypassedByDefault() {
        #expect(ModSource.allCases.contains(.envelopeFollower))

        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)
        var preset = SynthPreset.defaultPreset
        preset.modMatrix = [ModMatrixEntry(source: .envelopeFollower, destination: .cutoff, amount: 0.5)]
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var maxEnvFollower: Float = 0
        for _ in 0..<1000 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
            if engine.envelopeFollowerValue > maxEnvFollower {
                maxEnvFollower = engine.envelopeFollowerValue
            }
        }
        #expect(maxEnvFollower > 0.0, "Envelope follower must track active audio signal")
        #expect(maxEnvFollower <= 1.0)
    }

    // MARK: - Stereo LFO Modulation Tests

    @Test func lfoStereoZeroProducesMono() {
        let lfo = LFO()
        lfo.enabled = true
        lfo.stereoPhaseOffsetDegrees = 0.0
        lfo.waveform = .sine
        lfo.rate = 5.0

        for _ in 0..<200 {
            let (l, r) = lfo.nextStereoRawValue(sampleRate: 44100.0)
            #expect(l == r, "With zero stereo phase offset, L and R must be identical")
        }
    }

    @Test func lfoStereoPhaseOffsetProducesDifferentialOutputs() {
        let lfo = LFO()
        lfo.enabled = true
        lfo.stereoPhaseOffsetDegrees = 90.0
        lfo.waveform = .sine
        lfo.rate = 5.0

        var hadDifference = false
        for _ in 0..<200 {
            let (l, r) = lfo.nextStereoRawValue(sampleRate: 44100.0)
            #expect(l.isFinite && r.isFinite)
            if abs(l - r) > 0.1 {
                hadDifference = true
            }
        }
        #expect(hadDifference, "90-degree phase offset must produce distinct L and R signals")
    }

    @Test func stereoLFOModulatesAudioInStereo() {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100.0, maxFrames: 256)
        var preset = SynthPreset.defaultPreset
        preset.lfoEnabled = true
        preset.lfoTarget = .amplitude
        preset.lfoDepth = 1.0
        preset.lfoRate = 10.0
        preset.lfoStereoPhase = 180.0 // Anti-phase tremolo
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var hadStereoDiff = false
        for _ in 0..<1000 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
            if abs(l - r) > 0.05 {
                hadStereoDiff = true
            }
        }
        #expect(hadStereoDiff, "Anti-phase stereo LFO must produce stereo amplitude difference")
    }
}
