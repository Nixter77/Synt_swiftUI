//
//  Stage6SoundTests.swift
//  Chorus flanger and filter-to-mixer feedback.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage6SoundTests {

    @Test func missingKeysLeaveFlangerAndFeedbackOff() throws {
        let preset = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old","category":"Lead"}"#.utf8))
        #expect(preset.chorusFlanger == false)
        #expect(preset.chorusFeedback == 0)
        #expect(preset.chorusFlangerSync == false)
        #expect(preset.filterFeedback == 0)
        var hot = preset
        hot.chorusFeedback = 4
        hot.filterFeedback = .nan
        let cleaned = hot.sanitized()
        #expect(cleaned.chorusFeedback == 0.95)
        #expect(cleaned.filterFeedback == 0)
    }

    @Test func chorusBodyIsUnchangedUntilFlangerIsEnabled() {
        func impulse(_ chorus: DSPChorus) -> [Float] {
            var out: [Float] = []
            for i in 0..<180 {
                let x: Float = i == 10 ? 1 : 0
                out.append(chorus.process(inputL: x, inputR: x).0)
            }
            return out
        }
        let dry = DSPChorus(sampleRate: 44_100)
        dry.mix = 0
        dry.flanger = false
        let passed = dry.process(inputL: 0.25, inputR: -0.5)
        #expect(passed.0 == 0.25)
        #expect(passed.1 == -0.5)

        let a = DSPChorus(sampleRate: 44_100)
        a.mix = 0.6
        a.rate = 0.8
        a.depth = 0.4
        let b = DSPChorus(sampleRate: 44_100)
        b.mix = 0.6
        b.rate = 0.8
        b.depth = 0.4
        b.flanger = false
        #expect(impulse(a) == impulse(b))

        let flanged = DSPChorus(sampleRate: 44_100)
        flanged.mix = 0.6
        flanged.rate = 0.8
        flanged.depth = 0.4
        flanged.flanger = true
        flanged.feedback = 0.7
        let chorus = impulse(a)
        let flange = impulse(flanged)
        var diff: Float = 0
        for i in 0..<chorus.count { diff = max(diff, abs(chorus[i] - flange[i])) }
        #expect(diff > 0.01)
    }

    @Test func syncSetsTheFlangerRateOnlyWhileFlangerIsOn() {
        let synced = AudioEngine()
        var on = SynthPreset.defaultPreset
        on.bpm = 120
        on.chorusRate = 0.25
        on.chorusFlanger = true
        on.chorusFlangerSync = true
        on.chorusFlangerDivision = .quarter
        synced.preset = on
        #expect(synced.dspChorus.flanger)
        #expect(abs(synced.dspChorus.rate - TimeDivision.quarter.frequency(bpm: 120)) < 0.0001)

        let plain = AudioEngine()
        var off = SynthPreset.defaultPreset
        off.chorusRate = 0.25
        off.chorusFlanger = false
        off.chorusFlangerSync = true
        plain.preset = off
        #expect(plain.dspChorus.flanger == false)
        #expect(plain.dspChorus.rate == 0.25)
    }

    @Test func zeroFeedbackMatchesTheDefaultPathAndANonZeroValueChangesIt() {
        func render(_ mutate: (inout SynthPreset) -> Void) -> [Float] {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.filterResonance = 0.85
            preset.filterCutoff = 800
            mutate(&preset)
            engine.preset = preset
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 60, velocity: 1)
            var samples: [Float] = []
            for _ in 0..<600 {
                samples.append(engine.renderOneSample().0)
            }
            return samples
        }
        let base = render { _ in }
        let explicit = render {
            $0.filterFeedback = 0
            $0.chorusFlanger = false
            $0.chorusFeedback = 0
        }
        for i in 0..<base.count {
            #expect(base[i] == explicit[i])
        }
        let fed = render { $0.filterFeedback = 0.7 }
        var diff: Float = 0
        for i in 0..<base.count { diff = max(diff, abs(base[i] - fed[i])) }
        #expect(diff > 0.001)
    }
}
