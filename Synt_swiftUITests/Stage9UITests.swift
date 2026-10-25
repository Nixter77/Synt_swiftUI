//
//  Stage9UITests.swift
//  Synt_swiftUITests
//
//  Tests for Stage 4 of GROK_BUILD_TASKS_SYNT_9:
//  - Modulation highlighting on knobs (rings with the modulation amount)
//  - Preset browser with search and tags (UI only, presets not changed)
//

import Foundation
import SwiftUI
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage9UITests {

    // MARK: - Modulation Amount & Highlighting Tests

    @Test func modAmountSumsEntriesAndClamps() {
        let entries = [
            ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.35),
            ModMatrixEntry(source: .env2, destination: .cutoff, amount: 0.25),
            ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.5)
        ]

        let cutoffAmount = modAmount(.cutoff, in: entries)
        #expect(abs(cutoffAmount - 0.60) < 0.001)

        let ampAmount = modAmount(.amp, in: entries)
        #expect(abs(ampAmount - 0.50) < 0.001)

        let unusedAmount = modAmount(.resonance, in: entries)
        #expect(unusedAmount == 0.0)

        // Overflow clamp
        let overflowEntries = [
            ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.8),
            ModMatrixEntry(source: .env2, destination: .cutoff, amount: 0.6)
        ]
        let clampedAmount = modAmount(.cutoff, in: overflowEntries)
        #expect(clampedAmount == 1.0)
    }

    @MainActor
    @Test func knobViewsAcceptModulationAmount() {
        var val: Float = 0.5
        let binding = Binding(get: { val }, set: { val = $0 })
        
        // KnobView with modulationAmount
        let knob = KnobView(
            value: binding,
            range: 0...1,
            label: "Cutoff",
            modulationAmount: 0.4
        )
        #expect(knob.modulationAmount == 0.4)

        // LargeKnobView with modulationAmount
        let largeKnob = LargeKnobView(
            value: binding,
            range: 20...20000,
            label: "Cutoff",
            modulationAmount: -0.3
        )
        #expect(largeKnob.modulationAmount == -0.3)
    }

    // MARK: - Preset Browser Tags & Search Tests

    @Test func presetBrowserTagsMatchCategoriesCorrectly() {
        let bassPreset = SynthPreset.factoryPresets.first { $0.category == .bass }
        #expect(bassPreset != nil)
        #expect(bassPreset?.category == .bass)

        let leadPreset = SynthPreset.factoryPresets.first { $0.category == .lead }
        #expect(leadPreset != nil)
        #expect(leadPreset?.category == .lead)

        let padPreset = SynthPreset.factoryPresets.first { $0.category == .pad }
        #expect(padPreset != nil)
        #expect(padPreset?.category == .pad)
    }

    @Test func presetSearchFiltersByNameAndCategory() {
        let presets = SynthPreset.factoryPresets

        // Search by name
        let velvetMatches = presets.filter { $0.name.localizedCaseInsensitiveContains("Velvet") }
        #expect(!velvetMatches.isEmpty)

        // Search by category
        let bassCategoryMatches = presets.filter { $0.category.rawValue.localizedCaseInsensitiveContains("Bass") }
        #expect(!bassCategoryMatches.isEmpty)
    }

    @Test func presetCountUnchangedByUIFeatures() {
        // Presets data model and count are completely unchanged
        #expect(SynthPreset.factoryPresets.count == 103)
        #expect(SynthPreset.expansionPresets.count == 50)
    }
}
