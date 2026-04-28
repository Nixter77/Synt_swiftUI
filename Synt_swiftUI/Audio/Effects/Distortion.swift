//
//  Distortion.swift
//  Synt_swiftUI
//
//  Multiple distortion types for sound design.
//

import Foundation
import Accelerate

enum DistortionType: String, CaseIterable, Codable {
    case softClip = "Soft Clip"
    case hardClip = "Hard Clip"
    case tubeSaturation = "Tube"
    case tapeSaturation = "Tape"
    case bitcrusher = "Bitcrush"
    case wavefolder = "Wavefold"
}

final class Distortion {
    
    var type: DistortionType = .softClip
    var drive: Float = 0.5      // 0.0 to 1.0 -> maps to appropriate range per type
    var tone: Float = 0.5       // 0.0 (dark) to 1.0 (bright)
    var mix: Float = 0.5        // Dry/Wet
    var enabled: Bool = false
    
    // Internal state for filters
    private var lowpassState: Float = 0.0
    private var highpassState: Float = 0.0
    
    // For bitcrusher
    private var holdSample: Float = 0.0
    private var holdCounter: Int = 0
    
    init() {}
    
    @inline(__always)
    func process(_ input: Float) -> Float {
        guard enabled && mix > 0.001 else { return input }
        
        var processed: Float
        
        switch type {
        case .softClip:
            processed = processSoftClip(input)
        case .hardClip:
            processed = processHardClip(input)
        case .tubeSaturation:
            processed = processTube(input)
        case .tapeSaturation:
            processed = processTape(input)
        case .bitcrusher:
            processed = processBitcrush(input)
        case .wavefolder:
            processed = processWavefold(input)
        }
        
        // Apply tone control (simple one-pole filter)
        processed = applyTone(processed)
        
        // Mix dry/wet
        return input * (1.0 - mix) + processed * mix
    }
    
    // MARK: - Distortion Algorithms
    
    /// Soft clipping using tanh - warm and musical
    @inline(__always)
    private func processSoftClip(_ input: Float) -> Float {
        let gain = 1.0 + drive * 10.0  // 1x to 11x gain
        let driven = input * gain
        return tanh(driven)
    }
    
    /// Hard clipping - aggressive and digital
    @inline(__always)
    private func processHardClip(_ input: Float) -> Float {
        let gain = 1.0 + drive * 15.0  // 1x to 16x gain
        let threshold = 1.0 - drive * 0.7  // Lower threshold = more clipping
        let driven = input * gain
        return max(-threshold, min(threshold, driven))
    }
    
    /// Tube saturation - asymmetric soft clipping
    @inline(__always)
    private func processTube(_ input: Float) -> Float {
        let gain = 1.0 + drive * 8.0
        let driven = input * gain
        
        // Asymmetric saturation using different curves for +/-
        if driven >= 0 {
            // Positive half: softer saturation
            return 1.0 - exp(-driven)
        } else {
            // Negative half: slightly harder saturation (tube-like asymmetry)
            return -tanh(-driven * 1.2)
        }
    }
    
    /// Tape saturation - smooth compression with harmonics
    @inline(__always)
    private func processTape(_ input: Float) -> Float {
        let gain = 1.0 + drive * 5.0
        var driven = input * gain
        
        // Tape-style soft saturation
        let x = driven
        if abs(x) < 0.333 {
            driven = 2.0 * x
        } else if abs(x) < 0.667 {
            let sign: Float = x >= 0 ? 1.0 : -1.0
            let absX = abs(x)
            driven = sign * (3.0 - pow(2.0 - 3.0 * absX, 2.0)) / 3.0
        } else {
            driven = x >= 0 ? 1.0 : -1.0
        }
        
        return driven
    }
    
    /// Bitcrusher - reduce bit depth and sample rate
    @inline(__always)
    private func processBitcrush(_ input: Float) -> Float {
        // Bit depth reduction
        let bits = Int(16.0 - drive * 12.0)  // 16 bits down to 4 bits
        let levels = Float(1 << bits)
        let quantized = floor(input * levels + 0.5) / levels
        
        // Sample rate reduction (simple hold)
        let holdLength = Int(1.0 + drive * 31.0)  // 1 to 32 samples hold
        holdCounter += 1
        if holdCounter >= holdLength {
            holdCounter = 0
            holdSample = quantized
        }
        
        return holdSample
    }
    
    /// Wavefolder - folds the wave back on itself
    @inline(__always)
    private func processWavefold(_ input: Float) -> Float {
        let gain = 1.0 + drive * 8.0
        var value = input * gain
        
        // Fold the wave
        let folds = Int(1.0 + drive * 4.0)  // 1 to 5 folds
        for _ in 0..<folds {
            if value > 1.0 {
                value = 2.0 - value
            } else if value < -1.0 {
                value = -2.0 - value
            }
        }
        
        // Additional folding for extreme drive
        while abs(value) > 1.0 {
            if value > 1.0 {
                value = 2.0 - value
            } else if value < -1.0 {
                value = -2.0 - value
            }
        }
        
        return value * 0.8  // Slight output reduction
    }
    
    // MARK: - Tone Control
    
    /// Simple one-pole lowpass/highpass for tone control
    @inline(__always)
    private func applyTone(_ input: Float) -> Float {
        // Tone at 0.5 = neutral
        // Below 0.5 = lowpass (darker)
        // Above 0.5 = highpass boost (brighter)
        
        if tone < 0.5 {
            // Lowpass
            let cutoff = 0.1 + tone * 1.8  // 0.1 to 1.0
            lowpassState = lowpassState + cutoff * (input - lowpassState)
            return lowpassState
        } else if tone > 0.5 {
            // Highpass blend
            let amount = (tone - 0.5) * 2.0
            let cutoff: Float = 0.05
            highpassState = highpassState + cutoff * (input - highpassState)
            let highpassed = input - highpassState
            return input + highpassed * amount * 2.0
        } else {
            return input
        }
    }
    
    func reset() {
        lowpassState = 0.0
        highpassState = 0.0
        holdSample = 0.0
        holdCounter = 0
    }
}
