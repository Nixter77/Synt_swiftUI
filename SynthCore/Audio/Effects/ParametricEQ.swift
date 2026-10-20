//
//  ParametricEQ.swift
//  Synt_swiftUI
//
//  3-band parametric EQ with low/mid/high controls.
//

import Foundation

/// Factory EQ curves for the Advanced FX panel.
public enum EQPreset: String, CaseIterable, Identifiable, Codable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case bassCut = "Bass Cut"
    case midScoop = "Mid Scoop"
    case midPresence = "Presence"
    case bright = "Bright"
    case dark = "Dark"
    case vocal = "Vocal"
    case telephone = "Telephone"

    public var id: String { rawValue }

    /// Gains / freqs applied to both L/R EQ instances.
    public var settings: (
        lowGain: Float, lowFreq: Float,
        midGain: Float, midFreq: Float, midQ: Float,
        highGain: Float, highFreq: Float
    ) {
        switch self {
        case .flat:
            return (0, 100, 0, 1000, 1.0, 0, 8000)
        case .bassBoost:
            return (8, 80, 1, 400, 0.8, -1, 10000)
        case .bassCut:
            return (-8, 100, 0, 1000, 1.0, 2, 8000)
        case .midScoop:
            return (2, 90, -6, 800, 1.2, 2, 9000)
        case .midPresence:
            return (-1, 120, 5, 2500, 1.4, 1, 10000)
        case .bright:
            return (-2, 100, 1, 2000, 0.9, 7, 6000)
        case .dark:
            return (3, 120, 0, 800, 1.0, -8, 4000)
        case .vocal:
            return (-2, 150, 4, 1800, 1.1, 3, 7000)
        case .telephone:
            return (-12, 300, 6, 1200, 1.5, -10, 3500)
        }
    }
}

public final class ParametricEQ {
    
    // MARK: - Parameters
    
    /// Low band gain in dB (-24 to +24)
    public var lowGain: Float = 0.0 {
        didSet { lowDirty = true }
    }
    
    /// Low band frequency (20-500 Hz)
    public var lowFreq: Float = 100.0 {
        didSet { lowDirty = true }
    }
    
    /// Mid band gain in dB (-24 to +24)
    public var midGain: Float = 0.0 {
        didSet { midDirty = true }
    }
    
    /// Mid band frequency (200-8000 Hz)
    public var midFreq: Float = 1000.0 {
        didSet { midDirty = true }
    }
    
    /// Mid band Q (0.1 to 10)
    public var midQ: Float = 1.0 {
        didSet { midDirty = true }
    }
    
    /// High band gain in dB (-24 to +24)
    public var highGain: Float = 0.0 {
        didSet { highDirty = true }
    }
    
    /// High band frequency (2000-20000 Hz)
    public var highFreq: Float = 8000.0 {
        didSet { highDirty = true }
    }
    
    /// The setter only counts toggles. Biquad history is cleared on the first
    /// processed sample after a toggle (audio thread), not in the setter.
    public var enabled: Bool = false {
        didSet { if enabled != oldValue { toggleCount &+= 1 } }
    }
    private var toggleCount: UInt32 = 0
    private var toggleCountSeen: UInt32 = 0
    
    private var sampleRate: Float
    
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
    /// Cancels the loudest boost so a shelf changes tone without raising the peak.
    private var outputTrim: Float = 1
    
    // MARK: - Init
    
    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
    }

    /// Recalculate shelves off the render thread. Same rate is a no-op.
    public func setSampleRate(_ newRate: Float) {
        let newRate = max(8_000, newRate)
        guard abs(newRate - sampleRate) > 0.5 else { return }
        sampleRate = newRate
        calculateLowShelf()
        calculateMidPeak()
        calculateHighShelf()
        lowDirty = false
        midDirty = false
        highDirty = false
        let boost = max(0, lowGain, midGain, highGain)
        outputTrim = boost > 0.05 ? pow(10.0, -boost / 20.0) : 1
    }
    
    // MARK: - Processing
    
    @inline(__always)
    public func process(_ input: Float) -> Float {
        guard enabled else { return input }
        if toggleCountSeen != toggleCount {
            toggleCountSeen = toggleCount
            reset()
        }
        
        if lowDirty || midDirty || highDirty {
            if lowDirty { calculateLowShelf(); lowDirty = false }
            if midDirty { calculateMidPeak(); midDirty = false }
            if highDirty { calculateHighShelf(); highDirty = false }
            // +8 dB of bass used to leave the clean bus and bend in the ceiling.
            let boost = max(0, lowGain, midGain, highGain)
            outputTrim = boost > 0.05 ? pow(10.0, -boost / 20.0) : 1
        }
        
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

        return sample * outputTrim
    }
    
    @inline(__always)
    private func processBiquad(
        _ input: Float,
        b0: Float, b1: Float, b2: Float, a1: Float, a2: Float,
        x1: inout Float, x2: inout Float, y1: inout Float, y2: inout Float
    ) -> Float {
        var output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        if !output.isFinite {
            x1 = 0; x2 = 0; y1 = 0; y2 = 0
            return 0
        }
        // Denormals in a shelf sound like crackle once the note is quiet (Intel).
        if abs(output) < 1.0e-15 { output = 0 }

        x2 = x1
        x1 = input
        y2 = y1
        y1 = output
        
        return output
    }

    /// RBJ shelf slope S = 1. The previous `sqrt((A+1/A)*2)` rang at the corner.
    private func shelfAlpha(sinOmega: Float, a: Float) -> Float {
        let slope: Float = 1
        let under = (a + 1.0 / a) * (1.0 / slope - 1.0) + 2.0
        return sinOmega / 2.0 * sqrt(max(under, 0))
    }

    private func clampedFrequency(_ hz: Float) -> Float {
        min(max(hz, 20), sampleRate * 0.45)
    }
    
    // MARK: - Coefficient Calculation
    
    private func calculateLowShelf() {
        let A = pow(10.0, max(-24, min(24, lowGain)) / 40.0)
        let omega = 2.0 * Float.pi * clampedFrequency(lowFreq) / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = shelfAlpha(sinOmega: sinOmega, a: A)
        
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
        let A = pow(10.0, max(-24, min(24, midGain)) / 40.0)
        let omega = 2.0 * Float.pi * clampedFrequency(midFreq) / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let q = max(0.2, min(8, midQ))
        let alpha = sinOmega / (2.0 * q)
        
        let a0 = 1.0 + alpha / A
        let a0Inv = 1.0 / a0
        
        midB0 = (1.0 + alpha * A) * a0Inv
        midB1 = -2.0 * cosOmega * a0Inv
        midB2 = (1.0 - alpha * A) * a0Inv
        midA1 = -2.0 * cosOmega * a0Inv
        midA2 = (1.0 - alpha / A) * a0Inv
    }
    
    private func calculateHighShelf() {
        let A = pow(10.0, max(-24, min(24, highGain)) / 40.0)
        let omega = 2.0 * Float.pi * clampedFrequency(highFreq) / sampleRate
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)
        let alpha = shelfAlpha(sinOmega: sinOmega, a: A)
        
        let twoSqrtAAlpha = 2.0 * sqrt(A) * alpha
        
        let a0 = (A + 1.0) - (A - 1.0) * cosOmega + twoSqrtAAlpha
        let a0Inv = 1.0 / a0
        
        highB0 = A * ((A + 1.0) + (A - 1.0) * cosOmega + twoSqrtAAlpha) * a0Inv
        highB1 = -2.0 * A * ((A - 1.0) + (A + 1.0) * cosOmega) * a0Inv
        highB2 = A * ((A + 1.0) + (A - 1.0) * cosOmega - twoSqrtAAlpha) * a0Inv
        highA1 = 2.0 * ((A - 1.0) - (A + 1.0) * cosOmega) * a0Inv
        highA2 = ((A + 1.0) - (A - 1.0) * cosOmega - twoSqrtAAlpha) * a0Inv
    }
    
    public func reset() {
        lowX1 = 0; lowX2 = 0; lowY1 = 0; lowY2 = 0
        midX1 = 0; midX2 = 0; midY1 = 0; midY2 = 0
        highX1 = 0; highX2 = 0; highY1 = 0; highY2 = 0
        lowDirty = true
        midDirty = true
        highDirty = true
        outputTrim = 1
    }

    /// Apply a factory preset (marks coeffs dirty; does not change `enabled`).
    public func applyPreset(_ preset: EQPreset) {
        let s = preset.settings
        lowGain = s.lowGain
        lowFreq = s.lowFreq
        midGain = s.midGain
        midFreq = s.midFreq
        midQ = s.midQ
        highGain = s.highGain
        highFreq = s.highFreq
    }
}
