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
import CoreMIDI
import Foundation
import Synchronization

final class ArpRenderState {
    private static let ringCapacity = 256
    private static let ringMask = 255

    let mode = Atomic<UInt32>(0)
    let rate = Atomic<UInt32>(2)
    let gateMilli = Atomic<UInt32>(800)
    let octaves = Atomic<UInt32>(1)
    let hold = Atomic<UInt32>(0)

    var output: AUMIDIOutputEventBlock?
    var musical: AUHostMusicalContextBlock?
    var transport: AUHostTransportStateBlock?
    var rateHz: Double = 44_100

    private let ringBuffer: UnsafeMutablePointer<(status: UInt8, d1: UInt8, d2: UInt8)>
    private let ringHead = Atomic<Int>(0)
    private let ringTail = Atomic<Int>(0)
    private let pendingReset = Atomic<Bool>(false)

    private var velocity = [UInt8](repeating: 0, count: 128)
    private var physical = [UInt8](repeating: 0, count: 128)
    private var baseNotes = [UInt8](repeating: 0, count: 128)
    private var pattern = [UInt8](repeating: 0, count: 512)
    private var patternVelocities = [UInt8](repeating: 100, count: 512)
    private var patternCount = 0
    private var prevPatternCount = 0
    private var patternDirty = true
    private var lastOctaves = 1
    private var lastHold: UInt32 = 0
    private var channel: UInt8 = 0
    private var lastVelocity: UInt8 = 100

    private var stepCursor = 0
    private var direction = 1
    private var rng: UInt32 = 0xA341_316C
    private var lastStepIndex: Int64 = .min
    private var noteIsOn = false
    private var sounding: UInt8 = 0
    private var offAt: AUEventSampleTime = -1
    private var scratch = (UInt8(0), UInt8(0), UInt8(0))

    private var lastHostBeat: Double?
    private var wasUsingHostBeat = false
    private var freeBeat: Double = 0
    private var lastRenderEnd: AUEventSampleTime?

    init() {
        ringBuffer = UnsafeMutablePointer<(status: UInt8, d1: UInt8, d2: UInt8)>.allocate(capacity: Self.ringCapacity)
        ringBuffer.initialize(repeating: (0, 0, 0), count: Self.ringCapacity)
    }

    deinit {
        ringBuffer.deinitialize(count: Self.ringCapacity)
        ringBuffer.deallocate()
    }

    /// Producer (host MIDI thread via `scheduleMIDIEventBlock`). Lock-free SPSC push.
    func enqueueMIDI(_ bytes: UnsafePointer<UInt8>, length: Int) {
        guard length >= 3 else { return }
        let head = ringHead.load(ordering: .relaxed)
        let next = (head + 1) & Self.ringMask
        guard next != ringTail.load(ordering: .acquiring) else { return }
        ringBuffer[head] = (bytes[0], bytes[1], bytes[2])
        ringHead.store(next, ordering: .releasing)
    }

    /// Non-RT reset request while render resources are allocated; handled safely on next render.
    func requestReset() {
        pendingReset.store(true, ordering: .releasing)
    }

    /// Non-RT state clear when rendering is not active (allocation/deallocation/idle reset).
    func clearState() {
        pendingReset.store(false, ordering: .relaxed)
        ringHead.store(0, ordering: .relaxed)
        ringTail.store(0, ordering: .relaxed)
        resetPlaybackState()
    }

    private func resetPlaybackState() {
        for i in 0..<128 {
            velocity[i] = 0
            physical[i] = 0
        }
        patternCount = 0
        prevPatternCount = 0
        patternDirty = true
        lastOctaves = Int(min(4, max(1, octaves.load(ordering: .relaxed))))
        lastHold = hold.load(ordering: .relaxed)
        stepCursor = 0
        direction = 1
        lastStepIndex = .min
        noteIsOn = false
        sounding = 0
        offAt = -1
        lastHostBeat = nil
        wasUsingHostBeat = false
        freeBeat = 0
        lastRenderEnd = nil
    }

    private func drainMIDIRing() {
        var tail = ringTail.load(ordering: .relaxed)
        let head = ringHead.load(ordering: .acquiring)
        while tail != head {
            let msg = ringBuffer[tail]
            applyMIDI(status: msg.status, d1: msg.d1, d2: msg.d2)
            tail = (tail + 1) & Self.ringMask
        }
        ringTail.store(tail, ordering: .releasing)
    }

    private func parseRenderEvents(_ events: UnsafePointer<AURenderEvent>?) {
        var event = events
        while let current = event {
            let header = current.pointee.head
            switch header.eventType {
            case .MIDI:
                let midi = current.pointee.MIDI
                if Int(midi.length) >= 3 {
                    var data = midi.data
                    withUnsafeBytes(of: &data) { raw in
                        if let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                            applyMIDI(status: base[0], d1: base[1], d2: base[2])
                        }
                    }
                }
            case .midiEventList:
                parseUMPEventList(current)
            case .parameter, .parameterRamp:
                let param = current.pointee.parameter
                applyParameter(address: param.parameterAddress, value: param.value)
            default:
                break
            }
            event = UnsafePointer(header.next)
        }
    }

    private func parseUMPEventList(_ event: UnsafePointer<AURenderEvent>) {
        let listOffset = MemoryLayout<AUMIDIEventList>.offset(of: \AUMIDIEventList.eventList) ?? 0
        let list = UnsafeRawPointer(event).advanced(by: listOffset)
        let numPacketsOffset = MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.numPackets) ?? 4
        let numPackets = list.loadUnaligned(fromByteOffset: numPacketsOffset, as: UInt32.self)
        let wordCountOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.wordCount) ?? 8
        let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words) ?? 12
        var packet = list.advanced(by: MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.packet) ?? 8)
        for _ in 0..<min(Int(numPackets), 256) {
            let wordCount = min(Int(packet.loadUnaligned(fromByteOffset: wordCountOffset, as: UInt32.self)), 64)
            let words = packet.advanced(by: wordsOffset)
            var w = 0
            while w < wordCount {
                let word = words.loadUnaligned(fromByteOffset: w * 4, as: UInt32.self)
                let messageType = Int((word >> 28) & 0xF)
                let wordSpan: Int
                switch messageType {
                case 0x0, 0x1, 0x2, 0x6, 0x7: wordSpan = 1
                case 0x3, 0x4, 0x8, 0x9, 0xA: wordSpan = 2
                case 0xB, 0xC: wordSpan = 3
                default: wordSpan = 4
                }
                if messageType == 0x2 {
                    let status = UInt8((word >> 16) & 0xFF)
                    let d1 = UInt8((word >> 8) & 0x7F)
                    let d2 = UInt8(word & 0x7F)
                    applyMIDI(status: status, d1: d1, d2: d2)
                }
                w += max(1, wordSpan)
            }
            packet = words.advanced(by: wordCount * 4)
        }
    }

    func applyParameter(address: AUParameterAddress, value: AUValue) {
        switch address {
        case 0: mode.store(UInt32(max(0, min(3, value.rounded()))), ordering: .relaxed)
        case 1: rate.store(UInt32(max(0, min(3, value.rounded()))), ordering: .relaxed)
        case 2: gateMilli.store(UInt32(max(50, min(1000, value * 1000))), ordering: .relaxed)
        case 3: octaves.store(UInt32(max(1, min(4, value.rounded()))), ordering: .relaxed)
        case 4: hold.store(value >= 0.5 ? 1 : 0, ordering: .relaxed)
        default: break
        }
    }

    private func applyMIDI(status: UInt8, d1: UInt8, d2: UInt8) {
        let kind = status & 0xF0
        if kind == 0xB0 {
            let cc = d1 & 0x7F
            if cc == 120 || cc == 123 {
                for i in 0..<128 {
                    physical[i] = 0
                    velocity[i] = 0
                }
                patternDirty = true
            }
            return
        }
        guard kind == 0x90 || kind == 0x80 else { return }
        channel = status & 0x0F
        let note = Int(d1 & 0x7F)
        let vel = d2 & 0x7F
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

    func render(timestamp: UnsafePointer<AudioTimeStamp>, frameCount: AUAudioFrameCount, events: UnsafePointer<AURenderEvent>?) {
        let start = AUEventSampleTime(timestamp.pointee.mSampleTime.rounded(.down))
        let end = start + AUEventSampleTime(frameCount)

        if pendingReset.exchange(false, ordering: .acquiringAndReleasing) {
            if noteIsOn {
                emit(status: 0x80 | channel, note: sounding, velocity: 0, time: start)
                noteIsOn = false
            }
            resetPlaybackState()
        }

        drainMIDIRing()
        parseRenderEvents(events)

        let currentHold = hold.load(ordering: .relaxed)
        if lastHold != currentHold {
            lastHold = currentHold
            if currentHold == 0 {
                for i in 0..<128 where physical[i] == 0 {
                    velocity[i] = 0
                }
                patternDirty = true
            }
        }

        rebuildPatternIfNeeded()

        if let prevEnd = lastRenderEnd, start < prevEnd {
            if noteIsOn {
                emit(status: 0x80 | channel, note: sounding, velocity: 0, time: start)
                noteIsOn = false
            }
            lastStepIndex = .min
            freeBeat = 0
        }
        lastRenderEnd = end

        let tempo = hostTempo()
        let division = beatsPerStep()
        let samplesPerBeat = max(1.0, rateHz * 60.0 / tempo)
        let samplesPerStep = max(1.0, samplesPerBeat * division)
        let stepSamples = max(AUEventSampleTime(1), AUEventSampleTime(samplesPerStep.rounded(.down)))

        var hostIsMoving = true
        if let transport {
            var flags = AUHostTransportStateFlags()
            if transport(&flags, nil, nil, nil) {
                hostIsMoving = flags.contains(.moving)
            }
        }

        let currentBeat = hostBeat()
        let activeBeat: Double
        let usingFreeClock: Bool

        if let beat = currentBeat, hostIsMoving {
            if let prev = lastHostBeat {
                if abs(beat - prev) > 1e-9 {
                    wasUsingHostBeat = true
                    lastHostBeat = beat
                    activeBeat = beat
                    usingFreeClock = false
                } else {
                    if wasUsingHostBeat {
                        wasUsingHostBeat = false
                        freeBeat = (patternCount > 0 || noteIsOn) ? beat : 0
                    } else if patternCount > 0 && prevPatternCount == 0 && !noteIsOn {
                        freeBeat = 0
                        lastStepIndex = .min
                        stepCursor = 0
                        direction = 1
                    } else if patternCount == 0 && !noteIsOn {
                        freeBeat = 0
                        lastStepIndex = .min
                    }
                    lastHostBeat = beat
                    usingFreeClock = true
                    activeBeat = freeBeat
                }
            } else {
                lastHostBeat = beat
                freeBeat = (patternCount > 0 || noteIsOn) ? beat : 0
                activeBeat = beat
                usingFreeClock = true
            }
        } else {
            if wasUsingHostBeat {
                wasUsingHostBeat = false
                freeBeat = (patternCount > 0 || noteIsOn) ? (currentBeat ?? freeBeat) : 0
            } else if patternCount > 0 && prevPatternCount == 0 && !noteIsOn {
                freeBeat = 0
                lastStepIndex = .min
                stepCursor = 0
                direction = 1
            } else if patternCount == 0 && !noteIsOn {
                freeBeat = 0
                lastStepIndex = .min
            }
            if let beat = currentBeat {
                lastHostBeat = beat
            }
            usingFreeClock = true
            activeBeat = freeBeat
        }
        prevPatternCount = patternCount

        let stepPos = activeBeat / division
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

        if usingFreeClock && (patternCount > 0 || noteIsOn) {
            freeBeat += Double(frameCount) / samplesPerBeat
        }
    }

    private func fire(at time: AUEventSampleTime, samplesPerStep: Double) {
        if noteIsOn {
            emit(status: 0x80 | channel, note: sounding, velocity: 0, time: time)
            noteIsOn = false
        }
        guard patternCount > 0 else { return }
        let (note, noteVel) = nextNote()
        let vel = noteVel > 0 ? noteVel : lastVelocity
        emit(status: 0x90 | channel, note: note, velocity: vel, time: time)
        noteIsOn = true
        sounding = note
        let gate = min(0.99, max(0.05, Double(gateMilli.load(ordering: .relaxed)) / 1000.0))
        offAt = time + AUEventSampleTime(max(1, (samplesPerStep * gate).rounded(.down)))
    }

    private func releaseIfDue(from start: AUEventSampleTime, until end: AUEventSampleTime) {
        guard noteIsOn, offAt < end else { return }
        emit(status: 0x80 | channel, note: sounding, velocity: 0, time: max(start, offAt))
        noteIsOn = false
    }

    private func nextNote() -> (note: UInt8, velocity: UInt8) {
        let count = patternCount
        guard count > 0 else { return (60, lastVelocity) }
        stepCursor = max(0, min(count - 1, stepCursor))
        switch mode.load(ordering: .relaxed) {
        case 1:
            let idx = stepCursor
            stepCursor = (stepCursor - 1 + count) % count
            return (pattern[idx], patternVelocities[idx])
        case 2:
            if count == 1 { return (pattern[0], patternVelocities[0]) }
            if stepCursor <= 0 { direction = 1 }
            if stepCursor >= count - 1 { direction = -1 }
            let idx = stepCursor
            stepCursor += direction
            return (pattern[idx], patternVelocities[idx])
        case 3:
            rng = rng &* 1_664_525 &+ 1_013_904_223
            let idx = Int(rng % UInt32(count))
            return (pattern[idx], patternVelocities[idx])
        default:
            let idx = stepCursor
            stepCursor = (stepCursor + 1) % count
            return (pattern[idx], patternVelocities[idx])
        }
    }

    private func rebuildPatternIfNeeded() {
        let oct = Int(min(4, max(1, octaves.load(ordering: .relaxed))))
        if oct != lastOctaves {
            lastOctaves = oct
            patternDirty = true
        }
        guard patternDirty else { return }
        patternDirty = false
        var baseCount = 0
        for note in 0..<128 where velocity[note] > 0 && baseCount < baseNotes.count {
            baseNotes[baseCount] = UInt8(note)
            baseCount += 1
        }
        var count = 0
        for octave in 0..<oct {
            for index in 0..<baseCount {
                let baseNote = Int(baseNotes[index])
                let pitched = baseNote + octave * 12
                if pitched < 128 && count < pattern.count {
                    pattern[count] = UInt8(pitched)
                    let perNoteVel = velocity[baseNote]
                    patternVelocities[count] = perNoteVel > 0 ? perNoteVel : lastVelocity
                    count += 1
                }
            }
        }
        patternCount = count
        if count == 0 || stepCursor >= count { stepCursor = 0 }
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

    private func hostBeat() -> Double? {
        var beat = 0.0
        guard let musical else { return nil }
        let ok = musical(nil, nil, nil, &beat, nil, nil)
        if !ok || !beat.isFinite { return nil }
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
            unmanaged.takeUnretainedValue().enqueueMIDI(bytes, length: length)
        }
        installTree()
    }

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }
    public override var midiOutputNames: [String] { ["Arp"] }
    public override var scheduleMIDIEventBlock: AUScheduleMIDIEventBlock { midiBlock }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        state.clearState()
        state.output = midiOutputEventBlock
        state.musical = musicalContextBlock
        state.transport = transportStateBlock
        let rate = outputBus.format.sampleRate
        state.rateHz = rate > 0 ? rate : 44_100
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        state.clearState()
        state.output = nil
        state.musical = nil
        state.transport = nil
    }

    public override func reset() {
        super.reset()
        if renderResourcesAllocated {
            state.requestReset()
        } else {
            state.clearState()
        }
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let unmanaged = Unmanaged.passUnretained(state)
        return { _, timestamp, frameCount, _, outputData, events, _ in
            unmanaged.takeUnretainedValue().render(timestamp: timestamp, frameCount: frameCount, events: events)
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
            state.applyParameter(address: parameter.address, value: value)
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
