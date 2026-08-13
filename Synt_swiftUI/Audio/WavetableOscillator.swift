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

/// A single wavetable containing multiple frames
struct Wavetable {
    let name: String
    let frames: [[Float]]  // [frameIndex][sampleIndex]
    let frameCount: Int
    let samplesPerFrame: Int

    init(name: String, frames: [[Float]]) {
        self.name = name
        self.frames = frames
        self.frameCount = frames.count
        self.samplesPerFrame = frames.first?.count ?? 2048
    }
}

/// Band-limited wavetable oscillator with mip-mapping
final class WavetableOscillator {

    // MARK: - Properties

    /// Morph position target 0…1 (UI / preset writes here).
    var targetFramePosition: Float = 0.0 {
        didSet {
            targetFramePosition = max(0, min(1, targetFramePosition))
        }
    }

    /// Smoothed morph position used for rendering (audio thread advances this).
    private(set) var framePosition: Float = 0.0

    /// Kept for API compatibility; **not** applied in `generateSample` (avoid double volume).
    var volume: Float = 1.0
    var octave: Int = 0
    var detune: Float = 0.0  // cents

    /// One-pole toward targetFramePosition per sample (~5 ms @ 44.1 kHz).
    var morphSmoothingCoeff: Float = 0.002

    private var currentWavetable: Wavetable?
    private var mipMaps: [[[Float]]] = []  // [octave][frame][sample]

    private let tableSize: Int = 2048
    private let numOctaves: Int = 11  // C0 to C10

    // MARK: - Built-in Wavetables

    static let basicWavetables: [Wavetable] = {
        var tables: [Wavetable] = []
        tables.append(generateBasicShapes())
        tables.append(generateAnalogWaves())
        tables.append(generateDigitalWaves())
        tables.append(generatePWMWaves())
        tables.append(generateFormantWaves())
        return tables
    }()

    // MARK: - Initialization

    init() {
        loadWavetable(Self.basicWavetables[0])
    }

    // MARK: - Wavetable Loading

    func loadWavetable(_ wavetable: Wavetable) {
        currentWavetable = wavetable
        generateMipMaps(from: wavetable)
        framePosition = targetFramePosition
    }

    func loadBuiltin(index: Int) {
        let tables = Self.basicWavetables
        guard !tables.isEmpty else { return }
        let i = max(0, min(tables.count - 1, index))
        loadWavetable(tables[i])
    }

    private func generateMipMaps(from wavetable: Wavetable) {
        mipMaps = []

        for octave in 0..<numOctaves {
            var octaveFrames: [[Float]] = []
            // Higher playback octaves → fewer partials below Nyquist.
            let maxHarmonic = max(1, 1 << (numOctaves - 1 - octave))

            for frame in wavetable.frames {
                let bandLimited = applyFFTBandLimit(frame, maxHarmonic: maxHarmonic)
                octaveFrames.append(bandLimited)
            }

            mipMaps.append(octaveFrames)
        }
    }

    // MARK: - FFT band-limit (source-preserving)

    /// Zero spectral bins above `maxHarmonic` on the **existing** frame, then IFFT.
    /// Does **not** resynthesize a generic saw series.
    func applyFFTBandLimit(_ source: [Float], maxHarmonic: Int) -> [Float] {
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
            return bandLimitWithComplexFFT(source, maxHarmonic: maxH)
        }

        return bandLimitWithDFT(source, maxHarmonic: maxH)
    }

    /// Full complex FFT band-limit: keep bins 0...maxH and conjugate mirrors, zero the rest.
    private func bandLimitWithComplexFFT(_ source: [Float], maxHarmonic: Int) -> [Float] {
        let n = source.count
        let log2n = vDSP_Length(log2(Double(n)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return bandLimitWithDFT(source, maxHarmonic: maxHarmonic)
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
    private func bandLimitWithDFT(_ source: [Float], maxHarmonic: Int) -> [Float] {
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

    static func normalizePeak(_ data: [Float]) -> [Float] {
        var result = data
        var maxVal: Float = 0
        vDSP_maxmgv(result, 1, &maxVal, vDSP_Length(result.count))
        guard maxVal > 0.0001 else { return result }
        var scale = 1.0 / maxVal
        vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(result.count))
        return result
    }

    // MARK: - Sample Generation

    func frequencyWithModifiers(_ baseFrequency: Double) -> Double {
        let octaveMultiplier = pow(2.0, Double(octave))
        let detuneMultiplier = pow(2.0, Double(detune) / 1200.0)
        return baseFrequency * octaveMultiplier * detuneMultiplier
    }

    /// Advance morph smoother **once per audio sample** (not once per voice).
    /// Call from the render path before iterating voices.
    @inline(__always)
    func advanceMorph() {
        let morphErr = targetFramePosition - framePosition
        framePosition += morphErr * morphSmoothingCoeff
    }

    /// Raw wavetable sample in ≈[-1, 1]. **Does not** multiply by `volume`
    /// (Oscillator applies volume once to avoid double gain / clipping).
    /// Does not advance morph — call `advanceMorph()` once per sample from the engine.
    @inline(__always)
    func generateSample(phase: Double, phaseIncrement: Double, sampleRate: Double = 44100.0) -> Float {
        guard currentWavetable != nil, !mipMaps.isEmpty else {
            return 0.0
        }

        let frequency = phaseIncrement * sampleRate / (2.0 * Double.pi)
        let exactOctave = log2(max(20.0, frequency) / 20.0)
        let oct0 = max(0, min(numOctaves - 1, Int(floor(exactOctave))))
        let oct1 = min(oct0 + 1, numOctaves - 1)
        let octFrac = Float(max(0, min(1, exactOctave - Double(oct0))))

        let s0 = sampleMorphed(mipOctave: oct0, phase: phase)
        if oct0 == oct1 || octFrac < 0.0001 {
            return s0
        }
        let s1 = sampleMorphed(mipOctave: oct1, phase: phase)
        return s0 + (s1 - s0) * octFrac
    }

    @inline(__always)
    private func sampleMorphed(mipOctave: Int, phase: Double) -> Float {
        guard mipOctave >= 0, mipOctave < mipMaps.count else { return 0 }
        let frames = mipMaps[mipOctave]
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

        var normalizedPhase = phase / (2.0 * Double.pi)
        normalizedPhase -= floor(normalizedPhase)

        let pos = normalizedPhase * Double(tableSize)
        let frac = Float(pos - floor(pos))
        let i0 = Int(pos) % tableSize

        // Short tables: linear. Normal 2048-point frames: 4-point Hermite.
        if tableSize < 4 {
            let i1 = (i0 + 1) % tableSize
            return table[i0] + (table[i1] - table[i0]) * frac
        }

        let y = Self.hermite4(
            ym1: table[(i0 - 1 + tableSize) % tableSize],
            y0: table[i0],
            y1: table[(i0 + 1) % tableSize],
            y2: table[(i0 + 2) % tableSize],
            t: frac
        )
        return max(-1.15, min(1.15, y))
    }

    /// Catmull-Rom / cubic Hermite. `t == 0` returns `y0` exactly.
    @inline(__always)
    static func hermite4(ym1: Float, y0: Float, y1: Float, y2: Float, t: Float) -> Float {
        let c1 = 0.5 * (y1 - ym1)
        let c2 = ym1 - 2.5 * y0 + 2.0 * y1 - 0.5 * y2
        let c3 = 0.5 * (y2 - ym1) + 1.5 * (y0 - y1)
        return ((c3 * t + c2) * t + c1) * t + y0
    }

    func reset() {
        // Phase is owned by ActiveNote; only reset morph smoother.
        framePosition = targetFramePosition
    }

    // MARK: - Test helpers

    /// Expose band-limit for unit tests without going through full mip chain.
    func bandLimitForTesting(_ source: [Float], maxHarmonic: Int) -> [Float] {
        applyFFTBandLimit(source, maxHarmonic: maxHarmonic)
    }

    func sampleFromTableForTesting(_ table: [Float], phase: Double) -> Float {
        sampleFromTable(table, phase: phase)
    }

    var mipOctaveCountForTesting: Int { mipMaps.count }
    var currentFrameCountForTesting: Int { mipMaps.first?.count ?? 0 }

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
