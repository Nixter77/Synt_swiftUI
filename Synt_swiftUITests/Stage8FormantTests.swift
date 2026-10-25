//
//  Stage8FormantTests.swift
//  Formant filter type and the vowel matrix destination.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage8FormantTests {

    private func engine(_ mutate: (inout SynthPreset) -> Void) -> AudioEngine {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        mutate(&preset)
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.handleNoteOn(midiNote: 57, velocity: 1)
        return engine
    }

    private func render(_ mutate: (inout SynthPreset) -> Void, samples: Int) -> [Float] {
        let engine = engine(mutate)
        var out: [Float] = []
        out.reserveCapacity(samples)
        for _ in 0..<samples {
            out.append(engine.renderOneSample().0)
        }
        return out
    }

    @Test func formantStaysOffTheDefaultPath() throws {
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old"}"#.utf8))
        #expect(decoded.filterVowel == 0)
        #expect(decoded.filterType != .formant)

        let plain = render({ _ in }, samples: 600)
        let vowelOnly = render({ patch in
            patch.filterVowel = 3.7
        }, samples: 600)
        #expect(plain == vowelOnly)

        let formed = render({ patch in
            patch.filterType = .formant
            patch.filterVowel = 0
            patch.osc2Enabled = false
            patch.attack = 0.001
        }, samples: 600)
        var gap: Float = 0
        for i in 200..<plain.count {
            gap = max(gap, abs(plain[i] - formed[i]))
        }
        #expect(gap > 0.01)
    }

    @Test func vowelSweepDoesNotClick() {
        let engine = engine { patch in
            patch.filterType = .formant
            patch.filterVowel = 0
            patch.osc1Waveform = .sawtooth
            patch.osc2Enabled = false
            patch.attack = 0.001
            patch.release = 1
        }
        for _ in 0..<800 {
            _ = engine.renderOneSample()
        }
        var previous = engine.renderOneSample().0
        var steady: Float = 0
        var steadyPeak: Float = 0
        for _ in 0..<1200 {
            let sample = engine.renderOneSample().0
            steady = max(steady, abs(sample - previous))
            steadyPeak = max(steadyPeak, abs(sample))
            previous = sample
        }
        var swept: Float = 0
        let steps = 3000
        for i in 0..<steps {
            engine.cachedFilterVowel = Float(i) / Float(steps - 1) * 4
            let sample = engine.renderOneSample().0
            #expect(sample.isFinite)
            swept = max(swept, abs(sample - previous))
            previous = sample
        }
        #expect(steadyPeak > 0.01)
        #expect(swept < max(0.08, steady * 3))
    }

    @Test func formantNoiseStaysFiniteForTenSeconds() {
        let engine = engine { patch in
            patch.filterType = .formant
            patch.filterVowel = 2
            patch.osc1Waveform = .noise
            patch.osc2Enabled = false
            patch.attack = 0.001
            patch.release = 2
        }
        var finite = true
        for _ in 0..<(44_100 * 10) {
            let frame = engine.renderOneSample()
            if !frame.0.isFinite || !frame.1.isFinite {
                finite = false
                break
            }
        }
        #expect(finite)
    }

    @Test func filter2FormantChangesTheSpectrumAndStaysFinite() {
        func shape(_ patch: inout SynthPreset, routing: DualFilterRouting) {
            patch.osc1Waveform = .sawtooth
            patch.osc2Enabled = false
            patch.attack = 0.001
            patch.filterType = .lowPass
            patch.filterCutoff = 8000
            patch.filter2Routing = routing
            patch.filter2Type = .formant
            patch.filter2Balance = 1
            patch.filterVowel = 1
        }
        let off = render({ shape(&$0, routing: .off) }, samples: 2000)
        let serial = render({ shape(&$0, routing: .serial) }, samples: 2000)
        var gap: Float = 0
        var finite = true
        for i in 300..<off.count {
            if !serial[i].isFinite { finite = false }
            gap = max(gap, abs(off[i] - serial[i]))
        }
        #expect(finite)
        #expect(gap > 0.01)
    }
}
