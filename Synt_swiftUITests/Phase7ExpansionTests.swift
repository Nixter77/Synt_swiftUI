//
//  Phase7ExpansionTests.swift
//  Synt_swiftUITests
//
//  Tests for Phase 7: Sound Expansion Pack (+50 next-generation presets).
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct Phase7ExpansionTests {

    static let peakCeiling: Float = 0.95

    @Test func expansionPackHasExactlyFiftyPresets() {
        #expect(SynthPreset.expansionPresets.count == 50)
    }

    @Test func expansionPresetNamesAreUniqueAndNonEmpty() {
        let names = SynthPreset.expansionPresets.map(\.name)
        #expect(Set(names).count == 50)
        #expect(names.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty })
    }

    @Test func expansionPresetCategoriesAreValid() {
        let categories = Set(SynthPreset.expansionPresets.map(\.category))
        #expect(categories.contains(.pad))
        #expect(categories.contains(.bass))
        #expect(categories.contains(.lead))
        #expect(categories.contains(.keys))
        #expect(categories.contains(.pluck))
        #expect(categories.contains(.strings))
        #expect(categories.contains(.brass))
        #expect(categories.contains(.arp))
        #expect(categories.contains(.fx))
    }

    @Test func expansionPresetsRenderCleanlyAndWithinHeadroom() throws {
        for preset in SynthPreset.expansionPresets {
            let name = preset.name
            let runs: [(label: String, notes: [Int])] = [("1 note", [60]), ("3 notes", [60, 64, 67])]

        for run in runs {
            let engine = AudioEngine()
            engine.preset = preset
            engine.applyPresetForTesting()
            engine.clearAllNotes()
            engine.processCommandsForTesting()

            for n in run.notes {
                engine.noteOn(midiNote: n, velocity: 0.8)
            }
            engine.processCommandsForTesting()

            // 1 second offline render
            let m = engine.renderFramesMetricsForTesting(44_100)

            if m.nanCount > 0 || m.peak >= Self.peakCeiling || m.peak <= 0.005 || m.nearClipCount > 0 {
                print("FAILED PRESET: \(name) [\(run.label)]: peak=\(m.peak), nan=\(m.nanCount), nearClip=\(m.nearClipCount)")
            }

            #expect(m.nanCount == 0, "\(name) \(run.label): NaN/Inf detected")
            #expect(m.peak < Self.peakCeiling, "\(name) \(run.label): peak exceeds ceiling (\(m.peak))")
            #expect(m.peak > 0.005, "\(name) \(run.label): sound is silent (\(m.peak))")
            #expect(m.nearClipCount == 0, "\(name) \(run.label): nearClipCount=\(m.nearClipCount)")
        }
        }
    }

    @Test func phase7PreservesInitGolden() {
        let initPreset = SynthPreset.defaultPreset
        let hash = InitGoldenTests.renderHash(initPreset)
        #expect(hash == InitGoldenTests.golden["Init"]!, "Init preset hash must be bit-identical: 0x\(String(hash, radix: 16))")
    }
}
