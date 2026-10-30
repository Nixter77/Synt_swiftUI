//
//  FactoryCategoryMustHaveTests.swift
//  SYNT_37 audit: category gesture must-haves (docs/PRESET_TASTE.md) —
//  bass mono+sub, lead fast, pad/strings slow+clean, keys short, pluck short.
//  Init / Default / Template exempt. SYNT_38: FX pad-like ≤3 hard; Brass/Arp ≥70%.
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
        case .brass:
            // SYNT_38: fast bite or filter swell; dirt capped. No unison requirement (chord-safety).
            if !(p.attack <= 0.12 + e || p.filterEnvelopeAmount >= 0.40 - e) { m.append("slow atk \(p.attack) no fenv") }
            let cap: Float = FactoryAuthoring.has(p, ["soft", "velvet"]) ? 0.22 : 0.30
            if dirt(p) > cap + e { m.append("dirt \(dirt(p))") }
        case .arp:
            // SYNT_38: tight attack, echo or live motion, short sustain.
            if p.attack > 0.08 + e { m.append("atk \(p.attack)") }
            let echoOK = p.delayMix >= 0.12 - e
            if !(echoOK || FactoryAuthoring.strongestMotion(p) >= 0.30 - e) { m.append("no echo/motion") }
            if p.sustain > 0.55 + e { m.append("sus \(p.sustain)") }
        }
        return m
    }

    static let targets: [PresetCategory: Int] = [.bass: 85, .lead: 70, .pad: 80, .strings: 80, .keys: 80, .pluck: 90, .brass: 70, .arp: 70]
    static let fxPadLikeMax = 3
    static var fxPadLike: [String] { all.filter { $0.category == .fx && misses($0).contains("pad-like") }.map(\.name) }

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

    @Test func mustHaveTargetsMet() {
        for (c, t) in Self.targets {
            let r = Self.pct(c)
            #expect(r.pct >= t, "\(c.rawValue) must-have \(r.pct)% < \(t)%")
        }
    }

    @Test func fxPadLikeCapped() {
        let names = Self.fxPadLike
        #expect(names.count <= Self.fxPadLikeMax, "FX pad-like \(names.count) > \(Self.fxPadLikeMax): \(names)")
    }
    // SYNT_39: FX wet floor. wet = max(reverb, delay, chorus); reverb always sits in fxOrder.
    static let fxWetMin: Float = 0.30
    static let fxWetTargetPct = 80
    static var fxBank: [SynthPreset] { all.filter { $0.category == .fx && !["Init", "Default", "Template"].contains($0.name) } }
    static var fxWetMisses: [String] { fxBank.filter { FactoryCharacterAuditTests.fxWet($0) < fxWetMin - 1e-4 }.map(\.name) }
    static var fxWetPct: Int { fxBank.isEmpty ? 100 : (fxBank.count - fxWetMisses.count) * 100 / fxBank.count }

    @Test func fxWetInventory() {
        var lines = ["SYNT_39 FXWET | n \(Self.fxBank.count) | ok \(Self.fxWetPct)% | target \(Self.fxWetTargetPct)%"]
        for p in Self.fxBank {
            lines.append(String(format: "SYNT_39 FXWET | %@ | rev %.2f dly %.2f cho %.2f | wet %.2f | dspRev %d | atk %.3f rel %.2f | m %.2f",
                                p.name, p.reverbMix, p.delayMix, p.chorusMix, FactoryCharacterAuditTests.fxWet(p),
                                p.dspReverbEnabled ? 1 : 0, p.attack, p.release, p.masterVolume))
        }
        try? lines.joined(separator: "\n").write(toFile: "/tmp/synt39_fxwet.txt", atomically: true, encoding: .utf8)
        #expect(Self.fxWetPct >= Self.fxWetTargetPct, "FX wet \(Self.fxWetPct)% < \(Self.fxWetTargetPct)%: \(Self.fxWetMisses)")
    }
}
