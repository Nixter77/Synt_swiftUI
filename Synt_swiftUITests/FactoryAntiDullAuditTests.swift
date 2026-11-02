//
//  FactoryAntiDullAuditTests.swift
//  SYNT_41: anti-dull (Dull = Init-like) + lead vibrato floors over every shipped bank.
//  Meaningful override = stored field that differs from the soft FactoryAuthoring.make
//  baseline (same name/category, empty body) past a small epsilon. Init/Default/Template exempt.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryAntiDullAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    static let ignored: Set<String> = ["id", "name", "category"]

    static func overrides(_ p: SynthPreset) -> [String] {
        let base = FactoryAuthoring.make(p.name, p.category) { _ in }
        let a = Mirror(reflecting: p).children
        let b = Dictionary(uniqueKeysWithValues: Mirror(reflecting: base).children.compactMap { c in c.label.map { ($0, c.value) } })
        var out: [String] = []
        for c in a {
            guard let l = c.label, !ignored.contains(l), let bv = b[l] else { continue }
            if let x = c.value as? Float, let y = bv as? Float {
                if abs(x - y) > max(0.005, abs(y) * 0.02) { out.append(l) }
            } else if let x = c.value as? Double, let y = bv as? Double {
                if abs(x - y) > max(0.005, abs(y) * 0.02) { out.append(l) }
            } else if String(describing: c.value) != String(describing: bv) {
                out.append(l)
            }
        }
        return out
    }

    static func vibrato(_ p: SynthPreset) -> Float {
        var d: Float = 0
        if p.lfoEnabled && p.lfoTarget == .pitch { d = max(d, p.lfoDepth) }
        if p.lfo2Enabled && p.lfo2Target == .pitch { d = max(d, p.lfo2Depth) }
        for e in p.modMatrix where (e.source == .lfo1 || e.source == .lfo2)
            && FactoryAuthoring.pitchDestinations.contains(e.destination) {
            d = max(d, abs(e.amount))
        }
        return d
    }

    static func log(_ s: String) {
        print(s)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synt41_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    @Test func antiDullFloor() {
        var thin: [String] = []
        for p in Self.all {
            let n = Self.overrides(p).count
            if n < 20 { thin.append("\(p.name)(\(n))") }
        }
        let pct = Float(Self.all.count - thin.count) / Float(Self.all.count)
        Self.log(String(format: "SYNT_41 ANTIDULL | n %d | >=20 %d | %.1f%%", Self.all.count, Self.all.count - thin.count, pct * 100))
        Self.log("SYNT_41 ANTIDULL | thin \(thin.joined(separator: ", "))")
        #expect(pct >= 0.80, "anti-dull \(pct)")
    }

    @Test func leadVibratoFloor() {
        let leads = Self.all.filter { $0.category == .lead }
        let miss = leads.filter { Self.vibrato($0) < 0.10 }
        let pct = Float(leads.count - miss.count) / Float(max(1, leads.count))
        Self.log(String(format: "SYNT_41 VIBRATO | leads %d | vib %d | %.1f%%", leads.count, leads.count - miss.count, pct * 100))
        Self.log("SYNT_41 VIBRATO | miss \(miss.map(\.name))")
        #expect(pct >= 0.50, "lead vibrato \(pct)")
    }

    @Test func fmKeysBellsFloor() {
        let ps = Self.all.filter { ($0.category == .keys || $0.name.localizedCaseInsensitiveContains("bell")) && $0.fmAmount > 0 }
        #expect(ps.filter { $0.fmAmount < 0.15 }.isEmpty)
    }
}
