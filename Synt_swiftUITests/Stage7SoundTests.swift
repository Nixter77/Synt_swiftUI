//
//  Stage7SoundTests.swift
//  Fixed OSC 2, scene high-pass, and chorus ensemble. Each stays off by default.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage7SoundTests {

    private func render(_ mutate: (inout SynthPreset) -> Void, samples: Int = 600) -> [Float] {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        mutate(&preset)
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.handleNoteOn(midiNote: 36, velocity: 1)
        var out: [Float] = []
        out.reserveCapacity(samples)
        for _ in 0..<samples {
            let frame = engine.renderOneSample()
            out.append(frame.0)
        }
        return out
    }

    @Test func fixedOscillatorStaysOffUntilEnabled() throws {
        let json = #"{"name":"Old","category":"Lead"}"#
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(json.utf8))
        #expect(decoded.osc2FixedFrequency == false)
        #expect(decoded.sceneHPFEnabled == false)
        #expect(decoded.chorusMode == .standard)

        let plain = render { patch in
            patch.osc1Volume = 0
            patch.osc2Volume = 1
            patch.osc2FrequencyHz = 1760
        }
        let explicit = render { patch in
            patch.osc1Volume = 0
            patch.osc2Volume = 1
            patch.osc2FixedFrequency = false
            patch.osc2FrequencyHz = 1760
        }
        #expect(plain == explicit)
        let fixed = render { patch in
            patch.osc1Volume = 0
            patch.osc2Volume = 1
            patch.osc2FixedFrequency = true
            patch.osc2FrequencyHz = 1760
        }
        var gap: Float = 0
        for i in 200..<plain.count {
            gap = max(gap, abs(plain[i] - fixed[i]))
        }
        #expect(gap > 0.01)
    }

    @Test func sceneHighPassIsIdleUntilEnabled() {
        let plain = render { _ in }
        let off = render { $0.sceneHPFEnabled = false; $0.sceneHPFFrequency = 1500 }
        #expect(plain == off)
        let high = render { patch in
            patch.sceneHPFEnabled = true
            patch.sceneHPFFrequency = 1800
            patch.osc1Waveform = .sine
            patch.osc2Enabled = false
        }
        let open = render { patch in
            patch.osc1Waveform = .sine
            patch.osc2Enabled = false
        }
        var openPeak: Float = 0
        var highPeak: Float = 0
        for i in 200..<open.count {
            openPeak = max(openPeak, abs(open[i]))
            highPeak = max(highPeak, abs(high[i]))
        }
        #expect(openPeak > 0.02)
        #expect(highPeak < openPeak * 0.5)
    }

    @Test func ensembleChangesTheChorusAndStandardDoesNot() {
        let chorus = DSPChorus(sampleRate: 44_100)
        chorus.mix = 0.7
        chorus.rate = 0.6
        chorus.depth = 0.5
        let other = DSPChorus(sampleRate: 44_100)
        other.mix = 0.7
        other.rate = 0.6
        other.depth = 0.5
        var same = true
        for i in 0..<200 {
            let input: Float = i == 20 ? 1 : 0
            let a = chorus.process(inputL: input, inputR: input)
            let b = other.process(inputL: input, inputR: input)
            if a.0 != b.0 || a.1 != b.1 { same = false }
        }
        #expect(same)

        let wide = DSPChorus(sampleRate: 44_100)
        wide.mix = 0.7
        wide.rate = 0.6
        wide.depth = 0.5
        wide.ensemble = true
        var gap: Float = 0
        let reference = DSPChorus(sampleRate: 44_100)
        reference.mix = 0.7
        reference.rate = 0.6
        reference.depth = 0.5
        for i in 0..<300 {
            let input: Float = i == 10 ? 1 : 0
            let a = wide.process(inputL: input, inputR: input)
            let b = reference.process(inputL: input, inputR: input)
            gap = max(gap, abs(a.0 - b.0))
        }
        #expect(gap > 0.01)
    }
}
