//
//  Compressor.swift
//  Synt_swiftUI
//
//  Dynamic range compressor with optional limiter mode.
//  SYNT_68: log2/exp2 hot path, RMS/peak detector, bus-glue profile helper.
//

import Foundation

public final class Compressor {

    // MARK: - Parameters

    /// Threshold in dB (-60 to 0)
    public var threshold: Float = -12.0

    /// Ratio (1:1 to inf:1, stored as 1.0 to 20.0)
    public var ratio: Float = 4.0

    /// Attack time in seconds (0.001 to 0.5)
    public var attack: Float = 0.01

    /// Release time in seconds (0.01 to 2.0)
    public var release: Float = 0.2

    /// Makeup gain in dB (0 to 24)
    public var makeupGain: Float = 0.0

    /// Knee width in dB (0 = hard knee, up to 12 = soft knee)
    public var kneeWidth: Float = 6.0

    /// Enable limiter mode (infinite ratio, brick wall)
    public var limiterMode: Bool = false

    public var enabled: Bool = false

    /// When true, detector uses an RMS envelope; otherwise peak (abs).
    public var useRMSDetector: Bool = false

    // MARK: - State

    private var envelope: Float = 0.0
    private var rmsEnv: Float = 0.0
    private var gainReduction: Float = 0.0
    private var sampleRate: Float

    // Coefficient cache
    private var attackCoeff: Float = 0.0
    private var releaseCoeff: Float = 0.0
    private var rmsCoeff: Float = 0.0
    private var paramsDirty: Bool = true

    // 20/log10(2) ≈ 6.020599913; log2(10)/20 ≈ 0.16609640474
    private static let dbPerLog2: Float = 6.020599913
    private static let log2PerDb: Float = 0.16609640474

    // MARK: - Init

    public init(sampleRate: Float = 44100.0) {
        self.sampleRate = sampleRate
        updateCoefficients()
    }

    /// Optional post-CleanBus bus-glue profile (SYNT_68). 2:1, ~20 ms attack, auto-release.
    public func configureBusGlueProfile() {
        threshold = -18.0
        ratio = 2.0
        attack = 0.020
        release = 0.150
        makeupGain = 0.0
        kneeWidth = 6.0
        limiterMode = false
        useRMSDetector = true
        enabled = true
        paramsDirty = true
        updateCoefficients()
    }

    // MARK: - Fast dB ↔ linear (log2/exp2)

    @inline(__always)
    private static func absToDb(_ x: Float) -> Float {
        // 20*log10(x) = (20/log10(2))*log2(x)
        x > 0.000001 ? Self.dbPerLog2 * log2(x) : -120.0
    }

    @inline(__always)
    private static func dbToLinear(_ db: Float) -> Float {
        // 10^(db/20) = exp2(db * log2(10)/20)
        exp2(db * Self.log2PerDb)
    }

    // MARK: - Processing

    @inline(__always)
    public func process(_ input: Float) -> Float {
        guard enabled else { return input }

        if paramsDirty {
            updateCoefficients()
            paramsDirty = false
        }

        let inputAbs = abs(input)
        let detected = detectLevel(inputAbs)
        let inputDB = Self.absToDb(detected)
        let targetGainReduction = calculateGainReduction(inputDB: inputDB)
        smoothGainReduction(toward: targetGainReduction)

        let totalGainDB = -gainReduction + makeupGain
        let linearGain = Self.dbToLinear(totalGainDB)
        let output = input * linearGain

        return limiterMode ? max(-1.0, min(1.0, output)) : output
    }

    /// Process stereo pair (linked detection)
    @inline(__always)
    public func processStereo(inputL: Float, inputR: Float) -> (Float, Float) {
        guard enabled else { return (inputL, inputR) }

        if paramsDirty {
            updateCoefficients()
            paramsDirty = false
        }

        let inputAbs = max(abs(inputL), abs(inputR))
        let detected = detectLevel(inputAbs)
        let inputDB = Self.absToDb(detected)
        let targetGainReduction = calculateGainReduction(inputDB: inputDB)
        smoothGainReduction(toward: targetGainReduction)

        let totalGainDB = -gainReduction + makeupGain
        let linearGain = Self.dbToLinear(totalGainDB)
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
    private func detectLevel(_ inputAbs: Float) -> Float {
        if useRMSDetector {
            // One-pole on x^2, then sqrt — smoother bus-glue detector.
            let sq = inputAbs * inputAbs
            rmsEnv += rmsCoeff * (sq - rmsEnv)
            return sqrt(max(rmsEnv, 0))
        }
        return inputAbs
    }

    @inline(__always)
    private func smoothGainReduction(toward target: Float) {
        if target > gainReduction {
            gainReduction = limiterMode
                ? target
                : gainReduction + attackCoeff * (target - gainReduction)
        } else {
            gainReduction += releaseCoeff * (target - gainReduction)
        }
    }

    @inline(__always)
    private func calculateGainReduction(inputDB: Float) -> Float {
        let effectiveRatio = limiterMode ? Float.infinity : ratio
        let effectiveThreshold = limiterMode ? -0.1 : threshold

        if kneeWidth < 0.1 {
            if inputDB <= effectiveThreshold {
                return 0.0
            } else {
                return (inputDB - effectiveThreshold) * (1.0 - 1.0 / effectiveRatio)
            }
        } else {
            let kneeStart = effectiveThreshold - kneeWidth / 2.0
            let kneeEnd = effectiveThreshold + kneeWidth / 2.0

            if inputDB <= kneeStart {
                return 0.0
            } else if inputDB >= kneeEnd {
                return (inputDB - effectiveThreshold) * (1.0 - 1.0 / effectiveRatio)
            } else {
                let kneePosition = (inputDB - kneeStart) / kneeWidth
                let compressionAmount = (1.0 - 1.0 / effectiveRatio) * kneePosition * kneePosition
                let overshoot = inputDB - effectiveThreshold + kneeWidth / 2.0
                return overshoot * compressionAmount
            }
        }
    }

    private func updateCoefficients() {
        attackCoeff = 1.0 - exp(-1.0 / (attack * sampleRate))
        // Auto-release: slightly longer than the set release when GR is deep is
        // handled by the envelope follower itself; keep a stable release coeff.
        let autoRelease = max(release, attack * 4.0)
        releaseCoeff = 1.0 - exp(-1.0 / (autoRelease * sampleRate))
        // ~5 ms RMS window
        rmsCoeff = 1.0 - exp(-1.0 / (0.005 * sampleRate))
    }

    /// Get current gain reduction in dB (for metering)
    public var currentGainReduction: Float {
        return gainReduction
    }

    public func reset() {
        envelope = 0.0
        rmsEnv = 0.0
        gainReduction = 0.0
        paramsDirty = true
    }

    public func setSampleRate(_ newRate: Float) {
        let newRate = max(8_000, newRate)
        guard abs(newRate - sampleRate) > 0.5 else { return }
        sampleRate = newRate
        paramsDirty = true
        updateCoefficients()
    }

    public func setAttack(_ value: Float) {
        attack = max(0.001, min(0.5, value))
        paramsDirty = true
    }

    public func setRelease(_ value: Float) {
        release = max(0.01, min(2.0, value))
        paramsDirty = true
    }
}
