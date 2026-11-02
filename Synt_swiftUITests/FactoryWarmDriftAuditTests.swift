//
//  FactoryWarmDriftAuditTests.swift
//  SYNT_44: CharacterMode.warm + analogDrift [0.05, 0.20] floors (PRESET_TASTE tasty habits).
//  Init/Default/Template exempt.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryWarmDriftAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }

    static func hasDrift(_ p: SynthPreset) -> Bool { p.analogDrift >= 0.05 && p.analogDrift <= 0.20 }

    static func log(_ s: String) {
        print(s)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synt44_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    static func pct(_ ps: [SynthPreset], _ ok: (SynthPreset) -> Bool) -> Float {
        ps.isEmpty ? 1 : Float(ps.filter(ok).count) / Float(ps.count)
    }

    @Test func inventory() {
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c }
            guard !ps.isEmpty else { continue }
            let warm = Self.pct(ps) { $0.character == .warm }
            let nonOff = Self.pct(ps) { $0.character != .off }
            let drift = Self.pct(ps) { Self.hasDrift($0) }
            Self.log(String(format: "SYNT_44 WARMDRIFT | %@ | n %d | warm %.1f%% | nonOff %.1f%% | drift %.1f%%",
                            c.rawValue, ps.count, warm * 100, nonOff * 100, drift * 100))
            Self.log("SYNT_44 WARMDRIFT | \(c.rawValue) | charOff \(ps.filter { $0.character == .off }.map(\.name)) | noDrift \(ps.filter { !Self.hasDrift($0) }.map(\.name))")
        }
    }

    @Test func characterFloors() {
        func cat(_ c: PresetCategory) -> [SynthPreset] { Self.all.filter { $0.category == c } }
        #expect(Self.pct(cat(.pad)) { $0.character == .warm } >= 0.50)
        #expect(Self.pct(cat(.bass)) { $0.character == .warm } >= 0.40)
        #expect(Self.pct(cat(.lead)) { $0.character != .off } >= 0.35)
    }

    @Test func driftFloors() {
        func cat(_ c: PresetCategory) -> [SynthPreset] { Self.all.filter { $0.category == c } }
        #expect(Self.pct(cat(.bass), Self.hasDrift) >= 0.45)
        #expect(Self.pct(cat(.lead), Self.hasDrift) >= 0.45)
        #expect(Self.pct(cat(.pad), Self.hasDrift) >= 0.30)
        for p in Self.all { #expect(p.analogDrift <= 0.20, "\(p.name) drift \(p.analogDrift)") }
    }

    @Test func driftBucketVariety() {
        for c in [PresetCategory.bass, .pad] {
            let buckets = Set(Self.all.filter { $0.category == c && Self.hasDrift($0) }
                .map { Int(($0.analogDrift / 0.02).rounded(.down)) })
            Self.log("SYNT_44 BUCKETS | \(c.rawValue) | \(buckets.sorted())")
            #expect(buckets.count >= 3, "\(c.rawValue) drift buckets \(buckets)")
        }
    }

    @Test func initUntouched() {
        let i = SynthPreset.defaultPreset
        #expect(i.character == .off)
    }
}
