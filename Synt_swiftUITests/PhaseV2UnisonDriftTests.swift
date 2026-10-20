//
//  PhaseV2UnisonDriftTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.3: Unison Stereo Spread & Per-Voice Analog Drift.
//

import Foundation
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2UnisonDriftTests {

    @Test func unisonSpreadAndAnalogDriftDefaults() throws {
        let p = SynthPreset.defaultPreset
        #expect(p.unisonSpread == 0.0)
        #expect(p.unisonStereoSpread == 0.0)
        #expect(p.analogDrift == 0.0)

        // Decoding legacy JSON
        let minimalJSON = """
        {"name":"Vintage Patch"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(decoded.unisonSpread == 0.0)
        #expect(decoded.unisonStereoSpread == 0.0)
        #expect(decoded.analogDrift == 0.0)
    }

    @Test func unisonSpreadCreatesStereoWidth() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        // 1. Preset with Unison = 4, Spread = 0.0 (Mono center unison)
        var monoPreset = SynthPreset.defaultPreset
        monoPreset.unisonVoices = 4
        monoPreset.unisonDetune = 12.0
        monoPreset.unisonSpread = 0.0
        monoPreset.chorusMix = 0.0
        monoPreset.reverbMix = 0.0
        monoPreset.delayMix = 0.0

        engine.preset = monoPreset
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var maxMonoDiff: Float = 0
        for _ in 0..<512 {
            let (l, r) = engine.renderOneSample()
            maxMonoDiff = max(maxMonoDiff, abs(l - r))
        }
        #expect(maxMonoDiff < 0.0001, "Spread 0 should have identical L and R channels (diff \(maxMonoDiff))")

        // 2. Preset with Unison = 4, Spread = 1.0 (Full stereo spread)
        engine.clearAllVoices()
        var widePreset = monoPreset
        widePreset.unisonSpread = 1.0

        engine.preset = widePreset
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var maxStereoDiff: Float = 0
        for _ in 0..<512 {
            let (l, r) = engine.renderOneSample()
            maxStereoDiff = max(maxStereoDiff, abs(l - r))
        }
        #expect(maxStereoDiff > 0.05, "Spread 1.0 should create substantial L vs R difference (diff \(maxStereoDiff))")
    }

    @Test func analogDriftProducesStableOrganicAudio() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.unisonVoices = 2
        p.unisonDetune = 5.0
        p.analogDrift = 1.0 // 100% drift (±5 cents)

        engine.preset = p
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        var peak: Float = 0
        var hasFiniteSignal = true

        for _ in 0..<4410 { // ~100 ms
            let (l, r) = engine.renderOneSample()
            if !l.isFinite || !r.isFinite || l.isNaN || r.isNaN {
                hasFiniteSignal = false
            }
            peak = max(peak, abs(l), abs(r))
        }

        #expect(hasFiniteSignal)
        #expect(peak > 0.02)
        #expect(peak < 1.0)
    }

    @Test func unisonSpreadAliasSyncsWithUnisonSpread() {
        var p = SynthPreset.defaultPreset
        p.unisonSpread = 0.42
        #expect(p.unisonStereoSpread == 0.42)

        p.unisonStereoSpread = 0.85
        #expect(p.unisonSpread == 0.85)
    }
}
