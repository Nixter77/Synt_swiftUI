//
//  SyntAudioUnit.swift
//  SynthCore
//
//  AUv3 instrument. The device graph inside AudioEngine is not started.
//  Host MIDI is scheduled by sample offset. Host tempo replaces MIDI clock.
//

import AudioToolbox
import AVFoundation
import CoreMIDI
import Foundation
import Synchronization

public final class SyntAudioUnit: AUAudioUnit {
    let engine: AudioEngine
    /// Preset copy for the plugin view. Assign only from the main thread.
    /// Addressed knobs still go through the parameter tree.
    public var uiPreset: SynthPreset {
        get { presetSnapshot() }
        set { adoptPreset(newValue) }
    }
    /// Host-addressed parameter values: the single source of truth for the tree,
    /// `fullState`, and the render (which drains changes at the start of a buffer).
    let parameters: AddressedParameterStore
    private let outputBus: AUAudioUnitBus
    private var outputBusArray: AUAudioUnitBusArray!
    private var inputBusArray: AUAudioUnitBusArray!
    /// Everything the render block touches. The block captures this, never `self`.
    private let renderContext: SyntRenderContext
    /// Set while the tree is being copied from the engine, so the observer does not apply twice.
    private let suppressParameterObserver = Atomic<Bool>(false)
    private static let stateVersionKey = "syntStateVersion"
    static let stateVersion = 1
    private static let statePresetKey = "syntPreset"
    private static let stateIndexKey = "syntPresetIndex"

    public override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions = []) throws {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        outputBus = try AUAudioUnitBus(format: format)
        outputBus.maximumChannelCount = 2
        let core = AudioEngine(coreOnly: true)
        engine = core
        let store = AddressedParameterStore()
        parameters = store
        renderContext = SyntRenderContext(engine: core, parameters: store)
        try super.init(componentDescription: componentDescription, options: options)
        outputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
        inputBusArray = AUAudioUnitBusArray(audioUnit: self, busType: .input, busses: [])
        maximumFramesToRender = 512
        engine.usesHostTransport = true
        engine.rendersAllDelayInDSP = true
        engine.applyPreset()
        installParameterTree()
        startProgramChangePoll()
    }

    deinit {
        programChangeTimer?.cancel()
    }

    private var programChangeTimer: DispatchSourceTimer?

    /// Host MIDI program change: the render stores it, main loads it through
    /// the same path as `currentPreset`, so tree and view stay in sync.
    private func startProgramChangePoll() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.1, repeating: 0.1)
        timer.setEventHandler { [weak self] in self?.applyPendingProgram() }
        timer.resume()
        programChangeTimer = timer
    }

    /// Off by default. Logic re-sends a Program Change on every play ("Send used
    /// instrument settings on reset", region PCs), which loaded factory slot N over the
    /// patch chosen in the plugin. Hosts own the patch through `fullState`; a user who
    /// wants MIDI PC switching turns this on (saved in `fullState`).
    public var respondsToProgramChange: Bool {
        get { engine.respondsToProgramChange }
        set { engine.respondsToProgramChange = newValue }
    }
    private static let stateProgramChangeKey = "syntRespondsToProgramChange"

    public override var latency: TimeInterval { 0.0 }

    public override var channelCapabilities: [NSNumber]? {
        [0, 2]
    }

    public override var tailTime: TimeInterval {
        let preset = engine.preset
        var tail: Double = Double(preset.release)
        if preset.delayMix > 0.001 {
            let feedback = Double(min(0.95, max(0.0, preset.delayFeedback)))
            let delaySeconds = Double(max(0.05, preset.delayTime))
            let delayTail = delaySeconds / max(0.05, 1.0 - feedback)
            tail = max(tail, min(10.0, delayTail))
        }
        if preset.reverbMix > 0.001 {
            let room = Double(preset.reverbRoomSize)
            let reverbTail = 2.0 + room * 6.0
            tail = max(tail, min(12.0, reverbTail))
        }
        return tail
    }

    func applyPendingProgram() {
        let program = engine.pendingProgram.exchange(-1, ordering: .acquiringAndReleasing)
        guard program >= 0, respondsToProgramChange, let loaded = PresetBrowser.preset(forProgram: Int(program)) else { return }
        adoptPreset(loaded)
    }

    /// MIDI 1.0 protocol. Hosts may still deliver either `.MIDI` byte events or a
    /// `.midiEventList` of UMP packets (AVAudioEngine / Logic do the latter); both are parsed.
    public override var audioUnitMIDIProtocol: MIDIProtocolID { ._1_0 }

    public override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    public override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    /// Main thread, before rendering starts. Host blocks are cached here once.
    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        let frames = max(1, Int(maximumFramesToRender))
        renderContext.reserve(frames: frames)
        renderContext.musicalContext = musicalContextBlock
        renderContext.transportState = transportStateBlock
        let rate = outputBus.format.sampleRate
        engine.prepare(sampleRate: rate > 0 ? rate : 44_100, maxFrames: frames)
        engine.resetRenderStateForAllocation()
    }

    public override func deallocateRenderResources() {
        // R1: Do not nil out musicalContext/transportState while audio render might still be executing
        // the final buffer. They are safely replaced on next allocateRenderResources or deinit.
        super.deallocateRenderResources()
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        let contextUnmanaged = Unmanaged.passUnretained(renderContext)
        return { actionFlags, timestamp, frameCount, _, outputData, events, _ in
            contextUnmanaged.takeUnretainedValue().render(
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
            adoptPreset(PresetBrowser.list[index])
        }
    }

    public override var fullState: [String: Any]? {
        get {
            var state = super.fullState ?? [:]
            state[Self.stateVersionKey] = Self.stateVersion
            let snapshot = presetSnapshot()
            if let data = try? JSONEncoder().encode(snapshot) {
                state[Self.statePresetKey] = data
            }
            state[Self.stateIndexKey] = PresetBrowser.index(of: snapshot) ?? -1
            state[Self.stateProgramChangeKey] = respondsToProgramChange
            return state
        }
        set {
            guard let newValue else { return }
            // A newer plugin wrote this state: keep the current sound rather than
            // half-decode it, and say so.
            if let version = newValue[Self.stateVersionKey] as? Int, version > Self.stateVersion {
                NSLog("SyntAudioUnit: state version %d is newer than %d; not loaded", version, Self.stateVersion)
                return
            }
            if let flag = newValue[Self.stateProgramChangeKey] as? Bool {
                respondsToProgramChange = flag
            }
            guard let data = newValue[Self.statePresetKey] as? Data,
                  let preset = try? JSONDecoder().decode(SynthPreset.self, from: data) else {
                super.fullState = newValue
                return
            }
            adoptPreset(preset)
        }
    }

    /// The engine preset with every addressed value taken from the store.
    func presetSnapshot() -> SynthPreset {
        var snapshot = engine.preset
        for address in SynthParameterAddress.allCases {
            snapshot.setParameterValue(parameters.value(address.rawValue), for: address)
        }
        return snapshot
    }

    /// Posted on main after the whole preset was replaced (fullState, currentPreset,
    /// program change). The plugin view re-reads `uiPreset` so it never writes a stale copy back.
    public static let stateDidChangeNotification = Notification.Name("SyntAudioUnitStateDidChange")

    /// Whole-preset change: parameters store updates immediately, then main thread applies the preset.
    private func adoptPreset(_ preset: SynthPreset, notify: Bool = true) {
        for address in SynthParameterAddress.allCases {
            parameters.set(address.rawValue, preset.parameterValue(for: address))
        }
        // R5: Synchronously publish snapshot and modMatrix to RTPresetBuffer
        // before returning so the very first audio buffer receives the new preset immediately!
        let snap = RTPresetSnapshot(from: preset, rendersAllDelayInDSP: engine.rendersAllDelayInDSP)
        engine.rtPresetBuffer.publish(snap)
        engine.rtModMatrix.publish(preset.modMatrix)

        let apply: () -> Void = { [weak self] in
            guard let self else { return }
            self.engine.preset = preset
            self.syncParameterTreeFromEngine()
            if notify {
                NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: self)
            }
        }
        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    /// Main thread. A view edit of non-addressed fields (matrix, voice mode, ...).
    /// Addressed knobs keep their live values from the store; they travel through the tree.
    public func adoptNonAddressedFields(of edited: SynthPreset) {
        let live = presetSnapshot()
        var merged = edited
        for address in SynthParameterAddress.allCases {
            merged.setParameterValue(live.parameterValue(for: address), for: address)
        }
        guard merged != live else { return }
        adoptPreset(merged, notify: false)
    }

    private func installParameterTree() {
        let tree = SyntParameterTree.make()
        let store = parameters
        tree.implementorValueObserver = { [weak self] parameter, value in
            guard let self, !self.suppressParameterObserver.load(ordering: .acquiring),
                  let address = SynthParameterAddress(rawValue: parameter.address) else { return }
            // Any thread: the store is the only DSP writer path (render drains it).
            store.set(parameter.address, address.clamped(value))
            // The preset copy is display-only and lives on main.
            if Thread.isMainThread {
                self.engine.adoptAddressedParameterOnMain(id: parameter.address, value: value, pushToRender: false)
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.engine.adoptAddressedParameterOnMain(id: parameter.address, value: value, pushToRender: false)
                }
            }
        }
        tree.implementorValueProvider = { parameter in
            store.value(parameter.address)
        }
        parameterTree = tree
        syncParameterTreeFromEngine()
    }

    private func syncParameterTreeFromEngine() {
        guard let tree = parameterTree else { return }
        suppressParameterObserver.store(true, ordering: .releasing)
        for address in SynthParameterAddress.allCases {
            parameters.set(address.rawValue, engine.preset.parameterValue(for: address))
            guard let parameter = tree.parameter(withAddress: address.rawValue) else { continue }
            parameter.value = parameters.value(address.rawValue)
        }
        suppressParameterObserver.store(false, ordering: .releasing)
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
                // Reverb mix/room drive Apple Reverb, a device-graph node the
                // Audio Unit does not run, so they are not published here.
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
                knob(.pan, unit: .pan),
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
    private let engineUnmanaged: Unmanaged<AudioEngine>
    private let parametersUnmanaged: Unmanaged<AddressedParameterStore>
    var musicalContext: AUHostMusicalContextBlock?
    var transportState: AUHostTransportStateBlock?
    private var renderLeft: UnsafeMutablePointer<Float>?
    private var renderRight: UnsafeMutablePointer<Float>?
    private(set) var renderCapacity = 0

    var engine: AudioEngine { engineUnmanaged.takeUnretainedValue() }
    var parameters: AddressedParameterStore { parametersUnmanaged.takeUnretainedValue() }

    init(engine: AudioEngine, parameters: AddressedParameterStore) {
        self.engineUnmanaged = Unmanaged.passUnretained(engine)
        self.parametersUnmanaged = Unmanaged.passUnretained(parameters)
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
        let engine = self.engine
        engine.pullPresetSnapshotRT()
        parameters.drain { id, value in engine.applyAddressedParameterRT(id: id, value: value) }
        pullHostTransport()
        schedule(events, timestamp: timestamp, frameCount: frames)
        guard let buffers = bind(outputData, frames: frames) else { return kAudioUnitErr_FormatNotSupported }
        engine.render(frames: frames, intoL: buffers.left, intoR: buffers.right)
        if buffers.mono {
            // One planar channel: explicit (L + R) / 2 downmix.
            let l = buffers.left, r = buffers.right
            for i in 0..<frames { l[i] = (l[i] + r[i]) * 0.5 }
        }
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
            case .midiEventList:
                scheduleUMP(current, offset: offset)
            case .parameter:
                let parameter = current.pointee.parameter
                engine.enqueueParameter(id: parameter.parameterAddress, value: parameter.value, sampleOffset: offset)
                if let address = SynthParameterAddress(rawValue: parameter.parameterAddress) {
                    parameters.record(parameter.parameterAddress, address.clamped(parameter.value))
                }
            case .parameterRamp:
                let parameter = current.pointee.parameter
                let duration = Int(parameter.rampDurationSampleFrames)
                let startVal = parameters.value(parameter.parameterAddress)
                let endVal = parameter.value
                if duration > 1 {
                    engine.enqueueParameterRamp(
                        id: parameter.parameterAddress,
                        startValue: startVal,
                        endValue: endVal,
                        durationFrames: duration,
                        sampleOffset: offset
                    )
                } else {
                    engine.enqueueParameter(id: parameter.parameterAddress, value: endVal, sampleOffset: offset)
                }
                if let address = SynthParameterAddress(rawValue: parameter.parameterAddress) {
                    parameters.record(parameter.parameterAddress, address.clamped(endVal))
                }
            default:
                break
            }
            event = UnsafePointer(header.next)
        }
    }

    /// Audio thread. Walks the UMP packets in place (no copy of the list, no allocation)
    /// and feeds MIDI 1.0 bytes to the same parser as `.MIDI` events.
    private func scheduleUMP(_ event: UnsafePointer<AURenderEvent>, offset: Int) {
        let listOffset = MemoryLayout<AUMIDIEventList>.offset(of: \AUMIDIEventList.eventList) ?? 0
        let list = UnsafeRawPointer(event).advanced(by: listOffset)
        let numPackets = list.load(fromByteOffset: MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.numPackets) ?? 4, as: UInt32.self)
        let wordCountOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.wordCount) ?? 8
        let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \MIDIEventPacket.words) ?? 12
        var packet = list.advanced(by: MemoryLayout<MIDIEventList>.offset(of: \MIDIEventList.packet) ?? 8)
        var bytes: (UInt8, UInt8, UInt8) = (0, 0, 0)
        for _ in 0..<min(Int(numPackets), 256) {
            let wordCount = min(Int(packet.load(fromByteOffset: wordCountOffset, as: UInt32.self)), 64)
            let words = packet.advanced(by: wordsOffset)
            var w = 0
            while w < wordCount {
                let word = words.load(fromByteOffset: w * 4, as: UInt32.self)
                let type = Int(word >> 28)
                let size = Self.umpWordCount(type)
                var count = 0
                switch type {
                case 0x1, 0x2:
                    let status = UInt8((word >> 16) & 0xFF)
                    bytes = (status, UInt8((word >> 8) & 0x7F), UInt8(word & 0x7F))
                    count = Self.midi1Length(status)
                case 0x4 where w + 1 < wordCount:
                    let data = words.load(fromByteOffset: (w + 1) * 4, as: UInt32.self)
                    (bytes, count) = Self.midi2ToMidi1(word, data)
                default:
                    break
                }
                if count > 0 {
                    withUnsafeBytes(of: &bytes) { raw in
                        if let base = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) {
                            engine.enqueueMIDI(base, count: count, sampleOffset: offset)
                        }
                    }
                }
                w += size
            }
            packet = words.advanced(by: wordCount * 4)
        }
    }

    @inline(__always)
    static func umpWordCount(_ type: Int) -> Int {
        switch type {
        case 0x0, 0x1, 0x2, 0x6, 0x7: return 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: return 2
        case 0xB, 0xC: return 3
        default: return 4
        }
    }

    @inline(__always)
    static func midi1Length(_ status: UInt8) -> Int {
        switch status & 0xF0 {
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0: return 3
        case 0xC0, 0xD0: return 2
        case 0xF0:
            switch status {
            case 0xF2: return 3
            case 0xF1, 0xF3: return 2
            case 0xF0, 0xF7: return 0
            default: return 1
            }
        default: return 0
        }
    }

    /// MIDI 2.0 channel voice (UMP type 4) down to MIDI 1.0 bytes.
    static func midi2ToMidi1(_ word0: UInt32, _ word1: UInt32) -> ((UInt8, UInt8, UInt8), Int) {
        let opcode = UInt8((word0 >> 20) & 0xF)
        let channel = UInt8((word0 >> 16) & 0xF)
        let index = UInt8((word0 >> 8) & 0x7F)
        let status = (opcode << 4) | channel
        switch opcode {
        case 0x8, 0x9:
            var velocity = UInt8(word1 >> 25)
            if opcode == 0x9 && velocity == 0 && (word1 >> 16) != 0 { velocity = 1 }
            return ((status, index, velocity), 3)
        case 0xA, 0xB:
            return ((status, index, UInt8(word1 >> 25)), 3)
        case 0xC:
            return ((status, UInt8((word1 >> 24) & 0x7F), 0), 2)
        case 0xD:
            return ((status, UInt8(word1 >> 25), 0), 2)
        case 0xE:
            let bend = word1 >> 18
            return ((status, UInt8(bend & 0x7F), UInt8((bend >> 7) & 0x7F)), 3)
        default:
            return ((0, 0, 0), 0)
        }
    }

    private func sampleOffset(eventTime: AUEventSampleTime, bufferStart: AUEventSampleTime, frameCount: Int) -> Int {
        if eventTime == AUEventSampleTimeImmediate { return 0 }
        var delta = Int(eventTime - bufferStart)
        if delta < 0 { delta = 0 }
        if delta > frameCount { delta = frameCount }
        return delta
    }

    /// Deinterleaved Float32 only (the bus format). Interleaved buffers are refused.
    private func bind(_ outputData: UnsafeMutablePointer<AudioBufferList>, frames: Int) -> (left: UnsafeMutablePointer<Float>, right: UnsafeMutablePointer<Float>, mono: Bool)? {
        guard let renderLeft, let renderRight else { return nil }
        let buffers = UnsafeMutableAudioBufferListPointer(outputData)
        guard buffers.count >= 1 else { return nil }
        for i in 0..<min(2, buffers.count) where buffers[i].mNumberChannels != 1 {
            return nil
        }
        let byteCount = UInt32(frames * MemoryLayout<Float>.size)
        if buffers[0].mData == nil {
            buffers[0].mData = UnsafeMutableRawPointer(renderLeft)
            buffers[0].mDataByteSize = byteCount
        }
        let left = buffers[0].mData!.assumingMemoryBound(to: Float.self)
        guard buffers.count >= 2 else { return (left, renderRight, true) }
        if buffers[1].mData == nil {
            buffers[1].mData = UnsafeMutableRawPointer(renderRight)
            buffers[1].mDataByteSize = byteCount
        }
        return (left, buffers[1].mData!.assumingMemoryBound(to: Float.self), false)
    }
}
