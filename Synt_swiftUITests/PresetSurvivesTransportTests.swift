//
//  PresetSurvivesTransportTests.swift
//  A preset chosen in the plugin view must survive what a host does when playback starts.
//

import AVFoundation
import AudioToolbox
import Foundation
import Synchronization
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct PresetSurvivesTransportTests {
    private static let desc = AudioComponentDescription(
        componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
        componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)

    /// A factory patch that differs from both the init sound and program 0.
    private func chosen() -> SynthPreset {
        let init0 = SynthPreset.defaultPreset, prog0 = PresetBrowser.list[0]
        return PresetBrowser.list.first {
            $0.filterCutoff != init0.filterCutoff && $0.osc1Waveform != init0.osc1Waveform
                && $0.filterCutoff != prog0.filterCutoff && $0.osc1Waveform != prog0.osc1Waveform
        }!
    }

    /// Same path as AUParameterSurface.userSetPreset.
    private func pickInView(_ unit: SyntAudioUnit, _ p: SynthPreset) {
        let token = unit.parameterTree!.token(byAddingParameterObserver: { _, _ in })
        let old = unit.uiPreset
        for a in SynthParameterAddress.allCases where old.parameterValue(for: a) != p.parameterValue(for: a) {
            unit.parameterTree!.parameter(withAddress: a.rawValue)?.setValue(p.parameterValue(for: a), originator: token)
        }
        unit.adoptNonAddressedFields(of: p)
        unit.parameterTree!.removeParameterObserver(token)
    }

    private func render(_ unit: SyntAudioUnit, events: UnsafePointer<AURenderEvent>? = nil, buffers: Int = 4) {
        let frames = 256
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        let bytes = frames * 4
        for i in 0..<2 { list[i] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes), mData: .allocate(byteCount: bytes, alignment: 16)) }
        defer { list[0].mData?.deallocate(); list[1].mData?.deallocate(); list.unsafeMutablePointer.deallocate() }
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp(); time.mFlags = .sampleTimeValid
        for b in 0..<buffers {
            time.mSampleTime = Double(b * frames)
            _ = unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, b == 0 ? events : nil, nil)
        }
    }

    private func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.35)) }

    private func check(_ unit: SyntAudioUnit, _ p: SynthPreset, _ step: String) {
        #expect(unit.uiPreset.filterCutoff == p.filterCutoff, "\(step): ui cutoff \(unit.uiPreset.filterCutoff) != \(p.filterCutoff)")
        #expect(unit.uiPreset.osc1Waveform == p.osc1Waveform, "\(step): ui waveform")
        #expect(unit.engine.cachedFilterCutoff == p.filterCutoff, "\(step): dsp cutoff \(unit.engine.cachedFilterCutoff)")
        #expect(unit.engine.oscillator1.waveform == p.osc1Waveform, "\(step): dsp waveform")
    }

    @Test func presetChosenInViewSurvivesHostPlayStart() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        try unit.allocateRenderResources()
        let p = chosen()
        pickInView(unit, p)
        render(unit); pump()
        check(unit, p, "after pick")

        unit.reset(); render(unit); pump()
        check(unit, p, "after reset")

        unit.deallocateRenderResources(); try unit.allocateRenderResources(); render(unit); pump()
        check(unit, p, "after realloc")

        let state = unit.fullState
        unit.fullState = state; render(unit); pump()
        check(unit, p, "after fullState round-trip")

        // Logic's default "reset messages" on play: CC121, sustain off, pitch bend centre.
        for bytes: [UInt8] in [[0xB0, 121, 0], [0xB0, 64, 0], [0xE0, 0, 64], [0xB0, 123, 0], [0xFA]] {
            var b = bytes
            unit.engine.enqueueMIDI(&b, count: b.count, sampleOffset: 0)
            render(unit, buffers: 1)
        }
        pump()
        check(unit, p, "after reset messages")
    }

    /// Logic sends a Program Change on play. It must not replace the patch picked in the view.
    @Test func hostProgramChangeOnPlayDoesNotResetChosenPreset() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        try unit.allocateRenderResources()
        let p = chosen()
        pickInView(unit, p)
        render(unit); pump()
        var pc: [UInt8] = [0xC0, 0]
        unit.engine.enqueueMIDI(&pc, count: 2, sampleOffset: 0)
        render(unit, buffers: 1)
        unit.applyPendingProgram(); pump()
        check(unit, p, "after host program change")
        #expect(unit.engine.pendingProgram.load(ordering: .acquiring) == -1, "PC is drained even when ignored")
    }

    @Test func programChangeOptInIsSavedInFullState() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        #expect(!unit.respondsToProgramChange)
        unit.respondsToProgramChange = true
        let state = unit.fullState
        let other = try SyntAudioUnit(componentDescription: Self.desc)
        other.fullState = state
        #expect(other.respondsToProgramChange)
    }
}
