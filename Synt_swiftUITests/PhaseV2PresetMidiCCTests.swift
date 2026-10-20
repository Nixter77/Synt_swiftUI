//
//  PhaseV2PresetMidiCCTests.swift
//  Synt_swiftUITests
//
//  Unit tests for Phase V2.5: Preset Search, Favorites, and MIDI CC Learn.
//

import Foundation
import Testing
@testable import Synt_swiftUI

@MainActor
struct PhaseV2PresetMidiCCTests {

    @Test func favoritePresetsStoreOperations() {
        let store = FavoritePresetsStore.shared
        store.clearFavorites()

        #expect(!store.isFavorite(name: "Test Lead"))

        store.toggleFavorite(name: "Test Lead")
        #expect(store.isFavorite(name: "Test Lead"))

        store.toggleFavorite(name: "Test Lead")
        #expect(!store.isFavorite(name: "Test Lead"))

        store.setFavorite(name: "Bass Monster", isFav: true)
        #expect(store.isFavorite(name: "Bass Monster"))

        store.clearFavorites()
        #expect(!store.isFavorite(name: "Bass Monster"))
    }

    @Test func midiCCLearnAndMappingWorkflow() {
        let store = MIDICCLearnStore.shared
        store.clearMappings()

        var preset = SynthPreset.defaultPreset

        // 1. Start learning for Cutoff
        store.startLearning(for: .cutoff)
        #expect(store.learningDestination == .cutoff)

        // 2. First CC 74 arrives: should learn mapping and apply value
        let handled = store.handleIncomingCC(74, value: 127, currentPreset: &preset)
        #expect(handled)
        #expect(store.learningDestination == nil, "Learning state must reset after CC is learned")
        #expect(store.cc(for: .cutoff) == 74)
        #expect(preset.filterCutoff > 19000.0, "Cutoff with CC value 127 should be near 20000 Hz")

        // 3. Second CC 74 arrives with value 0: should modulate cutoff without learning
        let handled2 = store.handleIncomingCC(74, value: 0, currentPreset: &preset)
        #expect(handled2)
        #expect(abs(preset.filterCutoff - 20.0) < 1.0, "Cutoff with CC value 0 should be near 20 Hz")

        // 4. Unmap Cutoff
        store.unmap(destination: .cutoff)
        #expect(store.cc(for: .cutoff) == nil)

        // 5. Clean up
        store.clearMappings()
    }

    @Test func audioCommandQueuePushesControlChange() {
        let queue = AudioCommandQueue(capacity: 64)
        let pushed = queue.push(.controlChange(cc: 74, value: 64))
        #expect(pushed, "AudioCommandQueue must accept controlChange command")

        var poppedCommand: AudioCommand? = nil
        queue.drain(limit: 1) { cmd in
            poppedCommand = cmd
        }
        #expect(poppedCommand == .controlChange(cc: 74, value: 64))
    }

    @Test func phaseV2PreservesInitGolden() {
        let golden: UInt64 = 0xd1b3635203a4799e
        let hash = InitGoldenTests.renderHash(SynthPreset.defaultPreset)
        #expect(hash == golden,
                "Init hash changed to 0x\(String(hash, radix: 16)); expected 0x\(String(golden, radix: 16))")
    }
}
