//
//  Stage6ModTests.swift
//  Trance gate, smooth-random source, and mod-matrix curves.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage6ModTests {

    @Test func legacyMatrixJSONDecodesLinearAndNewFieldsStayOff() throws {
        let json = #"{"name":"Old","category":"Lead","modMatrix":[{"source":"Velocity","destination":"Amplitude","amount":0.4}]}"#
        let preset = try JSONDecoder().decode(SynthPreset.self, from: Data(json.utf8))
        #expect(preset.modMatrix.count == 1)
        #expect(preset.modMatrix[0].curve == .linear)
        #expect(preset.modMatrix[0].amount == 0.4)
        #expect(preset.tranceGateEnabled == false)
        #expect(preset.perlinTempoSync == false)
        #expect(preset.perlinRate == 1)
    }

    @Test func linearCurveMatchesTheRawProductAndExponentialDoesNot() {
        func render(curve: ModCurve) -> [Float] {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.modMatrix = [ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.8, curve: curve)]
            engine.preset = preset
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 60, velocity: 0.4)
            var samples: [Float] = []
            for _ in 0..<400 {
                samples.append(engine.renderOneSample().0)
            }
            return samples
        }

        let linear = render(curve: .linear)
        let plain = render(curve: .linear)
        let curved = render(curve: .exponential)
        for i in 0..<linear.count {
            #expect(linear[i] == plain[i])
        }
        var diff: Float = 0
        for i in 0..<linear.count {
            diff = max(diff, abs(linear[i] - curved[i]))
        }
        #expect(diff > 0.001)
    }

    @Test func publishedCurveTableMatchesTheRemapAndLinearSkipsIt() {
        let matrix = RTModMatrix()
        let entry = ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 1, curve: .exponential)
        matrix.publish([entry])
        let (slots, count) = matrix.snapshot()
        #expect(count == 1)
        #expect(slots[0].curve == .exponential)
        let looked = matrix.lookup(bank: slots[0].tableBank, slot: 0, source: 0.5)
        #expect(abs(looked - ModCurve.exponential.remap(0.5)) < 0.02)

        matrix.publish([ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.3)])
        let (linearSlots, _) = matrix.snapshot()
        #expect(linearSlots[0].curve == .linear)
        let raw: Float = 0.4
        let engine = AudioEngine()
        let shaped = engine.modulatedAmount(linearSlots[0], slot: 0, source: raw)
        #expect(shaped == raw * linearSlots[0].amount)
    }

    @Test func tranceGateOffDoesNotAdvanceAndAnEmptyPatternGoesQuiet() {
        let idle = AudioEngine()
        idle.preset = .defaultPreset
        idle.prepare(sampleRate: 44_100, maxFrames: 256)
        idle.handleNoteOn(midiNote: 60, velocity: 1)
        for _ in 0..<300 { _ = idle.renderOneSample() }
        #expect(idle.tranceCursor == 0)
        #expect(idle.smoothRandom.advanceCount == 0)

        func tailPeak(pattern: UInt16) -> Float {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.tranceGateEnabled = true
            preset.tranceGatePattern = pattern
            preset.tranceGateDepth = 1
            preset.tranceGateSmooth = 0
            preset.tranceGateDivision = .thirtySecond
            engine.preset = preset
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 60, velocity: 1)
            var peak: Float = 0
            for i in 0..<3_000 {
                let sample = abs(engine.renderOneSample().0)
                if i > 2_000 { peak = max(peak, sample) }
            }
            return peak
        }

        let open = tailPeak(pattern: 0xFFFF)
        let closed = tailPeak(pattern: 0)
        #expect(open > 0.02)
        #expect(closed < open * 0.15)
    }

    @Test func smoothRandomIsDeterministicAndStaysIdleWithoutARoute() {
        let generator = SmoothRandom()
        var noisePeak: Float = 0
        for _ in 0..<8_000 {
            noisePeak = max(noisePeak, abs(generator.advance(hz: 8, sampleRate: 44_100)))
        }
        #expect(noisePeak > 0.4)

        func render(useSource: Bool) -> (samples: [Float], advances: Int) {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.attack = 0.001
            preset.osc1Volume = 1
            preset.osc2Enabled = false
            preset.masterVolume = 1
            if useSource {
                preset.modMatrix = [ModMatrixEntry(source: .smoothRandom, destination: .pan, amount: 1)]
                preset.perlinRate = 20
            }
            engine.preset = preset
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 60, velocity: 1)
            var samples: [Float] = []
            for _ in 0..<1_500 {
                let frame = engine.renderOneSample()
                samples.append(frame.0 - frame.1)
            }
            return (samples, engine.smoothRandom.advanceCount)
        }

        let idle = render(useSource: false)
        #expect(idle.advances == 0)
        let a = render(useSource: true)
        let b = render(useSource: true)
        #expect(a.advances == 1_500)
        #expect(a.samples == b.samples)
        let peak = a.samples.reduce(Float(0)) { max($0, abs($1)) }
        #expect(peak > 0.01)
    }

    @Test func tempoSyncPublishesTheDivisionRate() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120
        preset.perlinTempoSync = true
        preset.perlinSyncDivision = .quarter
        engine.preset = preset
        let expected = TimeDivision.quarter.frequency(bpm: 120)
        #expect(abs(engine.cachedPerlinHz - expected) < 0.0001)
    }
}
