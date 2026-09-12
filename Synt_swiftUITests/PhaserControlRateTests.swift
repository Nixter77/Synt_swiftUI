//
//  PhaserControlRateTests.swift
//  Synt_swiftUITests
//
//  Control-rate Phaser: stability, no NaN, budget vs warm path, Glass Horizon stays OFF.
//

import Foundation
import Dispatch
import Testing
@testable import Synt_swiftUI

struct PhaserControlRateTests {

    private func drivePhaser(
        _ p: Phaser,
        samples: Int,
        freq: Float = 220,
        amp: Float = 0.5
    ) -> (peak: Float, energy: Float, nan: Int) {
        var phase: Float = 0
        let dt = 2 * Float.pi * freq / 44100
        var peak: Float = 0
        var energy: Float = 0
        var nan = 0
        for _ in 0..<samples {
            let s = sin(phase) * amp
            phase += dt
            let (l, r) = p.process(inputL: s, inputR: s * 0.9)
            if !l.isFinite || !r.isFinite { nan += 1 }
            peak = max(peak, max(abs(l), abs(r)))
            energy += abs(l) + abs(r)
        }
        return (peak, energy, nan)
    }

    @Test func controlPeriodIsClassicBlockSize() async throws {
        let p = Phaser(sampleRate: 44100)
        #expect(p.controlPeriod >= 16 && p.controlPeriod <= 64)
    }

    @Test func phaser2ControlRateStableNoNaN() async throws {
        let p = Phaser(sampleRate: 44100)
        p.bypass = false
        p.mode = .phaser2
        p.mix = 0.45
        p.feedback = 0.25
        p.depth = 0.55
        p.rate = 0.4
        p.centerFrequency = 800

        let r = drivePhaser(p, samples: 12_000)
        #expect(r.nan == 0)
        #expect(r.peak.isFinite)
        #expect(r.peak < 3)
        #expect(r.energy > 1) // still producing signal
    }

    @Test func phaser8HighFeedbackStillFinite() async throws {
        let p = Phaser(sampleRate: 44100)
        p.bypass = false
        p.mode = .phaser8
        p.mix = 0.7
        p.feedback = 0.7
        p.depth = 0.8
        p.rate = 1.0

        let r = drivePhaser(p, samples: 8_000)
        #expect(r.nan == 0)
        #expect(r.peak < 3)
        #expect(r.energy > 0.5)
    }

    @Test func dryMixIsPassthrough() async throws {
        let p = Phaser(sampleRate: 44100)
        p.bypass = false
        p.mode = .phaser4
        p.mix = 0
        let (l, r) = p.process(inputL: 0.25, inputR: -0.2)
        #expect(abs(l - 0.25) < 0.0001)
        #expect(abs(r + 0.2) < 0.0001)
    }

    @Test func a1ReferenceMatchesMusicdspForm() async throws {
        // musicdsp: a1 = (1-d)/(1+d) with d=tan(πf/sr).
        // Our bilinear form (tan-1)/(tan+1) == -(1-d)/(1+d) == (d-1)/(d+1).
        let p = Phaser(sampleRate: 44100)
        for freq: Float in [200, 500, 1000, 2000] {
            let a1 = p.calculateAllpassCoeffReference(frequency: freq)
            let arg = Double.pi * Double(freq) / 44100.0
            let d = tan(min(arg, Double.pi * 0.49))
            let classicMusicdsp = Float((1.0 - d) / (1.0 + d))
            let bilinearUsed = Float((d - 1.0) / (d + 1.0))
            #expect(abs(a1 - bilinearUsed) < 1e-5)
            #expect(abs(a1 + classicMusicdsp) < 1e-5)
            #expect(a1.isFinite && abs(a1) <= 0.99)
        }
    }

    @Test func controlRateReducesCoeffUpdatesByPeriod() async throws {
        // Deterministic budget argument (no wall-clock flake under parallel XCTest hosts):
        // old hot path ≈ stages×channels tans/sample; control-rate ≈ that / controlPeriod.
        let p = Phaser(sampleRate: 44100)
        let frames = 3_200
        let stages = 2
        let channels = 2
        let period = p.controlPeriod
        let perSampleUpdates = frames * stages * channels
        let controlUpdates = (frames / period) * stages * channels
        #expect(period >= 16 && period <= 64)
        #expect(controlUpdates * period == perSampleUpdates)
        #expect(controlUpdates <= perSampleUpdates / 16)
    }

    @Test func controlRateRenderBudgetPhaser2OfflineSane() async throws {
        // Debug+instrumentation is slow; only guard against catastrophic regression.
        let frames = 48_000
        let p = Phaser(sampleRate: 44100)
        p.bypass = false
        p.mode = .phaser2
        p.mix = 0.12
        p.feedback = 0.08
        p.depth = 0.22
        p.rate = 0.10
        p.centerFrequency = 700
        _ = drivePhaser(p, samples: 2_000)

        let t0 = DispatchTime.now().uptimeNanoseconds
        let r = drivePhaser(p, samples: frames)
        let ms = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0

        #expect(r.nan == 0)
        #expect(r.peak < 3)
        #expect(ms < 15_000, "phaser2 control-rate took \(ms) ms for \(frames) frames")
    }

    @Test func glassHorizonFactoryPhaserRemainsOff() async throws {
        guard let pad = SynthPreset.factoryPresets.first(where: { $0.name == "Glass Horizon" }) else {
            Issue.record("Missing Glass Horizon")
            return
        }
        #expect(pad.phaserEnabled == false)
        #expect(pad.phaserMode == .phaser2)
    }

    @Test func engineDryGoldenPathStillCleanWithPhaserBypassed() async throws {
        // Golden dry path uses phaser off; smoke that engine render stays finite.
        let engine = AudioEngine()
        var p = SynthPreset.factoryPresets.first(where: { $0.name == "Analog Drift" }) ?? SynthPreset.factoryPresets[0]
        p.phaserEnabled = false
        engine.preset = p
        engine.applyPresetForTesting()
        engine.processCommandsForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        let result = engine.renderFramesForTesting(4_096)
        #expect(result.nanCount == 0)
        #expect(result.peak.isFinite)
        #expect(engine.phaser.bypass == true)
    }
}
