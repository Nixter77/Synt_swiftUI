//
//  SyntAudioUnitRenderTests.swift
//  The Audio Unit renders through SynthCore without opening the device.
//

import AudioToolbox
import Foundation
import Synchronization
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct SyntAudioUnitRenderTests {
    @Test func audioUnitRendersFiniteSamplesAndUsesHostTransport() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        #expect(unit.engine.usesHostTransport)
        #expect(unit.inputBusses.count == 0)
        #expect(unit.outputBusses.count == 1)
        try unit.allocateRenderResources()

        let frames = 64
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
        let status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
        #expect(status == noErr)
        let left = list[0].mData!.assumingMemoryBound(to: Float.self)
        let right = list[1].mData!.assumingMemoryBound(to: Float.self)
        for index in 0..<frames {
            #expect(left[index].isFinite)
            #expect(right[index].isFinite)
        }
    }

    @Test func interleavedBufferIsRefusedAndMonoIsDownmixed() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)
        let unit = try SyntAudioUnit(componentDescription: description)
        try unit.allocateRenderResources()
        let frames = 64
        let list = AudioBufferList.allocate(maximumBuffers: 1)
        let bytes = frames * 2 * MemoryLayout<Float>.size
        let raw = UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16)
        defer { raw.deallocate(); list.unsafeMutablePointer.deallocate() }
        list[0] = AudioBuffer(mNumberChannels: 2, mDataByteSize: UInt32(bytes), mData: raw)
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mFlags = .sampleTimeValid
        var status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
        #expect(status == kAudioUnitErr_FormatNotSupported)

        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(frames * 4), mData: raw)
        status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
        #expect(status == noErr)
        let mono = raw.assumingMemoryBound(to: Float.self)
        for i in 0..<frames { #expect(mono[i].isFinite) }
    }

    @Test func fullStateWithModMatrixRoutingIsAudibleInRender() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unitA = try SyntAudioUnit(componentDescription: description)
        try unitA.allocateRenderResources()
        let unitB = try SyntAudioUnit(componentDescription: description)
        try unitB.allocateRenderResources()

        var presetWithMatrix = SynthPreset.defaultPreset
        presetWithMatrix.lfoEnabled = true
        presetWithMatrix.lfoRate = 5.0
        presetWithMatrix.lfoDepth = 1.0
        presetWithMatrix.modMatrix = [
            ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.8),
            ModMatrixEntry(source: .env2, destination: .cutoff, amount: 0.5)
        ]

        var stateB = try #require(unitB.fullState)
        stateB["syntPreset"] = try JSONEncoder().encode(presetWithMatrix)
        unitB.fullState = stateB

        var on: [UInt8] = [0x90, 60, 100]
        unitA.engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        unitB.engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)

        let frames = 512
        let lA = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let rA = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let lB = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let rB = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer {
            lA.deallocate(); rA.deallocate()
            lB.deallocate(); rB.deallocate()
        }

        unitA.engine.render(frames: frames, intoL: lA, intoR: rA)
        unitB.engine.render(frames: frames, intoL: lB, intoR: rB)

        var fnvA: UInt64 = 14695981039346656037
        var fnvB: UInt64 = 14695981039346656037
        let prime: UInt64 = 1099511628211
        for i in 0..<frames {
            fnvA = (fnvA ^ UInt64(lA[i].bitPattern)) &* prime
            fnvB = (fnvB ^ UInt64(lB[i].bitPattern)) &* prime
        }
        #expect(fnvA != fnvB, "Mod matrix routing in fullState must produce audible difference in render output")
    }

    @Test func concurrentPresetChangeDuringBackgroundRender() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        try unit.allocateRenderResources()
        let frames = 256
        let l = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer { l.deallocate(); r.deallocate() }

        var on: [UInt8] = [0x90, 60, 100]
        unit.engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)

        let stop = Atomic<Bool>(false)
        let group = DispatchGroup()

        group.enter()
        // Test-only cross-thread hand-off; the render thread owns l/r until group.wait().
        nonisolated(unsafe) let renderUnit = unit, renderL = l, renderR = r
        DispatchQueue.global().async {
            while !stop.load(ordering: .acquiring) {
                renderUnit.engine.render(frames: frames, intoL: renderL, intoR: renderR)
            }
            group.leave()
        }

        for i in 0..<30 {
            var p = SynthPreset.defaultPreset
            p.filterCutoff = Float(500 + i * 50)
            p.osc1Volume = Float(i % 10) / 10.0
            p.attack = 0.01 + Float(i) * 0.005
            unit.engine.preset = p
            Thread.sleep(forTimeInterval: 0.001)
        }

        stop.store(true, ordering: .releasing)
        group.wait()
    }
}
