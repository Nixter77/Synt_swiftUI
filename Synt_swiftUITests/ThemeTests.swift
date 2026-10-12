//
//  ThemeTests.swift
//  Three skins share 49 color fields and the control hexes from THEMES_V2.
//

import AppKit
import SwiftUI
import Testing
@testable import Synt_swiftUI

struct ThemeTests {

    @Test func threeThemeIDs() {
        #expect(ThemeID.allCases.count == 3)
        #expect(Theme.all.items.map(\.id) == [.baseline, .studio, .retro])
        #expect(Theme.all[.studio].displayName == "Dark Studio")
        #expect(Theme.all[.retro].displayName == "Retro Analog")
    }

    @Test func everyColorIsSetAndTheFieldCountMatches() {
        let themes = [Theme.baseline, Theme.studio, Theme.retro]
        let counts = themes.map(colorFieldCount)
        #expect(counts == [49, 49, 49])
        for theme in themes {
            for child in Mirror(reflecting: theme).children {
                guard let color = child.value as? Color else { continue }
                let parts = srgb(color)
                #expect(parts.a > 0.01)
            }
        }
    }

    @Test func controlHexesMatchTheTables() {
        expectSRGB(Theme.baseline.bg, "#F5F5F7")
        expectSRGB(Theme.studio.accent, "#FFB000")
        expectSRGB(Theme.retro.scopeLine, "#7FE0B0")
        expectSRGB(Theme.baseline.kbZone, "rgba(0,122,255,.15)")
        #expect(Theme.baseline.cardShadow.y == 4)
        #expect(Theme.baseline.cardShadow.radius == 10)
        #expect(Theme.studio.uppercaseLabels)
        #expect(Theme.retro.meterStyle == .needle)
        #expect(Theme.retro.chromeWidth == 14)
        #expect(Theme.baseline.chromeWidth == 0)
        #expect(Theme.baseline.uppercaseLabels == false)
    }

    @Test func knobArcFractionClampsEdgesAndMidpoint() {
        #expect(knobArcFraction(value: 0, range: 0...1) == 0)
        #expect(knobArcFraction(value: 1, range: 0...1) == 1)
        #expect(abs(knobArcFraction(value: 0.5, range: 0...1) - 0.5) < 0.0001)
        #expect(knobArcFraction(value: -4, range: 0...1) == 0)
        #expect(knobArcFraction(value: 3, range: 0...1) == 1)
        #expect(knobArcFraction(value: 20, range: 20...20000) == 0)
        #expect(knobArcFraction(value: 10010, range: 20...20000) > 0.49)
        #expect(knobArcFraction(value: 10010, range: 20...20000) < 0.51)
        #expect(knobArcFraction(value: 5, range: 5...5) == 0)
        #expect(knobArcFraction(value: .nan, range: 0...1) == 0)
    }

    @Test func fontsResolveWithoutBundledFaces() {
        _ = Theme.baseline.titleFont
        _ = Theme.baseline.valueFont(size: 12)
        _ = Theme.studio.titleFont
        _ = Theme.studio.valueFont(size: 11)
        _ = Theme.retro.titleFont
        _ = Theme.retro.headerFont
        _ = Theme.retro.labelFont
        _ = Theme.retro.valueFont(size: 13)
        #expect(Color(hex: "#FFFFFF") != Color.clear)
    }
}

private func colorFieldCount(_ theme: Theme) -> Int {
    Mirror(reflecting: theme).children.filter { $0.value is Color }.count
}

private func srgb(_ color: Color) -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
    let converted = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
    return (converted.redComponent, converted.greenComponent, converted.blueComponent, converted.alphaComponent)
}

private func expectSRGB(_ color: Color, _ hex: String) {
    let got = srgb(color)
    let want = srgb(Color(hex: hex))
    let tolerance: CGFloat = 0.004
    #expect(abs(got.r - want.r) < tolerance)
    #expect(abs(got.g - want.g) < tolerance)
    #expect(abs(got.b - want.b) < tolerance)
    #expect(abs(got.a - want.a) < tolerance)
}
