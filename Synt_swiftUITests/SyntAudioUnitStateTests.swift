//
//  SyntAudioUnitStateTests.swift
//  Parameter tree, factory preset list, and document state.
//

import AudioToolbox
import Foundation
import Synchronization
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

    @Test func hostCutoffFromAnyThreadLandsInFullStateAndTheRender() async throws {
        let unit = try makeUnit()
        let tree = try #require(unit.parameterTree)
        let cutoff = try #require(tree.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue))
        await Task.detached { cutoff.value = 1234 }.value
        let state = try #require(unit.fullState)
        let data = try #require(state["syntPreset"] as? Data)
        let saved = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(saved.filterCutoff == 1234)
        #expect(cutoff.value == 1234)
        #expect(unit.engine.cachedFilterCutoff != 1234, "only the render applies it")
        try renderOnce(unit)
        #expect(unit.engine.cachedFilterCutoff == 1234)
    }

    private func renderOnce(_ unit: SyntAudioUnit, frames: Int = 64) throws {
        try unit.allocateRenderResources()
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        let bytes = frames * MemoryLayout<Float>.size
        for i in 0..<2 {
            list[i] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes),
                                  mData: UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16))
        }
        defer {
            list[0].mData?.deallocate(); list[1].mData?.deallocate()
            list.unsafeMutablePointer.deallocate()
        }
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mFlags = .sampleTimeValid
        let status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
        #expect(status == noErr)
    }

    @Test func mainThreadCutoffWritesThePresetAndTheCache() throws {
        let unit = try makeUnit()
        let tree = try #require(unit.parameterTree)
        let cutoff = try #require(tree.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue))
        cutoff.value = 800
        #expect(unit.engine.preset.filterCutoff == 800)
        try renderOnce(unit)
        #expect(unit.engine.cachedFilterCutoff == 800)
        #expect(tree.allParameters.count == SynthParameterAddress.allCases.count - 2) // no Apple reverb in the AU
    }

    @Test func hostParameterEventsAreScheduledByOffsetAndNotRamped() throws {
        let unit = try makeUnit()
        let tree = try #require(unit.parameterTree)
        for parameter in tree.allParameters {
            #expect(!parameter.flags.contains(.flag_CanRamp))
        }
        let engine = unit.engine
        engine.prepare(sampleRate: 44_100, maxFrames: 64)
        engine.enqueueParameter(id: SynthParameterAddress.filterCutoff.rawValue, value: 1234, sampleOffset: 40)
        #expect(engine.cachedFilterCutoff != 1234, "not applied before its offset is rendered")
        let l = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { l.deallocate(); r.deallocate() }
        engine.render(frames: 64, intoL: l, intoR: r)
        #expect(engine.cachedFilterCutoff == 1234)
    }

    @Test func audioUnitDelayIsAudibleWithPingPongOff() throws {
        let unit = try makeUnit()
        var preset = unit.uiPreset
        preset.delayPingPong = false
        preset.delayMix = 0.8
        preset.delayTime = 0.01
        preset.delayFeedback = 0.5
        unit.uiPreset = preset
        #expect(unit.engine.cachedDelayPingPong, "DSP delay renders in the AU")
        #expect(unit.engine.pingPongDelay.enabled)
        #expect(!unit.engine.pingPongDelay.crossFeed)
        let tree = try #require(unit.parameterTree)
        #expect(tree.parameter(withAddress: SynthParameterAddress.reverbMix.rawValue) == nil)
    }

    @Test func audioUnitEngineIsCoreOnlyAndProgramChangeSyncsTheTree() throws {
        let unit = try makeUnit()
        #expect(unit.engine.sourceNodeSampleRateForTesting == 0, "no device graph in the AU")
        #expect(MIDICCLearnStore.shared.engine !== unit.engine)
        let target = try #require(PresetBrowser.preset(forProgram: 3))
        unit.engine.pendingProgram.store(3, ordering: .releasing)
        unit.applyPendingProgram()
        #expect(unit.engine.preset.name == target.name)
        let tree = try #require(unit.parameterTree)
        let cutoff = try #require(tree.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue))
        #expect(cutoff.value == SynthParameterAddress.filterCutoff.clamped(target.filterCutoff))
    }

    @Test func viewEditAfterFullStateKeepsTheLoadedState() throws {
        let unit = try makeUnit()
        var loaded = unit.uiPreset
        loaded.voiceMode = .mono
        loaded.unisonVoices = 3
        loaded.filterCutoff = 900
        let other = try makeUnit()
        other.uiPreset = loaded
        let state = try #require(other.fullState)

        var notified = 0
        let token = NotificationCenter.default.addObserver(
            forName: SyntAudioUnit.stateDidChangeNotification, object: unit, queue: nil
        ) { _ in notified += 1 }
        defer { NotificationCenter.default.removeObserver(token) }
        unit.fullState = state
        #expect(notified == 1, "the view is told to re-read the whole preset")

        // The view re-reads, then edits one non-addressed field.
        var edited = unit.uiPreset
        edited.unisonVoices = 4
        edited.filterCutoff = 5000 // stale addressed value must not win here
        unit.adoptNonAddressedFields(of: edited)
        #expect(unit.engine.preset.voiceMode == .mono)
        #expect(unit.engine.preset.unisonVoices == 4)
        #expect(unit.uiPreset.filterCutoff == 900)
    }

    @Test func reallocateDropsVoicesAndTheSchedule() throws {
        let unit = try makeUnit()
        try renderOnce(unit)
        var on: [UInt8] = [0x90, 60, 100]
        unit.engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        let l = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { l.deallocate(); r.deallocate() }
        unit.engine.render(frames: 64, intoL: l, intoR: r)
        #expect(unit.engine.voices.contains { $0.isActive })
        unit.engine.enqueueMIDI(&on, count: 3, sampleOffset: 10)
        unit.deallocateRenderResources()
        try unit.allocateRenderResources()
        #expect(unit.engine.midiScheduleCount == 0)
        #expect(!unit.engine.voices.contains { $0.isActive })
    }
}
