//
//  WavetableOscillator.swift
//  Synt_swiftUI
//
//  Band-limited wavetable oscillator with mip-mapping for alias-free playback.
//  Stage 3:
//  - FFT band-limit filters the *source* frame (does not replace it with a saw).
//  - Output is peak-normalized raw samples; volume is applied once by Oscillator.
//  - Smooth morph: one-pole frame position + crossfade between mip octaves.
//

import Foundation
import Accelerate
import AVFoundation
import Synchronization
import os
import Compression

/// Errors during audio-file wavetable parsing
public enum WavetableError: LocalizedError, Equatable {
    case insufficientSamples(found: Int, required: Int)
    case bufferCreationFailed
    case unsupportedAudioFormat
    case fileTooLarge
    case decompressedSizeExceedsLimit(found: Int, max: Int)

    public var errorDescription: String? {
        switch self {
        case .insufficientSamples(let found, let required):
            return "Wavetable requires at least \(required) samples, but file has \(found)."
        case .bufferCreationFailed:
            return "Failed to allocate audio buffer."
        case .unsupportedAudioFormat:
            return "Unsupported audio format. Float32 or PCM WAV is required."
        case .fileTooLarge:
            return "Audio file exceeds maximum allowed length (> 2^32 frames)."
        case .decompressedSizeExceedsLimit(let found, let max):
            return "Decompressed wavetable size (\(found) bytes) exceeds safe limit (\(max) bytes)."
        }
    }
}


/// A single wavetable containing multiple frames
public struct Wavetable {
    public let name: String
    public let frames: [[Float]]  // [frameIndex][sampleIndex]
    public let frameCount: Int
    public let samplesPerFrame: Int

    /// Maximum frames stored in a wavetable preset.
    public static let maxFramesLimit: Int = 64
    /// Maximum samples per single wavetable frame.
    public static let maxSamplesPerFrameLimit: Int = 2048
    /// Maximum uncompressed serialized size in bytes (64 frames * 2048 samples * 4 bytes + 8 bytes header = 524,296 bytes, ~512 KB).
    public static let maxSerializedBytes: Int = 512 * 1024 + 8

    public init(name: String, frames: [[Float]]) {
        self.name = name
        self.frames = frames
        self.frameCount = frames.count
        self.samplesPerFrame = frames.first?.count ?? 2048
    }

    public func serializedData() -> Data {
        var data = Data()
        var fCount = Int32(frameCount)
        var sCount = Int32(samplesPerFrame)
        data.append(Data(bytes: &fCount, count: MemoryLayout<Int32>.size))
        data.append(Data(bytes: &sCount, count: MemoryLayout<Int32>.size))
        for frame in frames {
            frame.withUnsafeBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    data.append(Data(bytes: base, count: ptr.count * MemoryLayout<Float>.size))
                }
            }
        }
        return data
    }

    /// 4-byte header magic: "WTZ1"
    public static let compressedMagic: UInt32 = 0x57545A31

    /// Canonical content hash for wavetable cache lookups.
    public var contentHash: UInt64 {
        return serializedData().fnv1aHash()
    }

    /// Compresses serialized wavetable frames using zlib deflate with safety header for compact preset storage.
    /// Format: [magic 4B] + [uncompressedSize 4B] + [canonicalContentHash 8B] + [zlibCompressedPayload]
    public func compressedSerializedData() -> Data {
        let raw = serializedData()
        let hash = raw.fnv1aHash()
        guard let compressedPayload = try? (raw as NSData).compressed(using: .zlib) as Data else {
            return raw
        }
        var data = Data()
        var magic = Self.compressedMagic
        var uncompressedSize = Int32(raw.count)
        var canonicalHash = hash
        data.append(Data(bytes: &magic, count: 4))
        data.append(Data(bytes: &uncompressedSize, count: 4))
        data.append(Data(bytes: &canonicalHash, count: 8))
        data.append(compressedPayload)
        return data
    }

    /// Returns canonical content hash for raw or compressed wavetable data.
    /// R12-9: memo of stored-bytes fingerprint -> verified canonical hash.
    /// The WTZ1 header hash is never trusted; each distinct blob is decoded
    /// once, then later lookups only fingerprint the stored bytes.
    private static var canonicalHashMemo: [UInt64: UInt64] = [:]
    private static let canonicalHashMemoLock: os_unfair_lock_t = {
        let l = os_unfair_lock_t.allocate(capacity: 1)
        l.initialize(to: os_unfair_lock())
        return l
    }()
    public static let canonicalHashDecodeCountForTesting = Atomic<Int>(0)

    static func storedBytesFingerprint(_ data: Data) -> UInt64 {
        var h: UInt64 = 0xcbf29ce484222325 ^ UInt64(data.count)
        data.withUnsafeBytes { raw in
            for b in raw.bindMemory(to: UInt8.self) {
                h = (h ^ UInt64(b)) &* 0x100000001b3
            }
        }
        return h
    }

    public static func canonicalContentHash(for data: Data) -> UInt64? {
        let fp = storedBytesFingerprint(data)
        os_unfair_lock_lock(canonicalHashMemoLock)
        let memo = canonicalHashMemo[fp]
        os_unfair_lock_unlock(canonicalHashMemoLock)
        if let memo { return memo }
        canonicalHashDecodeCountForTesting.wrappingAdd(1, ordering: .relaxed)
        guard let table = deserialize(from: data) else { return nil }
        let h = table.contentHash
        os_unfair_lock_lock(canonicalHashMemoLock)
        if canonicalHashMemo.count > 256 { canonicalHashMemo.removeAll() }
        canonicalHashMemo[fp] = h
        os_unfair_lock_unlock(canonicalHashMemoLock)
        return h
    }

    public static func deserializeOrThrow(from data: Data, name: String = "User") throws -> Wavetable {
        guard !data.isEmpty else { throw WavetableError.insufficientSamples(found: 0, required: 8) }

        // 1. Check for "WTZ1" magic header
        if data.count >= 16 {
            var magic: UInt32 = 0
            _ = withUnsafeMutableBytes(of: &magic) { data.copyBytes(to: $0, from: 0..<4) }
            if magic == compressedMagic {
                var declaredSize: Int32 = 0
                _ = withUnsafeMutableBytes(of: &declaredSize) { data.copyBytes(to: $0, from: 4..<8) }
                // R11-5: Check decompressed size limit BEFORE inflating!
                guard declaredSize >= 8 && declaredSize <= Int32(maxSerializedBytes) else {
                    throw WavetableError.decompressedSizeExceedsLimit(found: Int(declaredSize), max: maxSerializedBytes)
                }
                let payload = data.subdata(in: 16..<data.count)
                var dest = [UInt8](repeating: 0, count: Int(declaredSize) + 1)
                let decoded = payload.withUnsafeBytes { srcPtr in
                    dest.withUnsafeMutableBytes { dstPtr in
                        compression_decode_buffer(
                            dstPtr.bindMemory(to: UInt8.self).baseAddress!,
                            dstPtr.count,
                            srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                            srcPtr.count,
                            nil,
                            COMPRESSION_ZLIB
                        )
                    }
                }
                guard decoded == Int(declaredSize) else {
                    throw WavetableError.decompressedSizeExceedsLimit(found: decoded, max: Int(declaredSize))
                }
                let uncompressed = Data(bytes: dest, count: decoded)
                return try parseRawSerialized(uncompressed, name: name)
            }
        }

        // 2. Legacy zlib (without magic header) or zip-bomb payload
        // Inflate into a strictly bounded buffer of size maxSerializedBytes + 1
        var dest = [UInt8](repeating: 0, count: maxSerializedBytes + 1)
        let decoded = data.withUnsafeBytes { srcPtr in
            dest.withUnsafeMutableBytes { dstPtr in
                compression_decode_buffer(
                    dstPtr.bindMemory(to: UInt8.self).baseAddress!,
                    dstPtr.count,
                    srcPtr.bindMemory(to: UInt8.self).baseAddress!,
                    srcPtr.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        if decoded > maxSerializedBytes {
            // Zip-bomb detected! Refuse without large memory allocation!
            throw WavetableError.decompressedSizeExceedsLimit(found: decoded, max: maxSerializedBytes)
        } else if decoded >= 8 {
            let uncompressed = Data(bytes: dest, count: decoded)
            return try parseRawSerialized(uncompressed, name: name)
        } else {
            // Not zlib compressed: raw serialized data
            guard data.count <= maxSerializedBytes else {
                throw WavetableError.decompressedSizeExceedsLimit(found: data.count, max: maxSerializedBytes)
            }
            return try parseRawSerialized(data, name: name)
        }
    }

    public static func deserialize(from data: Data, name: String = "User") -> Wavetable? {
        return try? deserializeOrThrow(from: data, name: name)
    }

    private static func parseRawSerialized(_ uncompressedData: Data, name: String) throws -> Wavetable {
        guard uncompressedData.count >= 8, uncompressedData.count <= maxSerializedBytes else {
            throw WavetableError.decompressedSizeExceedsLimit(found: uncompressedData.count, max: maxSerializedBytes)
        }
        var fCount: Int32 = 0
        var sCount: Int32 = 0
        _ = withUnsafeMutableBytes(of: &fCount) { uncompressedData.copyBytes(to: $0, from: 0..<4) }
        _ = withUnsafeMutableBytes(of: &sCount) { uncompressedData.copyBytes(to: $0, from: 4..<8) }
        guard fCount > 0, sCount > 0, fCount <= Int32(maxFramesLimit), sCount <= Int32(maxSamplesPerFrameLimit) else {
            throw WavetableError.unsupportedAudioFormat
        }
        let totalFloats = Int(fCount * sCount)
        guard uncompressedData.count >= 8 + totalFloats * MemoryLayout<Float>.size else {
            throw WavetableError.insufficientSamples(found: uncompressedData.count, required: 8 + totalFloats * MemoryLayout<Float>.size)
        }

        var frames: [[Float]] = []
        frames.reserveCapacity(Int(fCount))
        var offset = 8
        for _ in 0..<fCount {
            var frame = [Float](repeating: 0, count: Int(sCount))
            frame.withUnsafeMutableBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    _ = uncompressedData.copyBytes(to: UnsafeMutableBufferPointer(start: base, count: Int(sCount)), from: offset..<(offset + Int(sCount) * 4))
                }
            }
            frames.append(frame)
            offset += Int(sCount) * 4
        }
        return Wavetable(name: name, frames: frames)
    }
}

extension Data {
    public func fnv1aHash() -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in self {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

public struct WavetableCacheKey: Hashable, Sendable {
    public let contentHash: UInt64
    public let sampleRateHz: Int

    public init(contentHash: UInt64, sampleRate: Double) {
        self.contentHash = contentHash
        self.sampleRateHz = Int(sampleRate.rounded())
    }
}

/// SYNT_16 R13-4: one immutable, immortal LFO shape (middle frame of a table).
/// Read on the render thread through a raw pointer: no ARC, no allocation.
public struct LFOShapeTable {
    public let data: UnsafePointer<Float>
    public let count: Int

    /// Off the render thread. Never freed (a few KB per compiled table), so a raw pointer
    /// held by an LFO can never dangle when the oscillator swaps tables.
    public static func makeImmortal(_ frame: [Float]) -> UnsafePointer<LFOShapeTable> {
        let n = max(1, frame.count)
        let d = UnsafeMutablePointer<Float>.allocate(capacity: n)
        if frame.isEmpty { d.initialize(to: 0) } else { d.initialize(from: frame, count: frame.count) }
        // SYNT_17 R14-5: normalize to peak 1 so a quiet user table still gives a full-depth LFO.
        let peak = frame.reduce(Float(0)) { max($0, abs($1)) }
        if peak > 1e-6 { for i in 0..<frame.count { d[i] /= peak } }
        let p = UnsafeMutablePointer<LFOShapeTable>.allocate(capacity: 1)
        p.initialize(to: LFOShapeTable(data: UnsafePointer(d), count: frame.isEmpty ? 1 : frame.count))
        return UnsafePointer(p)
    }

    /// Middle frame (frame 16 of 32 for the builtins, as the SYNT_15 fixed shape).
    public static func middleFrame(of table: Wavetable) -> [Float] {
        table.frames.isEmpty ? [] : table.frames[table.frames.count / 2]
    }
}

/// SYNT_18 R15-2: plain-old-data view of a compiled table's mips, laid out
/// `[octave][frame][sample]` in one raw buffer. Read on the render thread with no ARC.
public struct FlatMipView {
    public let base: UnsafePointer<Float>
    public let octaves: Int
    public let frames: Int
    public let samplesPerFrame: Int

    @inline(__always)
    public func frame(octave: Int, index: Int) -> UnsafePointer<Float> {
        base + (octave &* frames &+ index) &* samplesPerFrame
    }
}

/// Pre-compiled mipmapped wavetable ready for allocation-free render
public final class CompiledMipData: @unchecked Sendable {
    /// SYNT_18 R15-2: owned raw copy of `mipMaps` (+ its POD view). Allocated off render in init,
    /// freed in deinit; valid as long as this object is retained (the triple-buffer slot holds a retain).
    public let flatView: UnsafeMutablePointer<FlatMipView>
    private let flatData: UnsafeMutablePointer<Float>
    /// Test hook: counts deinit (proves a table is not freed on the render thread).
    public static let deinitCountForTesting = Atomic<Int>(0)
    /// SYNT_16 R13-4: shape the wavetable LFO reads when this table is the oscillator's table.
    public let lfoShape: UnsafePointer<LFOShapeTable>
    public let wavetable: Wavetable
    public let mipMaps: [[[Float]]]
    /// Harmonics kept per mip octave (Nyquist at the top of that octave).
    public let maxHarmonics: [Int]
    /// R12-6: sample rate the mips were built for (0 = unknown).
    public let sampleRate: Double
    public init(wavetable: Wavetable, mipMaps: [[[Float]]], maxHarmonics: [Int], sampleRate: Double = 0) {
        self.sampleRate = sampleRate
        self.wavetable = wavetable
        self.mipMaps = mipMaps
        self.maxHarmonics = maxHarmonics
        self.lfoShape = LFOShapeTable.makeImmortal(LFOShapeTable.middleFrame(of: wavetable))
        let octs = mipMaps.count
        let frms = mipMaps.first?.count ?? 0
        let spf = mipMaps.first?.first?.count ?? 0
        let total = max(1, octs * frms * spf)
        let d = UnsafeMutablePointer<Float>.allocate(capacity: total)
        d.initialize(repeating: 0, count: total)
        for o in 0..<octs {
            for f in 0..<min(frms, mipMaps[o].count) {
                let src = mipMaps[o][f]
                let n = min(spf, src.count)
                src.withUnsafeBufferPointer { b in
                    if let a = b.baseAddress { (d + (o * frms + f) * spf).update(from: a, count: n) }
                }
            }
        }
        self.flatData = d
        let v = UnsafeMutablePointer<FlatMipView>.allocate(capacity: 1)
        v.initialize(to: FlatMipView(base: UnsafePointer(d), octaves: (frms > 0 && spf > 0) ? octs : 0,
                                     frames: frms, samplesPerFrame: spf))
        self.flatView = v
    }

    deinit {
        Self.deinitCountForTesting.wrappingAdd(1, ordering: .relaxed)
        if let hook = CompiledMipData.onDeinitForTesting { hook() }
        flatView.deinitialize(count: 1)
        flatView.deallocate()
        flatData.deallocate()
    }

    /// Test hook run inside deinit (e.g. records whether it ran on the simulated render thread).
    nonisolated(unsafe) public static var onDeinitForTesting: (() -> Void)?
}

/// Band-limited wavetable oscillator with mip-mapping
public final class WavetableOscillator {

    // MARK: - Properties

    /// Morph position target 0…1 (UI / preset writes here).
    public var targetFramePosition: Float = 0.0 {
        didSet {
            targetFramePosition = max(0, min(1, targetFramePosition))
        }
    }

    /// Smoothed morph position used for rendering (audio thread advances this).
    private(set) var framePosition: Float = 0.0

    /// Kept for API compatibility; **not** applied in `generateSample` (avoid double volume).
    public var volume: Float = 1.0
    public var octave: Int = 0
    public var detune: Float = 0.0  // cents

    /// One-pole toward targetFramePosition per sample (~5 ms @ 44.1 kHz).
    public var morphSmoothingCoeff: Float = 0.002

    public private(set) var currentWavetable: Wavetable?
    public private(set) var currentBuiltinIndex: Int?
    public private(set) var activeCompiled: CompiledMipData?
    /// SYNT_16 R13-6: times loadBuiltin(5) saw a user table with no compiled mips.
    public var userTableWithoutMipsCountForTesting = 0
    /// SYNT_16 R13-4: bit pattern of `activeCompiled.lfoShape` (0 = none). One word, so a
    /// main-thread table swap is never seen torn by the render-side LFO snapshot.
    public let lfoShapeBits = Atomic<Int>(0)
    /// SYNT_17 R14-3: bit pattern of the immortal built-in set for `mipSampleRate`.
    /// Written on main (init / setSampleRate), read lock-free by `loadBuiltin` (may run on render).
    private let builtinSetBits = Atomic<Int>(0)

    // Triple buffer for RT lock-free handoff (Chen's wait-free 3-buffer algorithm)
    private static let hasNewDataFlag: Int = 0x80
    private let sharedBank = Atomic<Int>(0)
    private var writeBank: Int = 1
    private var readBank: Int = 2
    private let slots: UnsafeMutablePointer<Unmanaged<CompiledMipData>?>
    /// SYNT_18 R15-2: POD view per slot (same index as `slots`); the render path reads only this.
    private let viewSlots: UnsafeMutablePointer<UnsafePointer<FlatMipView>?>
    private let writeLock: os_unfair_lock_t

    private let tableSize: Int = 2048
    private let numOctaves: Int = 11  // C0 to C10
    /// Mips are built for the live engine rate. Must match AudioEngine.
    private var mipSampleRate: Double = 44100.0

    // MARK: - Built-in Wavetables & Cache

    public static let compileCountForTesting = Atomic<Int>(0)

    private static let cacheLock: os_unfair_lock_t = {
        let lock = os_unfair_lock_t.allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
        return lock
    }()
    /// SYNT_17 R14-3: counts every `cacheLock` acquisition (tests prove render paths never take it).
    public static let cacheLockCountForTesting = Atomic<Int>(0)
    @inline(__always) static func lockCache() {
        cacheLockCountForTesting.add(1, ordering: .relaxed)
        os_unfair_lock_lock(cacheLock)
    }
    /// Test hook: runs `body` while holding `cacheLock` (proves render paths do not wait on it).
    public static func withCacheLockHeldForTesting(_ body: () -> Void) {
        os_unfair_lock_lock(cacheLock)
        defer { os_unfair_lock_unlock(cacheLock) }
        body()
    }
    private static var compiledCache: [WavetableCacheKey: CompiledMipData] = [:]
    /// SYNT_17 R14-3: per sample rate, an immortal array of the 5 built-in tables (retained forever,
    /// never freed or mutated after publish). Main-thread built; render reads it lock-free.
    private static var builtinSets: [Int: UnsafeMutablePointer<Unmanaged<CompiledMipData>>] = [:]

    /// Main / setup thread only. Compiles (or reuses) all built-in tables for `sampleRate`.
    static func builtinSet(for sampleRate: Double) -> UnsafeMutablePointer<Unmanaged<CompiledMipData>> {
        let hz = Int(sampleRate.rounded())
        lockCache()
        if let set = builtinSets[hz] {
            // Keep the keyed cache view consistent after clearCacheForTesting.
            for i in 0..<basicWavetables.count {
                let key = BuiltinCacheKey(index: i, sampleRate: sampleRate)
                if precompiledBuiltins[key] == nil { precompiledBuiltins[key] = set[i].takeUnretainedValue() }
            }
            os_unfair_lock_unlock(cacheLock)
            return set
        }
        os_unfair_lock_unlock(cacheLock)
        let n = basicWavetables.count
        let set = UnsafeMutablePointer<Unmanaged<CompiledMipData>>.allocate(capacity: n)
        for i in 0..<n {
            let key = BuiltinCacheKey(index: i, sampleRate: sampleRate)
            lockCache()
            let existing = precompiledBuiltins[key]
            os_unfair_lock_unlock(cacheLock)
            let compiled = existing ?? compile(wavetable: basicWavetables[i], sampleRate: sampleRate)
            if existing == nil {
                lockCache()
                precompiledBuiltins[key] = compiled
                os_unfair_lock_unlock(cacheLock)
            }
            (set + i).initialize(to: Unmanaged.passRetained(compiled))
        }
        lockCache()
        defer { os_unfair_lock_unlock(cacheLock) }
        if let raced = builtinSets[hz] { return raced }   // leak the duplicate (immortal by design, rare)
        builtinSets[hz] = set
        return set
    }
    private static var inProgressKeys = Set<WavetableCacheKey>()

    public static func getCachedCompiled(for key: WavetableCacheKey) -> CompiledMipData? {
        lockCache()
        defer { os_unfair_lock_unlock(cacheLock) }
        return compiledCache[key]
    }

    public static func setCachedCompiled(_ compiled: CompiledMipData, for key: WavetableCacheKey) {
        lockCache()
        defer { os_unfair_lock_unlock(cacheLock) }
        compiledCache[key] = compiled
        inProgressKeys.remove(key)
    }

    public static func compileUserWavetableAsyncIfNeeded(
        data: Data,
        name: String,
        sampleRate: Double,
        completion: (@Sendable (CompiledMipData) -> Void)? = nil
    ) -> CompiledMipData? {
        let contentHash = Wavetable.canonicalContentHash(for: data) ?? data.fnv1aHash()
        let key = WavetableCacheKey(contentHash: contentHash, sampleRate: sampleRate)
        lockCache()
        if let cached = compiledCache[key] {
            os_unfair_lock_unlock(cacheLock)
            return cached
        }
        if inProgressKeys.contains(key) {
            os_unfair_lock_unlock(cacheLock)
            return nil
        }
        inProgressKeys.insert(key)
        os_unfair_lock_unlock(cacheLock)

        DispatchQueue.global(qos: .userInitiated).async {
            guard let table = Wavetable.deserialize(from: data, name: name) else {
                lockCache()
                inProgressKeys.remove(key)
                os_unfair_lock_unlock(cacheLock)
                return
            }
            let compiled = compile(wavetable: table, sampleRate: sampleRate)
            lockCache()
            compiledCache[key] = compiled
            inProgressKeys.remove(key)
            os_unfair_lock_unlock(cacheLock)
            completion?(compiled)
        }
        return nil
    }

    public static func clearCacheForTesting() {
        lockCache()
        defer { os_unfair_lock_unlock(cacheLock) }
        compiledCache.removeAll()
        inProgressKeys.removeAll()
        precompiledBuiltins.removeAll()
    }

    public static var userWavetable: Wavetable?
    public static var userCompiledWavetable: CompiledMipData?
    public struct BuiltinCacheKey: Hashable, Sendable {
        public let index: Int
        public let sampleRateHz: Int
        public init(index: Int, sampleRate: Double) {
            self.index = index
            self.sampleRateHz = Int(sampleRate.rounded())
        }
    }
    public static var precompiledBuiltins: [BuiltinCacheKey: CompiledMipData] = [:]

    public static let basicWavetables: [Wavetable] = {
        var tables: [Wavetable] = []
        tables.append(generateBasicShapes())
        tables.append(generateAnalogWaves())
        tables.append(generateDigitalWaves())
        tables.append(generatePWMWaves())
        tables.append(generateFormantWaves())
        return tables
    }()

    // MARK: - Audio File Parsing & User Wavetables

    /// Robust conditioning for imported frames: NaN/Inf rejection, seamless loop crossfade, DC removal, and peak normalization.
    public static func cleanAndConditionFrame(_ raw: [Float], seamCrossfadeLength: Int = 32) -> [Float] {
        guard !raw.isEmpty else { return raw }
        var frame = [Float](repeating: 0, count: raw.count)

        // 1. Clean / reject NaN and Inf
        for i in 0..<raw.count {
            let s = raw[i]
            frame[i] = (s.isNaN || s.isInfinite) ? 0.0 : s
        }

        // 2. Loop seam smoothing: eliminate click at frame boundary (connect last sample smoothly to first)
        let count = frame.count
        let seamK = min(seamCrossfadeLength, count / 4)
        if seamK > 1 {
            let diff = frame[0] - frame[count - 1]
            for i in 0..<seamK {
                let idx = count - seamK + i
                // Half-cosine ramp from 0 to 1 over the last seamK samples
                let t = 0.5 * (1.0 - cos(Float.pi * Float(i + 1) / Float(seamK)))
                frame[idx] += diff * t
            }
        }

        // 3. DC removal (performed after seam smoothing so the final frame has exactly zero mean)
        var mean: Float = 0
        vDSP_meanv(frame, 1, &mean, vDSP_Length(frame.count))
        var negMean = -mean
        vDSP_vsadd(frame, 1, &negMean, &frame, 1, vDSP_Length(frame.count))

        // 4. Peak normalization
        return normalizePeak(frame)
    }

    /// Parses a standard PCM / Float32 WAV or AIFF file (Serum format: 2048 samples per frame, up to maxFrames).
    public static func parseAudioFile(url: URL, samplesPerFrame: Int = 2048, maxFrames: Int = 64) throws -> Wavetable {
        let file = try AVAudioFile(forReading: url)
        let processingFormat = file.processingFormat
        let length = file.length

        // Guard against negative or > 2^32 frames
        guard length > 0, length <= Int64(UInt32.max) else {
            throw WavetableError.fileTooLarge
        }
        guard length >= Int64(samplesPerFrame) else {
            throw WavetableError.insufficientSamples(found: Int(length), required: samplesPerFrame)
        }
        let framesToRead = min(AVAudioFrameCount(length), AVAudioFrameCount(samplesPerFrame * maxFrames))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
            throw WavetableError.bufferCreationFailed
        }
        try file.read(into: buffer, frameCount: framesToRead)
        guard let channelData = buffer.floatChannelData else {
            throw WavetableError.unsupportedAudioFormat
        }
        let channelCount = Int(processingFormat.channelCount)
        guard channelCount > 0 else { throw WavetableError.unsupportedAudioFormat }

        let totalRead = Int(buffer.frameLength)
        let numFrames = min(maxFrames, totalRead / samplesPerFrame)
        guard numFrames > 0 else {
            throw WavetableError.insufficientSamples(found: totalRead, required: samplesPerFrame)
        }

        let invChannels = 1.0 / Float(channelCount)
        var frames: [[Float]] = []
        frames.reserveCapacity(numFrames)
        for f in 0..<numFrames {
            let offset = f * samplesPerFrame
            var rawFrame = [Float](repeating: 0, count: samplesPerFrame)
            if channelCount == 1 {
                let ch0 = channelData[0]
                for i in 0..<samplesPerFrame {
                    let s = ch0[offset + i]
                    rawFrame[i] = (s.isNaN || s.isInfinite) ? 0.0 : s
                }
            } else {
                // Downmix all channels (handles stereo, quad, 5.1, >2 channels)
                for i in 0..<samplesPerFrame {
                    var sum: Float = 0
                    for ch in 0..<channelCount {
                        let s = channelData[ch][offset + i]
                        if !s.isNaN && !s.isInfinite {
                            sum += s
                        }
                    }
                    rawFrame[i] = sum * invChannels
                }
            }
            frames.append(cleanAndConditionFrame(rawFrame))
        }
        let baseName = url.deletingPathExtension().lastPathComponent
        return Wavetable(name: baseName.isEmpty ? "User" : baseName, frames: frames)
    }

    /// Slices raw PCM buffer into N frames (default 2048 samples per frame, up to maxFrames), and normalizes each frame.
    public static func importAudioBuffer(
        samples: [Float],
        samplesPerFrame: Int = 2048,
        maxFrames: Int = 64,
        name: String = "Imported"
    ) throws -> Wavetable {
        let totalSamples = samples.count
        guard totalSamples >= samplesPerFrame else {
            throw WavetableError.insufficientSamples(found: totalSamples, required: samplesPerFrame)
        }
        let numFrames = min(maxFrames, totalSamples / samplesPerFrame)
        guard numFrames > 0 else {
            throw WavetableError.insufficientSamples(found: totalSamples, required: samplesPerFrame)
        }
        var frames: [[Float]] = []
        frames.reserveCapacity(numFrames)
        for f in 0..<numFrames {
            let offset = f * samplesPerFrame
            var rawFrame = [Float](repeating: 0, count: samplesPerFrame)
            for i in 0..<samplesPerFrame {
                rawFrame[i] = samples[offset + i]
            }
            frames.append(cleanAndConditionFrame(rawFrame))
        }
        return Wavetable(name: name, frames: frames)
    }

    /// Compiles a wavetable with all band-limited mipmaps outside of the render thread.
    public static func compile(wavetable: Wavetable, sampleRate: Double = 44100.0) -> CompiledMipData {
        compileCountForTesting.wrappingAdd(1, ordering: .relaxed)
        let maps = buildMipMaps(from: wavetable, sampleRate: sampleRate)
        return CompiledMipData(
            wavetable: wavetable,
            mipMaps: maps,
            maxHarmonics: mipMaxHarmonics(count: maps.count, sampleRate: sampleRate),
            sampleRate: sampleRate
        )
    }

    /// Nyquist at the TOP of octave i (f in [20·2^i, 20·2^{i+1})),
    /// so a note at the bright end cannot alias.
    public static func maxHarmonic(forOctave octave: Int, sampleRate: Double = 44100.0) -> Int {
        let nyquist = sampleRate * 0.5
        let fHigh = 20.0 * pow(2.0, Double(octave + 1))
        return max(1, Int(floor(nyquist / fHigh)))
    }

    /// Partials kept per mip octave: Nyquist at the TOP of octave i
    /// (f in [20·2^i, 20·2^{i+1})), so a note at the bright end cannot alias.
    public static func mipMaxHarmonics(count: Int = 11, sampleRate: Double = 44100.0) -> [Int] {
        return (0..<count).map { maxHarmonic(forOctave: $0, sampleRate: sampleRate) }
    }

    /// Precomputes mipmap tables for all 11 octave ranges.
    public static func buildMipMaps(from wavetable: Wavetable, sampleRate: Double = 44100.0) -> [[[Float]]] {
        var maps: [[[Float]]] = []
        let numOctaves = 11
        let harmonics = mipMaxHarmonics(count: numOctaves, sampleRate: sampleRate)
        for octave in 0..<numOctaves {
            let maxHarm = harmonics[octave]
            var octaveFrames: [[Float]] = []
            for frame in wavetable.frames {
                octaveFrames.append(applyFFTBandLimitStatic(frame, maxHarmonic: maxHarm))
            }
            maps.append(octaveFrames)
        }
        return maps
    }

    /// Instance-specific user wavetable (R11-4: isolated per oscillator / AU instance, not shared static)
    public var instanceUserWavetable: Wavetable?
    public var instanceUserCompiled: CompiledMipData? {
        didSet {
            // SYNT_19 R16-1: publish the new table first, then retire the old one. A retired table
            // is released (on main) only once render's ack no longer names it — hazard-pointer
            // protocol with `rtUserAck` (both sides seq-cst), not "one swap".
            userCompiledBits.store(instanceUserCompiled.map { Int(bitPattern: Unmanaged.passUnretained($0).toOpaque()) } ?? 0,
                                   ordering: .sequentiallyConsistent)
            if let old = oldValue, old !== instanceUserCompiled { retiredUserTables.append(old) }
            drainRetiredUserTablesMain()
        }
    }
    /// Main-only retire list (SYNT_19 R16-1).
    private var retiredUserTables: [CompiledMipData] = []
    /// SYNT_19 R16-1: the user `CompiledMipData` as an unretained POD word for render.
    private let userCompiledBits = Atomic<Int>(0)
    /// SYNT_19 R16-1: render's ack — the user table `rtView` currently points into (0 = none).
    public let rtUserAck = Atomic<Int>(0)
    public var retiredUserTableCountForTesting: Int { retiredUserTables.count }

    /// SYNT_19 R16-1: main thread. Releases retired user tables render is not using.
    public func drainRetiredUserTablesMain() {
        guard !retiredUserTables.isEmpty else { return }
        let ack = rtUserAck.load(ordering: .sequentiallyConsistent)
        retiredUserTables.removeAll { Int(bitPattern: Unmanaged.passUnretained($0).toOpaque()) != ack }
    }
    /// Render-owned override (set by `loadBuiltinRT`, cleared when main publishes again).
    private var rtView: UnsafePointer<FlatMipView>?
    /// Index loaded on render that main has not yet mirrored into `activeCompiled` (-1 = none).
    public let rtPendingIndex = Atomic<Int>(-1)
    /// Times `publishCompiled` took `writeLock` (test probe for "no lock on render").
    public static let publishLockCountForTesting = Atomic<Int>(0)

    /// Loads wavetable frames from an audio file, compiles mipmaps, and sets it as the active user table.
    public func loadFromAudioFile(url: URL) throws {
        let table = try Self.parseAudioFile(url: url)
        let key = WavetableCacheKey(contentHash: table.contentHash, sampleRate: mipSampleRate)
        let compiled: CompiledMipData
        if let cached = Self.getCachedCompiled(for: key) {
            compiled = cached
        } else {
            compiled = Self.compile(wavetable: table, sampleRate: mipSampleRate)
            Self.setCachedCompiled(compiled, for: key)
        }
        instanceUserWavetable = table
        instanceUserCompiled = compiled
        Self.userWavetable = table
        Self.userCompiledWavetable = compiled
        loadCompiledWavetable(compiled)
    }

    // MARK: - Initialization

    public init() {
        writeLock = .allocate(capacity: 1)
        writeLock.initialize(to: os_unfair_lock())
        slots = .allocate(capacity: 3)
        slots.initialize(repeating: nil, count: 3)
        viewSlots = .allocate(capacity: 3)
        viewSlots.initialize(repeating: nil, count: 3)
        builtinSetBits.store(Int(bitPattern: Self.builtinSet(for: mipSampleRate)), ordering: .releasing)
        loadBuiltin(index: 0)
    }

    deinit {
        for i in 0..<3 {
            slots[i]?.release()
        }
        slots.deinitialize(count: 3)
        slots.deallocate()
        viewSlots.deinitialize(count: 3)
        viewSlots.deallocate()
        writeLock.deinitialize(count: 1)
        writeLock.deallocate()
    }

    // MARK: - Wavetable Loading

    public func loadCompiledWavetable(_ compiled: CompiledMipData) {
        currentWavetable = compiled.wavetable
        activeCompiled = compiled
        lfoShapeBits.store(Int(bitPattern: compiled.lfoShape), ordering: .releasing)
        framePosition = targetFramePosition
        publishCompiled(compiled)
    }

    private func publishCompiled(_ compiled: CompiledMipData) {
        Self.publishLockCountForTesting.add(1, ordering: .relaxed)
        os_unfair_lock_lock(writeLock)
        let newRef = Unmanaged.passRetained(compiled)
        let oldRef = slots[writeBank]
        slots[writeBank] = newRef
        viewSlots[writeBank] = UnsafePointer(compiled.flatView)
        let previousShared = sharedBank.exchange(writeBank | Self.hasNewDataFlag, ordering: .acquiringAndReleasing)
        writeBank = previousShared & 0x03
        os_unfair_lock_unlock(writeLock)

        oldRef?.release()
    }

    @inline(__always)
    public func pullNewWavetableRT() {
        if (sharedBank.load(ordering: .acquiring) & Self.hasNewDataFlag) != 0 {
            let previousShared = sharedBank.exchange(readBank, ordering: .acquiringAndReleasing)
            readBank = previousShared & 0x03
            rtView = nil
            rtUserAck.store(0, ordering: .releasing)  // per publish, not per sample
        }
    }

    /// SYNT_18 R15-1: render-thread table switch. No lock, no allocation, no retain/release:
    /// built-ins come from the immortal per-rate set, the user table from POD words kept alive
    /// on main. Main mirrors the choice into `activeCompiled` later via `syncFromRenderMain()`.
    public func loadBuiltinRT(index: Int) {
        pullNewWavetableRT()  // an older main publish must not override this newer choice
        var view: UnsafePointer<FlatMipView>?
        var lfoBits = 0
        var effective = index
        var userBits = 0
        if index == 5 {
            // SYNT_19 R16-1 hazard pointer: ack, then confirm main has not swapped meanwhile.
            userBits = userCompiledBits.load(ordering: .sequentiallyConsistent)
            while true {
                rtUserAck.store(userBits, ordering: .sequentiallyConsistent)
                let again = userCompiledBits.load(ordering: .sequentiallyConsistent)
                if again == userBits { break }
                userBits = again
            }
        } else {
            rtUserAck.store(0, ordering: .releasing)
        }
        if index == 5, let raw = UnsafeRawPointer(bitPattern: userBits) {
            Unmanaged<CompiledMipData>.fromOpaque(raw)._withUnsafeGuaranteedRef { c in
                view = UnsafePointer(c.flatView)
                lfoBits = Int(bitPattern: c.lfoShape)
            }
        } else {
            if index == 5 { effective = 0 }
            let i = max(0, min(Self.basicWavetables.count - 1, effective))
            guard let set = UnsafeMutablePointer<Unmanaged<CompiledMipData>>(bitPattern: builtinSetBits.load(ordering: .acquiring)) else { return }
            set[i]._withUnsafeGuaranteedRef { c in
                view = UnsafePointer(c.flatView)
                lfoBits = Int(bitPattern: c.lfoShape)
            }
        }
        rtView = view
        lfoShapeBits.store(lfoBits, ordering: .releasing)
        framePosition = targetFramePosition
        rtPendingIndex.store(index, ordering: .releasing)
    }

    /// SYNT_18 R15-1: main-thread follow-up for a render-side `loadBuiltinRT`. Takes over the
    /// retain/release (and the lock) off the render thread.
    public func syncFromRenderMain() {
        defer { drainRetiredUserTablesMain() }
        let idx = rtPendingIndex.exchange(-1, ordering: .acquiringAndReleasing)
        if idx >= 0 { loadBuiltin(index: idx) }
    }

    public func loadWavetable(_ wavetable: Wavetable) {
        currentWavetable = wavetable
        currentBuiltinIndex = nil
        instanceUserWavetable = wavetable
        let key = WavetableCacheKey(contentHash: wavetable.contentHash, sampleRate: mipSampleRate)
        let compiled: CompiledMipData
        if let cached = Self.getCachedCompiled(for: key) {
            compiled = cached
        } else {
            compiled = Self.compile(wavetable: wavetable, sampleRate: mipSampleRate)
            Self.setCachedCompiled(compiled, for: key)
        }
        instanceUserCompiled = compiled
        loadCompiledWavetable(compiled)
    }

    /// Rebuild mip tables for a new Nyquist. Not safe on the render thread.
    public func setSampleRate(_ rate: Double) {
        // SYNT_19 R16-2: adopt a render-side table switch first, so the rebuild below uses the
        // table render is actually playing, not a stale `currentBuiltinIndex`.
        syncFromRenderMain()
        let rate = max(8_000, rate)
        let changed = abs(rate - mipSampleRate) > 0.5
        mipSampleRate = rate
        morphSmoothingCoeff = Float(88.2 / rate)
        guard changed else { return }
        // SYNT_17 R14-3: all built-ins for the new rate are ready before anything can look them up.
        builtinSetBits.store(Int(bitPattern: Self.builtinSet(for: rate)), ordering: .releasing)
        if currentBuiltinIndex == 5, let userTable = instanceUserWavetable ?? instanceUserCompiled?.wavetable {
            // R12-6: user table must be rebuilt for the new Nyquist (cache keyed by SR).
            loadWavetable(userTable)
            currentBuiltinIndex = 5
        } else if let idx = currentBuiltinIndex {
            loadBuiltin(index: idx)
        } else if let currentWavetable {
            loadWavetable(currentWavetable)
        }
    }

    public func loadBuiltin(index: Int) {
        currentBuiltinIndex = index
        if index == 5 {
            // R12-7: per-instance only; the statics are UI-display mirrors and
            // must never feed another engine's audio.
            if let userCompiled = instanceUserCompiled {
                currentWavetable = userCompiled.wavetable
                loadCompiledWavetable(userCompiled)
            } else {
                // SYNT_16 R13-6: never compile mips here (reachable from render via
                // applyPresetDSP). `loadWavetable` always sets `instanceUserCompiled`, so a
                // table without compiled mips cannot exist; fall back to builtin 0 instead.
                if instanceUserWavetable != nil { userTableWithoutMipsCountForTesting += 1 }
                loadBuiltin(index: 0)
            }
            return
        }
        let i = max(0, min(Self.basicWavetables.count - 1, index))
        let table = Self.basicWavetables[i]
        currentWavetable = table
        // SYNT_17 R14-3: lock-free lookup in the immortal set prepared on main for this rate.
        // Never takes `cacheLock`, never compiles (also the R13-6 fallback from index 5).
        let bits = builtinSetBits.load(ordering: .acquiring)
        guard let set = UnsafeMutablePointer<Unmanaged<CompiledMipData>>(bitPattern: bits) else { return }
        loadCompiledWavetable(set[i].takeUnretainedValue())
    }


    public func applyFFTBandLimit(_ source: [Float], maxHarmonic: Int) -> [Float] {
        Self.applyFFTBandLimitStatic(source, maxHarmonic: maxHarmonic)
    }

    /// Zero spectral bins above `maxHarmonic` on the **existing** frame, then IFFT.
    /// Does **not** resynthesize a generic saw series.
    public static func applyFFTBandLimitStatic(_ source: [Float], maxHarmonic: Int) -> [Float] {
        let n = source.count
        guard n > 2 else { return source }

        let nyquistBin = n / 2
        let maxH = max(1, min(maxHarmonic, nyquistBin - 1))

        // Already full-band enough — only normalize.
        if maxH >= nyquistBin - 1 {
            return Self.normalizePeak(source)
        }

        // Power-of-two complex FFT (clear bin layout, load-time only).
        if n > 0 && (n & (n - 1)) == 0 {
            return bandLimitWithComplexFFTStatic(source, maxHarmonic: maxH)
        }

        return bandLimitWithDFTStatic(source, maxHarmonic: maxH)
    }

    /// Full complex FFT band-limit: keep bins 0...maxH and conjugate mirrors, zero the rest.
    private static func bandLimitWithComplexFFTStatic(_ source: [Float], maxHarmonic: Int) -> [Float] {
        let n = source.count
        let log2n = vDSP_Length(log2(Double(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return bandLimitWithDFTStatic(source, maxHarmonic: maxHarmonic)
        }
        defer { vDSP_destroy_fftsetup(setup) }

        var real = source
        var imag = [Float](repeating: 0, count: n)

        real.withUnsafeMutableBufferPointer { rBuf in
            imag.withUnsafeMutableBufferPointer { iBuf in
                var split = DSPSplitComplex(realp: rBuf.baseAddress!, imagp: iBuf.baseAddress!)
                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))

                // Keep DC..maxH and n-maxH..n-1 (conjugate side); zero middle bins.
                let lo = maxHarmonic + 1
                let hi = n - maxHarmonic // exclusive end of zero region start.. 
                if lo < hi {
                    for k in lo..<hi {
                        rBuf[k] = 0
                        iBuf[k] = 0
                    }
                }

                vDSP_fft_zip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
            }
        }

        var scale = 1.0 / Float(n)
        vDSP_vsmul(real, 1, &scale, &real, 1, vDSP_Length(n))
        return Self.normalizePeak(real)
    }

    /// Portable DFT band-limit (non power-of-two fallback).
    private static func bandLimitWithDFTStatic(_ source: [Float], maxHarmonic: Int) -> [Float] {
        let n = source.count
        let maxH = max(1, min(maxHarmonic, n / 2 - 1))
        let twoPiOverN = 2.0 * Double.pi / Double(n)

        var cosCoeff = [Double](repeating: 0, count: maxH + 1)
        var sinCoeff = [Double](repeating: 0, count: maxH + 1)

        for h in 0...maxH {
            var a = 0.0
            var b = 0.0
            for i in 0..<n {
                let angle = twoPiOverN * Double(h) * Double(i)
                let x = Double(source[i])
                a += x * cos(angle)
                b += x * sin(angle)
            }
            cosCoeff[h] = a
            sinCoeff[h] = b
        }

        var result = [Float](repeating: 0, count: n)
        let invN = 1.0 / Double(n)
        for i in 0..<n {
            var sample = cosCoeff[0] * invN
            for h in 1...maxH {
                let angle = twoPiOverN * Double(h) * Double(i)
                sample += 2.0 * invN * (cosCoeff[h] * cos(angle) + sinCoeff[h] * sin(angle))
            }
            result[i] = Float(sample)
        }

        return Self.normalizePeak(result)
    }

    public static func normalizePeak(_ data: [Float]) -> [Float] {
        var result = data
        var maxVal: Float = 0
        vDSP_maxmgv(result, 1, &maxVal, vDSP_Length(result.count))
        guard maxVal > 0.0001 else { return result }
        var scale = 1.0 / maxVal
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(result.count))
        return result
    }

    // MARK: - Sample Generation

    public func frequencyWithModifiers(_ baseFrequency: Double) -> Double {
        let octaveMultiplier = pow(2.0, Double(octave))
        let detuneMultiplier = pow(2.0, Double(detune) / 1200.0)
        return baseFrequency * octaveMultiplier * detuneMultiplier
    }

    /// Advance morph smoother **once per audio sample** (not once per voice).
    /// Call from the render path before iterating voices.
    @inline(__always)
    public func advanceMorph() {
        let morphErr = targetFramePosition - framePosition
        framePosition += morphErr * morphSmoothingCoeff
    }

    /// Raw wavetable sample in ≈[-1, 1]. **Does not** multiply by `volume`
    /// (Oscillator applies volume once to avoid double gain / clipping).
    /// Does not advance morph — call `advanceMorph()` once per sample from the engine.
    @inline(__always)
    public func generateSample(phase: Double, phaseIncrement: Double, sampleRate: Double = 44100.0) -> Float {
        pullNewWavetableRT()
        // SYNT_18 R15-2: POD view only (no class, no Swift array → no retain/release per sample).
        guard let view = rtView ?? viewSlots[readBank] else {
            return 0.0
        }
        guard view.pointee.octaves > 0 else { return 0.0 }

        let frequency = phaseIncrement * sampleRate / (2.0 * Double.pi)
        // One mip, the table built for this octave range. Crossfading two
        // mips doubled Hermite work per voice and still used the hotter
        // (under-limited) table — 4 notes of that was the crunch.
        let oct = max(0, min(numOctaves - 1, Self.mipOctave(forFrequency: frequency)))
        return sampleMorphedFlat(view, mipOctave: oct, phase: phase)
    }

    /// SYNT_18 R15-2: `Int(log2(max(20, f) / 20))` without `log2`: for x ≥ 1 the binary exponent
    /// is floor(log2 x). (Non-finite x keeps the old clamp behaviour via the caller's min/max.)
    @inline(__always)
    public static func mipOctave(forFrequency frequency: Double) -> Int {
        let x = max(20.0, frequency) / 20.0
        guard x.isFinite else { return Int.max }
        // libm log2 rounds up to the next integer when the significand is within a few ulps of 2;
        // that edge (practically never hit) keeps the exact old result via log2 itself.
        if x.significand >= 1.999_999_999 { return Int(log2(x)) }
        return Int(x.exponent)
    }

    @inline(__always)
    private func sampleMorphedFlat(_ viewPtr: UnsafePointer<FlatMipView>, mipOctave: Int, phase: Double) -> Float {
        let view = viewPtr.pointee
        guard mipOctave >= 0, mipOctave < view.octaves else { return 0 }
        let frameCount = view.frames
        guard frameCount > 0 else { return 0 }

        let framePos = framePosition * Float(max(0, frameCount - 1))
        let frameIndex1 = max(0, min(frameCount - 1, Int(framePos)))
        let frameIndex2 = min(frameIndex1 + 1, frameCount - 1)
        let frameFrac = framePos - Float(frameIndex1)

        let n = view.samplesPerFrame
        let sample1 = sampleFromRaw(view.frame(octave: mipOctave, index: frameIndex1), count: n, phase: phase)
        if frameIndex1 == frameIndex2 || frameFrac < 0.0001 {
            return sample1
        }
        let sample2 = sampleFromRaw(view.frame(octave: mipOctave, index: frameIndex2), count: n, phase: phase)
        return sample1 + (sample2 - sample1) * frameFrac
    }

    /// SYNT_18 R15-2 test hook: the pre-SYNT_18 array path (class + nested Swift arrays + log2),
    /// kept only to prove the flat path is bit-identical.
    public func generateSampleArrayPathForTesting(phase: Double, phaseIncrement: Double, sampleRate: Double = 44100.0) -> Float {
        guard let compiled = activeCompiled else { return 0 }
        let maps = compiled.mipMaps
        guard !maps.isEmpty else { return 0.0 }
        let frequency = phaseIncrement * sampleRate / (2.0 * Double.pi)
        let exactOctave = log2(max(20.0, frequency) / 20.0)
        let oct = max(0, min(numOctaves - 1, Int(exactOctave)))
        return sampleMorphed(compiled: compiled, mipOctave: oct, phase: phase)
    }

    @inline(__always)
    private func sampleMorphed(compiled: CompiledMipData, mipOctave: Int, phase: Double) -> Float {
        let maps = compiled.mipMaps
        guard mipOctave >= 0, mipOctave < maps.count else { return 0 }
        let frames = maps[mipOctave]
        let frameCount = frames.count
        guard frameCount > 0 else { return 0 }

        // Smooth frame morph between adjacent wavetable frames
        let framePos = framePosition * Float(max(0, frameCount - 1))
        let frameIndex1 = max(0, min(frameCount - 1, Int(framePos)))
        let frameIndex2 = min(frameIndex1 + 1, frameCount - 1)
        let frameFrac = framePos - Float(frameIndex1)

        let sample1 = sampleFromTable(frames[frameIndex1], phase: phase)
        if frameIndex1 == frameIndex2 || frameFrac < 0.0001 {
            return sample1
        }
        let sample2 = sampleFromTable(frames[frameIndex2], phase: phase)
        return sample1 + (sample2 - sample1) * frameFrac
    }

    @inline(__always)
    private func sampleFromTable(_ table: [Float], phase: Double) -> Float {
        table.withUnsafeBufferPointer { b in
            guard let a = b.baseAddress else { return 0.0 }
            return sampleFromRaw(a, count: b.count, phase: phase)
        }
    }

    @inline(__always)
    private func sampleFromRaw(_ table: UnsafePointer<Float>, count tableSize: Int, phase: Double) -> Float {
        guard tableSize > 0 else { return 0.0 }

        var normalizedPhase = phase * (1.0 / (2.0 * Double.pi))
        normalizedPhase -= floor(normalizedPhase)

        let pos = normalizedPhase * Double(tableSize)
        let i0 = Int(pos)
        let frac = Float(pos - Double(i0))

        // Short tables: linear. Power-of-two frames: Hermite + cheap wrap.
        if tableSize < 4 {
            let i1 = (i0 + 1) % tableSize
            return table[i0] + (table[i1] - table[i0]) * frac
        }

        let y: Float
        if tableSize & (tableSize - 1) == 0 {
            let mask = tableSize - 1
            let i = i0 & mask
            y = Self.hermite4(
                ym1: table[(i &- 1) & mask],
                y0: table[i],
                y1: table[(i &+ 1) & mask],
                y2: table[(i &+ 2) & mask],
                t: frac
            )
        } else {
            y = Self.hermite4(
                ym1: table[(i0 - 1 + tableSize) % tableSize],
                y0: table[i0 % tableSize],
                y1: table[(i0 + 1) % tableSize],
                y2: table[(i0 + 2) % tableSize],
                t: frac
            )
        }
        return max(-1.15, min(1.15, y))
    }

    /// Catmull-Rom / cubic Hermite. `t == 0` returns `y0` exactly.
    @inline(__always)
    public static func hermite4(ym1: Float, y0: Float, y1: Float, y2: Float, t: Float) -> Float {
        let c1 = 0.5 * (y1 - ym1)
        let c2 = ym1 - 2.5 * y0 + 2.0 * y1 - 0.5 * y2
        let c3 = 0.5 * (y2 - ym1) + 1.5 * (y0 - y1)
        return ((c3 * t + c2) * t + c1) * t + y0
    }

    public func reset() {
        // Phase is owned by ActiveNote; only reset morph smoother.
        framePosition = targetFramePosition
    }

    // MARK: - Test helpers

    /// Expose band-limit for unit tests without going through full mip chain.
    public func bandLimitForTesting(_ source: [Float], maxHarmonic: Int) -> [Float] {
        applyFFTBandLimit(source, maxHarmonic: maxHarmonic)
    }

    public func sampleFromTableForTesting(_ table: [Float], phase: Double) -> Float {
        sampleFromTable(table, phase: phase)
    }

    public var mipOctaveCountForTesting: Int { activeCompiled?.mipMaps.count ?? 0 }
    public var currentFrameCountForTesting: Int { activeCompiled?.mipMaps.first?.count ?? 0 }

    public func mipMaxHarmonicForTesting(_ octave: Int) -> Int {
        guard let harmonics = activeCompiled?.maxHarmonics, octave >= 0, octave < harmonics.count else { return 0 }
        return harmonics[octave]
    }

    // MARK: - Static Wavetable Generators

    private static func generateBasicShapes() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 32

        for f in 0..<numFrames {
            var frame = [Float](repeating: 0.0, count: tableSize)
            let morphPos = Float(f) / Float(numFrames - 1)

            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize) * 2.0 * Float.pi
                let tNorm = Float(i) / Float(tableSize)

                if morphPos < 0.33 {
                    let t = morphPos / 0.33
                    let sine = sin(phase)
                    let triangle = 2.0 * abs(2.0 * (tNorm - 0.5)) - 1.0
                    frame[i] = sine * (1.0 - t) + triangle * t
                } else if morphPos < 0.67 {
                    let t = (morphPos - 0.33) / 0.34
                    let triangle = 2.0 * abs(2.0 * (tNorm - 0.5)) - 1.0
                    let saw = 2.0 * tNorm - 1.0
                    frame[i] = triangle * (1.0 - t) + saw * t
                } else {
                    let t = (morphPos - 0.67) / 0.33
                    let saw = 2.0 * tNorm - 1.0
                    let square: Float = tNorm < 0.5 ? 1.0 : -1.0
                    frame[i] = saw * (1.0 - t) + square * t
                }
            }

            frames.append(normalizePeak(frame))
        }

        return Wavetable(name: "Basic Shapes", frames: frames)
    }

    private static func generateAnalogWaves() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 16

        for f in 0..<numFrames {
            var frame = [Float](repeating: 0.0, count: tableSize)
            let harmonicDecay = 0.5 + 0.5 * Float(f) / Float(numFrames - 1)

            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize) * 2.0 * Float.pi
                var sum: Float = 0.0
                for h in 1...32 {
                    let amplitude = pow(Float(h), -harmonicDecay)
                    sum += amplitude * sin(phase * Float(h))
                }
                frame[i] = sum
            }

            frames.append(normalizePeak(frame))
        }

        return Wavetable(name: "Analog", frames: frames)
    }

    private static func generateDigitalWaves() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 16

        for f in 0..<numFrames {
            var frame = [Float](repeating: 0.0, count: tableSize)
            let foldAmount = Float(f) / Float(numFrames - 1)

            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize)
                var value = sin(phase * 2.0 * Float.pi)
                let fold = 1.0 + foldAmount * 3.0
                value *= fold
                while abs(value) > 1.0 {
                    if value > 1.0 {
                        value = 2.0 - value
                    } else if value < -1.0 {
                        value = -2.0 - value
                    }
                }
                frame[i] = value
            }

            frames.append(normalizePeak(frame))
        }

        return Wavetable(name: "Digital", frames: frames)
    }

    private static func generatePWMWaves() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 32

        for f in 0..<numFrames {
            var frame = [Float](repeating: 0.0, count: tableSize)
            let pulseWidth = 0.1 + 0.8 * Float(f) / Float(numFrames - 1)

            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize)
                frame[i] = phase < pulseWidth ? 1.0 : -1.0
            }

            for _ in 0..<3 {
                var smoothed = frame
                for i in 1..<(tableSize - 1) {
                    smoothed[i] = (frame[i - 1] + frame[i] * 2.0 + frame[i + 1]) / 4.0
                }
                frame = smoothed
            }

            frames.append(normalizePeak(frame))
        }

        return Wavetable(name: "PWM", frames: frames)
    }

    private static func generateFormantWaves() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 16

        let vowelFormants: [[Float]] = [
            [1.0, 2.5, 3.5],
            [1.0, 4.0, 5.0],
            [1.0, 3.5, 4.5],
            [1.0, 2.0, 3.0],
            [1.0, 1.5, 2.5],
        ]

        for f in 0..<numFrames {
            var frame = [Float](repeating: 0.0, count: tableSize)
            let vowelPos = Float(f) / Float(numFrames - 1) * Float(vowelFormants.count - 1)
            let vowelIndex = Int(vowelPos)
            let vowelFrac = vowelPos - Float(vowelIndex)

            let formants1 = vowelFormants[vowelIndex]
            let formants2 = vowelFormants[min(vowelIndex + 1, vowelFormants.count - 1)]

            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize) * 2.0 * Float.pi
                var sum: Float = 0.0

                for (idx, (f1, f2)) in zip(formants1, formants2).enumerated() {
                    let formant = f1 + (f2 - f1) * vowelFrac
                    let amplitude = 1.0 / Float(idx + 1)
                    sum += amplitude * sin(phase * formant)
                }

                frame[i] = sum
            }

            frames.append(normalizePeak(frame))
        }

        return Wavetable(name: "Formant", frames: frames)
    }
}
