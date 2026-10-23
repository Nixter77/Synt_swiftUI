//
//  Stage17Stage2Tests.swift
//  SYNT_17 Stage 2: R14-1 / R14-2 — controller MPE state is runtime only (nixter's decision).
//

import AudioToolbox
import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct Stage17Stage2Tests {
    typealias S1 = Stage16Stage1Tests
    static let mpeAddresses: Set<AUParameterAddress> = [163, 164, 165, 166].map { AUParameterAddress($0) }.reduce(into: []) { $0.insert($1) }

    static func savedPreset(_ unit: SyntAudioUnit) throws -> SynthPreset {
        let state = try #require(unit.fullState)
        let data = try #require(state[SyntAudioUnit.statePresetKey] as? Data)
        return try JSONDecoder().decode(SynthPreset.self, from: data)
    }

    /// Old code: storeControllerMPEConfig wrote 163–166 into store + tree → host observers fired
    /// (dirty project; Touch/Latch could record it) and fullState changed.
    @Test func testR14_1_ControllerMessagesDoNotNotifyHostOrChangeState() throws {
        let unit = try S1.makeMPEUnit()
        unit.drainControllerMPEConfig()
        let before = try Self.savedPreset(unit)
        let tree = try #require(unit.parameterTree)
        var notified: [AUParameterAddress] = []
        let token = tree.token(byAddingParameterObserver: { address, _ in
            if Self.mpeAddresses.contains(address) { notified.append(address) }
        })
        defer { tree.removeParameterObserver(token) }

        S1.render(unit, midi: S1.rpn(channel: 0, rpn: 6, value: 7))    // MCM 7 members
        S1.render(unit, midi: S1.rpn(channel: 1, rpn: 0, value: 24))   // member range
        S1.render(unit, midi: S1.rpn(channel: 0, rpn: 0, value: 5))    // master range
        unit.drainControllerMPEConfig()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))

        #expect(notified.isEmpty, "controller MPE must not reach host-visible parameters")
        let after = try Self.savedPreset(unit)
        #expect(after.mpePitchBendRange == before.mpePitchBendRange)
        #expect(after.mpeMemberChannelCount == before.mpeMemberChannelCount)
        #expect(after.mpeZone == before.mpeZone)
        #expect(after.mpeEnabled == before.mpeEnabled)
        #expect(after.pitchBendRange == before.pitchBendRange)
        // ... while the runtime really uses the controller values.
        #expect(unit.engine.cachedMpePitchBendRange == 24)
        #expect(unit.engine.cachedMpeMemberChannelCount == 7)
        #expect(unit.engine.cachedPitchBendRange == 5)
    }

    /// Old code: MCM N = 0 was stored as mpeEnabled = false and overrode the user's saved MPE setting.
    @Test func testR14_1_MCMZeroNeverOverridesSavedMPESetting() throws {
        let unit = try S1.makeMPEUnit()          // user turned MPE on
        S1.render(unit, midi: S1.rpn(channel: 0, rpn: 6, value: 0))   // controller "zone off"
        unit.drainControllerMPEConfig()
        #expect(!unit.engine.cachedMpeEnabled, "runtime follows the controller (MPE 1.0)")
        #expect(try Self.savedPreset(unit).mpeEnabled, "saved setting stays the user's")
        #expect(unit.parameterTree?.parameter(withAddress: 163)?.value == 1)

        let reopened = try SyntAudioUnit(componentDescription: S1.desc)
        try reopened.allocateRenderResources()
        reopened.fullState = unit.fullState
        S1.render(reopened)
        #expect(reopened.engine.cachedMpeEnabled, "reopened project uses the user's MPE on")
    }

    /// R14-2 last change wins, standalone main mirror: a different user value replaces the
    /// controller value; repeating the same base keeps it.
    @Test func testR14_2_LastChangeWinsMainMirror() {
        let engine = AudioEngine(coreOnly: true)
        engine.preset.mpeEnabled = true
        for cc: (UInt8, UInt8) in [(101, 0), (100, 0), (6, 20)] {
            engine.handleCommand(.mpeControlChange(channel: 1, cc: cc.0, value: cc.1))
        }
        engine.pollMPEConfigMailbox()
        #expect(engine.mpePitchBendRange == 20)
        engine.preset.filterCutoff = 900            // unrelated change: same MPE base → controller kept
        #expect(engine.mpePitchBendRange == 20)
        #expect(engine.cachedMpePitchBendRange == 20)
        engine.preset.mpePitchBendRange = 12        // user changes the value → user wins
        #expect(engine.mpePitchBendRange == 12)
        #expect(engine.cachedMpePitchBendRange == 12)
        #expect(engine.controllerMPEMain.memberRange == nil)
    }
}
