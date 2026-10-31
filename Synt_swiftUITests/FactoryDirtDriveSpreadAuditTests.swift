//
//  FactoryDirtDriveSpreadAuditTests.swift
//  SYNT_49: dirt-on drive spread off the 0.22 monoculture.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryDirtDriveSpreadAuditTests {
    typealias D = FactoryDirtDriveAuditTests
    static func share(_ ps: [SynthPreset], _ f: (SynthPreset) -> Bool) -> Double {
        ps.isEmpty ? 0 : Double(ps.filter(f).count) * 100 / Double(ps.count)
    }
    static func maxBucket(_ ps: [SynthPreset]) -> Double {
        let h = Dictionary(grouping: ps, by: { D.bucket($0.distortionDrive) }).mapValues(\.count)
        return ps.isEmpty ? 0 : Double(h.values.max() ?? 0) * 100 / Double(ps.count)
    }
    static func at22(_ p: SynthPreset) -> Bool { abs(p.distortionDrive - 0.22) <= 0.011 }

    @Test func inventory() {
        let on = D.on
        let hist = Dictionary(grouping: on, by: { String(format: "%.2f", Double(D.bucket($0.distortionDrive)) * 0.02) }).mapValues(\.count)
        let bl = on.filter { $0.category == .bass || $0.category == .lead }
        D.log("SYNT_49 SPREAD | dirtOn \(on.count) | max \(String(format: "%.1f", Self.maxBucket(on)))% | 0.22 \(String(format: "%.1f", Self.share(on, Self.at22)))% | BL buckets \(Set(bl.map { D.bucket($0.distortionDrive) }).count) | hist \(hist.sorted { $0.key < $1.key })")
        for p in on { D.log("SYNT_49 P | \(p.name) | \(p.category.rawValue) | \(p.distortionDrive)") }
    }

    @Test func floors() {
        let on = D.on
        #expect(Self.maxBucket(on) <= 40, "max \(Self.maxBucket(on))")
        #expect(Self.share(on, Self.at22) <= 40, "0.22 \(Self.share(on, Self.at22))")
        let bl = on.filter { $0.category == .bass || $0.category == .lead }
        #expect(Set(bl.map { D.bucket($0.distortionDrive) }).count >= 5)
        let soft = on.filter(D.isSoft)
        #expect(Self.maxBucket(soft) <= 60, "soft max \(Self.maxBucket(soft))")
        for p in on {
            #expect(p.distortionDrive <= 0.28)
            if D.isSoft(p) { #expect(p.distortionDrive <= 0.22, "soft \(p.name)") }
            else if D.isHard(p) { #expect((0.22...0.28).contains(p.distortionDrive), "hard \(p.name)") }
        }
    }
}
