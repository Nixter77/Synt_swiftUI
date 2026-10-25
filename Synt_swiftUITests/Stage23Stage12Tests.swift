//
//  Stage23Stage12Tests.swift
//  SYNT_23 Stage 1 (R14-9) and Stage 2 (R14-10).
//

import Testing
import Foundation
import AudioToolbox
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
@Suite(.serialized)
struct Stage23Stage12Tests {

    static func makeUnit() throws -> SyntAudioUnit {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)
        return try SyntAudioUnit(componentDescription: description)
    }

    /// R14-9. A host thread sets fullState and reads it back before main runs. Old code built the
    /// snapshot from main-owned `engine.preset`, still the previous patch until the main hop →
    /// non-addressed fields (fxOrder) came back stale.
    @Test func testR14_9_OffMainFullStateRoundTripSeesAdoptedPreset() throws {
        let unit = try Self.makeUnit()
        var b = SynthPreset.defaultPreset
        b.fxOrder = FXSlotID.defaultOrder.reversed()
        let data = try JSONEncoder().encode(b)
        var state = unit.fullState ?? [:]
        state[SyntAudioUnit.statePresetKey] = data

        // Main is blocked on the semaphore, so adoptPreset's main hop cannot run in between.
        let sem = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var readBack: [FXSlotID]?
        nonisolated(unsafe) let u = unit
        let s = state
        DispatchQueue.global().async {
            u.fullState = s
            if let d = u.fullState?[SyntAudioUnit.statePresetKey] as? Data,
               let p = try? JSONDecoder().decode(SynthPreset.self, from: d) {
                readBack = p.fxOrder
            }
            sem.signal()
        }
        sem.wait()
        #expect(readBack == FXSlotID.defaultOrder.reversed())
    }

    /// SYNT_24 R20-1 (fails on old code). Off-main set B; main takes a snapshot before the hop runs
    /// (old: refreshed the mirror from the stale engine.preset A); an off-main get must still see B.
    @Test func testR20_1_MainSnapshotBeforeHopDoesNotClobberMirror() throws {
        let unit = try Self.makeUnit()
        var b = SynthPreset.defaultPreset
        b.fxOrder = FXSlotID.defaultOrder.reversed()
        var state = unit.fullState ?? [:]
        state[SyntAudioUnit.statePresetKey] = try JSONEncoder().encode(b)
        nonisolated(unsafe) let u = unit
        let s = state
        let sem = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { u.fullState = s; sem.signal() }
        sem.wait()
        // Main, hop still queued behind this test.
        let mainSeen = unit.presetSnapshot().fxOrder
        nonisolated(unsafe) var readBack: [FXSlotID]?
        DispatchQueue.global().async {
            if let d = u.fullState?[SyntAudioUnit.statePresetKey] as? Data,
               let p = try? JSONDecoder().decode(SynthPreset.self, from: d) { readBack = p.fxOrder }
            sem.signal()
        }
        sem.wait()
        #expect(mainSeen == FXSlotID.defaultOrder.reversed())
        #expect(readBack == FXSlotID.defaultOrder.reversed())
    }

    /// R14-10. A `controllerMPEConfigDidChange` callback that writes `preset` fires from inside
    /// applyPreset (pollMPEConfigMailbox). Old code re-entered applyPreset mid-pass; now the nested
    /// call is coalesced into a follow-up pass and the callback's value is still applied.
    @Test func testR14_10_ApplyPresetReentryIsCoalesced() {
        let e = AudioEngine(coreOnly: true)
        e.preset.mpeEnabled = true
        e.controllerMPEConfigDidChange = { [unowned e] in
            // Runs inside applyPreset; this write would recurse on old code.
            e.preset.filterCutoff = 1234
        }
        // Render-side MCM (ch1, N=10) → mailbox.
        for (cc, v) in [(UInt8(101), UInt8(0)), (100, 6), (6, 10)] {
            let msg = MIDIMessage.controlChange(controller: cc, value: v, channel: 0)
            if let cmd = AudioEngine.command(for: msg, mpeEnabled: e.cachedMpeEnabled, zone: e.cachedMpeZone,
                                             memberCount: e.cachedMpeMemberChannelCount) {
                e.handleCommand(cmd)
            }
        }
        let before = e.applyPresetCallCountForTesting
        e.preset.filterCutoff = 500   // applyPreset → poll → callback → preset write
        #expect(e.applyPresetCoalescedCountForTesting == 1, "nested applyPreset must be coalesced")
        #expect(e.applyPresetCallCountForTesting - before == 2, "one pass + one coalesced rerun")
        #expect(e.preset.filterCutoff == 1234)
        #if DEBUG
        #expect(e.applyPresetOffMainCountForTesting == 0)
        #endif
    }

    /// SYNT_24 R20-2 (fails on old code: no cap counter, silent drop). A pass hook that writes
    /// `preset` 5 times never converges within 4 passes → counted once, assert suppressed.
    @Test func testR20_2_ApplyPresetCapHitIsCounted() {
        #if DEBUG
        let e = AudioEngine(coreOnly: true)
        e.applyPresetCapAssertEnabled = false
        var writes = 0
        e.applyPresetPassHookForTesting = { [unowned e] in
            if writes < 5 { writes += 1; e.preset.filterCutoff = Float(1000 + writes) }
        }
        let before = e.applyPresetCallCountForTesting
        e.preset.filterCutoff = 500
        e.applyPresetPassHookForTesting = nil
        #expect(e.applyPresetCallCountForTesting - before == AudioEngine.applyPresetMaxPasses)
        #expect(e.applyPresetCapHitCountForTesting == 1)
        #expect(writes == 4)
        // Converging case does not count.
        e.preset.filterCutoff = 600
        #expect(e.applyPresetCapHitCountForTesting == 1)
        #endif
    }

    /// SYNT_24 R19-5: the DEBUG fallback-key log is bounded.
    @Test func testR19_5_TolerantDecodeLogIsBounded() {
        #if DEBUG
        TolerantDecodeLog.resetForTesting()
        struct E: Error {}
        for i in 0..<(TolerantDecodeLog.maxKeys + 50) { TolerantDecodeLog.record(key: "k\(i)", error: E()) }
        let keys = TolerantDecodeLog.fallbackKeysForTesting()
        #expect(keys.count == TolerantDecodeLog.maxKeys)
        #expect(keys.last == "k\(TolerantDecodeLog.maxKeys + 49)")
        TolerantDecodeLog.resetForTesting()
        #endif
    }

    /// SYNT_25 Stage 3 (fails on old code: default was off). All Swift Testing suites are now
    /// @MainActor, so the DEBUG hard main-thread check on applyPreset is on by default.
    @Test func testStrictMainThreadApplyPresetDefaultOnInDebug() {
        #if DEBUG
        #expect(AudioEngine.strictMainThreadApplyPreset)
        let e = AudioEngine(coreOnly: true)
        let before = e.applyPresetOffMainCountForTesting
        e.preset.filterCutoff = 777   // main → must not trap, must not count
        #expect(e.applyPresetOffMainCountForTesting == before)
        #endif
    }
}
