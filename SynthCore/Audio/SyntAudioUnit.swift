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
    let engine: AudioEngine
    /// Preset copy for the plugin view. Assign only from the main thread.
    /// Addressed knobs still go through the parameter tree.
    public var uiPreset: SynthPreset {
        get { engine.preset }
        set { engine.preset = newValue }
    }
    private let outputBus: AUAudioUnitBus
    private var outputBusArray: AUAudioUnitBusArray!
    private var inputBusArray: AUAudioUnitBusArray!
    /// Everything the render block touches. The block captures this, never `self`.
    private let renderContext: SyntRenderContext
    /// Set while the tree is being copied from the engine, so the observer does not apply twice.
    private var suppressParameterObserver = false
    private static let stateVersionKey = "syntStateVersion"
    private static let statePresetKey = "syntPreset"
    private static let stateIndexKey = "syntPresetIndex"

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        let core = AudioEngine()
        engine = core
        renderContext = SyntRenderContext(engine: core)
        try super.init(componentDescription: componentDescription, options: options)
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
        maximumFramesToRender = 512
        engine.usesHostTransport = true
        installParameterTree()
    }

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    /// Main thread, before rendering starts. Host blocks are cached here once.
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        let frames = Int(maximumFramesToRender == 0 ? 512 : maximumFramesToRender)
        renderContext.reserve(frames: frames)
        renderContext.musicalContext = musicalContextBlock
        renderContext.transportState = transportStateBlock
        let rate = outputBus.format.sampleRate
        engine.prepare(sampleRate: rate > 0 ? rate : 44_100, maxFrames: frames)
    }

    public override func deallocateRenderResources() {
        renderContext.musicalContext = nil
        renderContext.transportState = nil
        super.deallocateRenderResources()
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let context = renderContext
        return { actionFlags, timestamp, frameCount, _, outputData, events, _ in
            context.render(
                actionFlags: actionFlags,
                timestamp: timestamp,
                frameCount: frameCount,
                outputData: outputData,
                events: events
            )
        }
    }

    // MARK: - Parameters, presets, document state

    /// Factory slots in browse order. Names carry the category so a flat host menu stays readable.
    private static let factoryPresetList: [AUAudioUnitPreset] = PresetBrowser.list.enumerated().map { index, preset in
        let item = AUAudioUnitPreset()
        item.number = index
        item.name = "\(preset.category.rawValue): \(preset.name)"
        return item
    }

    public override var factoryPresets: [AUAudioUnitPreset]? {
        Self.factoryPresetList
    }

    public override var currentPreset: AUAudioUnitPreset? {
        get {
            guard let index = PresetBrowser.index(of: engine.preset),
                  Self.factoryPresetList.indices.contains(index) else { return nil }
            return Self.factoryPresetList[index]
        }
        set {
            guard let newValue else { return }
            let index = newValue.number
            guard PresetBrowser.list.indices.contains(index) else { return }
            engine.preset = PresetBrowser.list[index]
            syncParameterTreeFromEngine()
        }
    }

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state[Self.stateVersionKey] = 1
            if let data = try? JSONEncoder().encode(engine.preset) {
                state[Self.statePresetKey] = data
            }
            state[Self.stateIndexKey] = PresetBrowser.index(of: engine.preset) ?? -1
            return state
        }
        set {
            guard let newValue else { return }
            guard let data = newValue[Self.statePresetKey] as? Data,
                  let preset = try? JSONDecoder().decode(SynthPreset.self, from: data) else {
                super.fullState = newValue
                return
            }
            engine.preset = preset
            syncParameterTreeFromEngine()
        }
    }

    public override var fullStateForDocument: [String: Any]? {
        get { fullState }
        set { fullState = newValue }
    }

    private func installParameterTree() {
        let tree = SyntParameterTree.make()
        tree.implementorValueObserver = { [weak self] parameter, value in
            guard let self, !self.suppressParameterObserver else { return }
            if Thread.isMainThread {
                self.engine.adoptAddressedParameterOnMain(id: parameter.address, value: value)
            } else {
                self.engine.applyAddressedParameterRT(id: parameter.address, value: value)
            }
        }
        tree.implementorValueProvider = { [weak self] parameter in
            guard let self, let address = SynthParameterAddress(rawValue: parameter.address) else {
                return parameter.minValue
            }
            return self.engine.addressedParameterValue(address)
        }
        parameterTree = tree
        syncParameterTreeFromEngine()
    }

    private func syncParameterTreeFromEngine() {
        guard let tree = parameterTree else { return }
        suppressParameterObserver = true
        for address in SynthParameterAddress.allCases {
            guard let parameter = tree.parameter(withAddress: address.rawValue) else { continue }
            parameter.value = engine.addressedParameterValue(address)
        }
        suppressParameterObserver = false
    }
}

/// Builds the published parameter tree. Addresses come from `SynthParameterAddress` and stay fixed.
enum SyntParameterTree {
    static func make() -> AUParameterTree {
        let readable = AudioUnitParameterOptions.flag_IsReadable
        let writable = AudioUnitParameterOptions.flag_IsWritable
        let logarithmic = AudioUnitParameterOptions.flag_DisplayLogarithmic
        let strings = AudioUnitParameterOptions.flag_ValuesHaveStrings
        let continuous: AudioUnitParameterOptions = [readable, writable]
        let indexed: AudioUnitParameterOptions = [readable, writable, strings]
        let toggle: AudioUnitParameterOptions = [readable, writable]

        func knob(
            _ address: SynthParameterAddress,
            unit: AudioUnitParameterUnit = .generic,
            flags: AudioUnitParameterOptions = continuous,
            valueStrings: [String]? = nil
        ) -> AUParameter {
            AUParameterTree.createParameter(
                withIdentifier: address.identifier,
                name: address.displayName,
                address: address.rawValue,
                min: address.min,
                max: address.max,
                unit: unit,
                unitName: nil,
                flags: flags,
                valueStrings: valueStrings,
                dependentParameters: nil
            )
        }

        func indexedKnob(_ address: SynthParameterAddress, _ names: [String]) -> AUParameter {
            knob(address, unit: .indexed, flags: indexed, valueStrings: names)
        }

        func toggleKnob(_ address: SynthParameterAddress) -> AUParameter {
            knob(address, unit: .boolean, flags: toggle)
        }

        let waveforms = ["Sine", "Saw", "Square", "Triangle", "Noise", "Wavetable"]
        let tables = ["Basic", "Analog", "Digital", "PWM", "Formant", "User"]
        let filters = ["Low Pass", "High Pass", "Band Pass", "Notch", "Ladder"]
        let lfoTargets = ["Pitch", "Filter", "Amplitude", "Pan", "None"]
        let noise = ["White", "Pink", "Brown"]

        let oscillators = AUParameterTree.createGroup(
            withIdentifier: "osc",
            name: "Oscillators",
            children: [
                knob(.osc1Volume),
                knob(.osc1Octave),
                knob(.osc1Detune, unit: .cents),
                knob(.osc1PulseWidth),
                knob(.osc1WavetableMorph),
                indexedKnob(.osc1Waveform, waveforms),
                indexedKnob(.osc1WavetableIndex, tables),
                knob(.osc2Volume),
                knob(.osc2Octave),
                knob(.osc2Detune, unit: .cents),
                knob(.osc2PulseWidth),
                knob(.osc2WavetableMorph),
                indexedKnob(.osc2Waveform, waveforms),
                indexedKnob(.osc2WavetableIndex, tables),
                toggleKnob(.osc2Enabled),
                knob(.subOscVolume),
                knob(.fmAmount),
                knob(.ringModAmount),
                indexedKnob(.noiseColor, noise),
            ]
        )
        let envelopes = AUParameterTree.createGroup(
            withIdentifier: "env",
            name: "Envelopes",
            children: [
                knob(.attack, unit: .seconds),
                knob(.decay, unit: .seconds),
                knob(.sustain),
                knob(.release, unit: .seconds),
                knob(.filterAttack, unit: .seconds),
                knob(.filterDecay, unit: .seconds),
                knob(.filterSustain),
                knob(.filterRelease, unit: .seconds),
            ]
        )
        let filter = AUParameterTree.createGroup(
            withIdentifier: "filter",
            name: "Filter",
            children: [
                knob(.filterCutoff, unit: .hertz, flags: [continuous, logarithmic]),
                knob(.filterResonance),
                indexedKnob(.filterType, filters),
                knob(.filterDrive),
                knob(.filterEnvelopeAmount),
                knob(.velocityToCutoff),
                knob(.filterKeyTracking),
            ]
        )
        let lfo = AUParameterTree.createGroup(
            withIdentifier: "lfo",
            name: "LFO",
            children: [
                toggleKnob(.lfoEnabled),
                knob(.lfoRate, unit: .hertz),
                knob(.lfoDepth),
                indexedKnob(.lfoWaveform, waveforms),
                indexedKnob(.lfoTarget, lfoTargets),
                toggleKnob(.lfo2Enabled),
                knob(.lfo2Rate, unit: .hertz),
                knob(.lfo2Depth),
                indexedKnob(.lfo2Waveform, waveforms),
                indexedKnob(.lfo2Target, lfoTargets),
            ]
        )
        let effects = AUParameterTree.createGroup(
            withIdentifier: "fx",
            name: "Effects",
            children: [
                knob(.reverbMix),
                knob(.reverbRoomSize),
                knob(.reverbShimmer),
                knob(.chorusRate, unit: .hertz),
                knob(.chorusDepth),
                knob(.chorusMix),
                knob(.delayTime, unit: .seconds),
                knob(.delayFeedback),
                knob(.delayMix),
                toggleKnob(.distortionEnabled),
                knob(.distortionDrive),
                knob(.distortionTone),
                knob(.distortionMix),
                toggleKnob(.phaserEnabled),
                knob(.phaserRate, unit: .hertz),
                knob(.phaserDepth),
                knob(.phaserMix),
                knob(.phaserFeedback),
                knob(.phaserCenterFrequency, unit: .hertz),
                knob(.phaserSpread),
                toggleKnob(.eqEnabled),
                knob(.eqLowGain, unit: .decibels),
                knob(.eqMidGain, unit: .decibels),
                knob(.eqHighGain, unit: .decibels),
                knob(.eqLowFreq, unit: .hertz),
                knob(.eqMidFreq, unit: .hertz),
                knob(.eqHighFreq, unit: .hertz),
            ]
        )
        let performance = AUParameterTree.createGroup(
            withIdentifier: "performance",
            name: "Performance",
            children: [
                knob(.unisonDetune, unit: .cents),
                knob(.unisonSpread),
                knob(.analogDrift),
                knob(.portamento, unit: .seconds),
                knob(.macro1),
                knob(.macro2),
                knob(.macro3),
                knob(.macro4),
            ]
        )
        return AUParameterTree.createTree(withChildren: [
            oscillators, envelopes, filter, lfo, effects, performance,
        ])
    }
}

/// Render-thread state for `SyntAudioUnit`. A final class with stored fields:
/// no Obj-C dispatch and no unowned-self checks per buffer.
final class SyntRenderContext {
    let engine: AudioEngine
    var musicalContext: AUHostMusicalContextBlock?
    var transportState: AUHostTransportStateBlock?
    private var renderLeft: UnsafeMutablePointer<Float>?
    private var renderRight: UnsafeMutablePointer<Float>?
    private(set) var renderCapacity = 0

    init(engine: AudioEngine) {
        self.engine = engine
    }

    deinit {
        renderLeft?.deallocate()
        renderRight?.deallocate()
    }

    /// Main thread, render stopped.
    func reserve(frames: Int) {
        guard renderCapacity < frames else { return }
        renderLeft?.deallocate()
        renderRight?.deallocate()
        renderLeft = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        renderRight = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        renderLeft?.initialize(repeating: 0, count: frames)
        renderRight?.initialize(repeating: 0, count: frames)
        renderCapacity = frames
    }

    func render(
        actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
        timestamp: UnsafePointer<AudioTimeStamp>,
        frameCount: AUAudioFrameCount,
        outputData: UnsafeMutablePointer<AudioBufferList>,
        events: UnsafePointer<AURenderEvent>?
    ) -> AUAudioUnitStatus {
        let frames = Int(frameCount)
        guard frames > 0 else { return noErr }
        guard frames <= renderCapacity else { return kAudioUnitErr_TooManyFramesToProcess }
        pullHostTransport()
        schedule(events, timestamp: timestamp, frameCount: frames)
        guard let buffers = bind(outputData, frames: frames) else { return kAudioUnitErr_TooManyFramesToProcess }
        engine.render(frames: frames, intoL: buffers.left, intoR: buffers.right)
        actionFlags.pointee.remove(.unitRenderAction_OutputIsSilence)
        return noErr
    }

    private func pullHostTransport() {
        var tempo: Double?
        if let musical = musicalContext {
            var bpm: Double = 0
            if musical(&bpm, nil, nil, nil, nil, nil) {
                tempo = bpm
            }
        }
        var moving: Bool?
        if let transport = transportState {
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
                // Applied at its sample offset, like MIDI. No ramps are advertised,
                // so a host sends dense `.parameter` events instead.
                let parameter = current.pointee.parameter
                engine.enqueueParameter(id: parameter.parameterAddress, value: parameter.value, sampleOffset: offset)
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
        guard let renderLeft, let renderRight else { return nil }
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
