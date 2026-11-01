//
//  FactoryResonanceUpperAuditTests.swift
//  SYNT_54: Lead + Strings non-Soft non-formant filterResonance upper-third >= 45%.
//  Soft-identity presets stay <= band mid. Factory + expansion + MPE; Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryResonanceUpperAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    /// (upper-third threshold, band mid) per category.
    static let bands: [PresetCategory: (upper: Float, mid: Float)] = [.lead: (0.53, 0.45), .strings: (0.33, 0.275)]
    static let softWords = ["soft", "velvet", "warm", "whisper", "silk", "round", "mellow"]
    static func isSoft(_ p: SynthPreset) -> Bool { softWords.contains { p.name.lowercased().contains($0) } }
    static func participants(_ c: PresetCategory) -> [SynthPreset] {
        all.filter { $0.category == c && !isSoft($0) && $0.filterType != .formant }
    }
    static func share(_ c: PresetCategory) -> Double {
        let ps = Self.participants(c)
        guard let b = bands[c], !ps.isEmpty else { return 0 }
        return Double(ps.filter { $0.filterResonance >= b.upper }.count) / Double(ps.count)
    }

    @Test func inventory() {
        for c in [PresetCategory.lead, .strings] {
            let ps = Self.participants(c)
            FactoryDirtDriveAuditTests.log(String(format: "SYNT_54 RESUP | %@ | n %d | upper %.1f%%", c.rawValue, ps.count, Self.share(c) * 100))
            for p in ps { FactoryDirtDriveAuditTests.log(String(format: "SYNT_54 ROW | %@ | %@ | res %.2f", c.rawValue, p.name, p.filterResonance)) }
        }
    }

    @Test func leadFloor() { #expect(Self.share(.lead) >= 0.45, "lead upper \(Self.share(.lead))") }
    @Test func stringsFloor() { #expect(Self.share(.strings) >= 0.45, "strings upper \(Self.share(.strings))") }
    @Test func softStaysAtOrBelowMid() {
        for p in Self.all where Self.isSoft(p) && p.filterType != .formant {
            guard let b = Self.bands[p.category] else { continue }
            #expect(p.filterResonance <= b.mid, "soft res breach \(p.name) \(p.filterResonance)")
        }
    }
}
