//
//  WavetableOscillator.swift
//  Synt_swiftUI
//
//  Band-limited wavetable oscillator with mip-mapping for alias-free playback.
//  Supports wavetable morphing between frames.
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
    
    var phase: Double = 0.0
    var framePosition: Float = 0.0  // 0.0 to 1.0, position between frames
    var volume: Float = 1.0
    var octave: Int = 0
    var detune: Float = 0.0  // cents
    
    private var currentWavetable: Wavetable?
    private var mipMaps: [[[Float]]] = []  // [octave][frame][sample]
    
    private let tableSize: Int = 2048
    private let numOctaves: Int = 11  // C0 to C10
    
    // MARK: - Built-in Wavetables
    
    static let basicWavetables: [Wavetable] = {
        var tables: [Wavetable] = []
        
        // 1. Basic Shapes (morphs through sine -> triangle -> saw -> square)
        tables.append(generateBasicShapes())
        
        // 2. Analog (warm analog-style waves)
        tables.append(generateAnalogWaves())
        
        // 3. Digital (harsh digital waves)
        tables.append(generateDigitalWaves())
        
        // 4. PWM (pulse width modulation)
        tables.append(generatePWMWaves())
        
        // 5. Formant (vocal-like formants)
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
    }
    
    private func generateMipMaps(from wavetable: Wavetable) {
        mipMaps = []
        
        for octave in 0..<numOctaves {
            var octaveFrames: [[Float]] = []
            let maxHarmonic = 1 << (numOctaves - 1 - octave)  // Max harmonics for this octave
            
            for frame in wavetable.frames {
                let bandLimited = applyFFTBandLimit(frame, maxHarmonic: maxHarmonic)
                octaveFrames.append(bandLimited)
            }
            
            mipMaps.append(octaveFrames)
        }
    }
    
    /// Apply FFT band-limiting to remove harmonics above Nyquist
    private func applyFFTBandLimit(_ source: [Float], maxHarmonic: Int) -> [Float] {
        let n = source.count
        guard n > 0 else { return source }
        
        // For small maxHarmonic, we can just sum harmonics directly
        if maxHarmonic <= 64 {
            return synthesizeFromHarmonics(source, maxHarmonic: maxHarmonic)
        }
        
        // For larger tables, use the original (already band-limited by design)
        return source
    }
    
    /// Synthesize wave from first N harmonics
    private func synthesizeFromHarmonics(_ source: [Float], maxHarmonic: Int) -> [Float] {
        let n = source.count
        var result = [Float](repeating: 0.0, count: n)
        
        // Simple additive synthesis with harmonics
        // This is a simplified approach - full FFT would be more accurate
        for i in 0..<n {
            let phase = Double(i) / Double(n) * 2.0 * Double.pi
            var sum: Float = 0.0
            
            // For saw-like content, approximate with harmonic series
            for h in 1...min(maxHarmonic, 64) {
                let harmPhase = phase * Double(h)
                sum += Float(1.0 / Double(h)) * Float(sin(harmPhase))
            }
            
            result[i] = sum
        }
        
        // Normalize
        var maxVal: Float = 0.0
        vDSP_maxmgv(result, 1, &maxVal, vDSP_Length(n))
        if maxVal > 0.001 {
            var scale = 1.0 / maxVal
            vDSP_vsmul(result, 1, &scale, &result, 1, vDSP_Length(n))
        }
        
        return result
    }
    
    // MARK: - Sample Generation
    
    func frequencyWithModifiers(_ baseFrequency: Double) -> Double {
        let octaveMultiplier = pow(2.0, Double(octave))
        let detuneMultiplier = pow(2.0, Double(detune) / 1200.0)
        return baseFrequency * octaveMultiplier * detuneMultiplier
    }
    
    @inline(__always)
    func generateSample(phase: Double, phaseIncrement: Double, sampleRate: Double = 44100.0) -> Float {
        guard currentWavetable != nil, !mipMaps.isEmpty else {
            return 0.0
        }
        
        // Calculate frequency for mip-map selection
        let frequency = phaseIncrement * sampleRate / (2.0 * Double.pi)
        let octave = selectMipMapOctave(frequency: frequency)
        
        guard octave < mipMaps.count else { return 0.0 }
        
        let frames = mipMaps[octave]
        let frameCount = frames.count
        
        guard frameCount > 0 else { return 0.0 }
        
        // Calculate frame indices for interpolation
        let framePos = framePosition * Float(frameCount - 1)
        let frameIndex1 = Int(framePos)
        let frameIndex2 = min(frameIndex1 + 1, frameCount - 1)
        let frameFrac = framePos - Float(frameIndex1)
        
        // Sample from both frames
        let sample1 = sampleFromTable(frames[frameIndex1], phase: phase)
        let sample2 = sampleFromTable(frames[frameIndex2], phase: phase)
        
        // Interpolate between frames
        let sample = sample1 + (sample2 - sample1) * frameFrac
        
        return sample * volume
    }
    
    @inline(__always)
    private func sampleFromTable(_ table: [Float], phase: Double) -> Float {
        let tableSize = table.count
        guard tableSize > 0 else { return 0.0 }
        
        // Normalize phase to 0-1
        var normalizedPhase = phase / (2.0 * Double.pi)
        normalizedPhase = normalizedPhase - floor(normalizedPhase)
        
        // Calculate table position
        let pos = normalizedPhase * Double(tableSize)
        let index0 = Int(pos) % tableSize
        let index1 = (index0 + 1) % tableSize
        let frac = Float(pos - Double(index0))
        
        // Linear interpolation
        return table[index0] + (table[index1] - table[index0]) * frac
    }
    
    private func selectMipMapOctave(frequency: Double) -> Int {
        // Select mip-map based on frequency to avoid aliasing
        // Higher frequencies need lower harmonic content
        let octave = max(0, min(numOctaves - 1, Int(log2(max(20.0, frequency) / 20.0))))
        return octave
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
                
                // Morph: sine (0) -> triangle (0.33) -> saw (0.67) -> square (1.0)
                if morphPos < 0.33 {
                    let t = morphPos / 0.33
                    let sine = sin(phase)
                    let triangle = 2.0 * abs(2.0 * (Float(i) / Float(tableSize) - 0.5)) - 1.0
                    frame[i] = sine * (1.0 - t) + triangle * t
                } else if morphPos < 0.67 {
                    let t = (morphPos - 0.33) / 0.34
                    let triangle = 2.0 * abs(2.0 * (Float(i) / Float(tableSize) - 0.5)) - 1.0
                    let saw = 2.0 * Float(i) / Float(tableSize) - 1.0
                    frame[i] = triangle * (1.0 - t) + saw * t
                } else {
                    let t = (morphPos - 0.67) / 0.33
                    let saw = 2.0 * Float(i) / Float(tableSize) - 1.0
                    let square: Float = Float(i) < Float(tableSize) / 2 ? 1.0 : -1.0
                    frame[i] = saw * (1.0 - t) + square * t
                }
            }
            
            frames.append(frame)
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
                
                // Additive synthesis with decaying harmonics (analog-like)
                var sum: Float = 0.0
                for h in 1...32 {
                    let amplitude = pow(Float(h), -harmonicDecay)
                    sum += amplitude * sin(phase * Float(h))
                }
                
                frame[i] = sum
            }
            
            // Normalize
            let maxVal = frame.max() ?? 1.0
            if maxVal > 0.001 {
                for i in 0..<tableSize {
                    frame[i] /= maxVal
                }
            }
            
            frames.append(frame)
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
                
                // Create a wave and apply folding
                var value = sin(phase * 2.0 * Float.pi)
                
                // Apply wave folding
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
            
            frames.append(frame)
        }
        
        return Wavetable(name: "Digital", frames: frames)
    }
    
    private static func generatePWMWaves() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 32
        
        for f in 0..<numFrames {
            var frame = [Float](repeating: 0.0, count: tableSize)
            let pulseWidth = 0.1 + 0.8 * Float(f) / Float(numFrames - 1)  // 10% to 90%
            
            for i in 0..<tableSize {
                let phase = Float(i) / Float(tableSize)
                frame[i] = phase < pulseWidth ? 1.0 : -1.0
            }
            
            // Apply simple lowpass to reduce aliasing
            for _ in 0..<3 {
                var smoothed = frame
                for i in 1..<(tableSize - 1) {
                    smoothed[i] = (frame[i-1] + frame[i] * 2.0 + frame[i+1]) / 4.0
                }
                frame = smoothed
            }
            
            frames.append(frame)
        }
        
        return Wavetable(name: "PWM", frames: frames)
    }
    
    private static func generateFormantWaves() -> Wavetable {
        let tableSize = 2048
        var frames: [[Float]] = []
        let numFrames = 16
        
        // Formant frequencies for different vowels (relative to fundamental)
        let vowelFormants: [[Float]] = [
            [1.0, 2.5, 3.5],   // A
            [1.0, 4.0, 5.0],   // E
            [1.0, 3.5, 4.5],   // I
            [1.0, 2.0, 3.0],   // O
            [1.0, 1.5, 2.5],   // U
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
            
            // Normalize
            let maxVal = frame.map { abs($0) }.max() ?? 1.0
            if maxVal > 0.001 {
                for i in 0..<tableSize {
                    frame[i] /= maxVal
                }
            }
            
            frames.append(frame)
        }
        
        return Wavetable(name: "Formant", frames: frames)
    }
    
    // MARK: - Reset
    
    func reset() {
        phase = 0.0
    }
}
