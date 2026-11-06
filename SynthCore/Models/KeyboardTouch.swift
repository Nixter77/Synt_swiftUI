//
//  KeyboardTouch.swift
//  SynthCore
//
//  App-wide keyboard feel. Not a preset field. Normal is bit-exact identity.
//

import Foundation

public enum KeyboardTouch: Int, CaseIterable, Codable, Sendable {
    case light = 0
    case normal = 1
    case heavy = 2

    public var title: String {
        switch self {
        case .light: return "Light"
        case .normal: return "Normal"
        case .heavy: return "Heavy"
        }
    }

    /// Applied once, before the preset velocity curve. Normal returns the same bits.
    public func shape(_ velocity: Float) -> Float {
        switch self {
        case .normal:
            return velocity
        case .light:
            let v = min(1, max(0, velocity))
            return v.squareRoot()
        case .heavy:
            let v = min(1, max(0, velocity))
            return v * v
        }
    }
}

/// UserDefaults plus the AU `fullState` keys. The engine does not read defaults itself.
public enum PerformanceSettings {
    public static let touchDefaultsKey = "synt.keyboardTouch"
    public static let expressionDefaultsKey = "synt.globalExpressionCC"
    /// SYNT_68. Setting-gated MIDI 2.0 AU protocol. Missing / false → MIDI 1.0.
    public static let midi2DefaultsKey = "synt.midi2ProtocolEnabled"
    public static let touchStateKey = "syntKeyboardTouch"
    public static let expressionStateKey = "syntGlobalExpressionCC"
    public static let midi2StateKey = "syntMIDI2ProtocolEnabled"

    /// A missing key is Normal. `integer(forKey:)` would return 0, which is Light.
    public static func storedTouch() -> KeyboardTouch {
        guard UserDefaults.standard.object(forKey: touchDefaultsKey) != nil else { return .normal }
        return KeyboardTouch(rawValue: UserDefaults.standard.integer(forKey: touchDefaultsKey)) ?? .normal
    }

    /// A missing key is off.
    public static func storedExpression() -> Bool {
        UserDefaults.standard.bool(forKey: expressionDefaultsKey)
    }

    /// A missing key is off (MIDI 1.0). Logic manual check = KEEP ME IN.
    public static func storedMIDI2Protocol() -> Bool {
        UserDefaults.standard.bool(forKey: midi2DefaultsKey)
    }

    public static func applyStored(to engine: AudioEngine) {
        engine.keyboardTouch = storedTouch()
        engine.globalExpressionCC = storedExpression()
    }

    public static func save(touch: KeyboardTouch, expression: Bool) {
        UserDefaults.standard.set(touch.rawValue, forKey: touchDefaultsKey)
        UserDefaults.standard.set(expression, forKey: expressionDefaultsKey)
    }

    public static func saveMIDI2Protocol(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: midi2DefaultsKey)
    }
}
