//
//  Phase5SequencerArpTests.swift
//  Synt_swiftUITests
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct Phase5SequencerArpTests {

    @Test func arpOctavesExpandsSortedNotes() {
        var arp = ArpeggiatorEngine()
        arp.mode = .up
        arp.octaves = 1
        arp.setHeldKeys([60, 64])
        #expect(arp.sortedNotes == [60, 64])

        arp.octaves = 2
        arp.setHeldKeys([60, 64])
        #expect(arp.sortedNotes == [60, 64, 72, 76])

        arp.octaves = 3
        arp.setHeldKeys([60, 64])
        #expect(arp.sortedNotes == [60, 64, 72, 76, 84, 88])
    }

    @Test func arpOctaveClampedToValidRange() {
        var preset = SynthPreset.defaultPreset
        preset.arpOctaves = 5
        let sanitized = preset.sanitized()
        #expect(sanitized.arpOctaves == 3)

        preset.arpOctaves = -2
        let sanitizedLow = preset.sanitized()
        #expect(sanitizedLow.arpOctaves == 1)
    }

    @Test func arpRateDivisorCalculatesAccurateTickDuration() {
        let engine = AudioEngine()
        var p = SynthPreset.defaultPreset
        p.bpm = 120
        p.arpMode = .up

        p.arpRate = .sixteenth
        engine.preset = p
        engine.applyPresetForTesting()
        _ = engine.renderOneSample()
        // 120 bpm = 2 bps = 22050 samples/beat. 1/16th = 22050 / 4 = 5512.5 samples.
        #expect(abs(engine.samplesPerTick - 5512.5) < 1.0)

        p.arpRate = .eighth
        engine.preset = p
        engine.applyPresetForTesting()
        _ = engine.renderOneSample()
        // 1/8th note = 22050 / 2 = 11025 samples.
        #expect(abs(engine.samplesPerTick - 11025.0) < 1.0)

        p.arpRate = .quarter
        engine.preset = p
        engine.applyPresetForTesting()
        _ = engine.renderOneSample()
        // 1/4th note = 22050 samples.
        #expect(abs(engine.samplesPerTick - 22050.0) < 1.0)
    }

    @Test func sequencerStepDecodingPreservesTieAndGateDefaults() throws {
        let json = #"{"isActive":true,"noteOffset":7}"#
        let step = try JSONDecoder().decode(SequencerStep.self, from: Data(json.utf8))
        #expect(!step.tie)
        #expect(step.gate == 0.8)
    }

    @Test func sequencerTieSlidesPitchWithoutReleasingVoice() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120
        preset.portamento = 0.05 // Portamento active for audible acid slide
        engine.preset = preset
        engine.applyPresetForTesting()

        var pattern = [SequencerStep](repeating: SequencerStep(), count: 16)
        pattern[0] = SequencerStep(isActive: true, noteOffset: 0, tie: false, gate: 0.9)
        pattern[1] = SequencerStep(isActive: true, noteOffset: 12, tie: true, gate: 0.9)

        engine.sequencerTransport.publish(
            playing: true,
            swing: 0,
            bpm: 120,
            rootNote: 60,
            length: 2,
            generation: 1,
            gate: 0.9,
            patternSteps: pattern
        )

        // Step 0: Trigger note 60
        _ = engine.renderOneSample()
        #expect(engine.seqMirror.heldNote == 60)
        let activeVoicesBefore = engine.voices.filter(\.isActive).count
        #expect(activeVoicesBefore > 0)

        // Advance to step 1 (tied)
        let stepLength = Int(engine.sampleRate * 60.0 / 120.0 / 4.0)
        for _ in 0..<stepLength {
            _ = engine.renderOneSample()
        }

        // On step 1, heldNote should be 72, and the voice should NOT have been killed/recreated
        #expect(engine.seqMirror.heldNote == 72)
        let tiedVoice = engine.voices.first(where: { $0.isActive && $0.midiNote == 72 })
        #expect(tiedVoice != nil)
        #expect(tiedVoice?.envelopePhase != .finished)
    }
}
