//
//  FactoryBassLeadMotionDepthStaggerAuditTests.swift
//  SYNT_60: Bass/Lead periodic motion-depth stagger 0.30…0.42 — max 0.01 bucket <= 40%, >= 5 distinct, hasPeriodicMotion kept.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryBassLeadMotionDepthStaggerAuditTests {
    static func presets(_ c: PresetCategory) -> [SynthPreset] { FactorySoftCapAuditTests.all.filter { $0.category == c } }
    /// Strongest periodic (non-pitch, live) depth per preset.
    static func depth(_ p: SynthPreset) -> Float { FactoryKeysPluckMotionDepthStaggerAuditTests.depth(p) }
    static func hist(_ ps: [SynthPreset]) -> [Int: Int] {
        var h: [Int: Int] = [:]
        for p in ps { h[Int((depth(p) * 100).rounded()), default: 0] += 1 }
        return h
    }

    @Test func inventory() {
        for c in [PresetCategory.bass, .lead] {
            let ps = Self.presets(c)
            FactoryDirtDriveAuditTests.log("SYNT_60 MOTION | \(c.rawValue) n \(ps.count) | hist \(Self.hist(ps).sorted { $0.key < $1.key })")
        }
    }
    @Test func periodicKept() {
        for c in [PresetCategory.bass, .lead] {
            for p in Self.presets(c) {
                #expect(FactoryAuthoring.hasPeriodicMotion(p), "motion \(p.name)")
                #expect(Self.depth(p) >= 0.30 - 1e-6, "depth \(p.name) \(Self.depth(p))")
            }
        }
    }
    @Test func maxBucketAndDistinct() {
        for c in [PresetCategory.bass, .lead] {
            let ps = Self.presets(c), h = Self.hist(ps), m = h.values.max() ?? 0
            let inLadder = Set(ps.map { Self.depth($0) }.filter { (0.295...0.425).contains($0) }.map { Int(($0 * 100).rounded()) })
            #expect(Double(m) <= 0.40 * Double(ps.count), "\(c.rawValue) max bucket \(m)/\(ps.count)")
            #expect(inLadder.count >= 5, "\(c.rawValue) distinct \(inLadder.count)")
        }
    }
}
