//
//  Stage14Stage4Tests.swift
//  Synt_swiftUITests
//
//  Stage 4 tests for GROK_BUILD_TASKS_SYNT_14:
//  - UI: MPE on/off, bend range, zone, and the three sources selectable in mod matrix
//  - Presets: save/load MPE settings (decodeIfPresent); 2 factory MPE presets (one pressure -> filter, one CC74 -> wavetable position)
//  - Tests: preset round-trip; old presets load with MPE off
//  - Golden audio hash preserved bit-identical: 0xd1b3635203a4799e
//

import XCTest
@testable import SynthCore
@testable import Synt_swiftUI

final class Stage14Stage4Tests: XCTestCase {

    // MARK: - 1. Preset Round-Trip with MPE Settings

    func testPresetRoundTripWithMPESettings() throws {
        var original = SynthPreset.defaultPreset
        original.name = "Custom MPE Patch"
        original.mpeEnabled = true
        original.mpePitchBendRange = 24.0
        original.mpeZone = .upper
        original.mpeMemberChannelCount = 7
        original.modMatrix = [
            ModMatrixEntry(source: .mpePressure, destination: .cutoff, amount: 0.75),
            ModMatrixEntry(source: .mpeTimbre, destination: .wtMorph1, amount: 0.50),
            ModMatrixEntry(source: .mpePitchBend, destination: .pitch1, amount: 0.25)
        ]

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SynthPreset.self, from: data)

        XCTAssertEqual(decoded.name, "Custom MPE Patch")
        XCTAssertTrue(decoded.mpeEnabled, "mpeEnabled must round-trip as true")
        XCTAssertEqual(decoded.mpePitchBendRange, 24.0, "mpePitchBendRange must round-trip accurately")
        XCTAssertEqual(decoded.mpeZone, .upper, "mpeZone must round-trip as .upper")
        XCTAssertEqual(decoded.mpeMemberChannelCount, 7, "mpeMemberChannelCount must round-trip accurately")

        XCTAssertEqual(decoded.modMatrix.count, 3)
        XCTAssertEqual(decoded.modMatrix[0].source, .mpePressure)
        XCTAssertEqual(decoded.modMatrix[0].destination, .cutoff)
        XCTAssertEqual(decoded.modMatrix[0].amount, 0.75)

        XCTAssertEqual(decoded.modMatrix[1].source, .mpeTimbre)
        XCTAssertEqual(decoded.modMatrix[1].destination, .wtMorph1)
        XCTAssertEqual(decoded.modMatrix[1].amount, 0.50)

        XCTAssertEqual(decoded.modMatrix[2].source, .mpePitchBend)
        XCTAssertEqual(decoded.modMatrix[2].destination, .pitch1)
        XCTAssertEqual(decoded.modMatrix[2].amount, 0.25)
    }

    // MARK: - 2. Old Presets Load With MPE Off (Backward Compatibility)

    func testOldPresetsLoadWithMPEOff() throws {
        // Take a valid preset, serialize to JSON
        var preset = SynthPreset.defaultPreset
        preset.name = "Vintage Synth Legacy"
        let data = try JSONEncoder().encode(preset)

        // Remove all MPE keys to simulate legacy preset saved before Stage 14
        var dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        dict.removeValue(forKey: "mpeEnabled")
        dict.removeValue(forKey: "mpePitchBendRange")
        dict.removeValue(forKey: "mpeZone")
        dict.removeValue(forKey: "mpeMemberChannelCount")

        let strippedData = try JSONSerialization.data(withJSONObject: dict)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SynthPreset.self, from: strippedData)

        XCTAssertEqual(decoded.name, "Vintage Synth Legacy")
        XCTAssertFalse(decoded.mpeEnabled, "Old presets must default mpeEnabled to false")
        XCTAssertEqual(decoded.mpePitchBendRange, 48.0, "Old presets must default mpePitchBendRange to 48")
        XCTAssertEqual(decoded.mpeZone, .lower, "Old presets must default mpeZone to lower")
        XCTAssertEqual(decoded.mpeMemberChannelCount, 15, "Old presets must default mpeMemberChannelCount to 15")
    }

    // MARK: - 3. Factory MPE Presets

    func testFactoryMPEPresets() {
        let presets = SynthPreset.mpeFactoryPresets
        XCTAssertEqual(presets.count, 2, "Must provide exactly 2 factory MPE presets")

        // 1. One pressure -> filter cutoff
        guard let pressurePreset = presets.first(where: { p in
            p.modMatrix.contains { $0.source == .mpePressure && $0.destination == .cutoff }
        }) else {
            XCTFail("Missing factory MPE preset with pressure -> cutoff")
            return
        }
        XCTAssertTrue(pressurePreset.mpeEnabled, "Factory MPE preset must have mpeEnabled=true")
        XCTAssertEqual(pressurePreset.mpePitchBendRange, 48.0)

        // 2. One CC74 timbre -> wavetable position
        guard let timbrePreset = presets.first(where: { p in
            p.modMatrix.contains { $0.source == .mpeTimbre && ($0.destination == .wtMorph1 || $0.destination == .wtMorph2) }
        }) else {
            XCTFail("Missing factory MPE preset with CC74 timbre -> wavetable position")
            return
        }
        XCTAssertTrue(timbrePreset.mpeEnabled, "Factory MPE preset must have mpeEnabled=true")
        XCTAssertEqual(timbrePreset.osc1Waveform, .wavetable)
    }

    // MARK: - 4. Mod Matrix Sources Available and Selectable

    func testModMatrixSourcesSelectable() {
        let allSources = ModSource.allCases
        XCTAssertTrue(allSources.contains(.mpePitchBend), "ModSource must include .mpePitchBend")
        XCTAssertTrue(allSources.contains(.mpePressure), "ModSource must include .mpePressure")
        XCTAssertTrue(allSources.contains(.mpeTimbre), "ModSource must include .mpeTimbre")

        XCTAssertEqual(ModSource.mpePitchBend.rawValue, "MPE Pitch Bend")
        XCTAssertEqual(ModSource.mpePressure.rawValue, "MPE Pressure")
        XCTAssertEqual(ModSource.mpeTimbre.rawValue, "MPE Timbre")
    }

    // MARK: - 5. Golden Audio Hash Preserved Bit-Identical

    @MainActor func testGoldenHarnessPreserved() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        XCTAssertEqual(hash, 0xd1b3635203a4799e, "Default preset render must match golden hash 0xd1b3635203a4799e")
    }
}
