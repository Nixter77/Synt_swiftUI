//
//  AUv3ReliabilityTests.swift
//  Synt_swiftUITests
//

import AudioToolbox
import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct AUv3ReliabilityTests {
    private static let testDescription = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice,
        componentSubType: 0x5379_6E74,
        componentManufacturer: 0x4E69_7872,
        componentFlags: 0,
        componentFlagsMask: 0
    )

    private func renderUnit(_ unit: SyntAudioUnit, frames: Int, events: UnsafePointer<AURenderEvent>? = nil) -> [Float] {
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer {
            list[0].mData?.deallocate()
            list[1].mData?.deallocate()
            list.unsafeMutablePointer.deallocate()
        }
        let bytes = frames * MemoryLayout<Float>.size
        list[0] = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: UInt32(bytes),
            mData: UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: MemoryLayout<Float>.alignment)
        )
        list[1] = AudioBuffer(
            mNumberChannels: 1,
            mDataByteSize: UInt32(bytes),
            mData: UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: MemoryLayout<Float>.alignment)
        )
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mSampleTime = 0
        time.mFlags = .sampleTimeValid

        _ = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, events, nil)
        let outL = list[0].mData!.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: outL, count: frames))
    }

    @Test func r5RegressionFirstBufferAfterFullStateRendersNewPatchImmediately() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        try unit.allocateRenderResources()

        var customPreset = SynthPreset.defaultPreset
        customPreset.name = "R5TestPreset"
        customPreset.osc1Waveform = .sawtooth
        customPreset.osc2Waveform = .square
        customPreset.filterCutoff = 800.0
        customPreset.distortionEnabled = true
        customPreset.distortionDrive = 0.8
        customPreset.lfoEnabled = true
        customPreset.lfoRate = 5.0
        customPreset.lfoDepth = 1.0
        customPreset.modMatrix = [
            ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.9)
        ]

        var state = try #require(unit.fullState)
        state["syntPreset"] = try JSONEncoder().encode(customPreset)

        // Set fullState. Under R5, it synchronously publishes rtPresetBuffer and rtModMatrix.
        unit.fullState = state

        // Render the very first buffer immediately through internalRenderBlock
        var midiEvent = AUMIDIEvent()
        midiEvent.eventSampleTime = 0
        midiEvent.eventType = .MIDI
        midiEvent.length = 3
        midiEvent.data = (0x90, 60, 100)

        var event = AURenderEvent()
        event.MIDI = midiEvent

        let frames = 512
        let samples = withUnsafePointer(to: &event) { eventPtr in
            renderUnit(unit, frames: frames, events: eventPtr)
        }

        let defaultUnit = try SyntAudioUnit(componentDescription: Self.testDescription)
        try defaultUnit.allocateRenderResources()
        let defSamples = withUnsafePointer(to: &event) { eventPtr in
            renderUnit(defaultUnit, frames: frames, events: eventPtr)
        }

        var hash: UInt64 = 14695981039346656037
        var defHash: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        for i in 0..<frames {
            hash = (hash ^ UInt64(samples[i].bitPattern)) &* prime
            defHash = (defHash ^ UInt64(defSamples[i].bitPattern)) &* prime
        }

        #expect(hash != defHash, "First buffer rendered immediately after fullState must reflect the new preset without waiting for main queue runloop")
    }

    @Test func parameterRampIsMonotonicOverFrames() throws {
        let engine = AudioEngine()
        let cutoffAddress = SynthParameterAddress.filterCutoff.rawValue

        // Start from 200 Hz, ramp to 2000 Hz over 512 frames
        engine.applyAddressedParameterRT(id: cutoffAddress, value: 200.0)
        engine.enqueueParameterRamp(
            id: cutoffAddress,
            startValue: 200.0,
            endValue: 2000.0,
            durationFrames: 512,
            sampleOffset: 0
        )

        var lastCutoff: Float = 200.0
        for _ in 0..<512 {
            engine.advanceParameterRampsRT()
            let current = engine.cachedFilterCutoff
            #expect(current >= lastCutoff, "Cutoff must be monotonically increasing during ramp: \(current) >= \(lastCutoff)")
            lastCutoff = current
        }

        // After ramp completes, it reaches the target
        #expect(abs(lastCutoff - 2000.0) < 1.0)
        #expect(!engine.hasActiveRamps)
    }

    @Test func tailTimeReportsCorrectlyForDelayAndReverb() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)

        // Default preset: delayMix = 0, reverbMix = 0.2, release = 0.3
        let dryReleaseTail = unit.tailTime
        #expect(dryReleaseTail >= 2.0, "Reverb is enabled by default so tailTime reflects reverb")

        // Turn off reverb and delay
        unit.engine.preset.delayMix = 0.0
        unit.engine.preset.reverbMix = 0.0
        unit.engine.preset.release = 0.5
        #expect(abs(unit.tailTime - 0.5) < 0.01)

        // Turn on delay with 0.8 feedback and 0.5s time
        unit.engine.preset.delayMix = 0.4
        unit.engine.preset.delayFeedback = 0.8
        unit.engine.preset.delayTime = 0.5
        let delayTail = unit.tailTime
        #expect(delayTail > 2.0, "Delay with 0.8 feedback should provide multi-second tailTime")
    }

    @Test func respondsToProgramChangeRoundtripInFullState() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        #expect(!unit.respondsToProgramChange, "Program change must be disabled by default")
        #expect(!unit.engine.respondsToProgramChange)

        unit.respondsToProgramChange = true
        #expect(unit.engine.respondsToProgramChange)

        let state = try #require(unit.fullState)
        let newUnit = try SyntAudioUnit(componentDescription: Self.testDescription)
        newUnit.fullState = state
        #expect(newUnit.respondsToProgramChange)
        #expect(newUnit.engine.respondsToProgramChange)
    }

    @Test func latencyAndChannelCapabilities() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.testDescription)
        #expect(unit.latency == 0.0)
        #expect(unit.channelCapabilities == [0, 2])
    }
}
