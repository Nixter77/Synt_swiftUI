//
//  ADSREnvelope.swift
//  Synt_swiftUI
//
//  Exponential-ish ADSR with minimum attack/release times so factory
//  presets with 0.001s attack never hard-step to full amplitude (clicks).
//

import Foundation

public struct ADSREnvelope {
    public var attack: Float = 0.01
    public var decay: Float = 0.1
    public var sustain: Float = 0.7
    public var release: Float = 0.3
    public var attackCurve: Float = 0.0
    public var decayCurve: Float = 0.0
    public var releaseCurve: Float = 0.0
    /// `.legacy` runs the body below. Analog and digital do not.
    public var model: EnvelopeModel = .legacy
    /// Seconds. 0 never enters `.delay` / `.hold`.
    public var delay: Float = 0
    public var hold: Float = 0
    /// Analog and digital only. Legacy always keeps the 4 ms attack floor.
    public var allowShortAttack: Bool = false

    /// Floor for attack/release — below this the ear hears a click on note on/off.
    public static let minAttackSeconds: Float = 0.004   // 4 ms
    public static let minReleaseSeconds: Float = 0.012  // 12 ms
    /// Fast release used by voice steal / re-trigger fade-out.
    public static let fastReleaseSeconds: Float = 0.006 // 6 ms
    /// EarLevel attack overshoot. 0.3 is a near-linear punch.
    public static let analogRatioA: Float = 0.3
    /// EarLevel decay/release overshoot. 0.0001 is −80 dB.
    public static let analogRatioDR: Float = 0.0001
    /// Floor used when `allowShortAttack` is on and the model is not legacy.
    public static let shortAttackSeconds: Float = 0.0005

    public init(
        attack: Float = 0.01,
        decay: Float = 0.1,
        sustain: Float = 0.7,
        release: Float = 0.3,
        attackCurve: Float = 0.0,
        decayCurve: Float = 0.0,
        releaseCurve: Float = 0.0
    ) {
        self.attack = attack
        self.decay = decay
        self.sustain = sustain
        self.release = release
        self.attackCurve = attackCurve
        self.decayCurve = decayCurve
        self.releaseCurve = releaseCurve
    }

    // Lazy one-pole coefficients. Recomputed only when the segment time or sample
    // rate changes. `exp` of the same Double arguments, so the Float matches the
    // old per-sample call. CC smoothing changes `attack`/`decay`/`release` on the
    // audio thread; a changed Float misses the cache and refills it.
    private struct OnePoleCoeff {
        var sampleRate: Double = -1
        var timeSeconds: Double = -1
        var value: Float = 0
        @inline(__always)
        mutating func coeff(timeSeconds t: Double, sampleRate sr: Double) -> Float {
            if sampleRate != sr || timeSeconds != t {
                sampleRate = sr
                timeSeconds = t
                let deltaTime = 1.0 / sr
                value = Float(exp(-5.0 * deltaTime / t))
            }
            return value
        }
    }
    private var attackCoeff = OnePoleCoeff()
    private var decayCoeff = OnePoleCoeff()
    private var releaseCoeff = OnePoleCoeff()
    /// Filled only when `model == .digital` and the segment curve is not 0.
    private var attackShapeLUT = [Float](repeating: 0, count: 256)
    private var decayShapeLUT = [Float](repeating: 0, count: 256)
    private var releaseShapeLUT = [Float](repeating: 0, count: 256)
    private var attackShapeKey: Float = .greatestFiniteMagnitude
    private var decayShapeKey: Float = .greatestFiniteMagnitude
    private var releaseShapeKey: Float = .greatestFiniteMagnitude
    private var analogAttackKey: Double = -1
    private var analogAttackCoef: Float = 0
    private var analogAttackBase: Float = 0
    private var analogDecayKey: Double = -1
    private var analogDecayCoef: Float = 0
    private var analogDecayBase: Float = 0
    private var analogReleaseKey: Double = -1
    private var analogReleaseCoef: Float = 0
    private var analogReleaseBase: Float = 0

    public mutating func process(
        currentValue: Float,
        phase: inout EnvelopePhase,
        time: inout Double,
        releaseStartValue: Float,
        isReleasing: Bool,
        sampleRate: Double,
        releaseOverride: Float? = nil,
        attackScale: Float = 1,
        decayScale: Float = 1,
        releaseScale: Float = 1
    ) -> Float {
        if model != .legacy {
            return processNonLegacy(
                currentValue: currentValue,
                phase: &phase,
                time: &time,
                releaseStartValue: releaseStartValue,
                isReleasing: isReleasing,
                sampleRate: sampleRate,
                releaseOverride: releaseOverride,
                attackScale: attackScale,
                decayScale: decayScale,
                releaseScale: releaseScale
            )
        }
        let deltaTime = 1.0 / sampleRate
        var value = currentValue

        // Scale 1 is exact: a finite Float times 1 is itself.
        let attackT = max(Self.minAttackSeconds, attack * attackScale)
        let releaseT = max(Self.minReleaseSeconds, releaseOverride ?? (release * releaseScale))

        if isReleasing && phase != .release && phase != .finished {
            phase = .release
            time = 0.0
        }

        switch phase {
        case .attack:
            if attackCurve == 0.0 {
                // Smooth raise: 1 - e^(-k t/T) reaches ~1 at t≈T (k≈5)
                let a = Double(attackT)
                let coeff = attackCoeff.coeff(timeSeconds: a, sampleRate: sampleRate)
                value = 1.0 - (1.0 - value) * coeff
                time += deltaTime
                if time >= a || value >= 0.999 {
                    value = 1.0
                    time = 0.0
                    phase = hold > 0 ? .hold : .decay
                }
            } else {
                let a = Double(attackT)
                if time == 0.0 && currentValue > 0.0001 {
                    let clamped = min(0.999, max(0.0, currentValue))
                    let p0: Float
                    if attackCurve > 0 {
                        p0 = pow(clamped, 1.0 / (1.0 + 3.0 * attackCurve))
                    } else {
                        p0 = pow(clamped, 1.0 - 3.0 * attackCurve)
                    }
                    time = Double(p0) * a
                }
                time += deltaTime
                let p = Float(min(1.0, max(0.0, time / a)))
                let shapedP: Float
                if attackCurve > 0 {
                    shapedP = pow(p, 1.0 + 3.0 * attackCurve)
                } else {
                    shapedP = pow(p, 1.0 / (1.0 - 3.0 * attackCurve))
                }
                value = shapedP
                if time >= a || value >= 0.999 {
                    value = 1.0
                    time = 0.0
                    phase = hold > 0 ? .hold : .decay
                }
            }

        case .decay:
            let decaySeconds = decay * decayScale
            if decayCurve == 0.0 {
                let d = max(0.003, Double(decaySeconds))
                if decaySeconds <= 0.001 {
                    value = sustain
                    phase = .sustain
                    time = 0.0
                } else {
                    let coefficient = decayCoeff.coeff(timeSeconds: d, sampleRate: sampleRate)
                    value = sustain + (value - sustain) * coefficient
                    time += deltaTime
                    if time >= d || abs(value - sustain) < 0.0005 {
                        value = sustain
                        phase = .sustain
                        time = 0.0
                    }
                }
            } else {
                let d = max(0.003, Double(decaySeconds))
                if decaySeconds <= 0.001 {
                    value = sustain
                    phase = .sustain
                    time = 0.0
                } else {
                    time += deltaTime
                    let p = Float(min(1.0, max(0.0, time / d)))
                    let shapedP: Float
                    if decayCurve > 0 {
                        shapedP = pow(p, 1.0 + 3.0 * decayCurve)
                    } else {
                        shapedP = pow(p, 1.0 / (1.0 - 3.0 * decayCurve))
                    }
                    value = sustain + (1.0 - sustain) * (1.0 - shapedP)
                    if time >= d || abs(value - sustain) < 0.0005 {
                        value = sustain
                        phase = .sustain
                        time = 0.0
                    }
                }
            }

        case .sustain:
            value = sustain

        case .release:
            if releaseCurve == 0.0 {
                let r = Double(releaseT)
                if releaseT <= 0.0001 {
                    value = 0.0
                    phase = .finished
                } else {
                    let coefficient = releaseCoeff.coeff(timeSeconds: r, sampleRate: sampleRate)
                    value = value * coefficient
                    time += deltaTime
                    if time >= r || value < 0.0002 {
                        value = 0.0
                        phase = .finished
                    }
                }
            } else {
                let r = Double(releaseT)
                if releaseT <= 0.0001 {
                    value = 0.0
                    phase = .finished
                } else {
                    time += deltaTime
                    let p = Float(min(1.0, max(0.0, time / r)))
                    let shapedP: Float
                    if releaseCurve > 0 {
                        shapedP = pow(p, 1.0 + 3.0 * releaseCurve)
                    } else {
                        shapedP = pow(p, 1.0 / (1.0 - 3.0 * releaseCurve))
                    }
                    let startVal = max(0.0, releaseStartValue)
                    value = startVal * (1.0 - shapedP)
                    if time >= r || value < 0.0002 {
                        value = 0.0
                        phase = .finished
                    }
                }
            }

        case .delay:
            let d = Double(max(0, delay))
            value = 0
            time += deltaTime
            if d <= 0 || time >= d {
                phase = .attack
                time = 0
            }

        case .hold:
            let h = Double(max(0, hold))
            value = 1
            time += deltaTime
            if h <= 0 || time >= h {
                phase = .decay
                time = 0
            }

        case .finished:
            value = 0.0
        }

        return AudioMath.clamp(value, min: 0.0, max: 1.0)
    }

    /// Analog is an EarLevel one-pole. Digital keeps the one-pole when the curve is 0
    /// and replaces per-sample `pow` with a 256-point line when it is not.
    private mutating func processNonLegacy(
        currentValue: Float,
        phase: inout EnvelopePhase,
        time: inout Double,
        releaseStartValue: Float,
        isReleasing: Bool,
        sampleRate: Double,
        releaseOverride: Float?,
        attackScale: Float,
        decayScale: Float,
        releaseScale: Float
    ) -> Float {
        let deltaTime = 1.0 / sampleRate
        var value = currentValue
        let floor = allowShortAttack ? Self.shortAttackSeconds : Self.minAttackSeconds
        let attackT = max(floor, attack * attackScale)
        let decaySeconds = decay * decayScale
        let releaseT = max(Self.minReleaseSeconds, releaseOverride ?? (release * releaseScale))

        if isReleasing && phase != .release && phase != .finished {
            phase = .release
            time = 0
        }

        switch phase {
        case .delay:
            let d = Double(max(0, delay))
            value = 0
            time += deltaTime
            if d <= 0 || time >= d {
                phase = .attack
                time = 0
            }

        case .hold:
            let h = Double(max(0, hold))
            value = 1
            time += deltaTime
            if h <= 0 || time >= h {
                phase = .decay
                time = 0
            }

        case .attack:
            if model == .analog {
                let samples = max(1, Double(attackT) * sampleRate)
                if analogAttackKey != samples {
                    analogAttackKey = samples
                    let ratio = Double(Self.analogRatioA)
                    analogAttackCoef = Float(exp(log(ratio / (1 + ratio)) / samples))
                    analogAttackBase = (1 + Self.analogRatioA) * (1 - analogAttackCoef)
                }
                value = analogAttackBase + value * analogAttackCoef
                time += deltaTime
            } else if attackCurve == 0 {
                let a = Double(attackT)
                let coeff = attackCoeff.coeff(timeSeconds: a, sampleRate: sampleRate)
                value = 1 - (1 - value) * coeff
                time += deltaTime
            } else {
                let a = Double(attackT)
                if time == 0 && currentValue > 0.0001 {
                    time = Double(inverseUnitShape(min(0.999, max(0, currentValue)), curve: attackCurve)) * a
                }
                time += deltaTime
                let p = Float(min(1, max(0, time / a)))
                value = unitShape(p, curve: attackCurve, which: 0)
            }
            if time >= Double(attackT) || value >= 0.999 {
                value = 1
                time = 0
                phase = hold > 0 ? .hold : .decay
            }

        case .decay:
            if decaySeconds <= 0.001 {
                value = sustain
                phase = .sustain
                time = 0
            } else if model == .analog {
                let samples = max(1, Double(max(0.003, decaySeconds)) * sampleRate)
                let sustainKey = Double(sustain)
                let key = samples + sustainKey
                if analogDecayKey != key {
                    analogDecayKey = key
                    let r = Double(Self.analogRatioDR)
                    let span = max(1e-6, 1 - Double(sustain) + r)
                    let coefN = r / span
                    analogDecayCoef = Float(exp(log(coefN) / samples))
                    let target = sustain - Self.analogRatioDR
                    analogDecayBase = target * (1 - analogDecayCoef)
                }
                value = analogDecayBase + value * analogDecayCoef
                time += deltaTime
                if time >= samples / sampleRate || value <= sustain {
                    value = sustain
                    phase = .sustain
                    time = 0
                }
            } else if decayCurve == 0 {
                let d = max(0.003, Double(decaySeconds))
                let coefficient = decayCoeff.coeff(timeSeconds: d, sampleRate: sampleRate)
                value = sustain + (value - sustain) * coefficient
                time += deltaTime
                if time >= d || abs(value - sustain) < 0.0005 {
                    value = sustain
                    phase = .sustain
                    time = 0
                }
            } else {
                let d = max(0.003, Double(decaySeconds))
                time += deltaTime
                let p = Float(min(1, max(0, time / d)))
                let shaped = unitShape(p, curve: decayCurve, which: 1)
                value = sustain + (1 - sustain) * (1 - shaped)
                if time >= d || abs(value - sustain) < 0.0005 {
                    value = sustain
                    phase = .sustain
                    time = 0
                }
            }

        case .sustain:
            value = sustain

        case .release:
            if releaseT <= 0.0001 {
                value = 0
                phase = .finished
            } else if model == .analog {
                // Calibrated from unity down to −80 dB in `releaseT`. Shared by every voice.
                let samples = max(1, Double(releaseT) * sampleRate)
                if analogReleaseKey != samples {
                    analogReleaseKey = samples
                    let r = Double(Self.analogRatioDR)
                    let coefN = (2 * r) / (1 + r)
                    analogReleaseCoef = Float(exp(log(coefN) / samples))
                    analogReleaseBase = Float(-r) * (1 - analogReleaseCoef)
                }
                value = analogReleaseBase + value * analogReleaseCoef
                time += deltaTime
                if time >= Double(releaseT) || value <= Self.analogRatioDR {
                    value = 0
                    phase = .finished
                }
            } else if releaseCurve == 0 {
                let r = Double(releaseT)
                let coefficient = releaseCoeff.coeff(timeSeconds: r, sampleRate: sampleRate)
                value = value * coefficient
                time += deltaTime
                if time >= r || value < 0.0002 {
                    value = 0
                    phase = .finished
                }
            } else {
                let r = Double(releaseT)
                time += deltaTime
                let p = Float(min(1, max(0, time / r)))
                let shaped = unitShape(p, curve: releaseCurve, which: 2)
                value = max(0, releaseStartValue) * (1 - shaped)
                if time >= r || value < 0.0002 {
                    value = 0
                    phase = .finished
                }
            }

        case .finished:
            value = 0
        }

        return AudioMath.clamp(value, min: 0.0, max: 1.0)
    }

    /// 256-point stand-in for the legacy power curve. `which` is attack, decay, or release.
    private mutating func unitShape(_ p: Float, curve: Float, which: Int) -> Float {
        let clamped = min(1, max(0, p))
        if curve == 0 { return clamped }
        switch which {
        case 0:
            if attackShapeKey != curve {
                Self.fillShape(&attackShapeLUT, curve: curve)
                attackShapeKey = curve
            }
            return Self.sampleShape(attackShapeLUT, clamped)
        case 1:
            if decayShapeKey != curve {
                Self.fillShape(&decayShapeLUT, curve: curve)
                decayShapeKey = curve
            }
            return Self.sampleShape(decayShapeLUT, clamped)
        default:
            if releaseShapeKey != curve {
                Self.fillShape(&releaseShapeLUT, curve: curve)
                releaseShapeKey = curve
            }
            return Self.sampleShape(releaseShapeLUT, clamped)
        }
    }

    private func inverseUnitShape(_ y: Float, curve: Float) -> Float {
        let clamped = min(0.999, max(0, y))
        if curve > 0 {
            return pow(clamped, 1 / (1 + 3 * curve))
        }
        return pow(clamped, 1 - 3 * curve)
    }

    private static func fillShape(_ lut: inout [Float], curve: Float) {
        let exponent: Float = curve > 0 ? (1 + 3 * curve) : (1 / (1 - 3 * curve))
        let denom = Float(255)
        for i in 0..<256 {
            lut[i] = pow(Float(i) / denom, exponent)
        }
    }

    private static func sampleShape(_ lut: [Float], _ p: Float) -> Float {
        let x = p * 255
        let i = min(254, Int(x))
        let frac = x - Float(i)
        return lut[i] + (lut[i + 1] - lut[i]) * frac
    }
}
