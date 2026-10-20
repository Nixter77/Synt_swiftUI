//
//  ScalaParser.swift
//  Synt_swiftUI
//
//  Scala (.scl) microtuning file parser and 128-note frequency table generator.
//

import Foundation

public enum ScalaParseError: Error, Equatable, LocalizedError {
    case emptyFile
    case missingDescription
    case missingNoteCount
    case invalidNoteCount(String)
    case insufficientPitches(expected: Int, found: Int)
    case invalidPitch(String)

    public var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The Scala file is empty."
        case .missingDescription:
            return "Missing scale description line."
        case .missingNoteCount:
            return "Missing scale note count line."
        case .invalidNoteCount(let s):
            return "Invalid scale note count: '\(s)'."
        case .insufficientPitches(let expected, let found):
            return "Expected \(expected) scale pitches, but found \(found)."
        case .invalidPitch(let s):
            return "Invalid pitch entry in Scala file: '\(s)'."
        }
    }
}

public struct ScalaScale: Equatable, Sendable {
    public let description: String
    public let noteCount: Int
    /// Frequency ratios relative to 1/1 (the 1.0 root). The last ratio is the formal period (usually 2.0).
    public let ratios: [Double]

    public init(description: String, noteCount: Int, ratios: [Double]) {
        self.description = description
        self.noteCount = noteCount
        self.ratios = ratios
    }
}

public enum ScalaParser {

    /// Parses a Scala (.scl) formatted string into a `ScalaScale`.
    public static func parse(_ text: String) throws -> ScalaScale {
        let lines = text.components(separatedBy: .newlines)
        var filteredLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("!") {
                continue
            }
            // Strip inline comments if any
            let clean: String
            if let excl = trimmed.firstIndex(of: "!") {
                clean = String(trimmed[..<excl]).trimmingCharacters(in: .whitespaces)
            } else {
                clean = trimmed
            }
            if !clean.isEmpty {
                filteredLines.append(clean)
            }
        }

        guard !filteredLines.isEmpty else {
            throw ScalaParseError.emptyFile
        }

        let description = filteredLines[0]
        guard filteredLines.count > 1 else {
            throw ScalaParseError.missingNoteCount
        }

        let countLine = filteredLines[1]
        guard let noteCount = Int(countLine), noteCount > 0 else {
            throw ScalaParseError.invalidNoteCount(countLine)
        }

        let pitchLines = Array(filteredLines.dropFirst(2))
        guard pitchLines.count >= noteCount else {
            throw ScalaParseError.insufficientPitches(expected: noteCount, found: pitchLines.count)
        }

        var ratios: [Double] = []
        for i in 0..<noteCount {
            let pStr = pitchLines[i].components(separatedBy: .whitespaces).first ?? ""
            let ratio = try parsePitch(pStr)
            ratios.append(ratio)
        }

        return ScalaScale(description: description, noteCount: noteCount, ratios: ratios)
    }

    /// Parses a single pitch line: either cents (contains '.') or ratio (contains '/' or plain integer).
    public static func parsePitch(_ token: String) throws -> Double {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw ScalaParseError.invalidPitch(token)
        }

        if trimmed.contains(".") {
            // Cents
            guard let cents = Double(trimmed), cents > 0 else {
                throw ScalaParseError.invalidPitch(token)
            }
            return pow(2.0, cents / 1200.0)
        } else if trimmed.contains("/") {
            // Fractional ratio numerator/denominator
            let parts = trimmed.split(separator: "/")
            guard parts.count == 2,
                  let num = Double(parts[0]),
                  let den = Double(parts[1]),
                  den > 0, num > 0 else {
                throw ScalaParseError.invalidPitch(token)
            }
            return num / den
        } else if let intVal = Double(trimmed), intVal > 0 {
            // Whole number ratio (e.g. "2" for octave = 2/1)
            return intVal
        } else {
            throw ScalaParseError.invalidPitch(token)
        }
    }

    /// Generates a full 128-note frequency table for MIDI notes 0...127.
    /// Default root is Middle C (MIDI note 60) = ~261.625565 Hz.
    public static func makeFrequencyTable(
        scale: ScalaScale,
        baseMIDINote: Int = 60,
        baseFrequency: Double = 261.6255653005986
    ) -> [Double] {
        let n = scale.noteCount
        guard n > 0, !scale.ratios.isEmpty else {
            return standard12TETTable()
        }

        let period = scale.ratios.last ?? 2.0
        var table = [Double](repeating: 0.0, count: 128)

        for m in 0..<128 {
            let diff = m - baseMIDINote
            let oct = floor(Double(diff) / Double(n))
            var deg = diff - Int(oct) * n
            if deg < 0 {
                deg += n
            }

            let periodRatio = pow(period, oct)
            let noteRatio: Double
            if deg == 0 {
                noteRatio = 1.0
            } else {
                noteRatio = scale.ratios[deg - 1]
            }

            table[m] = baseFrequency * periodRatio * noteRatio
        }

        return table
    }

    /// Standard 12-TET table matching `AudioMath.midiToFrequency(m)`.
    public static func standard12TETTable() -> [Double] {
        (0..<128).map { m in
            440.0 * pow(2.0, Double(m - 69) / 12.0)
        }
    }
}
