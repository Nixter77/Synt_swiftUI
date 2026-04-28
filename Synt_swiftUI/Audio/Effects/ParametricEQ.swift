//
//  ParametricEQ.swift
//  Synt_swiftUI
//
//  3-band parametric EQ with low/mid/high controls.
//

import Foundation

final class ParametricEQ {
    
    // MARK: - Parameters
    
    /// Low band gain in dB (-24 to +24)
    var lowGain: Float = 0.0 {
        didSet { lowDirty = true }
    }
    
    /// Low band frequency (20-500 Hz)
    var lowFreq: Float = 100.0 {
        didSet { lowDirty = true }
    }
    
    /// Mid band gain in dB (-24 to +24)
    var midGain: Float = 0.0 {
        didSet { midDirty = true }
    }
    
    /// Mid band frequency (200-8000 Hz)
    var midFreq: Float = 1000.0 {
        didSet { midDirty = true }
    }
    
    /// Mid band Q (0.1 to 10)
    var midQ: Float = 1.0 {
        didSet { midDirty = true }
    }
    
    /// High band gain in dB (-24 to +24)
    var highGain: Float = 0.0 {
        didSet { highDirty = true }
    }
    
    /// High band frequency (2000-20000 Hz)
    var highFreq: Float = 8000.0 {
        didSet { highDirty = true }
    }
    
    var enabled: Bool = false
    
    private let sampleRate: Float
    
    // MARK: - Filter State
    
    // Low shelf filter coefficients and state
    private var lowB0: Float = 1, lowB1: Float = 0, lowB2: Float = 0
    private var lowA1: Float = 0, lowA2: Float = 0
    private var lowX1: Float = 0, lowX2: Float = 0
    private var lowY1: Float = 0, lowY2: Float = 0
    private var lowDirty: Bool = true
    
    // Mid peaking filter coefficients and state
    private var midB0: Float = 1, midB1: Float = 0, midB2: Float = 0
    private var midA1: Float = 0, midA2: Float = 0
    private var midX1: Float = 0, midX2: Float = 0
    private var midY1: Float = 0, midY2: Float = 0
    private var midDirty: Bool = true
    
    // High shelf filter coefficients and state
    private var highB0: Float = 1, highB1: Float = 0, highB2: Float = 0
    private var highA1: Float = 0, highA2: Float = 0
    private var highX1: Float = 0, highX2: Float = 0
    private var highY1: Float = 0, highY2: Float = 0
    private var highDirty: Bool = true
    
    // MARK: - Init
    
    init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
    }
    
    // MARK: - Processing
    
    @inline(__always)
    func process(_ input: Float) -> Float {
        guard enabled else { return input }
        
        // Recalculate coefficients if needed
        if lowDirty { calculateLowShelf(); lowDirty = false }
        if midDirty { calculateMidPeak(); midDirty = false }
        if highDirty { calculateHighShelf(); highDirty = false }
        
        // Apply low shelf
        var sample = processBiquad(
            input,
            b0: lowB0, b1: lowB1, b2: lowB2, a1: lowA1, a2: lowA2,
            x1: &lowX1, x2: &lowX2, y1: &lowY1, y2: &lowY2
        )
        
        // Apply mid peak
        sample = processBiquad(
            sample,
            b0: midB0, b1: midB1, b2: midB2, a1: midA1, a2: midA2,
            x1: &midX1, x2: &midX2, y1: &midY1, y2: &midY2
        )
        
        // Apply high shelf
        sample = processBiquad(
            sample,
            b0: highB0, b1: highB1, b2: highB2, a1: highA1, a2: highA2,
            x1: &highX1, x2: &highX2, y1: &highY1, y2: &highY2
        )
        
        return sample
    }
    
    @inline(__always)
    private func processBiquad(
        _ input: Float,
        b0: Float, b1: Float, b2: Float, a1: Float, a2: Float,
        x1: inout Float, x2: inout Float, y1: inout Float, y2: inout Float
    ) -> Float {
        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        
        // Update state
        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        
        return output
    }
    
    // MARK: - Coefficient Calculation
    
    private func calculateLowShelf() {
        let A = pow(10.0, lowGain / 40.0)
        let omega = 2.0 * Float.pi * lowFreq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / 2.0 * sqrt((A + 1.0/A) * 2.0)
        
        let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
        
        let a0 = (A + 1.0) + (A - 1.0) * cosOmega + twoSqrtAAlpha
        let a0Inv = 1.0 / a0
        
        lowB0 = A * ((A + 1.0) - (A - 1.0) * cosOmega + twoSqrtAAlpha) * a0Inv
        lowB1 = 2.0 * A * ((A - 1.0) - (A + 1.0) * cosOmega) * a0Inv
        lowB2 = A * ((A + 1.0) - (A - 1.0) * cosOmega - twoSqrtAAlpha) * a0Inv
        lowA1 = -2.0 * ((A - 1.0) + (A + 1.0) * cosOmega) * a0Inv
        lowA2 = ((A + 1.0) + (A - 1.0) * cosOmega - twoSqrtAAlpha) * a0Inv
    }
    
    private func calculateMidPeak() {
        let A = pow(10.0, midGain / 40.0)
        let omega = 2.0 * Float.pi * midFreq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / (2.0 * midQ)
        
        let a0 = 1.0 + alpha / A
        let a0Inv = 1.0 / a0
        
        midB0 = (1.0 + alpha * A) * a0Inv
        midB1 = -2.0 * cosOmega * a0Inv
        midB2 = (1.0 - alpha * A) * a0Inv
        midA1 = -2.0 * cosOmega * a0Inv
        midA2 = (1.0 - alpha / A) * a0Inv
    }
    
    private func calculateHighShelf() {
        let A = pow(10.0, highGain / 40.0)
        let omega = 2.0 * Float.pi * highFreq / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = sinOmega / 2.0 * sqrt((A + 1.0/A) * 2.0)
        
        let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
        
        let a0 = (A + 1.0) - (A - 1.0) * cosOmega + twoSqrtAAlpha
        let a0Inv = 1.0 / a0
        
        highB0 = A * ((A + 1.0) + (A - 1.0) * cosOmega + twoSqrtAAlpha) * a0Inv
        highB1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosOmega) * a0Inv
        highB2 = A * ((A + 1.0) + (A - 1.0) * cosOmega - twoSqrtAAlpha) * a0Inv
        highA1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosOmega) * a0Inv
        highA2 = ((A + 1.0) - (A - 1.0) * cosOmega - twoSqrtAAlpha) * a0Inv
    }
    
    func reset() {
        lowX1 = 0; lowX2 = 0; lowY1 = 0; lowY2 = 0
        midX1 = 0; midX2 = 0; midY1 = 0; midY2 = 0
        highX1 = 0; highX2 = 0; highY1 = 0; highY2 = 0
        lowDirty = true
        midDirty = true
        highDirty = true
    }
}
