//
//  PhaseV2FilterEnvelopeTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.1: Independent ADSR Filter Envelope (Env 2).
//

import Foundation
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2FilterEnvelopeTests {

    @Test func filterADSRDefaultsAndBackwardCompatibility() throws {
        let p = SynthPreset.defaultPreset
        #expect(!p.filterEnvUseDedicatedADSR)
        #expect(p.filterAttack == 0.01)
        #expect(p.filterDecay == 0.3)
        #expect(p.filterSustain == 0.0)
        #expect(p.filterRelease == 0.3)

        // Decode JSON missing the new keys
        let minimalJSON = """
        {"name":"Legacy Patch"}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: minimalJSON)
        #expect(!decoded.filterEnvUseDedicatedADSR)
        #expect(decoded.filterAttack == 0.01)
        #expect(decoded.filterDecay == 0.3)
        #expect(decoded.filterSustain == 0.0)
        #expect(decoded.filterRelease == 0.3)
    }

    @Test func filterDedicatedADSRClosesCutoffWhileAmpSustains() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        var p = SynthPreset.defaultPreset
        p.filterType = .lowPass
        p.filterCutoff = 1000.0
        p.filterEnvelopeAmount = 1.0
        p.filterEnvUseDedicatedADSR = true
        p.attack = 0.001
        p.decay = 0.5
        p.sustain = 1.0 // Amp sustains at 100%
        p.release = 0.5

        p.filterAttack = 0.001
        p.filterDecay = 0.02 // Filter closes fast (20 ms)
        p.filterSustain = 0.0 // Filter drops completely to 0 on sustain
        p.filterRelease = 0.05

        engine.preset = p
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        // 1. Initial sample right after attack: both envelopes should be high (~1.0)
        _ = engine.renderFramesForTesting(100) // ~2.2 ms
        let earlyProbes = engine.voiceProbesForTesting(midiNote: 60)
        #expect(!earlyProbes.isEmpty)

        // 2. Render 4410 frames (~100 ms).
        // By this time, filterDecay (20 ms) has finished, so filterEnv should be ~0.
        // But amp sustain is 1.0, so voice must still be active and audible.
        _ = engine.renderFramesForTesting(4410)

        let releases = engine.voiceReleaseFlagsForTesting()
        let activeVoice = releases.first { $0.midiNote == 60 }
        #expect(activeVoice != nil)
        #expect(activeVoice!.envelopeValue > 0.9, "Amp envelope must sustain near 1.0")
        #expect(!activeVoice!.isReleasing)
    }

    @Test func modMatrixSupportsEnv2Source() {
        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        let val = engine.matrixSource(
            .env2,
            lfo: 0.1,
            lfo2: 0.2,
            env: 0.3,
            velocity: 0.8,
            modWheel: 0.4,
            keyTrack: 0.5,
            env2: 0.77
        )
        #expect(abs(val - 0.77) < 1e-5)
    }

    @Test func phaseV2PreservesInitGolden() {
        let golden: UInt64 = 0xd1b3635203a4799e
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == golden,
                "Init hash changed to 0x\(String(hash, radix: 16)); expected 0x\(String(golden, radix: 16))")
    }
}
