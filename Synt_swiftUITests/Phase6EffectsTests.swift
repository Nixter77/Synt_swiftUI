//
//  Phase6EffectsTests.swift
//  Synt_swiftUITests
//
//  Tests for Phase 6: 2x Oversampling in Distortion and Stereo Ping-Pong Delay.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct Phase6EffectsTests {

    @Test func distortionOversamplingDefaultsToFalseAndDecodesSafely() throws {
        let def = SynthPreset.defaultPreset
        #expect(def.distortionOversampling == false)
        #expect(def.delayPingPong == false)

        let json = "{\"name\": \"LegacyPatch\"}".data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: json)
        #expect(decoded.distortionOversampling == false)
        #expect(decoded.delayPingPong == false)
    }

    @Test func oversamplingReducesHighFrequencyAliasing() {
        let distNoOS = Distortion()
        distNoOS.enabled = true
        distNoOS.type = .wavefolder
        distNoOS.drive = 0.85
        distNoOS.mix = 1.0
        distNoOS.oversampling = false

        let distOS = Distortion()
        distOS.enabled = true
        distOS.type = .wavefolder
        distOS.drive = 0.85
        distOS.mix = 1.0
        distOS.oversampling = true

        let sampleRate: Double = 44100.0
        let freq: Double = 5000.0
        let numSamples = 4096

        // Compute alias product at 4100 Hz (8th harmonic = 40 kHz -> folds to 4100 Hz)
        let aliasFreq: Double = 4100.0
        var sinAccumNoOS: Double = 0
        var cosAccumNoOS: Double = 0
        var sinAccumOS: Double = 0
        var cosAccumOS: Double = 0

        for n in 0..<numSamples {
            let t = Double(n) / sampleRate
            let input = Float(sin(2.0 * .pi * freq * t))

            let outNoOS = distNoOS.process(input)
            let outOS = distOS.process(input)

            // Measure DFT bin at alias frequency after warm-up
            if n >= 256 {
                let aliasPhase = 2.0 * .pi * aliasFreq * t
                sinAccumNoOS += Double(outNoOS) * sin(aliasPhase)
                cosAccumNoOS += Double(outNoOS) * cos(aliasPhase)

                sinAccumOS += Double(outOS) * sin(aliasPhase)
                cosAccumOS += Double(outOS) * cos(aliasPhase)
            }
        }

        let magNoOS = sqrt(sinAccumNoOS * sinAccumNoOS + cosAccumNoOS * cosAccumNoOS)
        let magOS = sqrt(sinAccumOS * sinAccumOS + cosAccumOS * cosAccumOS)

        // 2x oversampling should significantly suppress the folded 8th harmonic alias
        #expect(magOS < magNoOS * 0.75, "Oversampling must suppress aliasing: OS=\(magOS) vs NoOS=\(magNoOS)")
    }

    @Test func pingPongDelayBouncesBetweenLeftAndRightChannels() {
        let delay = PingPongDelay(sampleRate: 44100.0, maxDelaySeconds: 1.0)
        delay.enabled = true
        delay.delayTime = 0.05 // 50 ms = 2205 samples
        delay.feedback = 0.6
        delay.mix = 1.0 // 100% wet to inspect echoes directly

        let delaySamples = Int(0.05 * 44100.0)

        // Send a single unit pulse at frame 0 (center panned)
        let (outL0, outR0) = delay.process(inputL: 1.0, inputR: 1.0)
        #expect(outL0 == 0) // No instant dry output in wet mode
        #expect(outR0 == 0)

        var peak1L: Float = 0
        var peak1R: Float = 0
        var peak2L: Float = 0
        var peak2R: Float = 0

        // Advance through first echo window
        for n in 1..<(delaySamples * 3) {
            let (l, r) = delay.process(inputL: 0, inputR: 0)

            // First echo window around delaySamples (±50 samples)
            if abs(n - delaySamples) < 50 {
                peak1L = max(peak1L, abs(l))
                peak1R = max(peak1R, abs(r))
            }

            // Second echo window around 2 * delaySamples (±50 samples)
            if abs(n - delaySamples * 2) < 50 {
                peak2L = max(peak2L, abs(l))
                peak2R = max(peak2R, abs(r))
            }
        }

        // Tap 1 should appear on Left (Left is dominant on first bounce)
        #expect(peak1L > 0.3, "First tap must be present on Left channel")
        #expect(peak1L > peak1R * 2.0, "First tap on Left (\(peak1L)) must be much louder than Right (\(peak1R))")

        // Tap 2 should bounce to Right (Right is dominant on second bounce)
        #expect(peak2R > 0.15, "Second tap must be present on Right channel")
        #expect(peak2R > peak2L * 2.0, "Second tap on Right (\(peak2R)) must be much louder than Left (\(peak2L))")
    }

    @Test func pingPongDelayDecaysSmoothlyAndStaysStable() {
        let delay = PingPongDelay(sampleRate: 44100.0, maxDelaySeconds: 1.0)
        delay.enabled = true
        delay.delayTime = 0.02
        delay.feedback = 0.8
        delay.mix = 0.5

        // Feed burst of 50 samples
        for _ in 0..<50 {
            let (l, r) = delay.process(inputL: 0.8, inputR: 0.8)
            #expect(l.isFinite && r.isFinite)
            #expect(abs(l) <= 1.5 && abs(r) <= 1.5)
        }

        // Allow to ring out for 20,000 samples
        var lastMax: Float = 0
        for _ in 0..<20000 {
            let (l, r) = delay.process(inputL: 0, inputR: 0)
            #expect(l.isFinite && r.isFinite)
            #expect(abs(l) <= 1.5 && abs(r) <= 1.5)
            lastMax = max(abs(l), abs(r))
        }

        // Must decay towards zero
        #expect(lastMax < 0.05, "Echo tail should decay smoothly: lastMax=\(lastMax)")
    }

    @Test func presetDelayPingPongAppliesInAudioEngine() {
        let engine = AudioEngine()
        var p = SynthPreset.defaultPreset
        p.delayPingPong = true
        p.delayMix = 0.35
        p.delayFeedback = 0.5
        engine.loadPreset(p)
        engine.applyPresetForTesting()

        #expect(engine.cachedDelayPingPong == true)
        #expect(engine.pingPongDelay.enabled == true)
        #expect(engine.pingPongDelay.mix == 0.35)
        #expect(engine.delayWetPercentForTesting == 0.0) // Apple delay muted to avoid doubling
    }

    @Test func phase6PreservesInitGoldenHash() {
        let initPreset = SynthPreset.defaultPreset
        let hash = InitGoldenTests.renderHash(initPreset)
        #expect(hash == InitGoldenTests.golden["Init"]!, "Init preset hash must be bit-identical: 0x\(String(hash, radix: 16))")
    }
}
