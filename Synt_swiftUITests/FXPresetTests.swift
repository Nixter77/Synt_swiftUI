//
//  FXPresetTests.swift
//  Effect presets are per effect and live outside the patch.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct FXPresetTests {

    @Test func captureRoundTripsEveryFactoryPreset() {
        for item in FactoryFXPresets.all {
            var patch = sentinel()
            let before = patch
            item.apply(to: &patch)
            let captured = FXPreset.capture(kind: item.kind, from: patch)
            #expect(item.matches(captured), "\(item.kind.rawValue) \(item.name) did not round-trip")
            #expect(withoutEffect(before, kind: item.kind) == withoutEffect(patch, kind: item.kind))
            #expect(patch.id == before.id)
            #expect(patch.name == before.name)
            switch item.kind {
            case .distortion:
                #expect(patch.distortionEnabled == before.distortionEnabled)
            case .eq:
                #expect(patch.eqEnabled == before.eqEnabled)
                if let curve = EQPreset(rawValue: item.name) {
                    #expect(patch.eqPreset == curve)
                }
            case .phaser:
                #expect(patch.phaserEnabled == before.phaserEnabled)
            case .chorus, .delay, .reverb:
                break
            }
        }
    }

    @Test func factoryCurvesReplaceTheEQPicker() {
        #expect(FactoryFXPresets.eq.map(\.name) == EQPreset.allCases.map(\.rawValue))
        for kind in FXKind.allCases where kind != .eq {
            let count = FactoryFXPresets.presets(for: kind).count
            #expect(count >= 4 && count <= 5, "\(kind.rawValue) has \(count) factories")
        }
    }

    @Test func factoryValuesSitInsideKnobRanges() {
        #expect(!FactoryFXPresets.all.isEmpty)
        for item in FactoryFXPresets.all {
            #expect(item.isFactory)
            for (key, value) in item.values {
                let range = FXPreset.range(kind: item.kind, key: key)
                #expect(range.contains(value), "\(item.name) \(key)=\(value) outside \(range)")
            }
            #expect(FXPreset.clampInts(kind: item.kind, ints: item.ints) == item.ints)
        }
    }

    @Test func initClampsNonFiniteAndOutOfRange() {
        let hot = FXPreset(
            name: "Hot",
            kind: .distortion,
            isFactory: false,
            values: ["drive": .infinity, "tone": .nan, "mix": -4],
            ints: ["type": -3]
        )
        #expect(hot.values["drive"] == 1)
        #expect(hot.values["tone"] == 0)
        #expect(hot.values["mix"] == 0)
        #expect(hot.ints["type"] == 0)
    }

    @Test func saveReloadAndDeleteUseTheInjectedDirectory() throws {
        let manager = try makeManager()
        defer { remove(manager) }
        #expect(manager.directory != FXPresetManager.defaultDirectory())

        var patch = SynthPreset.defaultPreset
        patch.delayTime = 0.22
        patch.delayFeedback = 0.33
        patch.delayMix = 0.44
        #expect(manager.save(kind: .delay, name: "  Room Slap  ", from: patch))
        #expect(manager.save(kind: .delay, name: "room slap", from: patch) == false)
        #expect(manager.save(kind: .delay, name: "   ", from: patch) == false)
        #expect(manager.save(kind: .distortion, name: "warm tape", from: patch) == false)

        let idsBeforePatchSwap = manager.userPresets.map(\.id)
        var other = SynthPreset.factoryPresets[0]
        FactoryFXPresets.chorus[0].apply(to: &other)
        #expect(manager.userPresets.map(\.id) == idsBeforePatchSwap)

        let reloaded = FXPresetManager(directory: manager.directory)
        let saved = try #require(reloaded.userPresets.first { $0.name == "Room Slap" })
        #expect(saved.isFactory == false)
        #expect(saved.kind == .delay)
        #expect(saved.values["time"] == 0.22)
        #expect(reloaded.matchingName(kind: .delay, in: patch) == "Room Slap")
        #expect(reloaded.matchingName(kind: .eq, in: .defaultPreset) == "Flat")

        #expect(reloaded.delete(id: FactoryFXPresets.reverb[0].id) == false)
        #expect(reloaded.delete(id: UUID()) == false)
        #expect(reloaded.delete(id: saved.id))
        let afterDelete = FXPresetManager(directory: manager.directory)
        #expect(afterDelete.userPresets.isEmpty)
        let reverbLeft = afterDelete.presets(for: .reverb)
        let reverbIsFactory = reverbLeft.allSatisfy { $0.isFactory }
        #expect(!reverbLeft.isEmpty)
        #expect(reverbIsFactory)
    }

    @Test func corruptJSONAndOutOfRangeValuesDoNotCrash() throws {
        let manager = try makeManager()
        defer { remove(manager) }

        let tooHot = """
        [
          {"id":"11111111-1111-1111-1111-111111111111","name":"Too Hot","kind":"distortion","isFactory":false,"schemaVersion":1,"values":{"drive":9,"tone":-2,"mix":0.4},"ints":{"type":99}},
          {"id":"22222222-2222-2222-2222-222222222222","name":"Sneaky","kind":"distortion","isFactory":true,"schemaVersion":1,"values":{"drive":0.2,"tone":0.2,"mix":0.2},"ints":{"type":0}}
        ]
        """
        try tooHot.write(to: manager.directory.appendingPathComponent("distortion.json"), atomically: true, encoding: .utf8)
        try "{".write(to: manager.directory.appendingPathComponent("chorus.json"), atomically: true, encoding: .utf8)
        manager.reload()

        let loaded = manager.userPresets.filter { $0.kind == .distortion }
        #expect(loaded.count == 1)
        let hot = try #require(loaded.first)
        #expect(hot.name == "Too Hot")
        #expect(hot.values["drive"] == 1)
        #expect(hot.values["tone"] == 0)
        #expect(hot.values["mix"] == 0.4)
        #expect(hot.ints["type"] == DistortionType.allCases.count - 1)
        #expect(hot.isFactory == false)
        #expect(manager.userPresets.filter { $0.kind == .chorus }.isEmpty)
        #expect(manager.presets(for: .chorus).count == FactoryFXPresets.chorus.count)
    }

    @Test func initPatchHashStaysTheGolden() {
        #expect(InitGoldenTests.renderHash(.defaultPreset) == 0xd1b3635203a4799e)
    }

    private func makeManager() throws -> FXPresetManager {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("fx-presets-\(UUID().uuidString)", isDirectory: true)
        return FXPresetManager(directory: dir)
    }

    private func remove(_ manager: FXPresetManager) {
        try? FileManager.default.removeItem(at: manager.directory)
    }

    private func sentinel() -> SynthPreset {
        var patch = SynthPreset.defaultPreset
        patch.osc1Volume = 0.33
        patch.filterCutoff = 1234
        patch.masterVolume = 0.42
        patch.unisonVoices = 3
        patch.modMatrix = [ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.3)]

        patch.distortionEnabled = true
        patch.distortionType = .softClip
        patch.distortionDrive = 0.01
        patch.distortionTone = 0.02
        patch.distortionMix = 0.03

        patch.eqEnabled = true
        patch.eqPreset = .flat
        patch.eqLowGain = 1
        patch.eqLowFreq = 111
        patch.eqMidGain = 1
        patch.eqMidFreq = 1111
        patch.eqMidQ = 2
        patch.eqHighGain = 1
        patch.eqHighFreq = 4000

        patch.phaserEnabled = true
        patch.phaserMode = .phaser2
        patch.phaserRate = 1
        patch.phaserDepth = 0.11
        patch.phaserFeedback = 0.12
        patch.phaserCenterFrequency = 1000
        patch.phaserStereoSpread = 0.13
        patch.phaserMix = 0.14

        patch.chorusRate = 1.1
        patch.chorusDepth = 0.16
        patch.chorusMix = 0.17
        patch.delayTime = 0.18
        patch.delayFeedback = 0.19
        patch.delayMix = 0.21
        patch.reverbMix = 0.23
        patch.reverbRoomSize = 0.24
        return patch
    }

    /// Effect fields blanked so equality checks the rest of the patch.
    private func withoutEffect(_ preset: SynthPreset, kind: FXKind) -> SynthPreset {
        var copy = preset
        switch kind {
        case .distortion:
            copy.distortionType = .softClip
            copy.distortionDrive = 0
            copy.distortionTone = 0
            copy.distortionMix = 0
        case .eq:
            copy.eqPreset = .flat
            copy.eqLowGain = 0
            copy.eqLowFreq = 0
            copy.eqMidGain = 0
            copy.eqMidFreq = 0
            copy.eqMidQ = 0
            copy.eqHighGain = 0
            copy.eqHighFreq = 0
        case .phaser:
            copy.phaserMode = .phaser4
            copy.phaserRate = 0
            copy.phaserDepth = 0
            copy.phaserFeedback = 0
            copy.phaserCenterFrequency = 0
            copy.phaserStereoSpread = 0
            copy.phaserMix = 0
        case .chorus:
            copy.chorusRate = 0
            copy.chorusDepth = 0
            copy.chorusMix = 0
        case .delay:
            copy.delayTime = 0
            copy.delayFeedback = 0
            copy.delayMix = 0
        case .reverb:
            copy.reverbMix = 0
            copy.reverbRoomSize = 0
        }
        return copy
    }
}
