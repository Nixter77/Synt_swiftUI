//
//  FactoryDirtDriveAuditTests.swift
//  SYNT_47: dirt drive tasty band [0.10, 0.28] when dirt is on (enabled && mix ≥ 0.12).
//  Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryDirtDriveAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    static func dirtOn(_ p: SynthPreset) -> Bool { p.distortionEnabled && p.distortionMix >= 0.12 }
    static func inBand(_ p: SynthPreset) -> Bool { (0.10...0.28).contains(p.distortionDrive) }
    static var on: [SynthPreset] { all.filter(dirtOn) }
    static func isSoft(_ p: SynthPreset) -> Bool { FactoryAuthoring.has(p, ["soft", "velvet", "warm"]) }
    static func isHard(_ p: SynthPreset) -> Bool {
        FactoryAuthoring.has(p, ["hard", "growl", "dirty", "overdrive"]) && FactoryAuthoring.isDirtCategory(p.category)
    }
    static func pct(_ ps: [SynthPreset]) -> Double { ps.isEmpty ? 100 : Double(ps.filter(inBand).count) * 100 / Double(ps.count) }
    static func bucket(_ d: Float) -> Int { Int((d * 100).rounded() / 2) }

    static func log(_ s: String) {
        let url = URL(fileURLWithPath: "/tmp/synt47_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    @Test func inventory() {
        let hist = Dictionary(grouping: Self.on, by: { String(format: "%.2f", Double(Self.bucket($0.distortionDrive)) * 0.02) }).mapValues(\.count)
        Self.log("SYNT_47 DRIVE | dirtOn \(Self.on.count) | band \(String(format: "%.1f", Self.pct(Self.on)))% | hist \(hist.sorted { $0.key < $1.key })")
        for c in [PresetCategory.bass, .lead] {
            Self.log("SYNT_47 DRIVE | \(c.rawValue) \(String(format: "%.1f", Self.pct(Self.on.filter { $0.category == c })))%")
        }
        for p in Self.on where !Self.inBand(p) {
            Self.log("SYNT_47 MISS | \(p.name) | \(p.category.rawValue) | drive \(p.distortionDrive) mix \(p.distortionMix)")
        }
        for p in Self.on where Self.isSoft(p) || Self.isHard(p) {
            Self.log("SYNT_47 ID | \(p.name) | \(Self.isSoft(p) ? "soft" : "hard") | drive \(p.distortionDrive)")
        }
    }

    @Test func floors() {
        #expect(Self.pct(Self.on) >= 90, "overall \(Self.pct(Self.on))")
        #expect(Self.pct(Self.on.filter { $0.category == .bass }) >= 85)
        #expect(Self.pct(Self.on.filter { $0.category == .lead }) >= 85)
        for p in Self.on {
            #expect(p.distortionDrive <= 0.28, "\(p.name) drive \(p.distortionDrive)")
            if Self.isSoft(p) { #expect(p.distortionDrive <= 0.22, "soft \(p.name) \(p.distortionDrive)") }
            else if Self.isHard(p) { #expect((0.22...0.28).contains(p.distortionDrive), "hard \(p.name) \(p.distortionDrive)") }
        }
        let bl = Self.on.filter { ($0.category == .bass || $0.category == .lead) && Self.inBand($0) }
        #expect(Set(bl.map { Self.bucket($0.distortionDrive) }).count >= 3)
    }
}
