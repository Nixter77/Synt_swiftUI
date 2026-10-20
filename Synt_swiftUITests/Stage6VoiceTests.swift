//
//  Stage6VoiceTests.swift
//  Stereo tool, oscillator phase modes, and the per-preset polyphony limit.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage6VoiceTests {

    @Test func missingKeysDecodeToStereoOffResetPhaseAndFullPolyphony() throws {
        let json = #"{"name":"Old","category":"Lead"}"#.data(using: .utf8)!
        let preset = try JSONDecoder().decode(SynthPreset.self, from: json)
        #expect(preset.stereoEnabled == false)
        #expect(preset.stereoWidth == 1)
        #expect(preset.stereoMidSide == 0)
        #expect(preset.stereoHaasMs == 0)
        #expect(preset.stereoMonoBassHz == 0)
        #expect(preset.oscPhaseMode == .reset)
        #expect(preset.polyphonyLimit == 32)
        let cleaned = preset.sanitized()
        #expect(cleaned.polyphonyLimit == 32)
        #expect(cleaned.oscPhaseMode == .reset)
    }

    @Test func sanitizeClampsStereoAndPolyphony() {
        var preset = SynthPreset.defaultPreset
        preset.stereoWidth = 9
        preset.stereoMidSide = -4
        preset.stereoHaasMs = 80
        preset.stereoMonoBassHz = .infinity
        preset.polyphonyLimit = 0
        let cleaned = preset.sanitized()
        #expect(cleaned.stereoWidth == 2)
        #expect(cleaned.stereoMidSide == -1)
        #expect(cleaned.stereoHaasMs == 30)
        #expect(cleaned.stereoMonoBassHz == 0)
        #expect(cleaned.polyphonyLimit == 1)
    }

    @Test func widthZeroCollapsesAStereoPair() {
        let tool = DSPStereoTool()
        let (l, r) = tool.process(
            left: 0.4,
            right: -0.2,
            width: 0,
            midSide: 0,
            haasMs: 0,
            monoBassHz: 0,
            sampleRate: 44_100
        )
        #expect(abs(l - r) < 1e-6)
        #expect(abs(l - 0.1) < 1e-5)
    }

    @Test func haasDelaysTheRightChannel() {
        let tool = DSPStereoTool()
        let sampleRate: Float = 44_100
        let ms: Float = 10
        let delay = Int(ms * 0.001 * sampleRate)
        var first: Int?
        for i in 0..<800 {
            let (_, right) = tool.process(
                left: 0,
                right: i == 0 ? 1 : 0,
                width: 1,
                midSide: 0,
                haasMs: ms,
                monoBassHz: 0,
                sampleRate: sampleRate
            )
            if abs(right) > 0.5 {
                first = i
                break
            }
        }
        #expect(first == delay)
    }

    @Test func monoBassCentersAConstantStereoOffset() {
        let tool = DSPStereoTool()
        var left: Float = 0
        var right: Float = 0
        for _ in 0..<4_000 {
            (left, right) = tool.process(
                left: 1,
                right: 0,
                width: 1,
                midSide: 0,
                haasMs: 0,
                monoBassHz: 200,
                sampleRate: 44_100
            )
        }
        #expect(abs(left - right) < 0.05)
        #expect(abs(left - 0.5) < 0.05)
    }

    @Test func resetPhaseMatchesVoiceStartPhases() {
        var note = ActiveNote()
        note.activate(midiNote: 60, velocity: 1.0, frequency: 261.63)
        let start = AudioMath.voiceStartPhases(midiNote: 60, partial: 0, partialCount: 1)
        #expect(note.phase == start.0)
        #expect(note.phase2 == start.1)
        #expect(note.subPhase == start.0)
    }

    @Test func freePhaseKeepsTheSlotAndRandomIsStable() {
        var note = ActiveNote()
        note.phase = 1.25
        note.phase2 = 2.5
        note.subPhase = 0.75
        note.activate(midiNote: 60, velocity: 1.0, frequency: 100, phaseMode: .free)
        #expect(note.phase == 1.25)
        #expect(note.phase2 == 2.5)
        #expect(note.subPhase == 0.75)

        var a = ActiveNote()
        a.activate(midiNote: 67, velocity: 0.8, frequency: 100, partial: 2, partialCount: 4, phaseMode: .random)
        var b = ActiveNote()
        b.activate(midiNote: 67, velocity: 0.8, frequency: 100, partial: 2, partialCount: 4, phaseMode: .random)
        let start = AudioMath.voiceStartPhases(midiNote: 67, partial: 2, partialCount: 4)
        #expect(a.phase == b.phase)
        #expect(a.phase2 == b.phase2)
        #expect(a.subPhase == b.subPhase)
        #expect(a.phase != start.0)
    }

    @Test func defaultPolyphonyStillUsesLaterSlots() {
        let engine = AudioEngine()
        engine.preset = .defaultPreset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        #expect(engine.cachedPolyphonyLimit == AudioEngine.maxVoices)
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        engine.handleNoteOn(midiNote: 64, velocity: 1)
        engine.handleNoteOn(midiNote: 67, velocity: 1)
        #expect(engine.voices[0].isActive)
        #expect(engine.voices[1].isActive)
        #expect(engine.voices[2].isActive)
    }

    @Test func polyphonyLimitOfOneKeepsASingleSlot() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.polyphonyLimit = 1
        preset.unisonVoices = 1
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        #expect(engine.cachedPolyphonyLimit == 1)
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        engine.handleNoteOn(midiNote: 64, velocity: 1)
        let active = engine.voices.enumerated().filter { $0.element.isActive }
        #expect(active.count == 1)
        #expect(active[0].offset == 0)
        #expect(engine.voices[1].isActive == false)
    }

    @Test func stereoOffLeavesARepeatedRenderIdenticalAndWidthZeroCentersUnison() {
        func render(mutate: (inout SynthPreset) -> Void) -> [(Float, Float)] {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            mutate(&preset)
            engine.preset = preset
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 60, velocity: 1)
            var frames: [(Float, Float)] = []
            for _ in 0..<2_000 {
                frames.append(engine.renderOneSample())
            }
            return frames
        }

        let first = render { _ in }
        let second = render { preset in
            preset.stereoEnabled = false
            preset.oscPhaseMode = .reset
            preset.polyphonyLimit = 32
        }
        for i in 0..<first.count {
            #expect(first[i].0 == second[i].0)
            #expect(first[i].1 == second[i].1)
        }

        let plain = render { preset in
            preset.stereoEnabled = false
        }
        let haas = render { preset in
            preset.stereoEnabled = true
            preset.stereoHaasMs = 20
            preset.stereoWidth = 1
        }
        let collapsed = render { preset in
            preset.unisonVoices = 2
            preset.unisonSpread = 1
            preset.stereoEnabled = true
            preset.stereoWidth = 0
        }
        let spread = render { preset in
            preset.unisonVoices = 2
            preset.unisonSpread = 1
            preset.stereoEnabled = false
        }
        var haasGap: Float = 0
        var spreadGap: Float = 0
        var collapsedGap: Float = 0
        var level: Float = 0
        for i in 800..<plain.count {
            level = max(level, abs(plain[i].0))
            haasGap = max(haasGap, abs(haas[i].1 - plain[i].1))
            spreadGap = max(spreadGap, abs(spread[i].0 - spread[i].1))
            collapsedGap = max(collapsedGap, abs(collapsed[i].0 - collapsed[i].1))
        }
        #expect(level > 0.02)
        #expect(haasGap > 0.01)
        #expect(spreadGap > 0.01)
        #expect(collapsedGap < spreadGap * 0.05)
    }
}
