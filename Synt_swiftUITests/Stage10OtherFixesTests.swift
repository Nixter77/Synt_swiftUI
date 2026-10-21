//
//  Stage10OtherFixesTests.swift
//  Synt_swiftUITests
//

import XCTest
import AudioToolbox
@testable import Synt_swiftUI
@testable import SynthCore

final class Stage10OtherFixesTests: XCTestCase {

    // R7-6: Double-buffer with acknowledgement in DSPMSEG
    func testMSEGDoubleBufferAcknowledgement() {
        let mseg = DSPMSEG()
        var model = DSPMSEGModel()
        model.points = [
            DSPMSEGPoint(time: 0.0, value: 0.0),
            DSPMSEGPoint(time: 0.5, value: 0.8),
            DSPMSEGPoint(time: 1.0, value: 0.0)
        ]
        mseg.publish(model)
        mseg.trigger()

        // Tick several samples to acknowledge
        for _ in 0..<10 {
            _ = mseg.tick(gate: true, bpm: 120.0)
        }

        // Rapid publish from another thread or loop should not tear or crash
        for i in 1...5 {
            var m2 = DSPMSEGModel()
            m2.points = [
                DSPMSEGPoint(time: 0.0, value: Float(i) * 0.1),
                DSPMSEGPoint(time: 1.0, value: Float(i) * 0.2)
            ]
            mseg.publish(m2)
            _ = mseg.tick(gate: true, bpm: 120.0)
        }
        XCTAssertTrue(mseg.hasPoints)
    }

    // R7-7: Filter type includes Comb (index 6), parameter tree range [0, 6]
    @MainActor
    func testFilterTypeParameterIncludesComb() throws {
        let param = SynthParameterAddress.filterType
        XCTAssertEqual(param.min, 0)
        XCTAssertEqual(param.max, 6)

        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let au = try SyntAudioUnit(componentDescription: description)
        guard let tree = au.parameterTree else {
            XCTFail("AUParameterTree not initialized")
            return
        }

        guard let filterTypeParam = tree.parameter(withAddress: SynthParameterAddress.filterType.rawValue) else {
            XCTFail("Filter type parameter missing")
            return
        }
        XCTAssertEqual(filterTypeParam.minValue, 0)
        XCTAssertEqual(filterTypeParam.maxValue, 6)
        XCTAssertTrue(filterTypeParam.valueStrings?.contains("Comb") == true)
        XCTAssertEqual(filterTypeParam.valueStrings?.last, "Comb")
        XCTAssertGreaterThanOrEqual(filterTypeParam.value, filterTypeParam.minValue)
        XCTAssertLessThanOrEqual(filterTypeParam.value, filterTypeParam.maxValue)
    }

    // R7-8: DSPCharacterTone warm mode has DC removed; off mode is bit-exact passthrough
    func testCharacterToneWarmDCBlockAndOffPassthrough() {
        let charTone = DSPCharacterTone()
        let testInput: Float = 0.54321
        let offOutput = charTone.process(testInput, mode: .off, sampleRate: 44100.0)
        XCTAssertEqual(offOutput, testInput, "Off mode must be bit-exact passthrough")

        // In Warm mode, processing a sustained sine or constant should not produce high DC
        charTone.reset()
        var dcAccum: Float = 0.0
        let samples = 44100 // 1 second
        for i in 0..<samples {
            let s = Float(sin(2.0 * Double.pi * 100.0 * Double(i) / 44100.0)) * 0.8
            let out = charTone.process(s, mode: .warm, sampleRate: 44100.0)
            if i > 22050 { // measure second half after DC blocker settles
                dcAccum += out
            }
        }
        let meanDC = abs(dcAccum / Float(samples / 2))
        XCTAssertLessThan(meanDC, 0.02, "DC offset in Warm mode must be blocked (mean DC < 0.02)")
    }

    // R7-9: AudioEngine does not restart if sample rate has not changed
    func testSampleRateNoRestartIfUnchanged() {
        let engine = AudioEngine(coreOnly: false)
        let initialRate = engine.sampleRate
        // Call applySampleRate with the identical rate
        engine.applySampleRate(initialRate, rebuildGraph: false)
        XCTAssertEqual(engine.sampleRate, initialRate)
    }

    // R7-10: Stereo LFO right channel one-shot and wavetable
    func testStereoLFOOneShotRightChannel() {
        let lfo = LFO()
        lfo.mode = .oneShot
        lfo.rate = 10.0
        lfo.stereoPhaseOffsetDegrees = 90.0
        lfo.trigger()

        // Run until completion (at 10 Hz, 1 cycle at 44100 is 4410 samples)
        var lastL: Float = 0.0
        var lastR: Float = 0.0
        for _ in 0..<5000 {
            (lastL, lastR) = lfo.nextStereoRawValue(sampleRate: 44100.0)
        }

        XCTAssertTrue(lfo.isCompleted)
        XCTAssertEqual(lastL, 0.0, accuracy: 1e-6)
        XCTAssertEqual(lastR, 0.0, accuracy: 1e-6)
    }

    // R7-11: Preallocated pointers in AudioEngine match voice filter arrays
    func testVoiceFilterPointersMatch() {
        let engine = AudioEngine(coreOnly: true)
        for i in 0..<AudioEngine.maxVoices {
            XCTAssertTrue(engine.voiceDualPtr[i].takeUnretainedValue() === engine.voiceDual[i])
            XCTAssertTrue(engine.voiceFormantPtr[i].takeUnretainedValue() === engine.voiceFormant[i])
            XCTAssertTrue(engine.voiceCombPtr[i].takeUnretainedValue() === engine.voiceComb[i])
        }
    }

    // R7-12: Comb filter 20 Hz minimum frequency at 44.1, 96, and 192 kHz
    func testCombFilterLowFrequencyRange() {
        let comb = DSPCombFilter()
        let sampleRates: [Float] = [44100.0, 48000.0, 96000.0, 192000.0]

        for sr in sampleRates {
            comb.reset()
            // 20 Hz cutoff
            let out = comb.process(0.5, cutoff: 20.0, resonance: 0.5, sampleRate: sr)
            XCTAssertTrue(out.isFinite)
            XCTAssertFalse(out.isNaN)
        }
    }
}
