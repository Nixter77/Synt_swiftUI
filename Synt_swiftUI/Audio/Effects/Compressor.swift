//
//  Compressor.swift
//  Synt_swiftUI
//
//  Dynamic range compressor with optional limiter mode.
//

import Foundation

final class Compressor {
    
    // MARK: - Parameters
    
    /// Threshold in dB (-60 to 0)
    var threshold: Float = -12.0
    
    /// Ratio (1:1 to inf:1, stored as 1.0 to 20.0)
    var ratio: Float = 4.0
    
    /// Attack time in seconds (0.001 to 0.5)
    var attack: Float = 0.01
    
    /// Release time in seconds (0.01 to 2.0)
    var release: Float = 0.2
    
    /// Makeup gain in dB (0 to 24)
    var makeupGain: Float = 0.0
    
    /// Knee width in dB (0 = hard knee, up to 12 = soft knee)
    var kneeWidth: Float = 6.0
    
    /// Enable limiter mode (infinite ratio, brick wall)
    var limiterMode: Bool = false
    
    var enabled: Bool = false
    
    // MARK: - State
    
    private var envelope: Float = 0.0
    private var gainReduction: Float = 0.0
    private let sampleRate: Float
    
    // Coefficient cache
    private var attackCoeff: Float = 0.0
    private var releaseCoeff: Float = 0.0
    private var paramsDirty: Bool = true
    
    // MARK: - Init
    
    init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }
    
    // MARK: - Processing
    
    @inline(__always)
    func process(_ input: Float) -> Float {
        guard enabled else { return input }
        
        if paramsDirty {
            updateCoefficients()
            paramsDirty = false
        }
        
        // Get input level in dB
        let inputAbs = abs(input)
        let inputDB = inputAbs > 0.000001 ? 20.0 * log10(inputAbs) : -120.0
        
        // Calculate gain reduction needed
        let targetGainReduction = calculateGainReduction(inputDB: inputDB)
        
        // Envelope follower with attack/release.
        // Limiter mode must catch the first transient immediately; smoothing the
        // attack lets overshoot through on exactly the peak we are trying to stop.
        if targetGainReduction > gainReduction {
            gainReduction = limiterMode
                ? targetGainReduction
                : gainReduction + attackCoeff * (targetGainReduction - gainReduction)
        } else {
            // Releasing (gain reduction decreasing)
            gainReduction += releaseCoeff * (targetGainReduction - gainReduction)
        }
        
        // Apply gain reduction and makeup
        let totalGainDB = -gainReduction + makeupGain
        let linearGain = pow(10.0, totalGainDB / 20.0)
        let output = input * linearGain

        return limiterMode ? max(-1.0, min(1.0, output)) : output
    }
    
    /// Process stereo pair (linked detection)
    @inline(__always)
    func processStereo(inputL: Float, inputR: Float) -> (Float, Float) {
        guard enabled else { return (inputL, inputR) }
        
        if paramsDirty {
            updateCoefficients()
            paramsDirty = false
        }
        
        // Linked stereo: use max of both channels for detection
        let inputAbs = max(abs(inputL), abs(inputR))
        let inputDB = inputAbs > 0.000001 ? 20.0 * log10(inputAbs) : -120.0
        
        // Calculate gain reduction needed
        let targetGainReduction = calculateGainReduction(inputDB: inputDB)
        
        // Envelope follower with attack/release.
        // Limiter mode must catch the first transient immediately; smoothing the
        // attack lets overshoot through on exactly the peak we are trying to stop.
        if targetGainReduction > gainReduction {
            gainReduction = limiterMode
                ? targetGainReduction
                : gainReduction + attackCoeff * (targetGainReduction - gainReduction)
        } else {
            gainReduction += releaseCoeff * (targetGainReduction - gainReduction)
        }
        
        // Apply gain reduction and makeup
        let totalGainDB = -gainReduction + makeupGain
        let linearGain = pow(10.0, totalGainDB / 20.0)
        let outputL = inputL * linearGain
        let outputR = inputR * linearGain

        if limiterMode {
            return (
                max(-1.0, min(1.0, outputL)),
                max(-1.0, min(1.0, outputR))
            )
        }

        return (outputL, outputR)
    }
    
    @inline(__always)
    private func calculateGainReduction(inputDB: Float) -> Float {
        let effectiveRatio = limiterMode ? Float.infinity : ratio
        let effectiveThreshold = limiterMode ? -0.1 : threshold  // Near 0 dB for limiter
        
        if kneeWidth < 0.1 {
            // Hard knee
            if inputDB <= effectiveThreshold {
                return 0.0
            } else {
                return (inputDB - effectiveThreshold) * (1.0 - 1.0 / effectiveRatio)
            }
        } else {
            // Soft knee
            let kneeStart = effectiveThreshold - kneeWidth / 2.0
            let kneeEnd = effectiveThreshold + kneeWidth / 2.0
            
            if inputDB <= kneeStart {
                return 0.0
            } else if inputDB >= kneeEnd {
                return (inputDB - effectiveThreshold) * (1.0 - 1.0 / effectiveRatio)
            } else {
                // In the knee region - interpolate
                let kneePosition = (inputDB - kneeStart) / kneeWidth
                let compressionAmount = (1.0 - 1.0 / effectiveRatio) * kneePosition * kneePosition
                let overshoot = inputDB - effectiveThreshold + kneeWidth / 2.0
                return overshoot * compressionAmount
            }
        }
    }
    
    private func updateCoefficients() {
        // Convert time constants to coefficients
        attackCoeff = 1.0 - exp(-1.0 / (attack * sampleRate))
        releaseCoeff = 1.0 - exp(-1.0 / (release * sampleRate))
    }
    
    /// Get current gain reduction in dB (for metering)
    var currentGainReduction: Float {
        return gainReduction
    }
    
    func reset() {
        envelope = 0.0
        gainReduction = 0.0
        paramsDirty = true
    }
    
    func setAttack(_ value: Float) {
        attack = max(0.001, min(0.5, value))
        paramsDirty = true
    }
    
    func setRelease(_ value: Float) {
        release = max(0.01, min(2.0, value))
        paramsDirty = true
    }
}
