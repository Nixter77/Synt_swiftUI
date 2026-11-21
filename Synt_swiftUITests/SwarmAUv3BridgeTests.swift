//
//  SwarmAUv3BridgeTests.swift
//  Synt_swiftUITests
//
//  Tests for AUv3 thread-safety, chrome fullState round-trips, tailTime sends,
//  and SyntAUViewController off-main lifecycle guarantees.
//

import AudioToolbox
import CoreAudioKit
import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct SwarmAUv3BridgeTests {
    private static let testDescription = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice,
        componentSubType: 0x5379_6E74,
        componentManufacturer: 0x4E69_7872,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private func drainMainRunLoop(seconds: TimeInterval = 0.1) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    @Test func offMainFullStateZoomAndLayoutRoundTripsSafely() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        unit.uiZoom = .p150
        unit.uiLayout = .extended

        nonisolated(unsafe) let bgUnit = unit
        let savedState: [String: Any]? = DispatchQueue.global(qos: .userInitiated).sync {
            bgUnit.fullState
        }
        let state = try #require(savedState)

        unit.uiZoom = .p75
        unit.uiLayout = .compact

        DispatchQueue.global(qos: .userInitiated).sync {
            bgUnit.fullState = state
        }

        // Synchronous off-main reads must immediately reflect the restored chrome.
        let restored: (PluginZoom, PluginLayout) = DispatchQueue.global(qos: .userInitiated).sync {
            (bgUnit.uiZoom, bgUnit.uiLayout)
        }
        #expect(restored.0 == .p150)
        #expect(restored.1 == .extended)
        #expect(unit.uiZoom == .p150)
        #expect(unit.uiLayout == .extended)
        drainMainRunLoop()
    }

    @Test func concurrentChromeAccessAndFullStateDoesNotRace() async throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        nonisolated(unsafe) let bgUnit = unit

        var presetA = SynthPreset.defaultPreset
        presetA.filterCutoff = 1100
        unit.uiPreset = presetA
        unit.uiZoom = .p125
        unit.uiLayout = .extended
        let stateA = try #require(unit.fullState)

        var presetB = SynthPreset.defaultPreset
        presetB.filterCutoff = 2200
        unit.uiPreset = presetB
        unit.uiZoom = .p75
        unit.uiLayout = .compact
        let stateB = try #require(unit.fullState)

        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for i in 0..<40 {
                    bgUnit.uiZoom = (i % 2 == 0) ? .p150 : .p100
                    bgUnit.uiLayout = (i % 2 == 0) ? .extended : .compact
                    _ = bgUnit.fullState
                }
            }
            group.addTask {
                for i in 0..<40 {
                    nonisolated(unsafe) let target = (i % 2 == 0) ? stateA : stateB
                    bgUnit.fullState = target
                    let z = bgUnit.uiZoom
                    let l = bgUnit.uiLayout
                    #expect(PluginZoom.allCases.contains(z))
                    #expect(PluginLayout.allCases.contains(l))
                }
            }
        }
        drainMainRunLoop()
    }

    @Test func tailTimeConsidersSendAAndSendBAndReverb() throws {
        var dry = SynthPreset.defaultPreset
        dry.release = 0.4
        dry.delayMix = 0.0
        dry.reverbMix = 0.0
        dry.sendA = 0.0
        dry.sendB = 0.0
        #expect(abs(SyntAudioUnit.tailTime(for: dry) - 0.4) < 1e-6)

        // Send A (reverb send) adds reverb tail even when insert reverbMix is 0.
        var sendAPreset = dry
        sendAPreset.sendA = 0.5
        sendAPreset.reverbRoomSize = 0.5
        #expect(abs(SyntAudioUnit.tailTime(for: sendAPreset) - 5.0) < 1e-6)

        // Send B (delay send) adds delay tail even when insert delayMix is 0.
        var sendBPreset = dry
        sendBPreset.sendB = 0.5
        sendBPreset.delayTime = 0.5
        sendBPreset.delayFeedback = 0.8
        #expect(abs(SyntAudioUnit.tailTime(for: sendBPreset) - 2.5) < 1e-6)

        // DSP reverb enabled with non-zero mix reports reverb tail.
        var dspRevPreset = dry
        dspRevPreset.dspReverbEnabled = true
        dspRevPreset.reverbMix = 0.25
        dspRevPreset.reverbRoomSize = 0.5
        #expect(abs(SyntAudioUnit.tailTime(for: dspRevPreset) - 5.0) < 1e-6)

        // DSP reverb enabled with zero mix adds no spurious tail beyond release.
        var zeroMixDspRev = dry
        zeroMixDspRev.dspReverbEnabled = true
        zeroMixDspRev.reverbMix = 0.0
        #expect(abs(SyntAudioUnit.tailTime(for: zeroMixDspRev) - 0.4) < 1e-6)

        // Unit-level check via uiPreset.
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        unit.uiPreset = sendBPreset
        #expect(abs(unit.tailTime - 2.5) < 1e-6)
    }

    @Test func allocateAndReallocateRenderResourcesRendersCleanly() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        for _ in 0..<2 {
            try unit.allocateRenderResources()
            let frames = 64
            let list = AudioBufferList.allocate(maximumBuffers: 2)
            let bytes = frames * MemoryLayout<Float>.size
            for i in 0..<2 {
                list[i] = AudioBuffer(
                    mNumberChannels: 1,
                    mDataByteSize: UInt32(bytes),
                    mData: UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16)
                )
            }
            defer {
                list[0].mData?.deallocate()
                list[1].mData?.deallocate()
                list.unsafeMutablePointer.deallocate()
            }
            var flags = AudioUnitRenderActionFlags()
            var time = AudioTimeStamp()
            time.mFlags = .sampleTimeValid
            let status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
            #expect(status == noErr)
            unit.deallocateRenderResources()
        }
    }

    @Test func headlessAudioUnitCreationDoesNotHijackPatchHistoryProvider() throws {
        PatchHistoryManager.shared.reset()
        defer { PatchHistoryManager.shared.reset() }

        var sentinel = SynthPreset.defaultPreset
        sentinel.name = "SentinelWindowPreset"
        PatchHistoryManager.shared.registerPresetProvider { sentinel }

        // Instantiate SyntAudioUnit off-main (simulating AUv3 XPC queue headless load).
        let desc = Self.testDescription
        let unit: SyntAudioUnit = try DispatchQueue.global(qos: .userInitiated).sync {
            try SyntAudioUnit(componentDescription: desc, options: [])
        }
        var other = SynthPreset.defaultPreset
        other.name = "HeadlessPluginPreset"
        unit.uiPreset = other
        drainMainRunLoop()

        // Sentinel provider must remain intact until a PluginScreen actually appears.
        PatchHistoryManager.shared.onDragStart()
        sentinel.filterCutoff = 1234
        PatchHistoryManager.shared.onDragEnd()
        #expect(PatchHistoryManager.shared.canUndo)
        let undone = PatchHistoryManager.shared.undo()
        #expect(undone?.preset.name == "SentinelWindowPreset")
    }

    @Test func syntAUViewControllerConstructsSurfaceOnMainAndRegistersUndoOnAppear() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SyntAUv3/SyntAUViewController.swift")
        let source = try String(contentsOf: url, encoding: .utf8)

        let createStart = try #require(source.range(of: "func createAudioUnit("))
        let createEnd = try #require(source.range(of: "return unit", range: createStart.upperBound..<source.endIndex))
        let createBody = String(source[createStart.upperBound..<createEnd.lowerBound])

        // createAudioUnit must never instantiate @MainActor AUParameterSurface or touch self.surface off-main.
        #expect(!createBody.contains("AUParameterSurface("))
        #expect(!createBody.contains("self.surface"))
        #expect(!createBody.contains("PatchHistoryManager"))
        #expect(createBody.contains("pendingAudioUnit"))
        #expect(createBody.contains("PluginMainThread.perform"))

        // AUParameterSurface.init must not register PatchHistoryManager provider (deferred to PluginScreen.onAppear).
        let initStart = try #require(source.range(of: "init(audioUnit: SyntAudioUnit)"))
        let deinitStart = try #require(source.range(of: "deinit {", range: initStart.upperBound..<source.endIndex))
        let initBody = String(source[initStart.upperBound..<deinitStart.lowerBound])
        #expect(!initBody.contains("registerPresetProvider"))

        // PluginScreen registers the preset provider inside .onAppear on main.
        let screenStart = try #require(source.range(of: "private struct PluginScreen: View"))
        let screenBody = String(source[screenStart.upperBound..<source.endIndex])
        #expect(screenBody.contains(".onAppear"))
        #expect(screenBody.contains("registerPresetProvider"))
    }
}
