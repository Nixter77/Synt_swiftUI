//
//  FactoryLoudnessAuditTests.swift
//  SYNT_36 audit: master loudness hierarchy (docs/PRESET_TASTE.md) — bass > lead > keys/pluck > pad/strings.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryLoudnessAuditTests {
    static var all: [SynthPreset] {
        FactoryCharacterAuditTests.all.filter { !["Init", "Default", "Template"].contains($0.name) }
    }

    static func wetSum(_ p: SynthPreset) -> Float { p.reverbMix + p.delayMix + p.chorusMix }

    /// Violations of the SYNT_36 master bands. Empty == green.
    static func violations() -> [String] {
        var out: [String] = []
        for p in all {
            let m = p.masterVolume
            if m > 0.75 + 1e-4 { out.append("\(p.name) master \(m) > 0.75") }
            guard let band = FactoryAuthoring.loudnessBand(p.category) else { continue }
            if m < band.lo - 1e-4 || m > band.hi + 1e-4 {
                out.append("\(p.name) [\(p.category.rawValue)] master \(m) outside \(band.lo)–\(band.hi)")
            }
            let mid = (band.lo + band.hi) / 2
            if FactoryAuthoring.isLoudnessSoft(p) && m > mid + 1e-4 {
                out.append("\(p.name) soft name master \(m) > lower-half \(mid)")
            }
        }
        return out
    }

    @Test func loudnessInventory() {
        var lines: [String] = []
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c }
            guard !ps.isEmpty else { continue }
            let ms = ps.map(\.masterVolume).sorted()
            let med = ms[ms.count / 2]
            var inside = "-"
            if let b = FactoryAuthoring.loudnessBand(c) {
                let n = ms.filter { $0 >= b.lo - 1e-4 && $0 <= b.hi + 1e-4 }.count
                inside = "\(n * 100 / ms.count)%"
            }
            let wet = ps.map(Self.wetSum).max() ?? 0
            lines.append(String(format: "SYNT_36 LOUD | %@ | n %d | min %.2f | med %.2f | max %.2f | inBand %@ | maxWetSum %.2f",
                                c.rawValue, ps.count, ms.first ?? 0, med, ms.last ?? 0, inside, wet))
        }
        for p in Self.all where Self.wetSum(p) > 0.45 + 1e-4 {
            lines.append(String(format: "SYNT_36 WET | %@ | %@ | rev %.2f dly %.2f cho %.2f | sum %.2f",
                                p.name, p.category.rawValue, p.reverbMix, p.delayMix, p.chorusMix, Self.wetSum(p)))
        }
        print(lines.joined(separator: "\n"))
        try? lines.joined(separator: "\n").write(toFile: "/tmp/synt36_loudness.txt", atomically: true, encoding: .utf8)
    }

    @Test func loudnessBandsHold() {
        let v = Self.violations()
        try? v.joined(separator: "\n").write(toFile: "/tmp/synt36_violations.txt", atomically: true, encoding: .utf8)
        #expect(v.isEmpty, "\(v.count) loudness violations:\n\(v.joined(separator: "\n"))")
    }

    @Test func hierarchyMediansOrdered() {
        func med(_ cs: [PresetCategory]) -> Float {
            let ms = Self.all.filter { cs.contains($0.category) }.map(\.masterVolume).sorted()
            return ms.isEmpty ? 0 : ms[ms.count / 2]
        }
        #expect(med([.bass]) > med([.lead]))
        #expect(med([.lead]) > med([.keys, .pluck]))
        #expect(med([.keys, .pluck]) > med([.pad, .strings]))
    }

    // MARK: - S3 peak / clip guard (offline render, no Apple FX; values only)

    /// Two notes like InitGoldenTests (vel 0.8 / 0.7, 8192 frames). Returns peak |sample| and NaN flag.
    static func peak(_ preset: SynthPreset) -> (peak: Float, nan: Bool) {
        var p = preset
        p.arpMode = .off
        let engine = AudioEngine()
        engine.preset = p
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.noteOn(midiNote: 64, velocity: 0.7)
        engine.processCommandsForTesting()
        var pk: Float = 0
        var nan = false
        for _ in 0..<8192 {
            let (l, r) = engine.renderOneSample()
            if !l.isFinite || !r.isFinite { nan = true; continue }
            pk = max(pk, abs(l), abs(r))
        }
        return (pk, nan)
    }

    @Test(.timeLimit(.minutes(8)))
    func factoryPeaksAudibleAndUnclipped() {
        var lines: [String] = []
        for p in Self.all {
            let r = Self.peak(p)
            lines.append(String(format: "SYNT_36 PEAK | %@ | %@ | master %.2f | peak %.4f", p.name, p.category.rawValue, p.masterVolume, r.peak))
            #expect(!r.nan, "\(p.name) NaN/Inf")
            #expect(r.peak > 0.005, "\(p.name) silent peak \(r.peak)")
            #expect(r.peak < 1.0, "\(p.name) hard clip peak \(r.peak)")
        }
        try? lines.joined(separator: "\n").write(toFile: "/tmp/synt36_peaks.txt", atomically: true, encoding: .utf8)
    }
}
