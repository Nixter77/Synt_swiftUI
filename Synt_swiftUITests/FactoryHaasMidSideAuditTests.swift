//
//  FactoryHaasMidSideAuditTests.swift
//  SYNT_48: stereoMidSide uptake + Haas stagger. Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryHaasMidSideAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    static func msOn(_ p: SynthPreset) -> Bool { abs(p.stereoMidSide) >= 0.12 }
    static func msBand(_ p: SynthPreset) -> Bool { (0.12...0.45).contains(abs(p.stereoMidSide)) }
    static func haasOn(_ p: SynthPreset) -> Bool { p.stereoHaasMs >= 1.5 }
    static func isSoft(_ p: SynthPreset) -> Bool { FactoryAuthoring.has(p, ["soft", "velvet", "warm"]) }
    static func cat(_ cs: [PresetCategory]) -> [SynthPreset] { all.filter { cs.contains($0.category) } }
    static func pct(_ n: Int, _ d: Int) -> Double { d == 0 ? 0 : Double(n) * 100 / Double(d) }
    static var haasPS: [SynthPreset] { cat([.pad, .strings]).filter(haasOn) }
    static func bucket(_ h: Float) -> Int { Int((h * 2).rounded()) }

    static func log(_ s: String) {
        let url = URL(fileURLWithPath: "/tmp/synt48_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    @Test func inventory() {
        for c in PresetCategory.allCases {
            let ps = Self.cat([c])
            Self.log("SYNT_48 MS | \(c.rawValue) \(ps.filter(Self.msOn).count)/\(ps.count)")
        }
        let pks = Self.cat([.pad, .keys, .strings])
        Self.log("SYNT_48 MS | PKS band \(String(format: "%.1f", Self.pct(pks.filter(Self.msBand).count, pks.count)))%")
        let hist = Dictionary(grouping: Self.haasPS, by: { String(format: "%.1f", Double(Self.bucket($0.stereoHaasMs)) / 2) }).mapValues(\.count)
        let c4 = Self.haasPS.filter { abs($0.stereoHaasMs - 4.0) <= 0.25 }.count
        Self.log("SYNT_48 HAAS | P+S on \(Self.haasPS.count) | @4.0 \(c4) | hist \(hist.sorted { $0.key < $1.key })")
    }

    @Test func floors() {
        let pks = Self.cat([.pad, .keys, .strings])
        #expect(Self.pct(pks.filter(Self.msBand).count, pks.count) >= 25)
        let lead = Self.cat([.lead])
        #expect(Self.pct(lead.filter { (0.10...0.35).contains(abs($0.stereoMidSide)) }.count, lead.count) >= 15)
        for p in Self.cat([.bass]) { #expect(abs(p.stereoMidSide) <= 0.05, "bass \(p.name)") }
        for p in Self.all where Self.msOn(p) { #expect(abs(p.stereoMidSide) <= 0.45, "\(p.name) ms") }
        for p in Self.all where Self.isSoft(p) {
            #expect(abs(p.stereoMidSide) <= 0.28, "soft ms \(p.name)")
            if Self.haasOn(p) { #expect(p.stereoHaasMs <= 5.0, "soft haas \(p.name)") }
        }
        let hs = Self.haasPS
        for p in hs { #expect((2.0...8.0).contains(p.stereoHaasMs), "haas \(p.name) \(p.stereoHaasMs)") }
        #expect(Set(hs.map { Self.bucket($0.stereoHaasMs) }).count >= 3)
        #expect(Self.pct(hs.filter { abs($0.stereoHaasMs - 4.0) <= 0.25 }.count, hs.count) <= 40)
    }
}
