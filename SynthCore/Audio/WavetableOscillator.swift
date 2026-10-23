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

/// Errors during audio-file wavetable parsing
public enum WavetableError: LocalizedError {
    case insufficientSamples(found: Int, required: Int)
    case bufferCreationFailed
    case unsupportedAudioFormat

    public var errorDescription: String? {
        switch self {
        case .insufficientSamples(let found, let required):
            return "Wavetable requires at least \(required) samples, but file has \(found)."
        case .bufferCreationFailed:
            return "Failed to allocate audio buffer."
        case .unsupportedAudioFormat:
            return "Unsupported audio format. Float32 or PCM WAV is required."
        }
    }
}


/// A single wavetable containing multiple frames
public struct Wavetable {
    public let name: String
    public let frames: [[Float]]  // [frameIndex][sampleIndex]
    public let frameCount: Int
    public let samplesPerFrame: Int

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

    public static func deserialize(from data: Data, name: String = "User") -> Wavetable? {
        guard data.count >= 8 else { return nil }
        var fCount: Int32 = 0
        var sCount: Int32 = 0
        _ = withUnsafeMutableBytes(of: &fCount) { data.copyBytes(to: $0, from: 0..<4) }
        _ = withUnsafeMutableBytes(of: &sCount) { data.copyBytes(to: $0, from: 4..<8) }
        guard fCount > 0, sCount > 0, fCount <= 256, sCount <= 4096 else { return nil }
        let totalFloats = Int(fCount * sCount)
        guard data.count >= 8 + totalFloats * MemoryLayout<Float>.size else { return nil }

        var frames: [[Float]] = []
        frames.reserveCapacity(Int(fCount))
        var offset = 8
        for _ in 0..<fCount {
            var frame = [Float](repeating: 0, count: Int(sCount))
            frame.withUnsafeMutableBufferPointer { ptr in
                if let base = ptr.baseAddress {
                    _ = data.copyBytes(to: UnsafeMutableBufferPointer(start: base, count: Int(sCount)), from: offset..<(offset + Int(sCount) * 4))
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

/// Pre-compiled mipmapped wavetable ready for allocation-free render
public final class CompiledMipData: @unchecked Sendable {
    public let wavetable: Wavetable
    public let mipMaps: [[[Float]]]
    /// Harmonics kept per mip octave (Nyquist at the top of that octave).
    public let maxHarmonics: [Int]
    public init(wavetable: Wavetable, mipMaps: [[[Float]]], maxHarmonics: [Int] = []) {
        self.wavetable = wavetable
        self.mipMaps = mipMaps
        self.maxHarmonics = maxHarmonics
    }
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
    public private(set) var activeCompiled: CompiledMipData?

    // Triple buffer for RT lock-free handoff (Chen's wait-free 3-buffer algorithm)
    private static let hasNewDataFlag: Int = 0x80
    private let sharedBank = Atomic<Int>(0)
    private var writeBank: Int = 1
    private var readBank: Int = 2
    private let slots: UnsafeMutablePointer<Unmanaged<CompiledMipData>?>
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
    private static var compiledCache: [WavetableCacheKey: CompiledMipData] = [:]
    private static var inProgressKeys = Set<WavetableCacheKey>()

    public static func getCachedCompiled(for key: WavetableCacheKey) -> CompiledMipData? {
        os_unfair_lock_lock(cacheLock)
        defer { os_unfair_lock_unlock(cacheLock) }
        return compiledCache[key]
    }

    public static func setCachedCompiled(_ compiled: CompiledMipData, for key: WavetableCacheKey) {
        os_unfair_lock_lock(cacheLock)
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
        let key = WavetableCacheKey(contentHash: data.fnv1aHash(), sampleRate: sampleRate)
        os_unfair_lock_lock(cacheLock)
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
                os_unfair_lock_lock(cacheLock)
                inProgressKeys.remove(key)
                os_unfair_lock_unlock(cacheLock)
                return
            }
            let compiled = compile(wavetable: table, sampleRate: sampleRate)
            os_unfair_lock_lock(cacheLock)
            compiledCache[key] = compiled
            inProgressKeys.remove(key)
            os_unfair_lock_unlock(cacheLock)
            completion?(compiled)
        }
        return nil
    }

    public static func clearCacheForTesting() {
        os_unfair_lock_lock(cacheLock)
        defer { os_unfair_lock_unlock(cacheLock) }
        compiledCache.removeAll()
        inProgressKeys.removeAll()
    }

    public static var userWavetable: Wavetable?
    public static var userCompiledWavetable: CompiledMipData?
    public static var precompiledBuiltins: [Int: CompiledMipData] = [:]

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

    /// Parses a standard PCM / Float32 WAV or AIFF file (Serum format: 2048 samples per frame, up to maxFrames).
    public static func parseAudioFile(url: URL, samplesPerFrame: Int = 2048, maxFrames: Int = 64) throws -> Wavetable {
        let file = try AVAudioFile(forReading: url)
        let processingFormat = file.processingFormat
        let length = AVAudioFrameCount(file.length)
        guard length >= AVAudioFrameCount(samplesPerFrame) else {
            throw WavetableError.insufficientSamples(found: Int(length), required: samplesPerFrame)
        }
        let framesToRead = min(length, AVAudioFrameCount(samplesPerFrame * maxFrames))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: framesToRead) else {
            throw WavetableError.bufferCreationFailed
        }
        try file.read(into: buffer, frameCount: framesToRead)
        guard let channelData = buffer.floatChannelData else {
            throw WavetableError.unsupportedAudioFormat
        }
        let channelCount = Int(processingFormat.channelCount)
        let totalRead = Int(buffer.frameLength)
        let numFrames = min(maxFrames, totalRead / samplesPerFrame)
        guard numFrames > 0 else {
            throw WavetableError.insufficientSamples(found: totalRead, required: samplesPerFrame)
        }

        var frames: [[Float]] = []
        frames.reserveCapacity(numFrames)
        for f in 0..<numFrames {
            let offset = f * samplesPerFrame
            var frame = [Float](repeating: 0, count: samplesPerFrame)
            if channelCount > 1 {
                let ch0 = channelData[0]
                let ch1 = channelData[1]
                for i in 0..<samplesPerFrame {
                    frame[i] = (ch0[offset + i] + ch1[offset + i]) * 0.5
                }
            } else {
                let ch0 = channelData[0]
                for i in 0..<samplesPerFrame {
                    frame[i] = ch0[offset + i]
                }
            }
            frames.append(normalizePeak(frame))
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
            var frame = [Float](repeating: 0, count: samplesPerFrame)
            for i in 0..<samplesPerFrame {
                frame[i] = samples[offset + i]
            }
            frames.append(normalizePeak(frame))
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
            maxHarmonics: mipMaxHarmonics(count: maps.count, sampleRate: sampleRate)
        )
    }

    /// Partials kept per mip octave: Nyquist at the TOP of octave i
    /// (f in [20·2^i, 20·2^{i+1})), so a note at the bright end cannot alias.
    public static func mipMaxHarmonics(count: Int = 11, sampleRate: Double = 44100.0) -> [Int] {
        let nyquist = sampleRate * 0.5
        return (0..<count).map { octave in
            max(1, Int(floor(nyquist / (20.0 * pow(2.0, Double(octave + 1))))))
        }
    }

    /// Precomputes mipmap tables for all 11 octave ranges.
    public static func buildMipMaps(from wavetable: Wavetable, sampleRate: Double = 44100.0) -> [[[Float]]] {
        var maps: [[[Float]]] = []
        let numOctaves = 11
        let nyquist = sampleRate * 0.5
        for octave in 0..<numOctaves {
            let fHigh = 20.0 * pow(2.0, Double(octave + 1))
            let maxHarmonic = max(1, Int(floor(nyquist / fHigh)))
            var octaveFrames: [[Float]] = []
            for frame in wavetable.frames {
                octaveFrames.append(applyFFTBandLimitStatic(frame, maxHarmonic: maxHarmonic))
            }
            maps.append(octaveFrames)
        }
        return maps
    }

    /// Loads wavetable frames from an audio file, compiles mipmaps, and sets it as the active user table.
    public func loadFromAudioFile(url: URL) throws {
        let table = try Self.parseAudioFile(url: url)
        let serialized = table.serializedData()
        let key = WavetableCacheKey(contentHash: serialized.fnv1aHash(), sampleRate: mipSampleRate)
        let compiled: CompiledMipData
        if let cached = Self.getCachedCompiled(for: key) {
            compiled = cached
        } else {
            compiled = Self.compile(wavetable: table, sampleRate: mipSampleRate)
            Self.setCachedCompiled(compiled, for: key)
        }
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
        loadBuiltin(index: 0)
    }

    deinit {
        for i in 0..<3 {
            slots[i]?.release()
        }
        slots.deinitialize(count: 3)
        slots.deallocate()
        writeLock.deinitialize(count: 1)
        writeLock.deallocate()
    }

    // MARK: - Wavetable Loading

    public func loadCompiledWavetable(_ compiled: CompiledMipData) {
        currentWavetable = compiled.wavetable
        activeCompiled = compiled
        framePosition = targetFramePosition
        publishCompiled(compiled)
    }

    private func publishCompiled(_ compiled: CompiledMipData) {
        os_unfair_lock_lock(writeLock)
        let newRef = Unmanaged.passRetained(compiled)
        let oldRef = slots[writeBank]
        slots[writeBank] = newRef
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
        }
    }

    public func loadWavetable(_ wavetable: Wavetable) {
        let serialized = wavetable.serializedData()
        let key = WavetableCacheKey(contentHash: serialized.fnv1aHash(), sampleRate: mipSampleRate)
        let compiled: CompiledMipData
        if let cached = Self.getCachedCompiled(for: key) {
            compiled = cached
        } else {
            compiled = Self.compile(wavetable: wavetable, sampleRate: mipSampleRate)
            Self.setCachedCompiled(compiled, for: key)
        }
        loadCompiledWavetable(compiled)
    }

    /// Rebuild mip tables for a new Nyquist. Not safe on the render thread.
    public func setSampleRate(_ rate: Double) {
        let rate = max(8_000, rate)
        let changed = abs(rate - mipSampleRate) > 0.5
        mipSampleRate = rate
        morphSmoothingCoeff = Float(88.2 / rate)
        guard changed, let currentWavetable else { return }
        loadWavetable(currentWavetable)
    }

    public func loadBuiltin(index: Int) {
        if index == 5 {
            if let userCompiled = Self.userCompiledWavetable {
                loadCompiledWavetable(userCompiled)
            } else if let userTable = Self.userWavetable {
                loadWavetable(userTable)
                Self.userCompiledWavetable = activeCompiled
            } else {
                loadBuiltin(index: 0)
            }
            return
        }
        let i = max(0, min(Self.basicWavetables.count - 1, index))
        if let compiled = Self.precompiledBuiltins[i] {
            loadCompiledWavetable(compiled)
        } else {
            let table = Self.basicWavetables[i]
            let compiled = Self.compile(wavetable: table, sampleRate: mipSampleRate)
            Self.precompiledBuiltins[i] = compiled
            loadCompiledWavetable(compiled)
        }
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
        guard let unmanaged = slots[readBank] else {
            return 0.0
        }
        let compiled = unmanaged.takeUnretainedValue()
        let maps = compiled.mipMaps
        guard !maps.isEmpty else { return 0.0 }

        let frequency = phaseIncrement * sampleRate / (2.0 * Double.pi)
        // One mip, the table built for this octave range. Crossfading two
        // mips doubled Hermite work per voice and still used the hotter
        // (under-limited) table — 4 notes of that was the crunch.
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
        let tableSize = table.count
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
