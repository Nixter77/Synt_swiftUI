//
//  PresetFileTests.swift
//  Factory files round-trip. Old and broken JSON stay safe.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct PresetFileTests {

    @Test func factoryPresetsRoundTripAsSynthpresetFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        for preset in SynthPreset.factoryPresets {
            let url = dir.appendingPathComponent("patch.synthpreset")
            try PresetManager.exportPreset(preset, to: url)
            let loaded = PresetManager.importPreset(from: url)
            #expect(loaded == preset, "round trip failed for \(preset.name)")
        }
    }

    @Test func oldJSONWithoutLaterFieldsDecodesToDefaults() throws {
        let json = #"{"name":"Old Patch","category":"Lead"}"#.data(using: .utf8)!
        let preset = try JSONDecoder().decode(SynthPreset.self, from: json)
        #expect(preset.name == "Old Patch")
        #expect(preset.osc1Waveform == .sawtooth)
        #expect(preset.osc2Enabled == true)
        #expect(preset.masterVolume == 0.55)
        #expect(preset.phaserEnabled == false)
        #expect(preset.attack == 0.01)
    }

    @Test func corruptSessionJSONReturnsNilAndCallerKeepsInit() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent(PresetManager.sessionFileName)
        try Data("{not-json".utf8).write(to: url)

        let loaded = PresetManager.loadLastSession(from: url)
        #expect(loaded == nil)
        let fallback = loaded ?? .defaultPreset
        #expect(fallback == .defaultPreset)
    }

    @Test func missingSessionFileReturnsNil() {
        let url = URL(fileURLWithPath: "/tmp/synt-missing-\(UUID().uuidString).json")
        #expect(PresetManager.loadLastSession(from: url) == nil)
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("synt-preset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
