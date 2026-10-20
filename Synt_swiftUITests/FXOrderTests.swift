//
//  FXOrderTests.swift
//  Synt_swiftUITests
//
//  Stage 3: FX chain reordering verification tests.
//

import Foundation
import AudioToolbox
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
struct FXOrderTests {

    @Test func defaultFXOrderRendersBitIdenticalToGolden() {
        let preset = SynthPreset.defaultPreset
        #expect(preset.fxOrder == FXSlotID.defaultOrder)
        let hash = InitGoldenTests.renderHash(preset)
        #expect(hash == 0xd1b3635203a4799e, "Default FX order must match golden hash 0xd1b3635203a4799e exactly")
    }

    @Test func reorderingFXSlotsChangesAudioRenderHash() {
        var presetA = SynthPreset.defaultPreset
        // Enable distortion and shimmer so the order of distortion vs shimmer is clearly audible and distinct.
        presetA.distortionEnabled = true
        presetA.distortionMix = 0.8
        presetA.distortionDrive = 0.7
        presetA.reverbShimmer = 0.8
        presetA.reverbMix = 0.8

        var presetB = presetA
        // Preset A: default order (distortion then reverb)
        presetA.fxOrder = [.eq, .distortion, .phaser, .chorus, .delay, .reverb]
        // Preset B: inverted order (reverb before distortion - saturating the reverb tails)
        presetB.fxOrder = [.eq, .reverb, .phaser, .chorus, .delay, .distortion]

        let hashA = InitGoldenTests.renderHash(presetA)
        let hashB = InitGoldenTests.renderHash(presetB)

        #expect(hashA != hashB, "Different FX order must produce audibly and mathematically distinct output (hashA: 0x\(String(hashA, radix: 16)), hashB: 0x\(String(hashB, radix: 16)))")
    }

    @Test func sanitizeFXOrderCleansDuplicatesAndPreservesAllSixSlots() {
        // Duplicates and partial slots
        let corrupt: [FXSlotID] = [.distortion, .distortion, .reverb]
        let cleaned = SynthPreset.sanitizeFXOrder(corrupt)

        #expect(cleaned.count == 6)
        #expect(cleaned[0] == .distortion)
        #expect(cleaned[1] == .reverb)
        #expect(Set(cleaned) == Set(FXSlotID.allCases))

        // Empty array fallback to default
        let emptyCleaned = SynthPreset.sanitizeFXOrder([])
        #expect(emptyCleaned == FXSlotID.defaultOrder)

        // Nil fallback to default
        let nilCleaned = SynthPreset.sanitizeFXOrder(nil)
        #expect(nilCleaned == FXSlotID.defaultOrder)
    }

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

    @Test func fullStateRoundtripPreservesCustomFXOrder() throws {
        let unit = try makeUnit()

        let customOrder: [FXSlotID] = [.delay, .reverb, .chorus, .phaser, .distortion, .eq]
        var p = SynthPreset.defaultPreset
        p.fxOrder = customOrder
        unit.engine.preset = p

        guard let state = unit.fullState else {
            Issue.record("fullState should not be nil")
            return
        }

        // Reset to default
        unit.engine.preset = SynthPreset.defaultPreset
        #expect(unit.engine.preset.fxOrder == FXSlotID.defaultOrder)

        // Restore fullState
        unit.fullState = state
        #expect(unit.engine.preset.fxOrder == customOrder)
    }

    @Test func engineSetFXOrderUpdatesAudioThreadLockFree() {
        let engine = AudioEngine()
        let customOrder: [FXSlotID] = [.phaser, .delay, .reverb, .chorus, .distortion, .eq]

        engine.setFXOrder(customOrder)
        #expect(engine.preset.fxOrder == customOrder)

        engine.processCommandsForTesting()
        #expect(engine.cachedFXOrder.asArray == customOrder)
    }
}
