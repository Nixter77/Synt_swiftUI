//
//  Stage16Stage1Tests.swift
//  SYNT_16 Stage 1: R13-1 — controller RPN 0 / MCM persists in the AU (coreOnly engine)
//  and in standalone across parameter / automation / preset snapshots.
//

import AudioToolbox
import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct Stage16Stage1Tests {
    static let desc = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
        componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)

    /// Renders one buffer through the real AU render block with the given 3-byte MIDI messages.
    static func render(_ unit: SyntAudioUnit, midi: [(UInt8, UInt8, UInt8)] = [], frames: Int = 256) {
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        let bytes = frames * 4
        for i in 0..<2 {
            list[i] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes),
                                  mData: UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16))
        }
        defer { list[0].mData?.deallocate(); list[1].mData?.deallocate(); list.unsafeMutablePointer.deallocate() }
        let events = UnsafeMutablePointer<AURenderEvent>.allocate(capacity: max(1, midi.count))
        defer { events.deallocate() }
        for (i, m) in midi.enumerated() {
            var e = AUMIDIEvent()
            e.eventSampleTime = AUEventSampleTime(i)
            e.eventType = .MIDI
            e.length = 3
            e.data = (m.0, m.1, m.2)
            events[i] = AURenderEvent(MIDI: e)
        }
        for i in 0..<midi.count {
            let next: UnsafeMutablePointer<AURenderEvent>? = i + 1 < midi.count ? events + i + 1 : nil
            events[i].head.next = next
        }
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mFlags = .sampleTimeValid
        _ = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer,
                                     midi.isEmpty ? nil : UnsafePointer(events), nil)
    }

    static func rpn(channel: UInt8, rpn: UInt8, value: UInt8) -> [(UInt8, UInt8, UInt8)] {
        let s = 0xB0 | channel
        return [(s, 101, 0), (s, 100, rpn), (s, 6, value)]
    }

    static func makeMPEUnit() throws -> SyntAudioUnit {
        let unit = try SyntAudioUnit(componentDescription: desc)
        try unit.allocateRenderResources()
        unit.parameterTree?.parameter(withAddress: SynthParameterAddress.mpeEnabled.rawValue)?.value = 1
        render(unit)
        #expect(unit.engine.cachedMpeEnabled)
        return unit
    }

    /// R13-1: RPN 0 from the controller, then a host automation write and a whole-state
    /// round trip: the controller range must still be in force (old code: snapshot → 48).
    @Test func testR13_1_AUControllerRangeSurvivesParameterAndPresetSnapshot() throws {
        let unit = try Self.makeMPEUnit()
        Self.render(unit, midi: Self.rpn(channel: 1, rpn: 0, value: 24))
        #expect(unit.engine.cachedMpePitchBendRange == 24)

        unit.parameterTree?.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue)?.value = 900
        Self.render(unit)
        #expect(unit.engine.cachedMpePitchBendRange == 24, "automation must not reset the controller range")

        unit.uiPreset = unit.uiPreset   // whole-preset adopt (snapshot path)
        Self.render(unit)
        Self.render(unit)
        #expect(unit.engine.cachedMpePitchBendRange == 24, "preset snapshot must not reset the controller range")
    }

    /// R13-1: saved with the project. fullState carries the controller range.
    @Test func testR13_1_AUControllerRangeIsSavedInFullState() throws {
        let unit = try Self.makeMPEUnit()
        Self.render(unit, midi: Self.rpn(channel: 1, rpn: 0, value: 30))
        let state = try #require(unit.fullState)
        let data = try #require(state[SyntAudioUnit.statePresetKey] as? Data)
        let saved = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(saved.mpePitchBendRange == 30)

        let restored = try SyntAudioUnit(componentDescription: Self.desc)
        try restored.allocateRenderResources()
        restored.fullState = state
        Self.render(restored)
        #expect(restored.engine.cachedMpePitchBendRange == 30)
    }

    /// R13-1: the AU's own main-thread timer drains the mailbox (no manual poll) into the tree.
    @Test func testR13_1_AUTimerDrainsMailboxIntoParameterTree() async throws {
        let unit = try Self.makeMPEUnit()
        Self.render(unit, midi: Self.rpn(channel: 0, rpn: 6, value: 9))
        Self.render(unit, midi: Self.rpn(channel: 1, rpn: 0, value: 36))
        try await Task.sleep(for: .milliseconds(450))   // main queue free: the AU's own timer fires
        let tree = try #require(unit.parameterTree)
        #expect(tree.parameter(withAddress: SynthParameterAddress.mpePitchBendRange.rawValue)?.value == 36)
        #expect(tree.parameter(withAddress: SynthParameterAddress.mpeMemberChannelCount.rawValue)?.value == 9)
        Self.render(unit)
        #expect(unit.engine.cachedMpePitchBendRange == 36)
        #expect(unit.engine.cachedMpeMemberChannelCount == 9)
    }

    /// An explicit user / host change of the parameter still wins over the controller value.
    @Test func testR13_1_ExplicitParameterChangeReplacesControllerValue() throws {
        let unit = try Self.makeMPEUnit()
        Self.render(unit, midi: Self.rpn(channel: 1, rpn: 0, value: 24))
        unit.parameterTree?.parameter(withAddress: SynthParameterAddress.mpePitchBendRange.rawValue)?.value = 12
        Self.render(unit)
        #expect(unit.engine.cachedMpePitchBendRange == 12)
    }

    /// Standalone race: a knob move (applyPreset) before the 33 ms poll must not drop the RPN.
    @Test func testR13_1_StandaloneKnobBeforePollKeepsControllerRange() {
        let engine = AudioEngine(coreOnly: true)
        engine.preset.mpeEnabled = true
        #expect(engine.cachedMpeEnabled)
        for cc: (UInt8, UInt8) in [(101, 0), (100, 0), (6, 20)] {
            engine.handleCommand(.mpeControlChange(channel: 1, cc: cc.0, value: cc.1))
        }
        engine.preset.filterCutoff = 700     // knob move → applyPreset → snapshot
        #expect(engine.cachedMpePitchBendRange == 20)
        #expect(engine.preset.mpePitchBendRange == 20)
        #expect(engine.mpePitchBendRange == 20)
    }
}
