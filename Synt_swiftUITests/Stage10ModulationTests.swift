//
//  Stage10ModulationTests.swift
//  Synt_swiftUITests
//

import XCTest
import AudioToolbox
@testable import Synt_swiftUI
@testable import SynthCore

final class Stage10ModulationTests: XCTestCase {

    // Test 1: LiveModulationSnapshot storage and retrieval
    func testLiveModulationSnapshot() {
        let snapshot = LiveModulationSnapshot()
        XCTAssertEqual(snapshot.value(for: .cutoff), 0.0)

        snapshot.store(0.42, for: .cutoff)
        snapshot.store(-0.75, for: .resonance)
        snapshot.store(0.123, for: .vowel)

        XCTAssertEqual(snapshot.value(for: .cutoff), 0.42, accuracy: 1e-6)
        XCTAssertEqual(snapshot.value(for: .resonance), -0.75, accuracy: 1e-6)
        XCTAssertEqual(snapshot.value(for: .vowel), 0.123, accuracy: 1e-6)

        snapshot.reset()
        XCTAssertEqual(snapshot.value(for: .cutoff), 0.0)
        XCTAssertEqual(snapshot.value(for: .resonance), 0.0)
    }

    // Test 2: Envelope follower attack/release parameters and AU parameter tree
    @MainActor
    func testEnvelopeFollowerParameters() throws {
        let preset = SynthPreset(name: "Test")
        XCTAssertEqual(preset.envFollowerAttack, 0.01)
        XCTAssertEqual(preset.envFollowerRelease, 0.05)

        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let au = try SyntAudioUnit(componentDescription: description)
        guard let tree = au.parameterTree else {
            XCTFail("AUParameterTree missing")
            return
        }

        guard let attParam = tree.parameter(withAddress: SynthParameterAddress.envFollowerAttack.rawValue),
              let relParam = tree.parameter(withAddress: SynthParameterAddress.envFollowerRelease.rawValue) else {
            XCTFail("Envelope follower parameters missing from AUParameterTree")
            return
        }

        XCTAssertEqual(attParam.minValue, 0.001)
        XCTAssertEqual(attParam.maxValue, 2.0)
        XCTAssertGreaterThanOrEqual(attParam.value, attParam.minValue)
        XCTAssertLessThanOrEqual(attParam.value, attParam.maxValue)

        XCTAssertEqual(relParam.minValue, 0.001)
        XCTAssertEqual(relParam.maxValue, 2.0)
        XCTAssertGreaterThanOrEqual(relParam.value, relParam.minValue)
        XCTAssertLessThanOrEqual(relParam.value, relParam.maxValue)
    }

    // Test 3: Envelope follower dynamic response changes with attack/release settings
    func testEnvelopeFollowerDynamicResponse() {
        let engine = AudioEngine(coreOnly: true)
        engine.cachedEnvFollowerAttack = 0.001 // Fast attack ~1 ms
        engine.cachedEnvFollowerRelease = 0.1  // Slow release ~100 ms

        let fastAttCoeff = engine.envFollowerAttCoeff
        let slowRelCoeff = engine.envFollowerRelCoeff
        XCTAssertGreaterThan(fastAttCoeff, slowRelCoeff)

        engine.cachedEnvFollowerAttack = 0.5   // Slow attack ~500 ms
        let slowAttCoeff = engine.envFollowerAttCoeff
        XCTAssertLessThan(slowAttCoeff, fastAttCoeff)
    }

    // Test 4: Random phase mode produces different phases on successive note triggers
    func testRandomPhaseModeProducesDifferentPhases() {
        XCTAssertEqual(OscPhaseMode.allCases.last, .random, "Random must be at the end of OscPhaseMode enum")

        var note1 = ActiveNote()
        var note2 = ActiveNote()

        // Two notes with different seeds
        note1.activate(
            midiNote: 60,
            velocity: 0.8,
            frequency: 261.63,
            phaseMode: .random,
            randomSeed: 0x12345678
        )
        note2.activate(
            midiNote: 60,
            velocity: 0.8,
            frequency: 261.63,
            phaseMode: .random,
            randomSeed: 0x87654321
        )

        XCTAssertNotEqual(note1.phase, note2.phase, "Successive notes in random mode must have different phases")
        XCTAssertNotEqual(note1.phase2, note2.phase2)
        XCTAssertNotEqual(note1.subPhase, note2.subPhase)
    }
}
