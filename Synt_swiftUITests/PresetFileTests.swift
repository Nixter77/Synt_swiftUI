//
//  PresetFileTests.swift
//  Factory files round-trip. Old and broken JSON stay safe.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct PresetFileTests {

    @Test func factoryPresetsRoundTripAsSynthpresetFiles() throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        for preset in SynthPreset.factoryPresets {
            let url = dir.appendingPathComponent("patch.synthpreset")
            try PresetManager.exportPreset(preset, to: url)
            var loaded = try PresetManager.importPreset(from: url)
            #expect(loaded.id != preset.id, "import must mint a fresh id")
            loaded.id = preset.id
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

    @Test func sanitizeLeavesFactoryAndInitUntouched() {
        for preset in SynthPreset.factoryPresets + [.defaultPreset] {
            #expect(preset.sanitized() == preset, "sanitize changed \(preset.name)")
        }
    }

    @Test func hostileJSONIsClampedNotTrusted() throws {
        let json = #"""
        {"name":"  ","bpm":1e30,"attack":-5,"masterVolume":40,"unisonVoices":9999,
         "osc1Octave":-80,"pitchBendRange":1000,
         "sequencerData":[{"id":"00000000-0000-0000-0000-000000000001","isActive":true,"noteOffset":99999999,"velocity":7,"octave":120}]}
        """#
        let p = try PresetManager.decodeImported(Data(json.utf8))
        #expect(p.name == "Imported")
        #expect(p.bpm == 300)
        #expect(p.attack > 0)
        #expect(p.masterVolume == 1)
        #expect(p.unisonVoices == 5)
        #expect(p.osc1Octave == -4)
        #expect(p.pitchBendRange == 24)
        #expect(p.sequencerData.count == 16)
        #expect(p.sequencerData[0].noteOffset == 48)
        #expect(p.sequencerData[0].octave == 4)
        #expect(p.sequencerData[0].velocity == 1)
    }

    @Test func garbageImportThrowsAReadableError() {
        #expect(throws: PresetImportError.self) {
            _ = try PresetManager.decodeImported(Data("{not-json".utf8))
        }
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("synt-preset-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}
