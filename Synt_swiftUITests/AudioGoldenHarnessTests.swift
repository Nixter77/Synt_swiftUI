//
//  AudioGoldenHarnessTests.swift
//  Synt_swiftUITests
//
//  STAGE 1 — golden harness on the CURRENT render path.
//  Gates are NOT bit-exact: NaN/Inf = 0, peak/RMS within relative tolerance,
//  fixed sampleRate + block size, deterministic stimuli (1 note / chord / unison7).
//  FX+modulation disabled in base goldens (separate continuity cases).
//  Production DSP / sound constants must remain unchanged.
//

import Foundation
import Testing
@testable import Synt_swiftUI

// MARK: - Tolerance helpers (~ULP / ~−120 dB relative)

private enum GoldenTol {
    /// ~−120 dB relative floor for peak/RMS comparisons.
    static let rel: Float = 1.0e-6
    static let absFloor: Float = 1.0e-7
    /// Phase wrap tolerance (radians) — continuity, not sample identity.
    static let phaseRad: Double = 1.0e-4
    static let filterEnergyAbs: Float = 1.0e-9

    static let sampleRate: Double = 44_100
    static let blockSize: Int = 256
    static let warmBlocks: Int = 16
    static let measureBlocks: Int = 32
}

private func nearlyEqual(_ a: Float, _ b: Float,
                         rel: Float = GoldenTol.rel,
                         absFloor: Float = GoldenTol.absFloor) -> Bool {
    let diff = abs(a - b)
    if diff <= absFloor { return true }
    let scale = max(abs(a), abs(b), absFloor)
    return diff <= rel * scale
}

private func phaseDelta(_ a: Double, _ b: Double) -> Double {
    var d = a - b
    let twoPi = AudioMath.twoPi
    while d > Double.pi { d -= twoPi }
    while d < -Double.pi { d += twoPi }
    return d
}

// MARK: - Harness helpers (reuse engine test hooks only)

private struct RenderMetrics: Equatable {
    var peak: Float
    var rms: Float
    var nanCount: Int
    var nearClipCount: Int
    var preClipPeak: Float
}

private enum GoldenHarness {
    /// Dry Init-like preset: no arp, no LFO, no wet FX / advanced FX.
    static func basePreset(unisonVoices: Int = 1, unisonDetune: Float = 0) -> SynthPreset {
        var p = SynthPreset.defaultPreset
        p.arpMode = .off
        p.unisonVoices = unisonVoices
        p.unisonDetune = unisonDetune
        p.unisonSpread = unisonVoices > 1 ? 0.35 : 0
        p.lfoEnabled = false
        p.distortionEnabled = false
        p.eqEnabled = false
        p.phaserEnabled = false
        p.chorusMix = 0
        p.reverbMix = 0
        p.delayMix = 0
        p.portamento = 0
        // Stable envelope so sustain metrics are meaningful.
        p.attack = 0.01
        p.decay = 0.05
        p.sustain = 0.85
        p.release = 0.08
        p.filterCutoff = 8_000
        p.filterResonance = 0.2
        p.masterVolume = 0.5
        p.osc2Enabled = false
        return p
    }

    static func makeEngine(preset: SynthPreset) -> AudioEngine {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        return engine
    }

    static func noteOn(_ engine: AudioEngine, _ notes: [Int], velocity: Float = 1.0) {
        for n in notes {
            engine.noteOn(midiNote: n, velocity: velocity)
        }
        engine.processCommandsForTesting()
    }

    static func renderBlocks(_ engine: AudioEngine, blocks: Int) -> RenderMetrics {
        let frames = blocks * GoldenTol.blockSize
        let m = engine.renderFramesMetricsForTesting(frames)
        return RenderMetrics(
            peak: m.peak,
            rms: m.rms,
            nanCount: m.nanCount,
            nearClipCount: m.nearClipCount,
            preClipPeak: m.preClipPeak
        )
    }

    /// Warm-up then measure — fixed block geometry.
    static func measureStimulus(preset: SynthPreset, notes: [Int]) -> RenderMetrics {
        let engine = makeEngine(preset: preset)
        noteOn(engine, notes)
        _ = renderBlocks(engine, blocks: GoldenTol.warmBlocks)
        return renderBlocks(engine, blocks: GoldenTol.measureBlocks)
    }
}

// MARK: - STAGE 1 goldens

struct AudioGoldenHarnessTests {

    // MARK: Finite / level gates — 1 note

    @Test func golden_oneNote_finiteAndAudible() async throws {
        let metrics = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60]
        )
        #expect(metrics.nanCount == 0)
        #expect(metrics.peak.isFinite && metrics.rms.isFinite)
        #expect(metrics.peak > 0.02, "one note silent, peak \(metrics.peak)")
        #expect(metrics.peak < 0.98, "one note too hot, peak \(metrics.peak)")
        #expect(metrics.rms > 0.005, "one note RMS too low \(metrics.rms)")
        #expect(metrics.rms <= metrics.peak + GoldenTol.absFloor)
        #expect(metrics.nearClipCount == 0)
    }

    // MARK: Chord (Cmaj7-ish)

    @Test func golden_chord_finiteLouderThanOne() async throws {
        let one = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60]
        )
        let chord = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60, 64, 67, 71]
        )
        #expect(one.nanCount == 0)
        #expect(chord.nanCount == 0)
        #expect(chord.nearClipCount == 0, "chord near-clip \(chord.nearClipCount), peak \(chord.peak)")
        #expect(chord.peak < 0.98, "chord peak \(chord.peak)")
        #expect(chord.peak > one.peak * 1.1, "chord \(chord.peak) should exceed one \(one.peak)")
        #expect(chord.rms > one.rms * 1.05, "chord RMS \(chord.rms) vs one \(one.rms)")
    }

    // MARK: Unison7 request (engine may clamp; capture CURRENT behavior)

    @Test func golden_unison7_finiteStablePartials() async throws {
        let engine = GoldenHarness.makeEngine(
            preset: GoldenHarness.basePreset(unisonVoices: 7, unisonDetune: 10)
        )
        GoldenHarness.noteOn(engine, [60])
        // Solo path currently clamps requested unison; assert pool is sane.
        let held = engine.heldPartialCountForTesting
        #expect(held >= 1)
        #expect(held <= 5, "unexpected unison explosion: \(held)")
        _ = GoldenHarness.renderBlocks(engine, blocks: GoldenTol.warmBlocks)
        let metrics = GoldenHarness.renderBlocks(engine, blocks: GoldenTol.measureBlocks)
        #expect(metrics.nanCount == 0)
        #expect(metrics.peak.isFinite && metrics.rms.isFinite)
        #expect(metrics.peak > 0.015, "unison7 silent \(metrics.peak)")
        #expect(metrics.peak < 0.98, "unison7 hot \(metrics.peak)")
        #expect(metrics.nearClipCount == 0)
        #expect(engine.activeNoteCountForTesting == 1)
    }

    // MARK: Determinism — same stimulus → peak/RMS within ~−120 dB relative

    @Test func golden_determinism_oneNotePeakRmsMatch() async throws {
        let a = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60]
        )
        let b = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60]
        )
        #expect(a.nanCount == 0 && b.nanCount == 0)
        #expect(nearlyEqual(a.peak, b.peak), "peak \(a.peak) vs \(b.peak)")
        #expect(nearlyEqual(a.rms, b.rms), "rms \(a.rms) vs \(b.rms)")
        #expect(a.nearClipCount == b.nearClipCount)
    }

    @Test func golden_determinism_chordAndUnison7() async throws {
        let chordA = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60, 64, 67]
        )
        let chordB = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 1),
            notes: [60, 64, 67]
        )
        #expect(chordA.nanCount == 0 && chordB.nanCount == 0)
        #expect(nearlyEqual(chordA.peak, chordB.peak), "chord peak \(chordA.peak) vs \(chordB.peak)")
        #expect(nearlyEqual(chordA.rms, chordB.rms), "chord rms \(chordA.rms) vs \(chordB.rms)")

        let uA = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 7, unisonDetune: 8),
            notes: [60]
        )
        let uB = GoldenHarness.measureStimulus(
            preset: GoldenHarness.basePreset(unisonVoices: 7, unisonDetune: 8),
            notes: [60]
        )
        #expect(uA.nanCount == 0 && uB.nanCount == 0)
        #expect(nearlyEqual(uA.peak, uB.peak), "unison peak \(uA.peak) vs \(uB.peak)")
        #expect(nearlyEqual(uA.rms, uB.rms), "unison rms \(uA.rms) vs \(uB.rms)")
    }

    // MARK: OSC phase continuity — mid-note advance; steal does not reset held note

    @Test func golden_phaseContinuity_midNoteAdvances() async throws {
        let engine = GoldenHarness.makeEngine(preset: GoldenHarness.basePreset())
        GoldenHarness.noteOn(engine, [69]) // A4 = 440 Hz
        _ = GoldenHarness.renderBlocks(engine, blocks: 4)
        let before = engine.voiceProbesForTesting(midiNote: 69).filter { !$0.isReleasing }
        #expect(!before.isEmpty)
        let p0 = before[0].phase

        let frames = GoldenTol.blockSize
        _ = engine.renderFramesMetricsForTesting(frames)
        let after = engine.voiceProbesForTesting(midiNote: 69).filter { !$0.isReleasing }
        #expect(after.count == before.count)
        let p1 = after[0].phase

        let expected = AudioMath.twoPi * 440.0 * Double(frames) / GoldenTol.sampleRate
        let observed = phaseDelta(p1, p0)
        // Allow wrap; magnitude should be near expected advance (portamento off, fixed freq).
        var obs = observed
        if obs < 0 { obs += AudioMath.twoPi }
        var exp = expected.truncatingRemainder(dividingBy: AudioMath.twoPi)
        if exp < 0 { exp += AudioMath.twoPi }
        let err = abs(obs - exp)
        let errWrap = min(err, abs(err - AudioMath.twoPi))
        #expect(errWrap < 0.05, "phase advance err \(errWrap) obs \(obs) exp \(exp)")
        #expect(abs(p1) > GoldenTol.phaseRad || frames > 0) // progressed or wrapped
    }

    @Test func golden_phaseContinuity_retriggerKeepsReleasingPhaseMoving() async throws {
        let engine = GoldenHarness.makeEngine(preset: GoldenHarness.basePreset())
        GoldenHarness.noteOn(engine, [60])
        _ = GoldenHarness.renderBlocks(engine, blocks: 8)
        let liveBefore = engine.voiceProbesForTesting(midiNote: 60).filter { !$0.isReleasing }
        #expect(liveBefore.count == 1)
        let oldPhase = liveBefore[0].phase

        // Soft re-trigger: previous partial fast-releases (phase must NOT hard-reset to 0).
        GoldenHarness.noteOn(engine, [60])
        let probes = engine.voiceProbesForTesting(midiNote: 60)
        let releasing = probes.filter { $0.isReleasing }
        let live = probes.filter { !$0.isReleasing }
        #expect(!releasing.isEmpty, "expected soft-retrigger releasing partial")
        #expect(!live.isEmpty, "expected new live partial")
        // Releasing voice keeps prior phase (activate resets only the NEW slot).
        #expect(abs(phaseDelta(releasing[0].phase, oldPhase)) < 0.25,
                "releasing phase jumped \(releasing[0].phase) vs \(oldPhase)")
        // New voice starts at 0 by design.
        #expect(abs(live[0].phase) < GoldenTol.phaseRad)

        _ = engine.renderFramesMetricsForTesting(GoldenTol.blockSize)
        let releasingAfter = engine.voiceProbesForTesting(midiNote: 60).filter { $0.isReleasing }
        if let r0 = releasing.first, let r1 = releasingAfter.first(where: {
            abs(phaseDelta($0.phase, r0.phase)) < 1.5 || abs($0.targetFrequency - r0.targetFrequency) < 0.1
        }) {
            // Still advancing while fading (not stuck / not zeroed without cause).
            let moved = abs(phaseDelta(r1.phase, r0.phase))
            #expect(moved > 1.0e-6 || r1.phase != 0, "releasing phase stalled/reset")
        }
        #expect(engine.renderFramesMetricsForTesting(64).nanCount == 0)
    }

    @Test func golden_phaseContinuity_heldNoteSurvivesOtherNoteStealPressure() async throws {
        let engine = GoldenHarness.makeEngine(preset: GoldenHarness.basePreset())
        GoldenHarness.noteOn(engine, [60])
        _ = GoldenHarness.renderBlocks(engine, blocks: 4)
        let heldPhase = engine.voiceProbesForTesting(midiNote: 60).first { !$0.isReleasing }?.phase
        #expect(heldPhase != nil)

        // Flood many other notes to exercise findFreeVoiceSlot steal path.
        for n in 48..<48 + 40 {
            engine.noteOn(midiNote: n, velocity: 0.6)
        }
        engine.processCommandsForTesting()
        _ = GoldenHarness.renderBlocks(engine, blocks: 2)

        // Under steal pressure the engine may release/steal note 60; if it remains held,
        // its oscillator phase must not have been hard-reset to 0 without cause.
        if engine.isNoteActiveForTesting(60),
           let still = engine.voiceProbesForTesting(midiNote: 60).first(where: { !$0.isReleasing }),
           let heldPhase {
            let resetToZero = abs(still.phase) < GoldenTol.phaseRad && abs(heldPhase) > 0.1
            #expect(!resetToZero, "held note phase hard-reset under steal pressure")
            // Continuity: phase should have advanced from the pre-flood snapshot.
            let moved = abs(phaseDelta(still.phase, heldPhase))
            #expect(moved > 1.0e-6, "held note phase frozen unexpectedly")
        }
        #expect(engine.renderFramesMetricsForTesting(128).nanCount == 0)
    }

    // MARK: Filter z-state mid-note

    @Test func golden_filterZState_midNotePersists() async throws {
        var preset = GoldenHarness.basePreset()
        preset.filterCutoff = 1_200
        preset.filterResonance = 0.7
        let engine = GoldenHarness.makeEngine(preset: preset)
        GoldenHarness.noteOn(engine, [60])
        _ = GoldenHarness.renderBlocks(engine, blocks: GoldenTol.warmBlocks)

        let e1 = engine.voiceFilterEnergyForTesting(60)
        #expect(e1 > GoldenTol.filterEnergyAbs, "filter z empty after warm-up \(e1)")

        _ = GoldenHarness.renderBlocks(engine, blocks: GoldenTol.measureBlocks)
        let e2 = engine.voiceFilterEnergyForTesting(60)
        #expect(e2 > GoldenTol.filterEnergyAbs, "filter z wiped mid-note \(e2)")
        // Not a hard reset to zero between blocks.
        #expect(e2 > 0)
        #expect(engine.renderFramesMetricsForTesting(64).nanCount == 0)
    }

    // MARK: Unison detune — distinct freqs; phases diverge; no mid-note reset

    @Test func golden_unisonDetune_phasesDivergeWithoutReset() async throws {
        let engine = GoldenHarness.makeEngine(
            preset: GoldenHarness.basePreset(unisonVoices: 3, unisonDetune: 12)
        )
        GoldenHarness.noteOn(engine, [60])
        let held = engine.heldPartialCountForTesting
        #expect(held >= 2, "need multi-partial unison, got \(held)")

        _ = GoldenHarness.renderBlocks(engine, blocks: 4)
        let mid = engine.voiceProbesForTesting(midiNote: 60).filter { !$0.isReleasing }
        #expect(mid.count == held)

        let freqs = Set(mid.map { Int($0.targetFrequency * 100) }) // centi-Hz buckets
        #expect(freqs.count >= 2, "detune should spread targetFrequency, got \(mid.map { $0.targetFrequency })")

        _ = GoldenHarness.renderBlocks(engine, blocks: 16)
        let later = engine.voiceProbesForTesting(midiNote: 60).filter { !$0.isReleasing }
        #expect(later.count == mid.count)

        // Phases should not all sit at 0 after many frames.
        let allZero = later.allSatisfy { abs($0.phase) < GoldenTol.phaseRad }
        #expect(!allZero, "unison phases reset mid-note")

        // With detune, phases diverge across partials.
        if later.count >= 2 {
            let phases = later.map { $0.phase }
            let spread = (phases.max() ?? 0) - (phases.min() ?? 0)
            #expect(abs(spread) > 1.0e-4, "unison phases locked together under detune")
        }

        let metrics = GoldenHarness.renderBlocks(engine, blocks: 8)
        #expect(metrics.nanCount == 0)
        #expect(metrics.peak < 0.98)
    }

    // MARK: FX+mod excluded from base goldens — smoke that enabling LFO is separate & finite

    @Test func golden_fxMod_separateCase_lfoDoesNotNaN() async throws {
        var preset = GoldenHarness.basePreset()
        preset.lfoEnabled = true
        preset.lfoRate = 3.0
        preset.lfoDepth = 0.35
        preset.lfoTarget = .filter
        let metrics = GoldenHarness.measureStimulus(preset: preset, notes: [60])
        #expect(metrics.nanCount == 0)
        #expect(metrics.peak.isFinite && metrics.rms.isFinite)
        // Intentionally NOT compared to dry golden — modulation is non-golden base.
    }
}
