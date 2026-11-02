//
//  FactoryBassLeadMasterStaggerAuditTests.swift
//  SYNT_58: Bass 0.58…0.65 (Soft<=0.61) / Lead 0.52…0.62 (Soft<=0.57) masterVolume stagger — max 0.01 bucket <= 40%, >= 5 distinct, Soft <= 0.50.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryBassLeadMasterStaggerAuditTests {
    static func presets(_ c: PresetCategory) -> [SynthPreset] { FactorySoftCapAuditTests.all.filter { $0.category == c } }
    static func hist(_ ps: [SynthPreset]) -> [Int: Int] {
        var h: [Int: Int] = [:]
        for p in ps { h[Int((p.masterVolume * 100).rounded()), default: 0] += 1 }
        return h
    }

    @Test func inventory() {
        for c in [PresetCategory.bass, .lead] {
            let ps = Self.presets(c)
            FactoryDirtDriveAuditTests.log("SYNT_58 MASTER | \(c.rawValue) n \(ps.count) | hist \(Self.hist(ps).sorted { $0.key < $1.key })")
        }
    }
    @Test func inBand() {
        for c in [PresetCategory.bass, .lead] {
            for p in Self.presets(c) { #expect((c == .bass ? (0.58...0.65) : (0.52...0.62)).contains(p.masterVolume), "band \(p.name) \(p.masterVolume)") }
        }
    }
    @Test func softCap() {
        for c in [PresetCategory.bass, .lead] {
            for p in Self.presets(c) where FactoryAuthoring.isLoudnessSoft(p) { #expect(p.masterVolume <= (c == .bass ? 0.61 : 0.57) + 1e-6, "soft \(p.name) \(p.masterVolume)") }
        }
    }
    @Test func maxBucketAndDistinct() {
        for c in [PresetCategory.bass, .lead] {
            let ps = Self.presets(c), h = Self.hist(ps), m = h.values.max() ?? 0
            #expect(Double(m) <= 0.40 * Double(ps.count), "\(c.rawValue) max bucket \(m)/\(ps.count)")
            #expect(h.count >= 5, "\(c.rawValue) distinct \(h.count)")
        }
    }
}
