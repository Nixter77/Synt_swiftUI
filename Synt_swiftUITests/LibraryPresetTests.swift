//
//  LibraryPresetTests.swift
//  The 100-preset factory library: count, names, categories, and every patch
//  rendered offline at 1 and 3 notes (and with its arp) — no NaN, no clipping,
//  not silent, and the new patches no louder than the loudest legacy one.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct LibraryPresetTests {
    /// Below the soft clip (0.95) and the Chord-hiss "hot" peak.
    static let peakCeiling: Float = 0.90
    /// The loudest legacy 3-note chord peaks ≈ 0.51 (Muted Funk); new patches stay ≤ 0.60.
    static let newPatchChordCeiling: Float = 0.60

    @Test func libraryHasExactlyOneHundredPresets() {
        #expect(SynthPreset.factoryPresets.count == 100)
        #expect(PresetBrowser.count == 100)
        #expect(SynthPreset.libraryPresets.count == 42)
    }

    @Test func namesAreUniqueAndNonEmpty() {
        let names = SynthPreset.factoryPresets.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(names.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty && $0 != "Init" })
    }

    @Test func everyCategoryHasAtLeastThree() {
        for category in PresetCategory.allCases {
            let n = SynthPreset.factoryPresets.filter { $0.category == category }.count
            #expect(n >= 3, "\(category.rawValue): \(n)")
        }
        #expect(SynthPreset.factoryPresets.contains { $0.category == .brass })
        #expect(SynthPreset.factoryPresets.filter { $0.category == .arp }.allSatisfy { $0.arpMode != .off })
    }

    @Test func newPatchesAreGenuinelyDistinct() {
        // Golden-style render with the arp off (a slow arp has not fired yet in
        // 8192 frames, so its golden hash is silence). No new patch may render
        // bit-identical to any other patch.
        func fingerprint(_ preset: SynthPreset) -> UInt64 {
            var p = preset
            p.arpMode = .off
            return InitGoldenTests.renderHash(p)
        }
        var owner: [UInt64: String] = [:]
        for p in SynthPreset.factoryPresets where owner[fingerprint(p)] == nil {
            owner[fingerprint(p)] = p.name
        }
        for p in SynthPreset.libraryPresets {
            #expect(owner[fingerprint(p)] == p.name, "\(p.name) renders like \(owner[fingerprint(p)] ?? "?")")
        }
    }

    @Test(arguments: SynthPreset.factoryPresets.map(\.name))
    func presetRendersCleanly(_ name: String) throws {
        let preset = try #require(SynthPreset.factoryPresets.first { $0.name == name })
        let isNew = SynthPreset.libraryPresets.contains { $0.name == name }
        var runs: [(label: String, notes: [Int], arp: Bool)] = [("1 note", [60], false), ("3 notes", [60, 64, 67], false)]
        if preset.arpMode != .off { runs.append(("arp", [60, 64, 67], true)) }

        for run in runs {
            var p = preset
            if !run.arp { p.arpMode = .off }
            let engine = AudioEngine()
            engine.preset = p
            engine.applyPresetForTesting()
            engine.clearAllNotes()
            engine.processCommandsForTesting()
            for n in run.notes { engine.noteOn(midiNote: n, velocity: 1) }
            engine.processCommandsForTesting()
            let m = engine.renderFramesMetricsForTesting(44_100)   // 1 s from note-on

            #expect(m.nanCount == 0, "\(name) \(run.label): NaN/Inf")
            #expect(m.peak < Self.peakCeiling, "\(name) \(run.label): peak \(m.peak)")
            #expect(m.preClipPeak < 1.0, "\(name) \(run.label): pre-clip \(m.preClipPeak)")
            #expect(m.nearClipCount == 0, "\(name) \(run.label): \(m.nearClipCount) near-clip samples")
            if isNew {
                #expect(m.peak > 0.02, "\(name) \(run.label): too quiet (peak \(m.peak))")
                if run.notes.count == 3 {
                    #expect(m.peak <= Self.newPatchChordCeiling, "\(name) \(run.label): louder than the library (\(m.peak))")
                }
            }
        }
    }
}
