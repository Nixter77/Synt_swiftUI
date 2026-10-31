//
//  FactoryFilterBodyAuditTests.swift
//  SYNT_45: filter-body cutoff Hz bands by category + comb filter-type variety.
//  Formant and Dark/Bright-identity presets are exempt-pass. Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryFilterBodyAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }

    static let bands: [PresetCategory: (ClosedRange<Float>, Float)] = [
        .bass: (400...1400, 0.65), .lead: (800...3200, 0.60),
        .pad: (1000...5000, 0.55), .strings: (1000...5000, 0.55),
        .keys: (900...4000, 0.50), .pluck: (800...3500, 0.50),
    ]
    static let darkWords = ["dark", "noir", "muted"]
    static let brightWords = ["bright", "crystal", "glass", "air"]

    static func has(_ p: SynthPreset, _ w: [String]) -> Bool { let n = p.name.lowercased(); return w.contains { n.contains($0) } }
    static func exempt(_ p: SynthPreset) -> Bool {
        p.filterType == .formant || has(p, darkWords) || has(p, brightWords)
    }
    static func inBand(_ p: SynthPreset) -> Bool {
        guard let b = bands[p.category] else { return true }
        return exempt(p) || b.0.contains(p.filterCutoff)
    }

    static func log(_ s: String) {
        print(s)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synt45_audit.txt")
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
            let hist = Dictionary(grouping: ps, by: { $0.filterType.rawValue }).mapValues(\.count)
            Self.log(String(format: "SYNT_45 BODY | %@ | n %d | inBand %.1f%%", c.rawValue, ps.count, Self.pct(ps, Self.inBand) * 100)
                     + " | types \(hist.sorted { $0.key < $1.key })")
            Self.log("SYNT_45 BODY | \(c.rawValue) | miss \(ps.filter { !Self.inBand($0) }.map { "\($0.name)@\(Int($0.filterCutoff))" })")
        }
        Self.log("SYNT_45 COMB | \(Self.all.filter { $0.filterType == .comb }.map { "\($0.name)[\($0.category.rawValue)]" })")
    }

    @Test func cutoffBandFloors() {
        for (c, b) in Self.bands {
            let ps = Self.all.filter { $0.category == c }
            #expect(Self.pct(ps, Self.inBand) >= b.1, "\(c.rawValue) band \(Self.pct(ps, Self.inBand))")
        }
    }

    @Test func identityStillWins() {
        for p in Self.all where p.filterType != .formant {
            if Self.has(p, Self.darkWords) { #expect(p.filterCutoff <= 1400, "\(p.name) dark \(p.filterCutoff)") }
            if Self.has(p, Self.brightWords) && p.category != .bass { #expect(p.filterCutoff >= 2200, "\(p.name) bright \(p.filterCutoff)") }
        }
    }

    @Test func combVariety() {
        let comb = Self.all.filter { $0.filterType == .comb }
        #expect(comb.count >= 8, "comb \(comb.count)")
        #expect(Set(comb.map(\.category)).count >= 3)
        #expect(Self.all.filter { $0.filterType == .formant }.count >= 4)
        // Low Pass + Ladder stay the bulk; comb stays a minority colour.
        #expect(comb.count * 10 < Self.all.count)
    }

    @Test func initUntouched() {
        #expect(SynthPreset.defaultPreset.filterType != .comb)
    }

    /// Comb slots must render finite, audible and bounded (resonator safety).
    @Test func combRendersSafely() {
        for p in Self.all where p.filterType == .comb {
            let engine = AudioEngine()
            engine.preset = p
            engine.applyPresetForTesting()
            engine.noteOn(midiNote: 60, velocity: 0.8)
            engine.noteOn(midiNote: 64, velocity: 0.7)
            engine.processCommandsForTesting()
            var peak: Float = 0, sum: Double = 0, finite = true
            for _ in 0..<16384 {
                let (l, r) = engine.renderOneSample()
                if !l.isFinite || !r.isFinite { finite = false; break }
                peak = max(peak, abs(l), abs(r)); sum += Double(l * l)
            }
            let rms = sqrt(sum / 16384)
            Self.log(String(format: "SYNT_45 COMBRENDER | %@ | peak %.3f | rms %.4f", p.name, peak, rms))
            #expect(finite, "\(p.name) non-finite")
            #expect(rms > 0.001, "\(p.name) silent")
            #expect(peak <= 1.0, "\(p.name) peak \(peak)")
        }
    }
}
