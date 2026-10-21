//
//  AudibleOutputRegressionTests.swift
//  A note-on must produce sound, both in the engine and in the AU render block.
//

import AVFoundation
import AudioToolbox
import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct AudibleOutputRegressionTests {
    private static let desc = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
        componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)

    private func rms(_ p: UnsafeMutablePointer<Float>, _ n: Int) -> Float {
        var s: Float = 0
        for i in 0..<n { s += p[i] * p[i] }
        return (s / Float(n)).squareRoot()
    }

    @Test func coreEngineNoteOnIsAudible() {
        let engine = AudioEngine(coreOnly: true)
        var on: [UInt8] = [0x90, 60, 100]
        engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        let frames = 512
        let l = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let r = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer { l.deallocate(); r.deallocate() }
        var peak: Float = 0
        for _ in 0..<20 {
            engine.render(frames: frames, intoL: l, intoR: r)
            peak = max(peak, rms(l, frames), rms(r, frames))
        }
        #expect(peak > 0.001, "engine silent: rms \(peak)")
    }

    @Test func audioUnitRenderBlockNoteOnIsAudible() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        let frames = 512
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
        var on: [UInt8] = [0x90, 60, 100]
        unit.engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        var peak: Float = 0
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mFlags = .sampleTimeValid
        for b in 0..<20 {
            time.mSampleTime = Double(b * frames)
            for i in 0..<2 { list[i].mDataByteSize = UInt32(bytes) }
            let status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
            #expect(status == noErr)
            peak = max(peak,
                       rms(list[0].mData!.assumingMemoryBound(to: Float.self), frames),
                       rms(list[1].mData!.assumingMemoryBound(to: Float.self), frames))
        }
        #expect(peak > 0.001, "AU silent: rms \(peak)")
    }

    @Test func ump2NoteOnConvertsToMidi1() {
        let (b, n) = SyntRenderContext.midi2ToMidi1(0x4090_3C00, 0xFFFF_0000)
        #expect(n == 3 && b.0 == 0x90 && b.1 == 60 && b.2 == 127)
        #expect(SyntRenderContext.midi1Length(0xC0) == 2)
        #expect(SyntRenderContext.umpWordCount(0x4) == 2)
    }

    /// Full host path: AVAudioEngine offline + scheduleMIDIEventBlock, like Logic.
    @Test func hostedAudioUnitNoteOnIsAudible() async throws {
        let d = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5354_5354,
            componentManufacturer: 0x5445_5354, componentFlags: 0, componentFlagsMask: 0)
        AUAudioUnit.registerSubclass(SyntAudioUnit.self, as: d, name: "Test: SyntHosted", version: 1)
        let avUnit = try await AVAudioUnit.instantiate(with: d, options: [])
        let engine = AVAudioEngine()
        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        try engine.enableManualRenderingMode(.offline, format: fmt, maximumFrameCount: 512)
        engine.attach(avUnit)
        engine.connect(avUnit, to: engine.mainMixerNode, format: fmt)
        try engine.start()
        defer { engine.stop() }
        let buf = AVAudioPCMBuffer(pcmFormat: engine.manualRenderingFormat, frameCapacity: 512)!
        var peak: Float = 0
        for b in 0..<40 {
            if b == 2 {
                var m: [UInt8] = [0x90, 60, 100]
                avUnit.auAudioUnit.scheduleMIDIEventBlock?(AUEventSampleTimeImmediate, 0, 3, &m)
            }
            _ = try engine.renderOffline(512, to: buf)
            peak = max(peak, rms(buf.floatChannelData![0], Int(buf.frameLength)))
        }
        #expect(peak > 0.001, "hosted AU silent (host sends .midiEventList UMP): rms \(peak)")
    }
}
