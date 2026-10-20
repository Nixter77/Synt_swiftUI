//
//  SyntAudioUnit.swift
//  SynthCore
//
//  AUv3 instrument. The device graph inside AudioEngine is not started.
//  Host MIDI is scheduled by sample offset. Host tempo replaces MIDI clock.
//

import AudioToolbox
import AVFoundation
import Foundation

public final class SyntAudioUnit: AUAudioUnit {
    let engine = AudioEngine()
    private let outputBus: AUAudioUnitBus
    private var outputBusArray: AUAudioUnitBusArray!
    private var inputBusArray: AUAudioUnitBusArray!
    private var renderLeft: UnsafeMutablePointer<Float>?
    private var renderRight: UnsafeMutablePointer<Float>?
    private var renderCapacity = 0

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        try super.init(componentDescription: componentDescription, options: options)
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
        maximumFramesToRender = 512
        engine.usesHostTransport = true
    }

    deinit {
        renderLeft?.deallocate()
        renderRight?.deallocate()
    }

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        let frames = Int(maximumFramesToRender == 0 ? 512 : maximumFramesToRender)
        if renderCapacity < frames {
            renderLeft?.deallocate()
            renderRight?.deallocate()
            renderLeft = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            renderRight = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            renderLeft?.initialize(repeating: 0, count: frames)
            renderRight?.initialize(repeating: 0, count: frames)
            renderCapacity = frames
        }
        let rate = outputBus.format.sampleRate
        engine.prepare(sampleRate: rate > 0 ? rate : 44_100, maxFrames: frames)
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        { [unowned self] actionFlags, timestamp, frameCount, _, outputData, events, _ in
            self.render(
                actionFlags: actionFlags,
                timestamp: timestamp,
                frameCount: frameCount,
                outputData: outputData,
                events: events
            )
        }
    }

    private func render(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AUAudioFrameCount,
        outputData: UnsafeMutablePointer<AudioBufferList>,
        events: UnsafePointer<AURenderEvent>?
    ) -> AUAudioUnitStatus {
        let frames = Int(frameCount)
        guard frames > 0 else { return noErr }
        guard renderResourcesAllocated, frames <= renderCapacity else {
            return kAudioUnitErr_TooManyFramesToProcess
        }
        pullHostTransport()
        schedule(events, timestamp: timestamp, frameCount: frames)
        guard let buffers = bind(outputData, frames: frames) else { return kAudioUnitErr_TooManyFramesToProcess }
        engine.render(frames: frames, intoL: buffers.left, intoR: buffers.right)
        actionFlags.pointee.remove(.unitRenderAction_OutputIsSilence)
        return noErr
    }

    private func pullHostTransport() {
        var tempo: Double?
        if let musical = musicalContextBlock {
            var bpm: Double = 0
            if musical(&bpm, nil, nil, nil, nil, nil) {
                tempo = bpm
            }
        }
        var moving: Bool?
        if let transport = transportStateBlock {
            var flags = AUHostTransportStateFlags()
            if transport(&flags, nil, nil, nil) {
                moving = flags.contains(.moving)
            }
        }
        engine.adoptHostContext(tempo: tempo, transportMoving: moving)
    }

    /// Audio thread. MIDI bytes are copied into the preallocated schedule.
    private func schedule(_ events: UnsafePointer<AURenderEvent>?, timestamp: UnsafePointer<AudioTimeStamp>, frameCount: Int) {
        var event = events
        let start = AUEventSampleTime(timestamp.pointee.mSampleTime)
        while let current = event {
            let header = current.pointee.head
            let offset = sampleOffset(eventTime: header.eventSampleTime, bufferStart: start, frameCount: frameCount)
            switch header.eventType {
            case .MIDI:
                let midi = current.pointee.MIDI
                let count = Int(midi.length)
                if count > 0 && count <= 3 {
                    var data = midi.data
                    withUnsafeBytes(of: &data) { raw in
                        if let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                            engine.enqueueMIDI(base, count: count, sampleOffset: offset)
                        }
                    }
                }
            case .parameter, .parameterRamp:
                let parameter = current.pointee.parameter
                engine.applyAddressedParameterRT(id: parameter.parameterAddress, value: parameter.value)
            default:
                break
            }
            event = UnsafePointer(header.next)
        }
    }

    private func sampleOffset(eventTime: AUEventSampleTime, bufferStart: AUEventSampleTime, frameCount: Int) -> Int {
        if eventTime == AUEventSampleTimeImmediate { return 0 }
        var delta = Int(eventTime - bufferStart)
        if delta < 0 { delta = 0 }
        if delta > frameCount { delta = frameCount }
        return delta
    }

    private func bind(_ outputData: UnsafeMutablePointer<AudioBufferList>, frames: Int) -> (left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>)? {
        guard frames <= renderCapacity, let renderLeft, let renderRight else { return nil }
        let buffers = UnsafeMutableAudioBufferListPointer(outputData)
        guard buffers.count >= 1 else { return nil }
        let byteCount = UInt32(frames * MemoryLayout<Float>.size)
        if buffers[0].mData == nil {
            buffers[0].mData = UnsafeMutableRawPointer(renderLeft)
            buffers[0].mDataByteSize = byteCount
            buffers[0].mNumberChannels = 1
        }
        let left = buffers[0].mData!.assumingMemoryBound(to: Float.self)
        let right: UnsafeMutablePointer<Float>
        if buffers.count >= 2 {
            if buffers[1].mData == nil {
                buffers[1].mData = UnsafeMutableRawPointer(renderRight)
                buffers[1].mDataByteSize = byteCount
                buffers[1].mNumberChannels = 1
            }
            right = buffers[1].mData!.assumingMemoryBound(to: Float.self)
        } else if buffers[0].mNumberChannels >= 2 {
            right = left.advanced(by: frames)
        } else {
            right = renderRight
        }
        return (left, right)
    }
}
