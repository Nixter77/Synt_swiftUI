//
//  FactoryFilterEnvCategoryAuditTests.swift
//  SYNT_50: per-category filterEnv upper (≥0.50) share on non-formant presets + 0.05 bucket stagger.
//  Init/Default/Template excluded; formant exempt (not in denom).
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryFilterEnvCategoryAuditTests {
    typealias D = FactoryDirtDriveAuditTests
    static var nonFormant: [SynthPreset] { D.all.filter { $0.filterType != .formant } }
    static func floor(_ c: PresetCategory) -> Double {
        switch c {
        case .bass, .lead, .brass, .arp, .pluck: return 50
        case .keys, .fx: return 45
        case .pad, .strings: return 40
        }
    }
    static func upper(_ ps: [SynthPreset]) -> Double {
        ps.isEmpty ? 100 : Double(ps.filter { $0.filterEnvelopeAmount >= 0.50 }.count) * 100 / Double(ps.count)
    }
    static func bucket(_ e: Float) -> Int { Int((e * 100 + 0.001) / 5) }
    static func hist(_ ps: [SynthPreset]) -> [Int: Int] {
        Dictionary(grouping: ps.filter { $0.filterEnvelopeAmount > 0 }, by: { bucket($0.filterEnvelopeAmount) }).mapValues(\.count)
    }
    static func maxBucket(_ ps: [SynthPreset]) -> Double {
        ps.isEmpty ? 0 : Double(hist(ps).values.max() ?? 0) * 100 / Double(ps.count)
    }
    static func cat(_ c: PresetCategory) -> [SynthPreset] { nonFormant.filter { $0.category == c } }
    static func isAcid(_ p: SynthPreset) -> Bool { p.name.localizedCaseInsensitiveContains("acid") }
    static func isSoft(_ p: SynthPreset) -> Bool { FactoryAuthoring.has(p, FactoryAuthoring.softWords) }

    @Test func inventory() {
        let formant = D.all.count - Self.nonFormant.count
        D.log("SYNT_50 ENV | nonFormant \(Self.nonFormant.count) | formant exempt \(formant)")
        for c in PresetCategory.allCases {
            let ps = Self.cat(c)
            let h = Self.hist(ps).sorted { $0.key < $1.key }.map { "\(String(format: "%.2f", Double($0.key) * 0.05)):\($0.value)" }
            D.log("SYNT_50 ENV | \(c.rawValue) n \(ps.count) | upper \(String(format: "%.1f", Self.upper(ps)))% (floor \(Int(Self.floor(c)))) | max \(String(format: "%.1f", Self.maxBucket(ps)))% | buckets \(h.count) | \(h)")
        }
        for p in D.all where (Self.isAcid(p) && p.filterEnvelopeAmount < 0.55)
            || (Self.isSoft(p) && !Self.isAcid(p) && p.filterType != .formant && p.filterEnvelopeAmount > 0.58) {
            D.log("SYNT_50 ID | \(p.name) | \(p.category.rawValue) | env \(p.filterEnvelopeAmount)")
        }
    }

    @Test func floors() {
        for c in PresetCategory.allCases {
            let ps = Self.cat(c)
            guard !ps.isEmpty else { continue }
            #expect(Self.upper(ps) >= Self.floor(c), "\(c.rawValue) upper \(Self.upper(ps))")
            if ps.count >= 6 {
                #expect(Self.hist(ps).count >= 3, "\(c.rawValue) buckets \(Self.hist(ps).count)")
                #expect(Self.maxBucket(ps) <= 55, "\(c.rawValue) max \(Self.maxBucket(ps))")
            }
        }
        for p in D.all {
            #expect(p.filterEnvelopeAmount <= 0.70, "cap \(p.name)")
            if Self.isAcid(p) { #expect(p.filterEnvelopeAmount >= 0.55, "acid \(p.name)") }
            if Self.isSoft(p) && !Self.isAcid(p) && p.filterType != .formant && p.filterEnvelopeAmount >= 0.50 {
                #expect(p.filterEnvelopeAmount <= 0.58, "soft \(p.name) \(p.filterEnvelopeAmount)")
            }
        }
    }
}
