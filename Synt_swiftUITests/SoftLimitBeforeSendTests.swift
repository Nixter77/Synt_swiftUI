//
//  SoftLimitBeforeSendTests.swift
//  Synt_swiftUITests
//
//  Option D — soft-limit / drive reduction on the bus entering Apple Delay/Reverb.
//  Dry-zero offline: soft-limit gate off → metrics ≈ baseline.
//  Live A/B (1 / 3 / 7 note wet pad) required before merge — SOFT_LIMIT_BEFORE_SEND_NOTES.md.
//

import Foundation
import Testing
@testable import Synt_swiftUI

@Suite("SoftLimitBeforeSend", .serialized)
struct SoftLimitBeforeSendTests {

    @Test func softLimitBeforeSend_belowKnee_isIdentity() {
        let knee = AudioMath.preSendSoftLimitKnee
        #expect(AudioMath.softLimitBeforeSend(0) == 0)
        #expect(AudioMath.softLimitBeforeSend(knee) == knee)
        #expect(AudioMath.softLimitBeforeSend(-knee) == -knee)
        #expect(AudioMath.softLimitBeforeSend(knee * 0.5) == knee * 0.5)
    }

    @Test func softLimitBeforeSend_aboveKnee_isQuieterAndBounded() {
        let ceiling = AudioMath.preSendSoftLimitCeiling
        let hot: Float = 0.95
        let out = AudioMath.softLimitBeforeSend(hot)
        #expect(out > AudioMath.preSendSoftLimitKnee)
        #expect(out <= ceiling + 1e-5)
        #expect(out < hot, "prefer quieter send over passing hot crest")
        #expect(AudioMath.softLimitBeforeSend(-hot) == -out)
    }

    @Test func preSendDriveGain_isQuieterBias() {
        #expect(AudioMath.preSendDriveGain > 0.75)
        #expect(AudioMath.preSendDriveGain < 1.0)
    }

    @Test func engine_preSendDrive_matchesConstant() {
        let engine = AudioEngine()
        #expect(abs(engine.preSendDriveGainForTesting - AudioMath.preSendDriveGain) < 1e-5)
    }

    /// Dry-zero → gate off → offline peak/nearClip behave like golden baseline.
    @Test func offlineDry_oneNote_matchesGoldenStyleBaseline() {
        var p = SynthPreset.defaultPreset
        p.arpMode = .off
        p.lfoEnabled = false
        p.distortionEnabled = false
        p.eqEnabled = false
        p.phaserEnabled = false
        p.chorusMix = 0
        p.reverbMix = 0
        p.delayMix = 0
        p.unisonVoices = 1
        p.osc2Enabled = false
        p.attack = 0.01
        p.decay = 0.05
        p.sustain = 0.85
        p.release = 0.08
        p.masterVolume = 0.5

        let engine = AudioEngine()
        engine.preset = p
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()

        #expect(engine.delayWetPercentForTesting <= 0.25)

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        _ = engine.renderFramesMetricsForTesting(256 * 16)
        let m = engine.renderFramesMetricsForTesting(256 * 48)

        #expect(m.nanCount == 0)
        #expect(m.nearClipCount == 0)
        #expect(m.peak > 0.02 && m.peak < 0.98)
        #expect(m.rms <= m.peak + 1e-6)
    }

    /// Stock wet engages the soft-limit gate; offline still has no Apple FX (live A/B gap).
    @Test func offlineWetGate_engagesWithoutNaN() {
        var p = SynthPreset.defaultPreset
        p.arpMode = .off
        p.lfoEnabled = false
        p.chorusMix = 0
        p.reverbMix = 0.22
        p.delayMix = 0.08
        p.unisonVoices = 1
        p.osc2Enabled = false
        p.attack = 0.01
        p.sustain = 0.85
        p.masterVolume = 0.5

        let engine = AudioEngine()
        engine.preset = p
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()

        #expect(max(engine.delayWetPercentForTesting, engine.reverb.wetDryMix) > 0.25)

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.noteOn(midiNote: 64, velocity: 1.0)
        engine.noteOn(midiNote: 67, velocity: 1.0)
        engine.processCommandsForTesting()

        let m = engine.renderFramesMetricsForTesting(256 * 32)
        #expect(m.nanCount == 0)
        #expect(m.peak.isFinite && m.peak < 0.98)
        // Apple Delay/Reverb still absent offline — listen live for rasp (NOTES).
    }
}
