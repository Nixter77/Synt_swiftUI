//
//  FactoryCategoryMustHaveTests.swift
//  SYNT_37 audit: category gesture must-haves (docs/PRESET_TASTE.md) —
//  bass mono+sub, lead fast, pad/strings slow+clean, keys short, pluck short.
//  Init / Default / Template exempt. FX / Brass / Arp report-only.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryCategoryMustHaveTests {
    static var all: [SynthPreset] { FactoryLoudnessAuditTests.all }

    static func dirt(_ p: SynthPreset) -> Float { p.distortionEnabled ? p.distortionMix : 0 }
    static func isSlapOrPluckBass(_ p: SynthPreset) -> Bool { FactoryAuthoring.has(p, ["slap", "pluck"]) }

    /// Missing must-haves for one preset. Empty == passes its category gesture.
    static func misses(_ p: SynthPreset) -> [String] {
        var m: [String] = []
        let e: Float = 1e-4
        switch p.category {
        case .bass:
            let mono = p.voiceMode == .mono || p.voiceMode == .legato
            if !mono { m.append("poly") }
            if mono && !isSlapOrPluckBass(p) && !(p.portamento >= 0.02 - e && p.portamento <= 0.12 + e) { m.append("porta \(p.portamento)") }
            if !(p.subOscVolume >= 0.08 - e || p.osc1Octave <= -1 || p.osc2Octave <= -1) { m.append("no sub/low oct") }
        case .lead:
            if !(p.attack <= 0.08 + e || (p.portamento >= 0.02 - e && p.portamento <= 0.15 + e)) { m.append("slow atk \(p.attack) no porta") }
            if p.attack > 0.25 && p.portamento > 0.20 { m.append("smeared") }
        case .pad, .strings:
            if p.attack < 0.15 - e { m.append("atk \(p.attack)") }
            if p.release < 0.60 - e { m.append("rel \(p.release)") }
            if dirt(p) > 0.10 + e { m.append("dirt \(dirt(p))") }
        case .keys:
            if p.attack > 0.05 + e { m.append("atk \(p.attack)") }
            if !(p.release >= 0.15 - e && p.release <= 0.55 + e) { m.append("rel \(p.release)") }
            if p.sustain > 0.75 + e { m.append("sus \(p.sustain)") }
        case .pluck:
            if p.attack > 0.01 + e { m.append("atk \(p.attack)") }
            if p.sustain > 0.25 + e { m.append("sus \(p.sustain)") }
            if p.release > 0.55 + e { m.append("rel \(p.release)") }
        case .fx:
            if p.attack >= 0.15 && p.release >= 0.60 { m.append("pad-like") }
        case .brass, .arp:
            break
        }
        return m
    }

    static let targets: [PresetCategory: Int] = [.bass: 85, .lead: 70, .pad: 80, .strings: 80, .keys: 80, .pluck: 90]

    static func pct(_ c: PresetCategory) -> (n: Int, pct: Int) {
        let ps = all.filter { $0.category == c }
        guard !ps.isEmpty else { return (0, 100) }
        let ok = ps.filter { misses($0).isEmpty }.count
        return (ps.count, ok * 100 / ps.count)
    }

    @Test func mustHaveInventory() {
        var lines: [String] = []
        for c in PresetCategory.allCases {
            let r = Self.pct(c)
            guard r.n > 0 else { continue }
            let t = Self.targets[c].map { "\($0)%" } ?? "report"
            let ps = Self.all.filter { $0.category == c }
            let atk = ps.map(\.attack).sorted(), rel = ps.map(\.release).sorted()
            lines.append(String(format: "SYNT_37 MUST | %@ | n %d | ok %d%% | target %@ | atk med %.3f | rel med %.2f | mono %d | sub %d",
                                c.rawValue, r.n, r.pct, t, atk[atk.count / 2], rel[rel.count / 2],
                                ps.filter { $0.voiceMode != .poly }.count, ps.filter { $0.subOscVolume >= 0.08 }.count))
        }
        for p in Self.all {
            let m = Self.misses(p)
            if !m.isEmpty { lines.append("SYNT_37 MISS | \(p.name) | \(p.category.rawValue) | \(m.joined(separator: ", "))") }
        }
        print(lines.joined(separator: "\n"))
        try? lines.joined(separator: "\n").write(toFile: "/tmp/synt37_musthave.txt", atomically: true, encoding: .utf8)
    }
}
