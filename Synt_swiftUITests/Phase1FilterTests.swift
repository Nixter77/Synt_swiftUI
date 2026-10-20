//
//  Phase1FilterTests.swift
//  SYNTH_ROADMAP Phase 1: filter envelope amount + key tracking (per-voice cutoff).
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct Phase1FilterTests {

    private func basePreset() -> SynthPreset {
        var p = SynthPreset.defaultPreset
        p.osc1Waveform = .sawtooth
        p.osc2Enabled = false
        p.attack = 0.2
        p.decay = 0.3
        p.sustain = 0.0
        p.release = 0.2
        p.filterCutoff = 500
        p.filterResonance = 0.2
        p.masterVolume = 0.5
        p.lfoEnabled = false
        p.reverbMix = 0
        p.delayMix = 0
        p.chorusMix = 0
        return p
    }

    private func render(_ preset: SynthPreset, note: Int, frames: Int) -> [Float] {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        engine.noteOn(midiNote: note, velocity: 1)
        engine.processCommandsForTesting()
        var out = [Float]()
        out.reserveCapacity(frames)
        for _ in 0..<frames {
            let (l, r) = engine.renderOneSample()
            out.append((l + r) * 0.5)
        }
        return out
    }

    /// Mean absolute second difference ≈ high-frequency energy (weights harmonic n by n²).
    private func brightness(_ x: ArraySlice<Float>) -> Float {
        let a = Array(x)
        guard a.count > 2 else { return 0 }
        var acc: Float = 0
        for i in 2..<a.count {
            acc += abs(a[i] - 2 * a[i - 1] + a[i - 2])
        }
        return acc / Float(a.count - 2)
    }

    private func rms(_ x: ArraySlice<Float>) -> Float {
        guard !x.isEmpty else { return 0 }
        var s: Float = 0
        for v in x { s += v * v }
        return sqrt(s / Float(x.count))
    }

    @Test func keyTrackingDefaultsToZeroAndDecodesFromOldJSON() throws {
        #expect(SynthPreset.defaultPreset.filterKeyTracking == 0)
        let json = try JSONEncoder().encode(SynthPreset.defaultPreset)
        var dict = try #require(try JSONSerialization.jsonObject(with: json) as? [String: Any])
        dict.removeValue(forKey: "filterKeyTracking")
        let old = try JSONSerialization.data(withJSONObject: dict)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: old)
        #expect(decoded.filterKeyTracking == 0)
    }

    @Test func sanitizeClampsKeyTracking() {
        var p = SynthPreset.defaultPreset
        p.filterKeyTracking = 9
        #expect(p.sanitized().filterKeyTracking == 1)
        p.filterKeyTracking = .nan
        #expect(p.sanitized().filterKeyTracking == 0)
    }

    @Test func filterEnvelopeAmountOpensCutoffAndBrightens() {
        var closed = basePreset()
        closed.filterEnvelopeAmount = 0
        var open = basePreset()
        open.filterEnvelopeAmount = 1

        // Samples ~0.15…0.25 s: envelope near its peak (attack 0.2 s).
        let sr = 44_100
        let a = render(closed, note: 48, frames: sr / 2)
        let b = render(open, note: 48, frames: sr / 2)
        let range = (sr * 15 / 100)..<(sr * 25 / 100)
        let normClosed = brightness(a[range]) / max(rms(a[range]), 1e-6)
        let normOpen = brightness(b[range]) / max(rms(b[range]), 1e-6)
        #expect(normOpen > normClosed * 1.2, "open \(normOpen) closed \(normClosed)")
        #expect(b.allSatisfy { $0.isFinite })
    }

    @Test func negativeEnvelopeAmountClosesFilter() {
        var neutral = basePreset()
        neutral.filterCutoff = 4_000
        var closing = neutral
        closing.filterEnvelopeAmount = -1
        let sr = 44_100
        let a = render(neutral, note: 60, frames: sr / 2)
        let b = render(closing, note: 60, frames: sr / 2)
        let range = (sr * 15 / 100)..<(sr * 25 / 100)
        let na = brightness(a[range]) / max(rms(a[range]), 1e-6)
        let nb = brightness(b[range]) / max(rms(b[range]), 1e-6)
        #expect(nb < na)
    }

    @Test func keyTrackingMakesHighNotesBrighterRelativeToLow() {
        var off = basePreset()
        off.attack = 0.005
        off.sustain = 1
        off.filterCutoff = 800
        var on = off
        on.filterKeyTracking = 1

        let sr = 44_100
        let range = (sr / 10)..<(sr / 4)
        // High note: tracking raises cutoff, so more of the saw's harmonics pass.
        let hiOff = render(off, note: 84, frames: sr / 3)
        let hiOn = render(on, note: 84, frames: sr / 3)
        #expect(rms(hiOn[range]) > rms(hiOff[range]) * 1.2)
        // Low note: tracking lowers cutoff, so it must not be louder than without.
        let loOff = render(off, note: 36, frames: sr / 3)
        let loOn = render(on, note: 36, frames: sr / 3)
        #expect(rms(loOn[range]) < rms(loOff[range]))
    }

    @Test func perVoiceFilterStaysFiniteAndUnderCeilingOnChord() {
        var p = basePreset()
        p.filterResonance = 0.9
        p.filterEnvelopeAmount = 1
        p.filterKeyTracking = 1
        let engine = AudioEngine()
        engine.preset = p
        engine.applyPresetForTesting()
        for n in [48, 55, 60, 64, 67, 72] { engine.noteOn(midiNote: n, velocity: 1) }
        engine.processCommandsForTesting()
        let m = engine.renderFramesMetricsForTesting(44_100)
        #expect(m.nanCount == 0)
        #expect(m.peak <= 1.0)
    }
}
