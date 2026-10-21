//
//  Theme.swift
//  Synt_swiftUI
//
//  One skin: 49 colors, radii, a single shadow layer, and fonts.
//

import AppKit
import SynthCore
import SwiftUI

extension Color {
    /// `#RRGGBB` or `rgba(r,g,b,a)`. Alpha may be written `.15`.
    init(themeHex: String) {
        let raw = themeHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.lowercased().hasPrefix("rgba") {
            let numbers = raw
                .replacingOccurrences(of: "rgba", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            let r = numbers.count > 0 ? numbers[0] / 255 : 0
            let g = numbers.count > 1 ? numbers[1] / 255 : 0
            let b = numbers.count > 2 ? numbers[2] / 255 : 0
            let a = numbers.count > 3 ? numbers[3] : 1
            self.init(red: r, green: g, blue: b, opacity: a)
            return
        }
        var hex = raw
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Spec name for the same parser.
    init(hex: String) {
        self.init(themeHex: hex)
    }
}

struct ThemeShadow: Equatable {
    var color: Color
    var radius: CGFloat
    var y: CGFloat

    /// CSS `x y blur color`. x is unused; every theme in the table uses 0.
    init(css: String) {
        let rgba = css.range(of: "rgba")
        let colorSource = rgba.map { String(css[$0.lowerBound...]) } ?? "#000000"
        let head = rgba.map { String(css[..<$0.lowerBound]) } ?? css
        let numbers = head
            .replacingOccurrences(of: "px", with: "")
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .compactMap { Double($0) }
        self.color = Color(themeHex: colorSource.trimmingCharacters(in: .whitespaces))
        self.y = CGFloat(numbers.count > 1 ? numbers[1] : 0)
        self.radius = CGFloat(numbers.count > 2 ? numbers[2] : 0)
    }
}

enum MeterStyle: String, Equatable {
    case led
    case needle
}

enum ThemeID: String, CaseIterable, Identifiable, Equatable {
    case baseline
    case studio
    case retro

    var id: String { rawValue }
}

struct Theme: Identifiable, Equatable {
    let id: ThemeID
    let displayName: String

    let bg: Color
    let panel: Color
    let card: Color
    let inset: Color
    let border: Color
    let text: Color
    let textDim: Color
    let textFaint: Color
    let accent: Color
    let accent2: Color
    let logoA: Color
    let logoB: Color
    let aOsc: Color
    let aEnv: Color
    let aFilter: Color
    let aLFO: Color
    let aFx: Color
    let aMod: Color
    let aSeq: Color
    let positive: Color
    let destructive: Color
    let knobTop: Color
    let knobBottom: Color
    let knobRing: Color
    let knobIndicator: Color
    let knobTrack: Color
    let knobFill: Color
    let meterLow: Color
    let meterMid: Color
    let meterHigh: Color
    let meterOff: Color
    let scopeBg: Color
    let scopeLine: Color
    let keyWhite: Color
    let keyWhiteEdge: Color
    let keyBlack: Color
    let keyBlackEnd: Color
    let keyPressed: Color
    let keyLabel: Color
    let kbZone: Color
    let kbZoneBorder: Color
    let toggleOn: Color
    let toggleOff: Color
    let toggleKnob: Color
    let sliderTrack: Color
    let sliderFill: Color
    let tile: Color
    let tileSel: Color
    /// Wood cheek color. Baseline and Studio still carry a real color so the field count matches.
    let chrome: Color

    let rCard: CGFloat
    let rHeader: CGFloat
    let rSmall: CGFloat
    let accentBar: CGFloat
    let cardShadow: ThemeShadow
    let knobShadow: ThemeShadow
    /// 14 pt on Retro, 0 on the other skins.
    let chromeWidth: CGFloat
    let meterStyle: MeterStyle
    let uppercaseLabels: Bool
    let labelTracking: CGFloat

    var titleFont: Font { Self.face(id, role: .title) }
    var headerFont: Font { Self.face(id, role: .header) }
    var labelFont: Font { Self.face(id, role: .label) }
    func valueFont(size: CGFloat) -> Font { Self.face(id, role: .value(size)) }

    /// Label face at the size already used in the layout.
    func captionFont(size: CGFloat, weight: Font.Weight = .medium) -> Font {
        switch id {
        case .baseline:
            return .system(size: size, weight: weight, design: .rounded)
        case .studio:
            return Self.custom(["Helvetica Neue", "Inter"], size: size, weight: weight, fallbackDesign: .default)
        case .retro:
            return Self.custom(["Avenir Next", "Futura"], size: size, weight: weight, fallbackDesign: .default)
        }
    }

    func monoFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch id {
        case .baseline:
            return .system(size: size, weight: weight, design: .monospaced)
        case .studio:
            return Self.custom(["JetBrains Mono", "SF Mono"], size: size, weight: weight, fallbackDesign: .monospaced)
        case .retro:
            return Self.custom(["Courier", "Courier New"], size: size, weight: weight, fallbackDesign: .monospaced)
        }
    }

    static let all = ThemeCollection(items: [.baseline, .studio, .retro])

    private enum FontRole {
        case title, header, label, value(CGFloat)
    }

    private static func face(_ id: ThemeID, role: FontRole) -> Font {
        switch (id, role) {
        case (.baseline, .title):
            return .system(size: 28, weight: .black, design: .rounded)
        case (.baseline, .header):
            return .system(size: 13, weight: .bold, design: .rounded)
        case (.baseline, .label):
            return .system(size: 10, weight: .medium, design: .rounded)
        case (.baseline, .value(let size)):
            return .system(size: size, weight: .regular, design: .monospaced)
        case (.studio, .title):
            return custom(["Helvetica Neue", "Inter"], size: 28, weight: .heavy, fallbackDesign: .default)
        case (.studio, .header):
            return custom(["Helvetica Neue", "Inter"], size: 13, weight: .bold, fallbackDesign: .default)
        case (.studio, .label):
            return custom(["Helvetica Neue", "Inter"], size: 10, weight: .medium, fallbackDesign: .default)
        case (.studio, .value(let size)):
            return custom(["JetBrains Mono", "SF Mono"], size: size, weight: .regular, fallbackDesign: .monospaced)
        case (.retro, .title):
            return custom(["Cooper Black", "Georgia"], size: 28, weight: .black, fallbackDesign: .serif)
        case (.retro, .header):
            return custom(["Avenir Next", "Futura"], size: 13, weight: .bold, fallbackDesign: .default)
        case (.retro, .label):
            return custom(["Avenir Next", "Futura"], size: 10, weight: .medium, fallbackDesign: .default)
        case (.retro, .value(let size)):
            return custom(["Courier", "Courier New"], size: size, weight: .regular, fallbackDesign: .monospaced)
        }
    }

    private static func custom(
        _ names: [String],
        size: CGFloat,
        weight: Font.Weight,
        fallbackDesign: Font.Design
    ) -> Font {
        if let name = FontNameCache.shared.firstInstalled(names) {
            return Font.custom(name, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: fallbackDesign)
    }
}

/// Resolves a family list to the first installed name once per list.
/// `NSFont(name:)` is a font-server lookup; body runs it dozens of times a frame.
final class FontNameCache: @unchecked Sendable {
    static let shared = FontNameCache()
    private let lock = NSLock()
    private var resolved: [[String]: String?] = [:]
    private(set) var lookups = 0

    func firstInstalled(_ names: [String]) -> String? {
        lock.lock()
        defer { lock.unlock() }
        if let hit = resolved[names] { return hit }
        lookups += 1
        let found = names.first { NSFont(name: $0, size: 12) != nil }
        resolved[names] = .some(found)
        return found
    }
}

/// Derived tokens. Kept computed so the 49-color table stays as specified.
extension Theme {
    /// Bevel highlight on keys: white on Baseline, the skin's own key tone elsewhere.
    var keyHighlight: Color {
        switch id {
        case .baseline: return .white
        case .studio: return keyWhiteEdge
        case .retro: return keyWhite
        }
    }

    /// Retro needle face, red zone and ink (task 5.2 values, now in one place).
    static let needleFace = Color(hex: "#F4E3B0")
    static let needleRed = Color(hex: "#C0392B")
    static let needleInk = Color.black
}

struct ThemeCollection: Equatable {
    let items: [Theme]

    subscript(id: ThemeID) -> Theme {
        items.first { $0.id == id } ?? .baseline
    }
}

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = Theme.baseline
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}
