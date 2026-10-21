//
//  PhaseV2WavetableImportTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.2: User Wavetable Import (.wav / Serum 2048-sample format).
//

import Foundation
@testable import SynthCore
import AVFoundation
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2WavetableImportTests {

    private func createTestWavFile(frameCount: Int, samplesPerFrame: Int = 2048) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test_wt_\(UUID().uuidString).wav")

        let sampleRate: Double = 44100.0
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false) else {
            throw NSError(domain: "Test", code: 1)
        }

        let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
        let totalSamples = frameCount * samplesPerFrame
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(totalSamples)) else {
            throw NSError(domain: "Test", code: 2)
        }
        buffer.frameLength = AVAudioFrameCount(totalSamples)

        guard let channelData = buffer.floatChannelData else {
            throw NSError(domain: "Test", code: 3)
        }
        let channel = channelData[0]
        for f in 0..<frameCount {
            for i in 0..<samplesPerFrame {
                let phase = Double(i) / Double(samplesPerFrame)
                // Different harmonic content per frame
                let sample = sin(2.0 * .pi * phase * Double(f + 1))
                channel[f * samplesPerFrame + i] = Float(sample) * 0.7
            }
        }

        try audioFile.write(from: buffer)
        return fileURL
    }

    @Test func wavetableParserLoadsMultiFrameAudioFile() throws {
        let fileURL = try createTestWavFile(frameCount: 4, samplesPerFrame: 2048)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let wavetable = try WavetableOscillator.parseAudioFile(url: fileURL)
        #expect(wavetable.frameCount == 4)
        #expect(wavetable.samplesPerFrame == 2048)
        #expect(!wavetable.frames.isEmpty)

        // Verify peak normalization (~1.0)
        for frame in wavetable.frames {
            let maxPeak = frame.map { abs($0) }.max() ?? 0
            #expect(abs(maxPeak - 1.0) < 0.01)
        }
    }

    @Test func wavetableParserRejectsInsufficientSamples() throws {
        let fileURL = try createTestWavFile(frameCount: 1, samplesPerFrame: 1024)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        #expect(throws: WavetableError.self) {
            _ = try WavetableOscillator.parseAudioFile(url: fileURL, samplesPerFrame: 2048)
        }
    }

    @Test func oscillatorLoadsUserWavetableAndRendersAudio() throws {
        let fileURL = try createTestWavFile(frameCount: 3, samplesPerFrame: 2048)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let osc = WavetableOscillator()
        try osc.loadFromAudioFile(url: fileURL)

        #expect(WavetableOscillator.userWavetable != nil)
        #expect(WavetableOscillator.userWavetable?.frameCount == 3)

        // Advance morph and generate sample
        osc.targetFramePosition = 0.5
        for _ in 0..<500 {
            osc.advanceMorph()
        }

        let phaseInc = 440.0 * 2.0 * .pi / 44100.0
        var phase: Double = 0.0
        var generatedNonZero = false

        for _ in 0..<100 {
            let s = osc.generateSample(phase: phase, phaseIncrement: phaseInc, sampleRate: 44100.0)
            #expect(s.isFinite)
            #expect(!s.isNaN)
            #expect(abs(s) <= 1.2)
            if abs(s) > 0.01 {
                generatedNonZero = true
            }
            phase += phaseInc
        }

        #expect(generatedNonZero)
    }

    @Test func audioEngineLoadsUserWavetableAndAppliesPreset() throws {
        let fileURL = try createTestWavFile(frameCount: 4, samplesPerFrame: 2048)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let engine = AudioEngine()
        engine.setSampleRateForTesting(44100.0)

        try engine.loadUserWavetable(url: fileURL, forOscillator: 1)
        #expect(engine.preset.osc1Waveform == .wavetable)
        #expect(engine.preset.osc1WavetableIndex == 5)

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        let result = engine.renderFramesForTesting(512)
        #expect(result.nanCount == 0)
        #expect(result.peak > 0.01)
    }

    @Test func fallbackWhenNoUserWavetableLoaded() {
        WavetableOscillator.userWavetable = nil
        let osc = WavetableOscillator()
        osc.loadBuiltin(index: 5)
        // Should fall back to basic table 0 safely without crashing
        let s = osc.generateSample(phase: 0.5, phaseIncrement: 0.1, sampleRate: 44100.0)
        #expect(s.isFinite)
    }
}
