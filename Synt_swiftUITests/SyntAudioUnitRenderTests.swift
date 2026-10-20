//
//  SyntAudioUnitRenderTests.swift
//  The Audio Unit renders through SynthCore without opening the device.
//

import AudioToolbox
import Foundation
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
}
