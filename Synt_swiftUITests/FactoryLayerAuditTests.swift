//
//  FactoryLayerAuditTests.swift
//  SYNT_42: layer floor (PRESET_TASTE "Must hear: Layers") over every shipped bank.
//  Layer = osc2Enabled && osc2Volume >= 0.12, or subOscVolume >= 0.08,
//  or (bass/lead/fx only) unisonVoices >= 2. Keys: fmAmount >= 0.15 also counts.
//  Pad/strings: unison never counts (pad unison floor DROPPED). Init/Default/Template exempt.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryLayerAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }

    static func hasLayer(_ p: SynthPreset) -> Bool {
        if p.osc2Enabled && p.osc2Volume >= 0.12 { return true }
        if p.subOscVolume >= 0.08 { return true }
        switch p.category {
        case .bass, .lead, .fx: return p.unisonVoices >= 2
        case .keys: return p.fmAmount >= 0.15
        default: return false
        }
    }

    static let targets: [PresetCategory: Float] = [
        .bass: 0.85, .lead: 0.60, .pad: 0.60, .strings: 0.60, .keys: 0.50, .pluck: 0.50,
    ]

    static func log(_ s: String) {
        print(s)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synt42_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    @Test func layerFloors() {
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c }
            guard !ps.isEmpty else { continue }
            let thin = ps.filter { !Self.hasLayer($0) }
            let pct = Float(ps.count - thin.count) / Float(ps.count)
            Self.log(String(format: "SYNT_42 LAYER | %@ | n %d | layered %d | %.1f%%", c.rawValue, ps.count, ps.count - thin.count, pct * 100))
            Self.log("SYNT_42 LAYER | \(c.rawValue) | thin \(thin.map(\.name))")
            if let t = Self.targets[c] { #expect(pct >= t, "\(c.rawValue) layers \(pct) < \(t)") }
        }
    }

    @Test func padStringsUnisonNotForced() {
        for p in Self.all where p.category == .pad || p.category == .strings {
            #expect(p.unisonVoices <= 2, "\(p.name) unison \(p.unisonVoices)")
        }
    }

    /// S3 (hard): reverbMix >= 0.20 should use the DSP reverb.
    @Test func dspReverbWhenWet() {
        let miss = Self.all.filter { $0.reverbMix >= 0.20 && !$0.dspReverbEnabled }
        Self.log("SYNT_42 DSPREV | wet>=0.20 \(Self.all.filter { $0.reverbMix >= 0.20 }.count) | miss \(miss.count) \(miss.map(\.name))")
        #expect(miss.isEmpty, "dspReverb misses \(miss.count)")
    }
}
