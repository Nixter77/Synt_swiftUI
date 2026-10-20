//
//  KnobValueParser.swift
//  Synt_swiftUI
//
//  Typed knob values. Empty or garbage is nil so the knob stays put.
//

import Foundation

public enum KnobValueParser {
    /// Understands a sign, spaces, a comma or a dot, and a unit suffix.
    /// `k` / `kHz` scale by 1000. `ms` scales by 1/1000 when `format` is seconds.
    /// `%` scales by 1/100 when `range` is 0…1. The result is clamped into `range`.
    public static func parse(_ text: String, format: String, range: ClosedRange<Float>) -> Float? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let compact = trimmed
            .replacingOccurrences(of: ",", with: ".")
            .filter { !$0.isWhitespace }
        guard let parts = split(compact) else { return nil }
        var numeric = parts.number
        if numeric.hasSuffix(".") { numeric += "0" }
        guard let number = Double(numeric), number.isFinite else { return nil }
        guard let scaled = apply(suffix: parts.suffix, number: number, format: format, range: range) else {
            return nil
        }
        let value = Float(scaled)
        guard value.isFinite else { return nil }
        return min(range.upperBound, max(range.lowerBound, value))
    }

    /// Label under the knob. A 0…1 format that prints `%` shows 0…100.
    public static func display(value: Float, format: String, valueText: String?, range: ClosedRange<Float>) -> String {
        if let valueText { return valueText }
        if format.contains("%%"), range.lowerBound == 0, range.upperBound == 1 {
            return String(format: format, value * 100)
        }
        return String(format: format, value)
    }

    /// Text placed in the field. Uses the label when typing it back yields `value`.
    public static func editingText(value: Float, format: String, valueText: String?, range: ClosedRange<Float>) -> String {
        let shown = display(value: value, format: format, valueText: valueText, range: range)
        if let parsed = parse(shown, format: format, range: range), abs(parsed - value) <= 0.011 {
            return shown
        }
        return String(format: "%g", value)
    }

    private static let pattern = try! NSRegularExpression(
        pattern: #"^([+-]?(?:\d+(?:\.\d*)?|\.\d+))([A-Za-z%×]*)?$"#
    )

    private static func split(_ compact: String) -> (number: String, suffix: String)? {
        let range = NSRange(compact.startIndex..., in: compact)
        guard let match = pattern.firstMatch(in: compact, range: range),
              let numberRange = Range(match.range(at: 1), in: compact) else { return nil }
        let number = String(compact[numberRange])
        let suffix: String
        if match.range(at: 2).location != NSNotFound, let suffixRange = Range(match.range(at: 2), in: compact) {
            suffix = String(compact[suffixRange])
        } else {
            suffix = ""
        }
        return (number, suffix)
    }

    private static func apply(
        suffix raw: String,
        number: Double,
        format: String,
        range: ClosedRange<Float>
    ) -> Double? {
        switch raw.lowercased() {
        case "":
            // A 0…1 knob that prints % shows 0…100, so a bare "50" means 50 %.
            if isPercentUnitKnob(format: format, range: range) {
                return number / 100
            }
            return number
        case "hz", "db", "oct", "ct", "st":
            return number
        case "k", "khz":
            return number * 1000
        case "%":
            if range.lowerBound == 0, range.upperBound == 1 {
                return number / 100
            }
            let limit = Double(max(abs(range.lowerBound), abs(range.upperBound)))
            let scaled = number / 100
            if abs(number) > limit, scaled >= Double(range.lowerBound), scaled <= Double(range.upperBound) {
                return scaled
            }
            return number
        case "ms":
            return formatIsSeconds(format) ? number / 1000 : nil
        case "s":
            return formatIsSeconds(format) ? number : nil
        default:
            return nil
        }
    }

    private static func isPercentUnitKnob(format: String, range: ClosedRange<Float>) -> Bool {
        format.contains("%%") && range.lowerBound == 0 && range.upperBound == 1
    }

    private static func formatIsSeconds(_ format: String) -> Bool {
        let lower = format.lowercased()
        return lower.contains("s") && !lower.contains("ms")
    }
}

public enum KnobTyping {
    /// Esc keeps `current`. Empty or garbage keeps `current` and is invalid.
    public static func resolved(
        draft: String,
        current: Float,
        format: String,
        range: ClosedRange<Float>,
        cancelled: Bool
    ) -> (value: Float, invalid: Bool) {
        if cancelled { return (current, false) }
        guard let parsed = KnobValueParser.parse(draft, format: format, range: range) else {
            return (current, true)
        }
        return (parsed, false)
    }
}
