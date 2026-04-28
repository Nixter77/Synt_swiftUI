//
//  Phaser.swift
//  Synt_swiftUI
//
//  Stereo Phaser/Flanger effect with multiple all-pass stages.
//

import Foundation

enum PhaserMode: String, CaseIterable, Codable {
    case phaser2 = "Phaser 2"
    case phaser4 = "Phaser 4"
    case phaser6 = "Phaser 6"
    case phaser8 = "Phaser 8"
    case flanger = "Flanger"
    case chorus = "Chorus"
    
    var stageCount: Int {
        switch self {
        case .phaser2: return 2
        case .phaser4: return 4
        case .phaser6: return 6
        case .phaser8: return 8
        case .flanger: return 0
        case .chorus: return 0
        }
    }
}

final class Phaser {
    
    // MARK: - Parameters
    
    /// LFO rate in Hz (0.01 to 10)
    var rate: Float = 0.5 {
        didSet { rate = max(0.01, min(10.0, rate)) }
    }
    
    /// Modulation depth (0 to 1)
    var depth: Float = 0.7 {
        didSet { depth = max(0.0, min(1.0, depth)) }
    }
    
    /// Feedback amount (-0.99 to 0.99)
    var feedback: Float = 0.5 {
        didSet { feedback = max(-0.99, min(0.99, feedback)) }
    }
    
    /// Center frequency in Hz (100 to 5000)
    var centerFrequency: Float = 1000 {
        didSet { centerFrequency = max(100, min(5000, centerFrequency)) }
    }
    
    /// Stereo spread (0 to 1) - LFO phase difference between L/R
    var stereoSpread: Float = 0.5 {
        didSet { stereoSpread = max(0.0, min(1.0, stereoSpread)) }
    }
    
    /// Dry/Wet mix (0 to 1)
    var mix: Float = 0.5 {
        didSet { mix = max(0.0, min(1.0, mix)) }
    }
    
    /// Current mode
    var mode: PhaserMode = .phaser4
    
    /// Bypass
    var bypass: Bool = false
    
    // MARK: - Internal State
    
    private var sampleRate: Float = 44100
    private var lfoPhaseL: Float = 0
    private var lfoPhaseR: Float = 0
    
    // All-pass filter states (8 stages max, stereo)
    private var allpassStatesL: [Float] = Array(repeating: 0, count: 8)
    private var allpassStatesR: [Float] = Array(repeating: 0, count: 8)
    
    // Delay line for flanger/chorus modes
    private let maxDelayMs: Float = 20.0
    private var delayBufferL: [Float] = []
    private var delayBufferR: [Float] = []
    private var delayWriteIndex: Int = 0
    
    // Feedback state
    private var feedbackL: Float = 0
    private var feedbackR: Float = 0
    
    // MARK: - Initialization
    
    init(sampleRate: Float = 44100) {
        self.sampleRate = sampleRate
        
        // Initialize delay buffer for flanger/chorus
        let maxDelaySamples = Int(sampleRate * maxDelayMs / 1000.0)
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
    }
    
    // MARK: - Processing
    
    func process(inputL: Float, inputR: Float) -> (left: Float, right: Float) {
        guard !bypass else { return (inputL, inputR) }
        
        // Update LFO
        let lfoIncrement = rate / sampleRate
        lfoPhaseL += lfoIncrement
        if lfoPhaseL >= 1.0 { lfoPhaseL -= 1.0 }
        
        // Right channel LFO with stereo spread offset
        lfoPhaseR = lfoPhaseL + stereoSpread * 0.5
        if lfoPhaseR >= 1.0 { lfoPhaseR -= 1.0 }
        
        // Calculate LFO values (sine wave)
        let lfoL = sin(lfoPhaseL * 2 * .pi)
        let lfoR = sin(lfoPhaseR * 2 * .pi)
        
        var outL: Float
        var outR: Float
        
        switch mode {
        case .phaser2, .phaser4, .phaser6, .phaser8:
            (outL, outR) = processPhaserMode(inputL: inputL, inputR: inputR, lfoL: lfoL, lfoR: lfoR)
        case .flanger:
            (outL, outR) = processFlangerMode(inputL: inputL, inputR: inputR, lfoL: lfoL, lfoR: lfoR)
        case .chorus:
            (outL, outR) = processChorusMode(inputL: inputL, inputR: inputR, lfoL: lfoL, lfoR: lfoR)
        }
        
        // Mix dry/wet
        let dryL = inputL * (1.0 - mix)
        let dryR = inputR * (1.0 - mix)
        let wetL = outL * mix
        let wetR = outR * mix
        
        return (dryL + wetL, dryR + wetR)
    }
    
    // MARK: - Phaser Processing
    
    private func processPhaserMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        // Calculate modulated frequencies
        let modL = depth * lfoL
        let modR = depth * lfoR
        
        // Frequency range: centerFrequency * 0.5 to centerFrequency * 2
        let freqL = centerFrequency * (1.0 + modL * 0.5)
        let freqR = centerFrequency * (1.0 + modR * 0.5)
        
        // Add feedback
        var sampleL = inputL + feedbackL * feedback
        var sampleR = inputR + feedbackR * feedback
        
        // Process through all-pass filter stages
        let stageCount = mode.stageCount
        for i in 0..<stageCount {
            // Calculate all-pass coefficient for this stage
            // Each stage is offset in frequency
            let stageOffset = Float(i) / Float(stageCount)
            let stageFreqL = freqL * pow(2.0, stageOffset * 2.0)
            let stageFreqR = freqR * pow(2.0, stageOffset * 2.0)
            
            let coeffL = calculateAllpassCoeff(frequency: stageFreqL)
            let coeffR = calculateAllpassCoeff(frequency: stageFreqR)
            
            // Process all-pass filter
            sampleL = processAllpass(input: sampleL, coeff: coeffL, state: &allpassStatesL[i])
            sampleR = processAllpass(input: sampleR, coeff: coeffR, state: &allpassStatesR[i])
        }
        
        // Store feedback
        feedbackL = sampleL
        feedbackR = sampleR
        
        return (sampleL, sampleR)
    }
    
    // MARK: - Flanger Processing
    
    private func processFlangerMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        // Flanger uses short delay modulation (0.1 - 5 ms)
        let minDelayMs: Float = 0.1
        let maxFlangerDelayMs: Float = 5.0
        
        let delayMsL = minDelayMs + (maxFlangerDelayMs - minDelayMs) * (0.5 + 0.5 * lfoL * depth)
        let delayMsR = minDelayMs + (maxFlangerDelayMs - minDelayMs) * (0.5 + 0.5 * lfoR * depth)
        
        // Write to delay buffer
        delayBufferL[delayWriteIndex] = inputL + feedbackL * feedback
        delayBufferR[delayWriteIndex] = inputR + feedbackR * feedback
        
        // Read from delay buffer with interpolation
        let outL = readDelayInterpolated(buffer: delayBufferL, delayMs: delayMsL)
        let outR = readDelayInterpolated(buffer: delayBufferR, delayMs: delayMsR)
        
        // Update feedback
        feedbackL = outL
        feedbackR = outR
        
        // Increment write index
        delayWriteIndex += 1
        if delayWriteIndex >= delayBufferL.count {
            delayWriteIndex = 0
        }
        
        return (outL, outR)
    }
    
    // MARK: - Chorus Processing
    
    private func processChorusMode(inputL: Float, inputR: Float, lfoL: Float, lfoR: Float) -> (Float, Float) {
        // Chorus uses longer delay modulation (5 - 20 ms)
        let minDelayMs: Float = 5.0
        let maxChorusDelayMs: Float = 15.0
        
        let delayMsL = minDelayMs + (maxChorusDelayMs - minDelayMs) * (0.5 + 0.5 * lfoL * depth)
        let delayMsR = minDelayMs + (maxChorusDelayMs - minDelayMs) * (0.5 + 0.5 * lfoR * depth)
        
        // Write to delay buffer (no feedback for chorus typically)
        delayBufferL[delayWriteIndex] = inputL
        delayBufferR[delayWriteIndex] = inputR
        
        // Read from delay buffer with interpolation
        let outL = readDelayInterpolated(buffer: delayBufferL, delayMs: delayMsL)
        let outR = readDelayInterpolated(buffer: delayBufferR, delayMs: delayMsR)
        
        // Increment write index
        delayWriteIndex += 1
        if delayWriteIndex >= delayBufferL.count {
            delayWriteIndex = 0
        }
        
        // For chorus, mix original with delayed
        return (outL, outR)
    }
    
    // MARK: - Utility Functions
    
    @inline(__always)
    private func calculateAllpassCoeff(frequency: Float) -> Float {
        // First-order all-pass coefficient
        let tan_half_wc = tan(.pi * frequency / sampleRate)
        return (tan_half_wc - 1.0) / (tan_half_wc + 1.0)
    }
    
    @inline(__always)
    private func processAllpass(input: Float, coeff: Float, state: inout Float) -> Float {
        // First-order all-pass filter: y[n] = a*(x[n] - y[n-1]) + x[n-1]
        // Where state holds x[n-1] and we track y[n-1] implicitly
        let output = coeff * input + state - coeff * state
        state = input
        return output
    }
    
    @inline(__always)
    private func readDelayInterpolated(buffer: [Float], delayMs: Float) -> Float {
        let delaySamples = delayMs * sampleRate / 1000.0
        let readPos = Float(delayWriteIndex) - delaySamples
        
        var readIndex = Int(readPos)
        var frac = readPos - Float(readIndex)
        
        // Wrap if necessary
        while readIndex < 0 {
            readIndex += buffer.count
        }
        while readIndex >= buffer.count {
            readIndex -= buffer.count
        }
        
        // Ensure frac is positive
        if frac < 0 {
            frac += 1.0
            readIndex -= 1
            if readIndex < 0 { readIndex += buffer.count }
        }
        
        let nextIndex = (readIndex + 1) % buffer.count
        
        // Linear interpolation
        return buffer[readIndex] * (1.0 - frac) + buffer[nextIndex] * frac
    }
    
    // MARK: - Reset
    
    func reset() {
        lfoPhaseL = 0
        lfoPhaseR = 0
        allpassStatesL = Array(repeating: 0, count: 8)
        allpassStatesR = Array(repeating: 0, count: 8)
        delayBufferL = Array(repeating: 0, count: delayBufferL.count)
        delayBufferR = Array(repeating: 0, count: delayBufferR.count)
        delayWriteIndex = 0
        feedbackL = 0
        feedbackR = 0
    }
    
    func setSampleRate(_ newSampleRate: Float) {
        sampleRate = newSampleRate
        let maxDelaySamples = Int(sampleRate * maxDelayMs / 1000.0)
        delayBufferL = Array(repeating: 0, count: maxDelaySamples)
        delayBufferR = Array(repeating: 0, count: maxDelaySamples)
        delayWriteIndex = 0
    }
}
