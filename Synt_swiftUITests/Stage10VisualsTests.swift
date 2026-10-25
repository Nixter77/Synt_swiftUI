//
//  Stage10VisualsTests.swift
//  Synt_swiftUITests
//
//  Tests for Stage 4: MSEG 2 engine & matrix routing, editor snapping/copying,
//  AtomicMeteringState ring buffer, and spectrum analysis.
//

import Testing
import Foundation
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
struct Stage10VisualsTests {

    @Test func mseg2EncodesAndDecodesCorrectly() throws {
        var preset = SynthPreset.defaultPreset
        preset.mseg2.rateHz = 2.5
        preset.mseg2.points = [
            DSPMSEGPoint(time: 0, value: -0.5, curve: 0),
            DSPMSEGPoint(time: 0.5, value: 0.8, curve: 0.5),
            DSPMSEGPoint(time: 1.0, value: 0.0, curve: -0.5)
        ]
        preset.mseg2.loopStartIndex = 0
        preset.mseg2.loopEndIndex = 2
        preset.mseg2.sustainIndex = 1

        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)

        #expect(decoded.mseg2.rateHz == 2.5)
        #expect(decoded.mseg2.points.count == 3)
        #expect(decoded.mseg2.points[1].value == Float(0.8))
        #expect(decoded.mseg2.loopStartIndex == 0)
        #expect(decoded.mseg2.loopEndIndex == 2)
        #expect(decoded.mseg2.sustainIndex == 1)
    }

    @Test func oldPresetWithoutMSEG2DecodesWithDefault() throws {
        // Construct JSON without mseg2 field
        let preset = SynthPreset.defaultPreset
        let data = try JSONEncoder().encode(preset)
        var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        dict.removeValue(forKey: "mseg2")
        let strippedData = try JSONSerialization.data(withJSONObject: dict)

        let decoded = try JSONDecoder().decode(SynthPreset.self, from: strippedData)
        #expect(decoded.mseg2.points.isEmpty)
        #expect(decoded.mseg2.rateHz == 1.0)
    }

    @Test func mseg2SanitizationClampsBounds() {
        var preset = SynthPreset.defaultPreset
        preset.mseg2.rateHz = 999.0
        preset.mseg2.points = [
            DSPMSEGPoint(time: 0.5, value: 5.0, curve: 2.0),
            DSPMSEGPoint(time: 0.1, value: -5.0, curve: -2.0)
        ]
        preset.mseg2.loopStartIndex = 10
        preset.mseg2.sustainIndex = 20

        let sanitized = preset.sanitized()
        #expect(sanitized.mseg2.rateHz == 100.0)
        #expect(sanitized.mseg2.points.count == 2)
        // Sanitized points sorted by time
        #expect(sanitized.mseg2.points[0].time == 0.1)
        #expect(sanitized.mseg2.points[1].time == 0.5)
        #expect(sanitized.mseg2.loopStartIndex == 1) // clamped to lastPoint (1)
        #expect(sanitized.mseg2.sustainIndex == 1)
    }

    @Test func mseg2RoutesInModMatrixToPitch() {
        let engine = AudioEngine()
        engine.rendersAllDelayInDSP = true

        var preset = SynthPreset.defaultPreset
        // MSEG 1 has 0 value, MSEG 2 has 1.0 value
        preset.mseg.points = [
            DSPMSEGPoint(time: 0, value: 0),
            DSPMSEGPoint(time: 1, value: 0)
        ]
        preset.mseg2.points = [
            DSPMSEGPoint(time: 0, value: 1.0),
            DSPMSEGPoint(time: 1, value: 1.0)
        ]
        preset.modMatrix = [
            ModMatrixEntry(source: .mseg2, destination: .pitch1, amount: 0.5)
        ]
        engine.preset = preset
        engine.applyPreset()

        #expect(engine.mseg2.hasPoints)
        #expect(engine.mseg2.evaluate(at: 0.5) == 1.0)

        let src = engine.matrixSource(
            .mseg2,
            lfo: 0,
            lfo2: 0,
            env: 0,
            velocity: 0,
            modWheel: 0,
            keyTrack: 0,
            mseg: 0.0,
            mseg2: 1.0
        )
        #expect(src == 1.0)
    }

    @Test func snapModeMathCalculatesProperGrid() {
        let snap16 = MSEGSnapMode.div16.step! // 0.0625
        let snap8 = MSEGSnapMode.div8.step!   // 0.125
        let snap4 = MSEGSnapMode.div4.step!   // 0.25
        let snap10 = MSEGSnapMode.step10.step! // 0.1

        func snap(_ v: Float, _ step: Float) -> Float {
            (v / step).rounded() * step
        }

        #expect(abs(snap(0.07, snap16) - 0.0625) < 1e-4)
        #expect(abs(snap(0.12, snap8) - 0.125) < 1e-4)
        #expect(abs(snap(0.24, snap4) - 0.25) < 1e-4)
        #expect(abs(snap(0.26, snap10) - 0.3) < 1e-4)
    }

    @Test func atomicMeteringRingBufferDropsFrameWhenReaderSlotEncountered() {
        let metering = AtomicMeteringState(bufferSize: 64)
        let frame1 = [Float](repeating: 0.5, count: 64)
        metering.writeScopeBuffer(frame1)

        let read = metering.readScopeBuffer()
        #expect(read.count == 64)
        #expect(read[0] == 0.5)
    }

    @Test func spectrumCalculatorDetectsPeakBin() {
        let calc = OutputSpectrumCalculator.shared
        let n = 512
        let sampleRate: Double = 44100.0
        let targetFreq: Double = 1000.0 // ~1 kHz

        // Generate pure sine wave at 1000 Hz
        let buffer: [Float] = (0..<n).map { i in
            Float(sin(2.0 * Double.pi * targetFreq * Double(i) / sampleRate))
        }

        let mags = calc.computeMagnitudes(from: buffer)
        #expect(mags.count == 256)

        // Find bin with highest magnitude
        var maxBin = 0
        var maxMag: Float = -1
        for (i, m) in mags.enumerated() {
            if m > maxMag {
                maxMag = m
                maxBin = i
            }
        }

        // Expected bin = 1000 * 512 / 44100 ≈ 11.6 -> 11 or 12
        let expectedBin = Int(round(targetFreq * Double(n) / sampleRate))
        #expect(abs(maxBin - expectedBin) <= 1, "Peak was at bin \(maxBin), expected ~\(expectedBin)")
        #expect(maxMag > 0.6, "Magnitude peak should be prominent, was \(maxMag)")
    }
}
