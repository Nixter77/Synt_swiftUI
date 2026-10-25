//
//  Stage7ReverbTests.swift
//  DSP reverb stays off for existing presets and tails in the Audio Unit.
//

import AudioToolbox
import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage7ReverbTests {

    @Test func missingKeyLeavesDSPReverbOffAndTheRenderUnchanged() throws {
        let json = #"{"name":"Old","category":"Lead","reverbMix":0.2}"#
        let preset = try JSONDecoder().decode(SynthPreset.self, from: Data(json.utf8))
        #expect(preset.dspReverbEnabled == false)
        var hot = preset
        hot.reverbDamping = 4
        let cleaned = hot.sanitized()
        #expect(cleaned.reverbDamping == 1)
        #expect(cleaned.dspReverbEnabled == false)

        func render(_ mutate: (inout SynthPreset) -> Void) -> [Float] {
            let engine = AudioEngine()
            var patch = SynthPreset.defaultPreset
            mutate(&patch)
            engine.preset = patch
            engine.prepare(sampleRate: 44_100, maxFrames: 256)
            engine.handleNoteOn(midiNote: 60, velocity: 1)
            var samples: [Float] = []
            samples.reserveCapacity(256)
            for _ in 0..<256 {
                samples.append(engine.renderOneSample().0)
            }
            return samples
        }
        let plain = render { _ in }
        let explicit = render {
            $0.dspReverbEnabled = false
            $0.reverbDamping = 0.9
        }
        #expect(plain == explicit)
    }

    @Test func audioUnitReverbMixLeavesATailAfterNoteOff() throws {
        let on = try tailRMS(enabled: true)
        let off = try tailRMS(enabled: false)
        #expect(on > 0.001)
        // SYNT_20 P2-8: the AU has no Apple Reverb node, so it renders the DSP reverb for every
        // preset. `dspReverbEnabled == false` used to be silent here (the old assertion encoded that).
        #expect(off > 0.001)
    }

    private func tailRMS(enabled: Bool) throws -> Float {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        var preset = SynthPreset.defaultPreset
        preset.dspReverbEnabled = enabled
        preset.reverbMix = 0.9
        preset.reverbRoomSize = 0.92
        preset.reverbDamping = 0.15
        preset.reverbShimmer = 0
        preset.delayMix = 0
        preset.chorusMix = 0
        preset.release = 0.02
        unit.uiPreset = preset // the AU path: store and tree follow the preset
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        #expect(unit.engine.dspReverb.isAllocated)

        let frames = 512
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

        func renderBlock() -> Float {
            var flags = AudioUnitRenderActionFlags()
            var time = AudioTimeStamp()
            time.mFlags = .sampleTimeValid
            for i in 0..<2 { list[i].mDataByteSize = UInt32(bytes) }
            let status = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
            #expect(status == noErr)
            let left = list[0].mData!.assumingMemoryBound(to: Float.self)
            var sum: Float = 0
            for i in 0..<frames {
                #expect(left[i].isFinite)
                sum += left[i] * left[i]
            }
            return (sum / Float(frames)).squareRoot()
        }

        var on: [UInt8] = [0x90, 60, 110]
        unit.engine.enqueueMIDI(&on, count: 3, sampleOffset: 0)
        for _ in 0..<12 { _ = renderBlock() }
        var off: [UInt8] = [0x80, 60, 0]
        unit.engine.enqueueMIDI(&off, count: 3, sampleOffset: 0)
        for _ in 0..<20 { _ = renderBlock() }
        var tail: Float = 0
        for _ in 0..<16 {
            tail = max(tail, renderBlock())
        }
        return tail
    }
}
