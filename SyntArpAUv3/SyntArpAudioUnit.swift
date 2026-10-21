//
//  SyntArpAudioUnit.swift
//  SyntArpAUv3
//
//  Prototype MIDI FX. The synthesizer is not linked. Render emits note on/off
//  through the host MIDIOutputEventBlock and writes silence.
//

import AudioToolbox
import AVFoundation
import CoreAudioKit
import Foundation
import Synchronization

final class ArpRenderState {
    let mode = Atomic<UInt32>(0)
    let rate = Atomic<UInt32>(2)
    let gateMilli = Atomic<UInt32>(800)
    let octaves = Atomic<UInt32>(1)
    let hold = Atomic<UInt32>(0)

    var output: AUMIDIOutputEventBlock?
    var musical: AUHostMusicalContextBlock?
    var rateHz: Double = 44_100

    var velocity = [UInt8](repeating: 0, count: 128)
    var physical = [UInt8](repeating: 0, count: 128)
    var baseNotes = [UInt8](repeating: 0, count: 16)
    var pattern = [UInt8](repeating: 0, count: 64)
    var patternCount = 0
    var patternDirty = true
    var channel: UInt8 = 0
    var lastVelocity: UInt8 = 100

    var stepCursor = 0
    var direction = 1
    var rng: UInt32 = 0xA341_316C
    var lastStepIndex: Int64 = .min
    var noteIsOn = false
    var sounding: UInt8 = 0
    var offAt: AUEventSampleTime = -1
    var scratch = (UInt8(0), UInt8(0), UInt8(0))

    func handleMIDI(_ bytes: UnsafePointer<UInt8>, length: Int) {
        guard length >= 3 else { return }
        let status = bytes[0]
        let kind = status & 0xF0
        guard kind == 0x90 || kind == 0x80 else { return }
        channel = status & 0x0F
        let note = Int(bytes[1])
        let vel = bytes[2]
        guard note >= 0, note < 128 else { return }
        if kind == 0x90 && vel > 0 {
            if hold.load(ordering: .relaxed) != 0 && physicalDowns() == 0 {
                for i in 0..<128 { velocity[i] = 0 }
            }
            physical[note] = 1
            velocity[note] = vel
            lastVelocity = vel
            patternDirty = true
        } else {
            physical[note] = 0
            if hold.load(ordering: .relaxed) == 0 {
                velocity[note] = 0
                patternDirty = true
            }
        }
    }

    func render(timestamp: UnsafePointer<AudioTimeStamp>, frameCount: AUAudioFrameCount) {
        rebuildPatternIfNeeded()
        let start = AUEventSampleTime(timestamp.pointee.mSampleTime.rounded(.down))
        let end = start + AUEventSampleTime(frameCount)
        let tempo = hostTempo()
        let division = beatsPerStep()
        let samplesPerStep = max(1.0, rateHz * 60.0 / tempo * division)
        let stepSamples = max(AUEventSampleTime(1), AUEventSampleTime(samplesPerStep.rounded(.down)))
        let stepPos = hostBeat() / division
        var stepIndex = Int64(stepPos.rounded(.down))
        let into = stepPos - Double(stepIndex)
        var boundary = start
        if into > 0.000_001 {
            let skip = AUEventSampleTime(((1.0 - into) * samplesPerStep).rounded(.down))
            boundary = start + skip
            stepIndex += 1
        }
        releaseIfDue(from: start, until: min(end, boundary))
        var guardSteps = 0
        while boundary < end && guardSteps < 32 {
            if stepIndex != lastStepIndex {
                fire(at: boundary, samplesPerStep: samplesPerStep)
                lastStepIndex = stepIndex
            }
            let next = boundary + stepSamples
            releaseIfDue(from: boundary, until: min(end, next))
            boundary = next
            stepIndex += 1
            guardSteps += 1
        }
    }

    private func fire(at time: AUEventSampleTime, samplesPerStep: Double) {
        if noteIsOn {
            emit(status: 0x80 | channel, note: sounding, velocity: 0, time: time)
            noteIsOn = false
        }
        guard patternCount > 0 else { return }
        let note = nextNote()
        emit(status: 0x90 | channel, note: note, velocity: lastVelocity, time: time)
        noteIsOn = true
        sounding = note
        let gate = min(0.99, max(0.05, Double(gateMilli.load(ordering: .relaxed)) / 1000.0))
        offAt = time + AUEventSampleTime(max(1, (samplesPerStep * gate).rounded(.down)))
    }

    private func releaseIfDue(from start: AUEventSampleTime, until end: AUEventSampleTime) {
        guard noteIsOn, offAt >= start, offAt < end else { return }
        emit(status: 0x80 | channel, note: sounding, velocity: 0, time: offAt)
        noteIsOn = false
    }

    private func nextNote() -> UInt8 {
        let count = patternCount
        guard count > 0 else { return 60 }
        switch mode.load(ordering: .relaxed) {
        case 1:
            let note = pattern[stepCursor]
            stepCursor = (stepCursor - 1 + count) % count
            return note
        case 2:
            if count == 1 { return pattern[0] }
            if stepCursor <= 0 { direction = 1 }
            if stepCursor >= count - 1 { direction = -1 }
            let note = pattern[stepCursor]
            stepCursor += direction
            return note
        case 3:
            rng = rng &* 1_664_525 &+ 1_013_904_223
            return pattern[Int(rng % UInt32(count))]
        default:
            let note = pattern[stepCursor]
            stepCursor = (stepCursor + 1) % count
            return note
        }
    }

    private func rebuildPatternIfNeeded() {
        guard patternDirty else { return }
        patternDirty = false
        var baseCount = 0
        for note in 0..<128 where velocity[note] > 0 && baseCount < baseNotes.count {
            baseNotes[baseCount] = UInt8(note)
            baseCount += 1
        }
        let oct = Int(min(4, max(1, octaves.load(ordering: .relaxed))))
        var count = 0
        for octave in 0..<oct {
            for index in 0..<baseCount {
                let pitched = Int(baseNotes[index]) + octave * 12
                if pitched < 128 && count < pattern.count {
                    pattern[count] = UInt8(pitched)
                    count += 1
                }
            }
        }
        patternCount = count
        if stepCursor >= count { stepCursor = 0 }
    }

    private func physicalDowns() -> Int {
        var n = 0
        for i in 0..<128 where physical[i] != 0 { n += 1 }
        return n
    }

    private func beatsPerStep() -> Double {
        switch rate.load(ordering: .relaxed) {
        case 0: return 1
        case 1: return 0.5
        case 3: return 0.125
        default: return 0.25
        }
    }

    private func hostTempo() -> Double {
        var tempo = 120.0
        guard let musical else { return tempo }
        let ok = musical(&tempo, nil, nil, nil, nil, nil)
        if !ok || !tempo.isFinite || tempo < 20 || tempo > 400 { return 120 }
        return tempo
    }

    private func hostBeat() -> Double {
        var beat = 0.0
        guard let musical else { return 0 }
        let ok = musical(nil, nil, nil, &beat, nil, nil)
        if !ok || !beat.isFinite { return 0 }
        return beat
    }

    private func emit(status: UInt8, note: UInt8, velocity: UInt8, time: AUEventSampleTime) {
        guard let output else { return }
        scratch = (status, note, velocity)
        withUnsafeBytes(of: scratch) { raw in
            guard let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            _ = output(time, 0, 3, base)
        }
    }
}

public final class SyntArpAudioUnit: AUAudioUnit {
    private let state = ArpRenderState()
    private let outputBus: AUAudioUnitBus
    private var outputBusArray: AUAudioUnitBusArray!
    private var inputBusArray: AUAudioUnitBusArray!
    private var midiBlock: AUScheduleMIDIEventBlock!

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        try super.init(componentDescription: componentDescription, options: options)
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
        maximumFramesToRender = 512
        let unmanaged = Unmanaged.passUnretained(state)
        midiBlock = { sampleTime, _, length, bytes in
            _ = sampleTime
            unmanaged.takeUnretainedValue().handleMIDI(bytes, length: length)
        }
        installTree()
    }

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }
    public override var midiOutputNames: [String] { ["Arp"] }
    public override var scheduleMIDIEventBlock: AUScheduleMIDIEventBlock { midiBlock }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        state.output = midiOutputEventBlock
        state.musical = musicalContextBlock
        state.rateHz = outputBus.format.sampleRate
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let unmanaged = Unmanaged.passUnretained(state)
        return { _, timestamp, frameCount, _, outputData, _, _ in
            unmanaged.takeUnretainedValue().render(timestamp: timestamp, frameCount: frameCount)
            let buffers = UnsafeMutableAudioBufferListPointer(outputData)
            for buffer in buffers {
                if let data = buffer.mData {
                    memset(data, 0, Int(buffer.mDataByteSize))
                }
            }
            return noErr
        }
    }

    private func installTree() {
        let readable = AudioUnitParameterOptions.flag_IsReadable
        let writable = AudioUnitParameterOptions.flag_IsWritable
        let plain: AudioUnitParameterOptions = [readable, writable]
        func param(
            _ address: AUParameterAddress,
            _ identifier: String,
            _ name: String,
            _ min: AUValue,
            _ max: AUValue,
            _ unit: AudioUnitParameterUnit,
            _ strings: [String]?
        ) -> AUParameter {
            AUParameterTree.createParameter(
                withIdentifier: identifier,
                name: name,
                address: address,
                min: min,
                max: max,
                unit: unit,
                unitName: nil,
                flags: strings == nil ? plain : [readable, writable, .flag_ValuesHaveStrings],
                valueStrings: strings,
                dependentParameters: nil
            )
        }
        let tree = AUParameterTree.createTree(withChildren: [
            param(0, "mode", "Mode", 0, 3, .indexed, ["Up", "Down", "Up-Down", "Random"]),
            param(1, "rate", "Rate", 0, 3, .indexed, ["1/4", "1/8", "1/16", "1/32"]),
            param(2, "gate", "Gate", 0.05, 1, .generic, nil),
            param(3, "octaves", "Octaves", 1, 4, .indexed, ["1", "2", "3", "4"]),
            param(4, "hold", "Hold", 0, 1, .boolean, nil),
        ])
        tree.implementorValueObserver = { [state] parameter, value in
            switch parameter.address {
            case 0: state.mode.store(UInt32(max(0, min(3, value.rounded()))), ordering: .relaxed)
            case 1: state.rate.store(UInt32(max(0, min(3, value.rounded()))), ordering: .relaxed)
            case 2: state.gateMilli.store(UInt32(max(50, min(1000, value * 1000))), ordering: .relaxed)
            case 3: state.octaves.store(UInt32(max(1, min(4, value.rounded()))), ordering: .relaxed)
            case 4: state.hold.store(value >= 0.5 ? 1 : 0, ordering: .relaxed)
            default: break
            }
        }
        tree.implementorValueProvider = { [state] parameter in
            switch parameter.address {
            case 0: return AUValue(state.mode.load(ordering: .relaxed))
            case 1: return AUValue(state.rate.load(ordering: .relaxed))
            case 2: return AUValue(state.gateMilli.load(ordering: .relaxed)) / 1000
            case 3: return AUValue(state.octaves.load(ordering: .relaxed))
            case 4: return state.hold.load(ordering: .relaxed) == 0 ? 0 : 1
            default: return 0
            }
        }
        parameterTree = tree
        tree.parameter(withAddress: 1)?.value = 2
        tree.parameter(withAddress: 2)?.value = 0.8
        tree.parameter(withAddress: 3)?.value = 1
    }
}
