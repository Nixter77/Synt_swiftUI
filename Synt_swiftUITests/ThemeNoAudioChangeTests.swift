//
//  ThemeNoAudioChangeTests.swift
//  Each skin is view-only. Factory renders stay on the existing goldens.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct ThemeNoAudioChangeTests {

    @Test func factoryRendersMatchGoldensUnderEverySkin() {
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
}
