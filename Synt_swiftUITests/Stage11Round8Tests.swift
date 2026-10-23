//
//  Stage11Round8Tests.swift
//  Synt_swiftUITests
//

import XCTest
@testable import Synt_swiftUI
@testable import SynthCore

final class Stage11Round8Tests: XCTestCase {

    func testStereoAmplitudeLFOAppliesEachOscillatorOnce() {
        func render(lfo2OnAmplitude: Bool) -> (Float, Float) {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.attack = 0.01
            preset.decay = 0.05
            preset.sustain = 1
            preset.release = 0.2
            preset.unisonVoices = 1
            preset.reverbMix = 0
            preset.delayMix = 0
            preset.chorusMix = 0
            preset.filterEnvelopeAmount = 0
            preset.lfoEnabled = true
            preset.lfoTarget = .amplitude
            preset.lfoDepth = 1
            preset.lfoRate = 0.01
            preset.lfoWaveform = .sine
            preset.lfoStereoPhase = 0
            preset.lfo2Enabled = true
            preset.lfo2Depth = 1
            preset.lfo2Rate = 0.01
            preset.lfo2Waveform = .sine
            preset.lfo2StereoPhase = 90
            preset.lfo2Target = lfo2OnAmplitude ? .amplitude : .filter
            engine.preset = preset
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 69, velocity: 1)
            var best = (Float(0), Float(0))
            var bestAbs: Float = 0
            for _ in 0..<2048 {
                let sample = engine.renderOneSample()
                let mag = abs(sample.0) + abs(sample.1)
                if mag > bestAbs {
                    bestAbs = mag
                    best = sample
                }
            }
            return best
        }

        let once = render(lfo2OnAmplitude: false)
        let stereo = render(lfo2OnAmplitude: true)
        XCTAssertGreaterThan(abs(once.0), 1e-4)
        XCTAssertGreaterThan(abs(once.1), 1e-4)
        // LFO2 at phase 0 / offset 90: left gain 0.5, right gain 1, on top of one LFO1.
        XCTAssertEqual(stereo.0 / once.0, 0.5, accuracy: 0.08)
        XCTAssertEqual(stereo.1 / once.1, 1.0, accuracy: 0.08)
        XCTAssertEqual(abs(stereo.1) / abs(stereo.0), 2.0, accuracy: 0.15)
    }

    func testMSEGPublishDoesNotSpinWhenTickIsNotRunning() {
        let mseg = DSPMSEG()
        var model = DSPMSEGModel()
        model.points = [
            DSPMSEGPoint(time: 0, value: 0.25),
            DSPMSEGPoint(time: 1, value: 0.25)
        ]
        let keptCount = model.points.count
        mseg.model = model
        mseg.publishEmpty()
        XCTAssertEqual(mseg.model.points.count, keptCount)
        XCTAssertFalse(mseg.hasPoints)
        mseg.trigger()
        XCTAssertEqual(mseg.tick(), 0)
        XCTAssertEqual(mseg.currentValue, 0)

        let start = CFAbsoluteTimeGetCurrent()
        for i in 0..<40 {
            var next = DSPMSEGModel()
            next.points = [
                DSPMSEGPoint(time: 0, value: Float(i) * 0.01),
                DSPMSEGPoint(time: 1, value: 0.5)
            ]
            mseg.publish(next)
        }
        XCTAssertLessThan(CFAbsoluteTimeGetCurrent() - start, 0.05)
        XCTAssertEqual(mseg.evaluate(at: 0), 0.39, accuracy: 1e-4)
        XCTAssertTrue(mseg.hasPoints)
    }

    func testLiveModulationIsPerEngine() {
        let a = AudioEngine(coreOnly: true)
        let b = AudioEngine(coreOnly: true)
        XCTAssertFalse(a.liveModulation === b.liveModulation)
        a.liveModulation.store(0.5, for: .cutoff)
        XCTAssertEqual(a.liveModulation.value(for: .cutoff), 0.5, accuracy: 1e-6)
        XCTAssertEqual(b.liveModulation.value(for: .cutoff), 0, accuracy: 1e-6)
    }

    func testModulationHighlightUsesLatestVoiceAndResets() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        var preset = SynthPreset.defaultPreset
        preset.attack = 0.01
        preset.decay = 0.05
        preset.sustain = 1
        preset.release = 0.005
        preset.unisonVoices = 1
        preset.modMatrix = [
            ModMatrixEntry(source: .keyTrack, destination: .amp, amount: 1)
        ]
        engine.preset = preset
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        engine.handleNoteOn(midiNote: 72, velocity: 1)
        _ = engine.renderOneSample()
        let highlighted = engine.liveModulation.value(for: .amp)
        XCTAssertEqual(highlighted, 1, accuracy: 0.05)

        engine.handleNoteOff(midiNote: 60)
        engine.handleNoteOff(midiNote: 72)
        var stillActive = true
        for _ in 0..<8_000 {
            _ = engine.renderOneSample()
            stillActive = false
            for i in 0..<AudioEngine.maxVoices where engine.voices[i].isActive {
                stillActive = true
            }
            if !stillActive { break }
        }
        XCTAssertFalse(stillActive)
        XCTAssertEqual(engine.liveModulation.value(for: .amp), 0, accuracy: 1e-5)
    }

    func testScopePublishesWholeFramesOnly() {
        let metering = AtomicMeteringState(bufferSize: 8)
        let first = [Float](repeating: 0.25, count: 8)
        let second = [Float](repeating: -0.5, count: 8)
        metering.writeScopeBuffer(first)
        metering.writeScopeBuffer(second)
        let read = metering.readScopeBuffer()
        XCTAssertEqual(read.count, 8)
        XCTAssertTrue(read.allSatisfy { $0 == -0.5 })

        metering.writeScopeBuffer([Float](repeating: 0.9, count: 3))
        let kept = metering.readScopeBuffer()
        XCTAssertEqual(kept, read)
    }

    func testRandomPhaseKeepsNoteHashAndRandomPerNoteUsesSeed() {
        var seeded = ActiveNote()
        var plain = ActiveNote()
        seeded.activate(midiNote: 64, velocity: 1, frequency: 100, partial: 1, partialCount: 3, phaseMode: .random, randomSeed: 99)
        plain.activate(midiNote: 64, velocity: 1, frequency: 100, partial: 1, partialCount: 3, phaseMode: .random, randomSeed: 0)
        XCTAssertEqual(seeded.phase, plain.phase)
        XCTAssertEqual(seeded.phase2, plain.phase2)

        var perNote = ActiveNote()
        perNote.activate(midiNote: 64, velocity: 1, frequency: 100, partial: 1, partialCount: 3, phaseMode: .randomPerNote, randomSeed: 99)
        XCTAssertNotEqual(perNote.phase, plain.phase)
    }

    func testCharacterToneOffStaysPassthroughAfterWarm() {
        let tone = DSPCharacterTone()
        _ = tone.process(0.2, mode: .warm, sampleRate: 48_000)
        XCTAssertEqual(tone.process(0.2, mode: .off, sampleRate: 48_000), 0.2)
        _ = tone.process(0.2, mode: .warm, sampleRate: 96_000)
        var finite = true
        for _ in 0..<32 {
            let y = tone.process(0.2, mode: .bright, sampleRate: 96_000)
            if !y.isFinite { finite = false }
        }
        XCTAssertTrue(finite)
    }

    func testOneShotStereoRightMatchesLeftAndWavetable() {
        let matched = LFO()
        matched.mode = .oneShot
        matched.waveform = .sine
        matched.rate = 44_100
        matched.startPhaseDegrees = 90
        matched.stereoPhaseOffsetDegrees = 0
        matched.trigger()
        let pair = matched.nextStereoRawValue(sampleRate: 44_100)
        XCTAssertTrue(matched.isCompleted)
        XCTAssertEqual(pair.left, pair.right, accuracy: 1e-4)
        XCTAssertGreaterThan(abs(pair.left), 0.5)
        let silenced = matched.nextStereoRawValue(sampleRate: 44_100)
        XCTAssertEqual(silenced.left, 0, accuracy: 1e-5)
        XCTAssertEqual(silenced.right, 0, accuracy: 1e-5)

        let table = LFO()
        table.mode = .oneShot
        table.waveform = .wavetable
        table.rate = 44_100
        table.startPhaseDegrees = 45
        table.stereoPhaseOffsetDegrees = 90
        table.trigger()
        let stereo = table.nextStereoRawValue(sampleRate: 44_100)
        // R7-10 (SYNT_14): .wavetable LFO reads a real table shape, not sine.
        // Verify stereo offset: left at 45 deg, right at 45+90 = 135 deg of the same shape.
        let expectedLeft = table.sampleWaveform(at: Double.pi * 0.25)
        let expectedRight = table.sampleWaveform(at: Double.pi * 0.75)
        XCTAssertEqual(stereo.left, expectedLeft, accuracy: 1e-4)
        XCTAssertEqual(stereo.right, expectedRight, accuracy: 1e-4)
        XCTAssertGreaterThan(abs(stereo.left - stereo.right), 0.05)
    }
}
