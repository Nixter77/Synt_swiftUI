//
//  Stage12WavetableImportTests.swift
//  Synt_swiftUITests
//
//  Tests for Stage 4: Sample -> Wavetable import, normalization, preset embedding, and lock-free handoff.
//

import XCTest
import AVFoundation
@testable import SynthCore

final class Stage12WavetableImportTests: XCTestCase {

    func testImportAudioBufferSlicingAndPeakNormalization() throws {
        // Create synthetic sample buffer of 64 frames * 2048 samples
        let frameCount = 64
        let samplesPerFrame = 2048
        var rawSamples = [Float](repeating: 0, count: frameCount * samplesPerFrame)

        for f in 0..<frameCount {
            let mult: Float = Float(f + 1) / Float(frameCount) * 0.4 // Max amplitude varies 0.006...0.4
            for s in 0..<samplesPerFrame {
                let phase = Float(s) / Float(samplesPerFrame)
                rawSamples[f * samplesPerFrame + s] = sin(phase * 2.0 * .pi * Float(f + 1)) * mult
            }
        }

        let wavetable = try WavetableOscillator.importAudioBuffer(
            samples: rawSamples,
            samplesPerFrame: samplesPerFrame,
            maxFrames: 64,
            name: "TestImport"
        )

        XCTAssertEqual(wavetable.frameCount, 64)
        XCTAssertEqual(wavetable.samplesPerFrame, 2048)
        XCTAssertEqual(wavetable.name, "TestImport")

        // Every frame must be peak normalized to 1.0 (within float tolerance)
        for f in 0..<wavetable.frameCount {
            let maxPeak = wavetable.frames[f].map { abs($0) }.max() ?? 0
            XCTAssertEqual(maxPeak, 1.0, accuracy: 0.001, "Frame \(f) was not peak normalized to 1.0")
        }
    }

    func testImportAudioBufferRejectsInsufficientSamples() {
        let shortSamples = [Float](repeating: 0.5, count: 1024)
        XCTAssertThrowsError(try WavetableOscillator.importAudioBuffer(samples: shortSamples, samplesPerFrame: 2048)) { error in
            guard case WavetableError.insufficientSamples = error else {
                XCTFail("Expected insufficientSamples error, got: \(error)")
                return
            }
        }
    }

    func testWavetableSerializationAndPresetEmbeddingRoundtrip() throws {
        // Generate small test wavetable
        var frames: [[Float]] = []
        for f in 0..<8 {
            var frame = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 {
                frame[i] = Float(sin(Double(i) * Double(f + 1) * 0.01))
            }
            frames.append(WavetableOscillator.normalizePeak(frame))
        }

        let originalTable = Wavetable(name: "EmbeddedWT", frames: frames)
        let serialized = originalTable.serializedData()

        // Deserialization check
        guard let restoredTable = Wavetable.deserialize(from: serialized, name: "EmbeddedWT") else {
            XCTFail("Failed to deserialize wavetable from data")
            return
        }

        XCTAssertEqual(restoredTable.frameCount, 8)
        XCTAssertEqual(restoredTable.samplesPerFrame, 2048)
        for f in 0..<8 {
            for i in 0..<2048 {
                XCTAssertEqual(restoredTable.frames[f][i], originalTable.frames[f][i], accuracy: 1e-6)
            }
        }

        // Test embedding in SynthPreset JSON serialization
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .wavetable
        preset.osc1WavetableIndex = 5
        preset.userWavetableName = "EmbeddedWT"
        preset.userWavetableData = serialized

        let encoder = JSONEncoder()
        let data = try encoder.encode(preset)

        let decoder = JSONDecoder()
        let decodedPreset = try decoder.decode(SynthPreset.self, from: data)

        XCTAssertEqual(decodedPreset.userWavetableName, "EmbeddedWT")
        XCTAssertEqual(decodedPreset.userWavetableData, serialized)
        XCTAssertEqual(decodedPreset.osc1WavetableIndex, 5)
    }

    func testLockFreeHandoffAndNoImportInRender() throws {
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44100, maxFrames: 512)

        // Synthesize 16 frames of audio outside render
        let frameCount = 16
        var samples = [Float](repeating: 0, count: frameCount * 2048)
        for i in 0..<samples.count {
            samples[i] = sin(Float(i) * 0.05) * 0.8
        }

        // Import on main thread
        try engine.loadUserWavetable(samples: samples, name: "TestStream", forOscillator: 1)
        XCTAssertEqual(engine.preset.osc1Waveform, .wavetable)
        XCTAssertEqual(engine.preset.osc1WavetableIndex, 5)

        // Trigger note and render
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        let result = engine.renderFramesForTesting(512)
        XCTAssertEqual(result.nanCount, 0, "No NaNs during wavetable playback")
        XCTAssertGreaterThan(result.peak, 0.01, "Rendered output should be non-zero sound")
    }
}
