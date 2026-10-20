//
//  SyntAudioUnitStateTests.swift
//  Parameter tree, factory preset list, and document state.
//

import AudioToolbox
import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct SyntAudioUnitStateTests {
    private func makeUnit() throws -> SyntAudioUnit {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        return try SyntAudioUnit(componentDescription: description)
    }

    @Test func fullStateRestoresInitGolden() throws {
        let unit = try makeUnit()
        let saved = try #require(unit.fullState)
        let factories = try #require(unit.factoryPresets)
        unit.currentPreset = factories[0]
        #expect(unit.engine.preset.name != "Init")
        unit.fullState = saved
        let hash = InitGoldenTests.renderHash(unit.engine.preset)
        #expect(hash == 0xd1b3635203a4799e)
        #expect(hash == InitGoldenTests.renderHash(.defaultPreset))
    }

    @Test func documentStateUsesTheSamePresetBlob() throws {
        let unit = try makeUnit()
        let document = try #require(unit.fullStateForDocument)
        #expect(document["syntPreset"] is Data)
        #expect(document["syntPresetIndex"] as? Int == -1)
        #expect(document["syntStateVersion"] as? Int == 1)
    }

    @Test func factoryPresetNamesCarryTheCategory() throws {
        let unit = try makeUnit()
        let presets = try #require(unit.factoryPresets)
        #expect(presets.count == SynthPreset.factoryPresets.count)
        let first = PresetBrowser.list[0]
        #expect(presets[0].name == "\(first.category.rawValue): \(first.name)")
        #expect(presets[0].name.hasPrefix("Bass: "))
        unit.currentPreset = presets[0]
        #expect(unit.currentPreset?.number == 0)
        #expect(unit.engine.preset.name == first.name)
    }

    @Test func renderThreadCutoffDoesNotWriteThePreset() throws {
        let unit = try makeUnit()
        let before = unit.engine.preset.filterCutoff
        unit.engine.applyAddressedParameterRT(
            id: SynthParameterAddress.filterCutoff.rawValue,
            value: 1234
        )
        #expect(unit.engine.cachedFilterCutoff == 1234)
        #expect(unit.engine.preset.filterCutoff == before)
    }

    @Test func mainThreadCutoffWritesThePresetAndTheCache() throws {
        let unit = try makeUnit()
        let tree = try #require(unit.parameterTree)
        let cutoff = try #require(tree.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue))
        cutoff.value = 800
        #expect(unit.engine.preset.filterCutoff == 800)
        unit.engine.processCommandsForTesting()
        #expect(unit.engine.cachedFilterCutoff == 800)
        #expect(tree.allParameters.count == SynthParameterAddress.allCases.count)
    }
}
