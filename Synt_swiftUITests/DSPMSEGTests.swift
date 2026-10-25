//
//  DSPMSEGTests.swift
//  Synt_swiftUITests
//
//  Stage 2: MSEG engine tests (interpolation, loop, sustain, phase after retrigger).
//

import Testing
import Foundation
@testable import SynthCore

@MainActor
@Suite struct DSPMSEGTests {

    @Test func interpolationLinearConvexConcave() {
        let linearModel = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.0, curve: 0.0),
                DSPMSEGPoint(time: 1.0, value: 1.0, curve: 0.0)
            ],
            sustainIndex: nil
        )
        let msegLinear = DSPMSEG(model: linearModel)
        let midLinear = msegLinear.evaluate(at: 0.5)
        #expect(abs(midLinear - 0.5) < 1.0e-4, "Linear interpolation at 0.5 must be 0.5, got \(midLinear)")

        let convexModel = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.0, curve: 0.5),
                DSPMSEGPoint(time: 1.0, value: 1.0, curve: 0.0)
            ],
            sustainIndex: nil
        )
        let msegConvex = DSPMSEG(model: convexModel)
        let midConvex = msegConvex.evaluate(at: 0.5)
        #expect(midConvex < 0.45, "Convex curve at 0.5 must be < 0.45, got \(midConvex)")

        let concaveModel = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.0, curve: -0.5),
                DSPMSEGPoint(time: 1.0, value: 1.0, curve: 0.0)
            ],
            sustainIndex: nil
        )
        let msegConcave = DSPMSEG(model: concaveModel)
        let midConcave = msegConcave.evaluate(at: 0.5)
        #expect(midConcave > 0.55, "Concave curve at 0.5 must be > 0.55, got \(midConcave)")
    }

    @Test func loopRegionBetweenPoints() {
        // Model with 4 points: 0.0, 0.2, 0.8, 1.0
        // Loop from point 1 (0.2) to point 2 (0.8)
        let model = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.0),
                DSPMSEGPoint(time: 0.2, value: 0.2),
                DSPMSEGPoint(time: 0.8, value: 0.8),
                DSPMSEGPoint(time: 1.0, value: 1.0)
            ],
            isOneShot: false,
            rateHz: 10.0, // 0.1s per cycle
            loopStartIndex: 1,
            loopEndIndex: 2,
            sustainIndex: nil
        )
        let sampleRate: Double = 1000.0 // 100 samples per cycle
        let mseg = DSPMSEG(model: model, sampleRate: sampleRate)
        mseg.trigger()

        // Advance 25 samples (phase ~ 0.25, inside loop)
        for _ in 0..<25 {
            _ = mseg.tick(gate: true)
        }
        #expect(mseg.phase >= 0.2 && mseg.phase <= 0.8)

        // Advance 100 more samples (crossing loop end multiple times)
        for _ in 0..<100 {
            _ = mseg.tick(gate: true)
            #expect(mseg.phase >= 0.19 && mseg.phase <= 0.81, "Phase (\(mseg.phase)) must stay confined within loop bounds [0.2, 0.8]")
        }
    }

    @Test func sustainPointHoldsUntilGateRelease() {
        // Sustain at point 1 (time: 0.4, value: 0.75)
        let model = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.0),
                DSPMSEGPoint(time: 0.4, value: 0.75),
                DSPMSEGPoint(time: 1.0, value: 0.0)
            ],
            rateHz: 5.0, // 0.2s duration
            sustainIndex: 1
        )
        let sampleRate: Double = 1000.0 // 200 samples duration, sustain reached around sample 80
        let mseg = DSPMSEG(model: model, sampleRate: sampleRate)
        mseg.trigger()

        // Tick past sustain point
        for _ in 0..<120 {
            _ = mseg.tick(gate: true)
        }

        #expect(mseg.isSustaining, "MSEG must be sustaining")
        #expect(abs(mseg.phase - 0.4) < 1.0e-3, "Phase must lock to sustain point 0.4")
        #expect(abs(mseg.currentValue - 0.75) < 1.0e-3, "Value must hold sustain value 0.75")

        // Tick 200 more samples with gate=true -> must still sustain
        for _ in 0..<200 {
            let val = mseg.tick(gate: true)
            #expect(abs(val - 0.75) < 1.0e-3)
        }

        // Release gate -> must leave sustain and finish to 1.0
        var released = false
        for _ in 0..<200 {
            _ = mseg.tick(gate: false)
            if !mseg.isSustaining && mseg.phase > 0.41 {
                released = true
            }
        }
        #expect(released, "MSEG must advance past sustain after gate release")
    }

    @Test func phaseAfterRetrigger() {
        let model = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.0),
                DSPMSEGPoint(time: 1.0, value: 1.0)
            ],
            rateHz: 1.0,
            triggerMode: .retrigger,
            sustainIndex: nil
        )
        let sampleRate: Double = 100.0
        let mseg = DSPMSEG(model: model, sampleRate: sampleRate)
        mseg.trigger()

        // Advance 50 samples (phase ~ 0.5)
        for _ in 0..<50 {
            _ = mseg.tick(gate: true)
        }
        #expect(abs(mseg.phase - 0.5) < 0.02)

        // Retrigger
        mseg.trigger()
        #expect(mseg.phase == 0.0, "Phase must reset to 0.0 on retrigger")
        let firstSample = mseg.tick(gate: true)
        #expect(firstSample < 0.05, "Value must restart from start value")

        // Continuous mode test
        var continuousModel = model
        continuousModel.triggerMode = .continuous
        mseg.model = continuousModel

        for _ in 0..<30 {
            _ = mseg.tick(gate: true)
        }
        let currentPhase = mseg.phase
        #expect(currentPhase > 0.2)
        mseg.trigger()
        #expect(mseg.phase == currentPhase, "Phase must NOT reset on trigger when mode is continuous")
    }

    @Test func codableModelWithDecodeIfPresent() throws {
        let minimalJSON = "{}"
        let data = try #require(minimalJSON.data(using: .utf8))
        let decoded = try JSONDecoder().decode(DSPMSEGModel.self, from: data)

        #expect(decoded.points.count >= 2)
        #expect(decoded.rateHz == 1.0)
        #expect(decoded.syncMode == .hz)
        #expect(decoded.triggerMode == .retrigger)
        #expect(decoded.isOneShot == false)

        // Roundtrip encode/decode
        let original = DSPMSEGModel(
            points: [
                DSPMSEGPoint(time: 0.0, value: 0.1, curve: -0.2),
                DSPMSEGPoint(time: 0.5, value: 0.9, curve: 0.4),
                DSPMSEGPoint(time: 1.0, value: 0.0, curve: 0.0)
            ],
            isOneShot: true,
            syncMode: .beats,
            rateHz: 2.5,
            syncBeats: 2.0,
            triggerMode: .continuous,
            loopStartIndex: 0,
            loopEndIndex: 1,
            sustainIndex: 1
        )
        let encoded = try JSONEncoder().encode(original)
        let roundtrip = try JSONDecoder().decode(DSPMSEGModel.self, from: encoded)
        #expect(roundtrip == original)
    }

    @Test func max32PointsClamped() {
        var manyPoints: [DSPMSEGPoint] = []
        for i in 0..<50 {
            manyPoints.append(DSPMSEGPoint(time: Float(i) / 50.0, value: Float(i) / 50.0))
        }
        let model = DSPMSEGModel(points: manyPoints)
        #expect(model.points.count == 32, "Points count must be clamped to max 32 points")
    }
}
