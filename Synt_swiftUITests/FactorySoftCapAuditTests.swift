//
//  FactorySoftCapAuditTests.swift
//  SYNT_40: soft caps as hard FAIL over every shipped bank.
//  Pad unison >= 50% floor DROPPED per nixter 2026-10-31 (conflicts with chord-safety:
//  unison is bass/lead/FX only; pads are chords). padUnisonReport is report-only.
//  stereoWidth bucket is verify-only (SYNT_32). FM keys/bells is report-only.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactorySoftCapAuditTests {
    static var all: [SynthPreset] {
        (SynthPreset.factoryPresets + SynthPreset.expansionPresets + SynthPreset.mpeFactoryPresets)
            .filter { !["Init", "Default", "Template"].contains($0.name) }
    }

    static func capViolations(_ p: SynthPreset) -> [String] {
        let fx = p.category == .fx
        var v: [String] = []
        if p.masterVolume > 0.75 { v.append(String(format: "master %.2f", p.masterVolume)) }
        if p.reverbMix > (fx ? 0.45 : 0.35) { v.append(String(format: "reverb %.2f", p.reverbMix)) }
        if p.delayMix > (fx ? 0.30 : 0.22) { v.append(String(format: "delay %.2f", p.delayMix)) }
        if p.chorusMix > (fx ? 0.30 : 0.22) { v.append(String(format: "chorus %.2f", p.chorusMix)) }
        if (p.category == .pad || p.category == .strings) && p.unisonVoices > 2 { v.append("unison \(p.unisonVoices)") }
        return v
    }

    @Test func softCapsHaveNoViolations() {
        var lines: [String] = []
        var total = 0
        for p in Self.all {
            let v = Self.capViolations(p)
            if !v.isEmpty {
                total += 1
                lines.append("SYNT_40 SOFTCAP | \(p.category.rawValue) | \(p.name) | \(v.joined(separator: ", "))")
            }
        }
        lines.append("SYNT_40 SOFTCAP | n \(Self.all.count) | violations \(total)")
        print(lines.joined(separator: "\n"))
        #expect(total == 0, "SYNT_40 soft-cap violations: \(total)")
    }

    @Test func padUnisonReport() {
        let pads = Self.all.filter { $0.category == .pad }
        let n = pads.filter { $0.unisonVoices >= 2 }.count
        let pct = pads.isEmpty ? 0 : Float(n) / Float(pads.count)
        print(String(format: "SYNT_40 PADUNI | n %d | uni2 %d | %.0f%% | report-only (floor dropped)", pads.count, n, pct * 100))
        for p in pads { print("SYNT_40 PADUNI | \(p.name) | uni \(p.unisonVoices)") }
    }

    @Test func stereoWidthBucketVerify() {
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c }
            var b: [Int: Int] = [:]
            for p in ps { b[Int((p.stereoWidth / 0.02).rounded()), default: 0] += 1 }
            let m = b.values.max() ?? 0
            print("SYNT_40 WIDTH | \(c.rawValue) | maxBucket \(m)")
            #expect(m <= 3, "\(c.rawValue) width bucket \(m)")
        }
    }

    @Test func fmKeysBellsReport() {
        let ps = Self.all.filter { ($0.category == .keys || $0.name.localizedCaseInsensitiveContains("bell")) && $0.fmAmount > 0 }
        let low = ps.filter { $0.fmAmount < 0.15 }
        print("SYNT_40 FM | on \(ps.count) | <0.15 \(low.count) \(low.map(\.name))")
    }
}
