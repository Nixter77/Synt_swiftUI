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
        unit.respondsToProgramChange = true
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

    @Test func fullScheduleStillAppliesNoteOff() throws {
        let unit = try makeUnit()
        #expect(unit.audioUnitMIDIProtocol == ._1_0)
        let engine = unit.engine
        var on: [UInt8] = [0x90, 60, 100]
        engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        let l = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: 64)
        defer { l.deallocate(); r.deallocate() }
        engine.render(frames: 64, intoL: l, intoR: r)
        #expect(engine.voices.contains { $0.isActive && !$0.isReleasing && $0.midiNote == 60 })
        var cc: [UInt8] = [0xB0, 1, 10]
        for _ in 0..<512 { engine.enqueueMIDI(&cc, count: 3, sampleOffset: 0) }
        var off: [UInt8] = [0x80, 60, 0]
        engine.enqueueMIDI(&off, count: 3, sampleOffset: 0)
        #expect(!engine.voices.contains { $0.isActive && !$0.isReleasing && $0.midiNote == 60 })
    }

    @Test func newerStateVersionIsNotLoaded() throws {
        let unit = try makeUnit()
        var state = try #require(unit.fullState)
        var other = unit.uiPreset
        other.filterCutoff = 321
        state["syntPreset"] = try JSONEncoder().encode(other)
        state["syntStateVersion"] = 99
        let before = unit.uiPreset.filterCutoff
        unit.fullState = state
        #expect(unit.uiPreset.filterCutoff == before)
        state["syntStateVersion"] = 1
        unit.fullState = state
        #expect(unit.uiPreset.filterCutoff == 321)
    }

    @Test func auPluginMetricsAre1100x520() {
        #expect(AUPluginMetrics.contentWidth == 1100)
        #expect(AUPluginMetrics.contentHeight == 520)
    }

    @Test func fullStateSetFromBackgroundThreadDispatchesToMain() throws {
        let unit = try makeUnit()
        var other = unit.uiPreset
        other.filterCutoff = 432
        var state = try #require(unit.fullState)
        state["syntPreset"] = try JSONEncoder().encode(other)

        let exp = NotificationCenter.default.addObserver(
            forName: SyntAudioUnit.stateDidChangeNotification,
            object: unit,
            queue: nil
        ) { _ in
            #expect(Thread.isMainThread, "stateDidChangeNotification must arrive on main thread")
        }
        defer { NotificationCenter.default.removeObserver(exp) }

        let group = DispatchGroup()
        group.enter()
        nonisolated(unsafe) let bgUnit = unit  // test-only: exercise off-main fullState set
        DispatchQueue.global().async {
            bgUnit.fullState = state
            group.leave()
        }
        group.wait()

        let start = Date()
        while Date().timeIntervalSince(start) < 2.0 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            if unit.uiPreset.filterCutoff == 432 { break }
        }
        #expect(unit.uiPreset.filterCutoff == 432)
    }

    /// The matrix row and the MSEG bank are published before this returns.
    /// Main applies the preset copy later. The buffer in between must already
    /// read the new curve.
    @Test func backgroundFullStatePublishesTheMSEGBankBeforeMain() throws {
        let unit = try makeUnit()
        #expect(unit.engine.mseg.hasPoints == false)
        var preset = SynthPreset.defaultPreset
        preset.mseg.points = [
            DSPMSEGPoint(time: 0, value: -1),
            DSPMSEGPoint(time: 1, value: -1)
        ]
        preset.mseg.sustainIndex = nil
        preset.modMatrix = [ModMatrixEntry(source: .mseg, destination: .pitch1, amount: 0.2)]
        var state = try #require(unit.fullState)
        state[SyntAudioUnit.statePresetKey] = try JSONEncoder().encode(preset)

        DispatchQueue.global().sync {
            unit.fullState = state
            #expect(unit.engine.mseg.hasPoints)
            unit.engine.handleNoteOn(midiNote: 60, velocity: 1)
            let frame = unit.engine.renderOneSample()
            #expect(frame.0.isFinite && frame.1.isFinite)
            #expect(abs(unit.engine.mseg.currentValue - (-1)) < 1.0e-3)
        }

        let start = Date()
        while Date().timeIntervalSince(start) < 2.0 {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            if unit.engine.preset.mseg.points.count == 2 { break }
        }
        #expect(unit.engine.preset.mseg.points.count == 2)
    }

    @Test func panIsPreservedInPresetRoundtrip() throws {
        let unit = try makeUnit()
        var preset = SynthPreset.defaultPreset
        preset.pan = 0.42
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(abs(decoded.pan - 0.42) < 1e-5)

        var state = try #require(unit.fullState)
        state["syntPreset"] = data
        unit.fullState = state
        #expect(abs(unit.uiPreset.pan - 0.42) < 1e-5)
    }
}
