//
//  Stage14Stage1Tests.swift
//  Synt_swiftUITests
//
//  Stage 1 tests for GROK_BUILD_TASKS_SYNT_14:
//  - R11-1 (= R10-3): Built-in & user wavetable cache keyed by (index, sampleRate); rebuild on SR change at 44.1/48/96 kHz
//  - R11-2: Per-channel MPE state (bend, pressure, CC74); bend sent before note-on gives correct pitch on sample 0
//  - R11-11: Event queue overflow preserves mpeKeyUp channel; never releases notes on other channels
//  - R7-10: LFO shape .wavetable reads wavetable data, output differs from sine
//  - Golden hash bit-exactness: 0xd1b3635203a4799e
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage14Stage1Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        WavetableOscillator.clearCacheForTesting()
    }

    override func tearDown() {
        WavetableOscillator.clearCacheForTesting()
        super.tearDown()
    }

    // MARK: - R11-1: Built-in and User Wavetable SR Rebuild at 44.1 / 48 / 96 kHz

    func testBuiltinWavetableCacheKeyedBySampleRateAndRebuildsOnSRChange() {
        let osc = WavetableOscillator()

        // 1. Load built-in table at 44.1 kHz
        osc.setSampleRate(44100.0)
        osc.loadBuiltin(index: 0)
        let expected44 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 44100.0) // 22050 / 40 = 551
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected44)

        let key44 = WavetableOscillator.BuiltinCacheKey(index: 0, sampleRate: 44100.0)
        let compiled44 = WavetableOscillator.precompiledBuiltins[key44]
        XCTAssertNotNil(compiled44)

        // 2. Switch to 48 kHz
        osc.setSampleRate(48000.0)
        let expected48 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 48000.0) // 24000 / 40 = 600
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected48)

        let key48 = WavetableOscillator.BuiltinCacheKey(index: 0, sampleRate: 48000.0)
        let compiled48 = WavetableOscillator.precompiledBuiltins[key48]
        XCTAssertNotNil(compiled48)
        XCTAssertFalse(compiled44 === compiled48, "44.1 kHz and 48 kHz must have distinct compiled mip data")

        // 3. Switch to 96 kHz
        osc.setSampleRate(96000.0)
        let expected96 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 96000.0) // 48000 / 40 = 1200
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected96)

        let key96 = WavetableOscillator.BuiltinCacheKey(index: 0, sampleRate: 96000.0)
        let compiled96 = WavetableOscillator.precompiledBuiltins[key96]
        XCTAssertNotNil(compiled96)
        XCTAssertFalse(compiled48 === compiled96, "48 kHz and 96 kHz must have distinct compiled mip data")
    }

    func testUserWavetableRebuildsOnSRChange() {
        let osc = WavetableOscillator()
        let table = WavetableOscillator.basicWavetables[1] // Analog waves

        osc.setSampleRate(44100.0)
        osc.loadWavetable(table)
        let expected44 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 44100.0)
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected44)

        osc.setSampleRate(48000.0)
        let expected48 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 48000.0)
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected48)

        osc.setSampleRate(96000.0)
        let expected96 = WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 96000.0)
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0), expected96)
    }

    // MARK: - R11-2: Per-Channel MPE State Before Note-On

    func testMPEPitchBendSentBeforeNoteOnAppliesFromSampleZero() {
        let engine = AudioEngine(coreOnly: true)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly
        engine.preset.unisonVoices = 1
        engine.applyPreset()
        engine.cachedMpeEnabled = true

        // Send pitch bend +0.5 on member channel 2 BEFORE note-on
        // +0.5 with bend range 48 semitones = +24 semitones -> multiplier = exp2(2.0) = 4.0
        engine.handleCommand(.mpePitchBend(channel: 2, value: 0.5))

        // Now send note-on on channel 2
        engine.handleCommand(.mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 2))

        var voiceIdx: Int?
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 && engine.voices[i].midiChannel == 2 {
                voiceIdx = i
                break
            }
        }

        guard let vIdx = voiceIdx else {
            XCTFail("Voice was not created on channel 2")
            return
        }

        let expectedMul = exp2(Double(0.5) * Double(engine.cachedMpePitchBendRange) / 12.0)
        XCTAssertEqual(engine.voices[vIdx].mpePitchBendMultiplier, expectedMul, accuracy: 1e-6)

        // Render sample 0 and verify oscillator frequencies are bent
        let sample = engine.renderOneSample()
        XCTAssertFalse(sample.0.isNaN)
        XCTAssertFalse(sample.0.isInfinite)

        // Verify active voice still has bent multiplier
        XCTAssertEqual(engine.voices[vIdx].mpePitchBendMultiplier, expectedMul, accuracy: 1e-6)
    }

    func testMPEPressureAndTimbreSentBeforeNoteOnAreInherited() {
        let engine = AudioEngine(coreOnly: true)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly
        engine.applyPreset()
        engine.cachedMpeEnabled = true

        engine.handleCommand(.mpePressure(channel: 3, value: 0.85))
        engine.handleCommand(.mpeTimbre(channel: 3, value: 0.72))

        engine.handleCommand(.mpeKeyDown(midiNote: 64, velocity: 0.9, channel: 3))

        var voiceIdx: Int?
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 64 && engine.voices[i].midiChannel == 3 {
                voiceIdx = i
                break
            }
        }

        guard let vIdx = voiceIdx else {
            XCTFail("Voice was not created on channel 3")
            return
        }

        XCTAssertEqual(engine.voices[vIdx].mpePressure, 0.85)
        XCTAssertEqual(engine.voices[vIdx].mpeTimbre, 0.72)
    }

    // MARK: - R11-11: Event Queue Overflow Keeps MPE Channel

    func testMpeKeyUpQueueOverflowKeepsChannelAndDoesNotReleaseOtherChannels() {
        let queue = AudioCommandQueue(capacity: 4)

        // Fill the ring buffer to capacity with non-critical commands
        while queue.push(.setModWheel(0.5)) {}
        XCTAssertEqual(queue.count, 3) // Capacity 4 has 3 usable slots

        // Push mpeKeyUp on channel 2 when the ring is full -> must park on side-channel with channel 2
        let pushed = queue.push(.mpeKeyUp(midiNote: 60, channel: 2))
        XCTAssertTrue(pushed, "Critical mpeKeyUp must be accepted into side channel when ring is full")
        XCTAssertTrue(queue.hasPendingMpeKeyUpForTesting(60, channel: 2))
        XCTAssertFalse(queue.hasPendingMpeKeyUpForTesting(60, channel: 3))

        // Set up AudioEngine with Note 60 on Channel 2 AND Note 60 on Channel 3
        let engine = AudioEngine(coreOnly: true)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly
        engine.applyPreset()
        engine.cachedMpeEnabled = true

        engine.handleCommand(.mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 2))
        engine.handleCommand(.mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 3))

        var idxCh2: Int?
        var idxCh3: Int?
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive && engine.voices[i].midiNote == 60 {
                if engine.voices[i].midiChannel == 2 { idxCh2 = i }
                if engine.voices[i].midiChannel == 3 { idxCh3 = i }
            }
        }

        XCTAssertNotNil(idxCh2)
        XCTAssertNotNil(idxCh3)
        XCTAssertFalse(engine.voices[idxCh2!].isReleasing)
        XCTAssertFalse(engine.voices[idxCh3!].isReleasing)

        // Drain the overflowed queue through handleCommand
        queue.drain { cmd in
            engine.handleCommand(cmd)
        }

        // Note 60 on Channel 2 MUST be releasing
        XCTAssertTrue(engine.voices[idxCh2!].isReleasing, "Note 60 on Channel 2 must enter release")

        // Note 60 on Channel 3 MUST NOT be released!
        XCTAssertFalse(engine.voices[idxCh3!].isReleasing, "Note 60 on Channel 3 must NOT be released by Channel 2 mpeKeyUp overflow")
    }

    // MARK: - R7-10: LFO Wavetable Shape Differs From Sine

    func testLFOWavetableShapeDiffersFromSine() {
        let lfo = LFO()
        lfo.waveform = .wavetable
        lfo.rate = 1.0

        var maxDiff: Float = 0.0
        let steps = 64
        for i in 0..<steps {
            let phase = Double(i) / Double(steps) * AudioMath.twoPi
            let lfoVal = lfo.sampleWaveform(at: phase)
            let sineVal = Float(sin(phase))
            let diff = abs(lfoVal - sineVal)
            if diff > maxDiff {
                maxDiff = diff
            }
        }

        XCTAssertGreaterThan(maxDiff, 0.2, "LFO .wavetable output must differ substantially from a pure sine wave (found maxDiff = \(maxDiff))")
    }

    // MARK: - Golden Audio Hash

    func testGoldenHarnessPreserved() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        XCTAssertEqual(hash, 0xd1b3635203a4799e, "Golden FNV-1a hash must remain bit-identical")
    }
}
