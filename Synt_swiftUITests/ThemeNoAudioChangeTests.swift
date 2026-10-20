//
//  ThemeNoAudioChangeTests.swift
//  Each skin is view-only. The real guard is the source scan below: the audio
//  side cannot see any theme type. The render part only re-checks the goldens.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct ThemeNoAudioChangeTests {

    /// Not a proof of isolation on its own (renderHash never reads the theme);
    /// it confirms the goldens still hold with a store set to each skin.
    @Test func goldensUnchangedWithEachSkinSelected() {
        let names = ["Init", "Crystal Lead", "Clean Sub", "Warm Mono", "Soft EP"]
        let presets = ([SynthPreset.defaultPreset] + SynthPreset.factoryPresets)
            .filter { names.contains($0.name) }
        #expect(Set(presets.map(\.name)) == Set(names))

        var hashesByTheme: [ThemeID: [String: UInt64]] = [:]
        for id in ThemeID.allCases {
            let suite = "ThemeNoAudioChangeTests.\(id.rawValue).\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defaults.removePersistentDomain(forName: suite)
            let store = ThemeStore(defaults: defaults)
            store.id = id
            #expect(store.id == id)
            #expect(Theme.all[store.id].id == id)

            var hashes: [String: UInt64] = [:]
            for preset in presets {
                let hash = InitGoldenTests.renderHash(preset)
                #expect(
                    hash == InitGoldenTests.golden[preset.name],
                    "\(preset.name) under \(id.rawValue) is 0x\(String(hash, radix: 16))"
                )
                hashes[preset.name] = hash
            }
            hashesByTheme[id] = hashes
        }

        #expect(hashesByTheme[.baseline] == hashesByTheme[.studio])
        #expect(hashesByTheme[.baseline] == hashesByTheme[.retro])
    }

    /// Audio, models, input and utils must not reference any theme type, so a
    /// skin cannot reach the engine through a singleton or environment.
    @Test func audioSideHasNoThemeReferences() throws {
        let app = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Synt_swiftUI", isDirectory: true)
        let banned = ["Theme", ".theme", "@Environment", "@EnvironmentObject"]
        var scanned = 0
        var hits: [String] = []
        for dir in ["Audio", "Models", "Input", "Utils"] {
            let root = app.appendingPathComponent(dir, isDirectory: true)
            guard let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in e where url.pathExtension == "swift" {
                scanned += 1
                let text = try String(contentsOf: url, encoding: .utf8)
                for word in banned where text.contains(word) {
                    hits.append("\(dir)/\(url.lastPathComponent): \(word)")
                }
            }
        }
        #expect(scanned > 20, "scanned only \(scanned) files")
        #expect(hits.isEmpty, Comment(rawValue: hits.joined(separator: "\n")))
    }
}
