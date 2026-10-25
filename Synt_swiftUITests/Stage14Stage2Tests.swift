//
//  Stage14Stage2Tests.swift
//  Synt_swiftUITests
//
//  Stage 2 tests for GROK_BUILD_TASKS_SYNT_14:
//  - R11-5 (Security): check decompressed size limit BEFORE inflating zlib table data in presets (zip-bomb prevention).
//  - R11-3: One unified content hash for a table (no double compilation of raw vs compressed).
//  - R11-4: Async table load targets the requesting oscillator; user table storage per AU instance, not static/shared.
//  - R9-2: Smooth 10–20 ms tail fade when send drops to zero and raises back; no click, discontinuity below threshold.
//  - Golden hash bit-exactness: 0xd1b3635203a4799e
//

import XCTest
import Compression
@testable import SynthCore

final class Stage14Stage2Tests: XCTestCase {

    override func setUp() {
        super.setUp()
        WavetableOscillator.clearCacheForTesting()
    }

    override func tearDown() {
        WavetableOscillator.clearCacheForTesting()
        super.tearDown()
    }

    // MARK: - R11-5 (Security): Decompressed Size Limit Checked Before Inflating (Zip-Bomb Prevention)

    func testOversizedPayloadWithDeclaredSizeRejectsBeforeInflating() {
        // Construct crafted payload with magic "WTZ1" and declared size = 50 MB (> maxSerializedBytes 512 KB)
        var data = Data()
        var magic: UInt32 = Wavetable.compressedMagic
        var hugeSize: Int32 = 50 * 1024 * 1024 // 50 MB
        var dummyHash: UInt64 = 0x1234567890abcdef
        data.append(Data(bytes: &magic, count: 4))
        data.append(Data(bytes: &hugeSize, count: 4))
        data.append(Data(bytes: &dummyHash, count: 8))
        // Append 100 bytes of dummy zlib data
        data.append(Data(repeating: 0x78, count: 100))

        // Must reject without big allocation and throw decompressedSizeExceedsLimit
        XCTAssertNil(Wavetable.deserialize(from: data))
        XCTAssertThrowsError(try Wavetable.deserializeOrThrow(from: data)) { error in
            guard case WavetableError.decompressedSizeExceedsLimit(let found, let max) = error else {
                XCTFail("Expected decompressedSizeExceedsLimit, got \(error)")
                return
            }
            XCTAssertEqual(found, 50 * 1024 * 1024)
            XCTAssertEqual(max, Wavetable.maxSerializedBytes)
        }
    }

    func testCraftedZipBombWithoutHeaderRejectsSafelyWithoutBigAllocation() {
        // Create an actual zlib zip-bomb: 10 MB of repeated zeros compressed into ~10 KB
        let hugeUncompressed = Data(repeating: 0, count: 10 * 1024 * 1024)
        guard let compressedBomb = try? (hugeUncompressed as NSData).compressed(using: .zlib) as Data else {
            XCTFail("Failed to compress test zip bomb")
            return
        }
        XCTAssertLessThan(compressedBomb.count, 20 * 1024, "Zip bomb should be small in compressed form")

        // Deserializing raw zip bomb without header must detect overflow (> maxSerializedBytes) safely
        XCTAssertNil(Wavetable.deserialize(from: compressedBomb))
        XCTAssertThrowsError(try Wavetable.deserializeOrThrow(from: compressedBomb)) { error in
            guard case WavetableError.decompressedSizeExceedsLimit(let found, let max) = error else {
                XCTFail("Expected decompressedSizeExceedsLimit, got \(error)")
                return
            }
            XCTAssertGreaterThan(found, Wavetable.maxSerializedBytes)
            XCTAssertEqual(max, Wavetable.maxSerializedBytes)
        }
    }

    func testOversizedUncompressedRawDataRejectsBeforeParsing() {
        // Raw uncompressed data exceeding maxSerializedBytes
        let oversizedRaw = Data(repeating: 0x42, count: Wavetable.maxSerializedBytes + 100)
        XCTAssertNil(Wavetable.deserialize(from: oversizedRaw))
        XCTAssertThrowsError(try Wavetable.deserializeOrThrow(from: oversizedRaw))
    }

    // MARK: - R11-3: One Content Hash for Table (No Double Compilation)

    func testOneContentHashForRawAndCompressedTable() {
        let table = WavetableOscillator.basicWavetables[0]
        let rawData = table.serializedData()
        let compressedData = table.compressedSerializedData()

        let rawHash = table.contentHash
        let extractedFromCompressed = Wavetable.canonicalContentHash(for: compressedData)
        let extractedFromRaw = Wavetable.canonicalContentHash(for: rawData)

        XCTAssertEqual(extractedFromCompressed, rawHash, "Compressed table must yield exact canonical contentHash")
        XCTAssertEqual(extractedFromRaw, rawHash, "Raw table data must yield exact canonical contentHash")

        // Fast O(1) header extraction without full decompression
        var magic: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &magic) { compressedData.copyBytes(to: $0, from: 0..<4) }
        XCTAssertEqual(magic, Wavetable.compressedMagic)

        // Verify no double compilation: compiling compressed data caches under the same key as raw
        let key = WavetableCacheKey(contentHash: rawHash, sampleRate: 44100.0)
        let compiled = WavetableOscillator.compile(wavetable: table, sampleRate: 44100.0)
        WavetableOscillator.setCachedCompiled(compiled, for: key)

        // Calling compileUserWavetableAsyncIfNeeded with compressed data must immediately find the cached compiled data
        let hit = WavetableOscillator.compileUserWavetableAsyncIfNeeded(
            data: compressedData,
            name: "Test",
            sampleRate: 44100.0
        )
        XCTAssertTrue(hit === compiled, "Async compiler must hit cache for compressed data without recompiling")
    }

    // MARK: - R11-4: Async Table Load Targets Requesting Oscillator & Per-Instance Storage

    func testPerInstanceUserWavetableStorageBetweenEngines() throws {
        let engineA = AudioEngine(coreOnly: true)
        let engineB = AudioEngine(coreOnly: true)

        let tableA = WavetableOscillator.basicWavetables[1] // Analog
        let tableB = WavetableOscillator.basicWavetables[2] // Digital

        try engineA.loadUserWavetable(samples: tableA.frames[0], name: "TableA", forOscillator: 1)
        try engineB.loadUserWavetable(samples: tableB.frames[0], name: "TableB", forOscillator: 1)

        XCTAssertEqual(engineA.userWavetable?.name, "TableA")
        XCTAssertEqual(engineB.userWavetable?.name, "TableB")
        XCTAssertNotEqual(engineA.userWavetable?.name, engineB.userWavetable?.name, "AU instances must not share user wavetables")

        XCTAssertEqual(engineA.wavetableEngine1.instanceUserWavetable?.name, "TableA")
        XCTAssertEqual(engineB.wavetableEngine1.instanceUserWavetable?.name, "TableB")
    }

    func testLoadUserWavetableTargetsOnlyRequestingOscillator() throws {
        let engine = AudioEngine(coreOnly: true)
        engine.preset.osc1Waveform = .wavetable
        engine.preset.osc1WavetableIndex = 0 // Basic shapes
        engine.preset.osc2Waveform = .sawtooth
        engine.preset.osc2WavetableIndex = 1
        engine.applyPreset()

        let table = WavetableOscillator.basicWavetables[3] // PWM
        try engine.loadUserWavetable(samples: table.frames[0], name: "CustomPWM", forOscillator: 2)

        // Osc 2 should be set to wavetable 5 (user)
        XCTAssertEqual(engine.preset.osc2Waveform, .wavetable)
        XCTAssertEqual(engine.preset.osc2WavetableIndex, 5)
        XCTAssertEqual(engine.loadedWTIndex2, 5)

        // Osc 1 must NOT be clobbered
        XCTAssertEqual(engine.preset.osc1WavetableIndex, 0)
        XCTAssertNotEqual(engine.loadedWTIndex1, 5)
    }

    // MARK: - R9-2: Smooth 10–20 ms Tail Fade on Send Drops (No Click / Discontinuity)

    func testSendTailFadeSmoothnessAndDuration() {
        let engine = AudioEngine(coreOnly: true)
        let sampleRate = 44100.0
        engine.prepare(sampleRate: sampleRate, maxFrames: 256)

        // Activate send A with signal feeding reverb
        engine.cachedSendA = 0.8
        engine.sendFadeA = 0.8

        // Render 200 samples to establish reverb tail
        var maxDiffDuringDrop: Float = 0.0
        var prevSample: Float = 0.0
        for _ in 0..<200 {
            let s = engine.renderOneSample().0
            maxDiffDuringDrop = max(maxDiffDuringDrop, abs(s - prevSample))
            prevSample = s
        }

        // Drop send A to zero
        engine.cachedSendA = 0.0

        // Track how many samples sendFadeA takes to reach 0
        var fadeSampleCount = 0
        while engine.sendFadeA > 0 && fadeSampleCount < 2000 {
            let s = engine.renderOneSample().0
            let diff = abs(s - prevSample)
            maxDiffDuringDrop = max(maxDiffDuringDrop, diff)
            prevSample = s
            fadeSampleCount += 1
        }

        XCTAssertEqual(engine.sendFadeA, 0.0)

        // Duration should be between 10 ms (441 samples) and 20 ms (882 samples)
        // With starting fade 0.8, duration = 0.8 * 0.015 * 44100 = 529 samples
        let durationMs = (Double(fadeSampleCount) / sampleRate) * 1000.0
        XCTAssertGreaterThanOrEqual(durationMs, 10.0, "Fade out duration should be at least ~10 ms (was \(durationMs) ms)")
        XCTAssertLessThanOrEqual(durationMs, 20.0, "Fade out duration should be at most ~20 ms (was \(durationMs) ms)")

        // Discontinuity check: no sudden jump > 0.02
        XCTAssertLessThan(maxDiffDuringDrop, 0.02, "Sample-to-sample difference should never exceed click threshold")

        // Raise send back up and verify smooth ramp up without click
        engine.cachedSendA = 0.8
        for _ in 0..<500 {
            let s = engine.renderOneSample().0
            let diff = abs(s - prevSample)
            maxDiffDuringDrop = max(maxDiffDuringDrop, diff)
            prevSample = s
        }
        XCTAssertLessThan(maxDiffDuringDrop, 0.02, "Raising send back up must not cause a click")
        XCTAssertGreaterThan(engine.sendFadeA, 0.7)
    }

    // MARK: - Golden Audio Harness Bit-Exactness

    @MainActor func testGoldenHarnessPreserved() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        XCTAssertEqual(hash, 0xd1b3635203a4799e, "Default sound must remain bit-identical to golden hash")
    }
}
