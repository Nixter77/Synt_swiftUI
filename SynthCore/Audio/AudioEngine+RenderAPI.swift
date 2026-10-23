//
//  AudioEngine+RenderAPI.swift
//  SynthCore
//
//  Block render for the standalone graph and the Audio Unit.
//  An empty MIDI schedule takes the same path the source node used to:
//  drain both queues once, then renderBlock for the whole buffer.
//

import AVFoundation
import Foundation

public struct ScheduledMIDI {
    public var offset: Int32
    public var command: AudioCommand
    public init(offset: Int32, command: AudioCommand) {
        self.offset = offset
        self.command = command
    }
}

extension AudioEngine {
    /// Sample rate. Block size is enforced by the caller (the AU refuses larger
    /// buffers); allocations for the schedule already happened in `init`.
    public func prepare(sampleRate: Double, maxFrames: Int) {
        applySampleRate(sampleRate, rebuildGraph: false)
        dspReverb.allocate(sampleRate: sampleRate)
        sendReverb.allocate(sampleRate: sampleRate)
        prepareVoiceFilters(sampleRate: sampleRate, maxFrames: maxFrames)
    }

    /// Filter 2 buffers. Main thread and allocateRenderResources only.
    public func prepareVoiceFilters(sampleRate: Double, maxFrames: Int) {
        let frames = max(1, maxFrames)
        for i in 0..<AudioEngine.maxVoices {
            voiceDual[i].prepare(sampleRate: sampleRate, maxFrames: frames)
            voiceFormant[i].prepare(sampleRate: sampleRate, maxFrames: frames)
        }
    }

    /// Note-on and note-off. The objects live beside the voice, so `ActiveNote`
    /// activate/deactivate cannot see them.
    @inline(__always)
    func resetVoiceToneBanks(at index: Int) {
        voiceDual[index].reset()
        voiceFormant[index].reset()
    }

    /// Render stopped (AU allocate/deallocate). Voices, pedal, schedule, parser
    /// and effect tails start from silence, so nothing survives a re-allocate.
    public func resetRenderStateForAllocation() {
        midiScheduleCount = 0
        blockMIDIParser = MIDIByteParser()
        handleCommand(.clearAll)
        resetPatchStateRT()
        pingPongDelay.reset()
        dspChorus.reset()
        shimmer.reset()
        dspReverb.reset()
        sendReverb.reset()
        sendDelay.reset()
        rotary.reset()
        phaser.reset()
        distortion.reset()
        parametricEQL.reset()
        parametricEQR.reset()
    }

    /// UI / main thread. The audio thread applies the value from `commandQueue`.
    public func setParameter(id: UInt64, value: Float) {
        _ = commandQueue.push(.setAddressedParameter(id: id, value: value))
    }

    /// Audio thread. One MIDI 1.0 byte string, applied at `sampleOffset` inside the next `render`.
    public func enqueueMIDI(_ bytes: UnsafePointer<UInt8>, count: Int, sampleOffset: Int) {
        guard count > 0 else { return }
        let offset = Int32(max(0, sampleOffset))
        for i in 0..<count {
            guard let message = blockMIDIParser.feed(bytes[i]) else { continue }
            if case let .programChange(program, _) = message {
                pendingProgram.store(Int32(program), ordering: .releasing)
                continue
            }
            guard let command = Self.command(for: message, mpeEnabled: cachedMpeEnabled, zone: cachedMpeZone, memberCount: cachedMpeMemberChannelCount) else { continue }
            guard midiScheduleCount < 512 else {
                // Schedule full: releases must never be lost (stuck notes). Apply
                // them now, a few samples early; drop only non-release events.
                switch command {
                case .keyUp, .allNotesOff, .clearAll, .setSustain(false), .mpeKeyUp:
                    handleCommand(command)
                default:
                    break
                }
                continue
            }
            midiSchedule[midiScheduleCount] = ScheduledMIDI(offset: offset, command: command)
            midiScheduleCount += 1
        }
    }

    /// Audio thread. Host automation, applied at `sampleOffset` inside the next `render`.
    /// A full schedule applies it at once rather than dropping it.
    public func enqueueParameter(id: UInt64, value: Float, sampleOffset: Int) {
        guard midiScheduleCount < 512 else {
            applyAddressedParameterRT(id: id, value: value)
            return
        }
        let offset = Int32(max(0, sampleOffset))
        midiSchedule[midiScheduleCount] = ScheduledMIDI(offset: offset, command: .setAddressedParameter(id: id, value: value))
        midiScheduleCount += 1
    }

    public func render(frames: Int, into audioBufferList: UnsafeMutablePointer<AudioBufferList>) {
        let frames = max(0, frames)
        guard frames > 0 else { return }
        let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let left: UnsafeMutablePointer<Float>?
        let right: UnsafeMutablePointer<Float>?
        if abl.count >= 2,
           let bufL = abl[0].mData?.assumingMemoryBound(to: Float.self),
           let bufR = abl[1].mData?.assumingMemoryBound(to: Float.self) {
            left = bufL
            right = bufR
        } else if abl.count >= 1, let buf = abl[0].mData?.assumingMemoryBound(to: Float.self) {
            left = buf
            right = nil
        } else {
            return
        }
        guard let left else { return }
        render(frames: frames, intoL: left, intoR: right)
    }

    /// Stereo (or mono-downmixed) block. No allocation.
    public func render(frames: Int, intoL: UnsafeMutablePointer<Float>, intoR: UnsafeMutablePointer<Float>?) {
        let frames = max(0, frames)
        guard frames > 0 else { return }
        isRenderingActive.store(true, ordering: .releasing)
        defer { isRenderingActive.store(false, ordering: .releasing) }
        let scheduled = midiScheduleCount
        processCommandQueue()
        guard scheduled > 0 else {
            renderBlock(intoL: intoL, intoR: intoR, frameCount: frames)
            return
        }
        sortMIDISchedule(scheduled)
        // Offsets are clamped to [0, frames] by the caller, so every event of
        // this buffer is applied here: render up to it, apply, continue.
        var cursor = 0
        for index in 0..<scheduled {
            let at = min(frames, max(cursor, Int(midiSchedule[index].offset)))
            if at > cursor {
                renderBlock(intoL: intoL.advanced(by: cursor), intoR: intoR?.advanced(by: cursor), frameCount: at - cursor)
                cursor = at
            }
            handleCommand(midiSchedule[index].command)
        }
        if cursor < frames {
            renderBlock(intoL: intoL.advanced(by: cursor), intoR: intoR?.advanced(by: cursor), frameCount: frames - cursor)
        }
        trimAbandonedTails()
        midiScheduleCount = 0
    }

    /// Audio thread. Host tempo updates the render cache only. `preset.bpm` stays
    /// on the main thread. Apple Delay is a graph object and is left at the
    /// preset tempo; the DSP ping-pong delay follows the host.
    func adoptHostContext(tempo: Double?, transportMoving: Bool?, beatPosition: Double? = nil) {
        if let tempo, tempo >= 20, tempo <= 400 {
            cachedBPM = Float(tempo)
            if cachedLfoTempoSync {
                lfo.rate = cachedLfoSyncDivision.frequency(bpm: cachedBPM)
            }
            if cachedLfo2TempoSync {
                lfo2.rate = cachedLfo2SyncDivision.frequency(bpm: cachedBPM)
            }
            if cachedDelayTempoSync && cachedDelayPingPong {
                let dur = cachedDelaySyncDivision.duration(bpm: cachedBPM)
                pingPongDelay.delayTime = max(0.001, min(2, dur))
            }
            if cachedPerlinTempoSync {
                cachedPerlinHz = cachedPerlinDivision.frequency(bpm: cachedBPM)
            }
            if cachedChorusFlanger && cachedChorusFlangerSync {
                dspChorus.rate = cachedChorusFlangerDivision.frequency(bpm: cachedBPM)
            }
        }
        if let transportMoving {
            hostTransportMoving = transportMoving
        }
        if let beatPosition {
            cachedHostBeatPosition = beatPosition
            tranceHostBeat = beatPosition
            tranceHostLocked = true
            if cachedLfoTempoSync {
                lfo.syncPhase(beat: beatPosition, rateInCyclesPerBeat: cachedLfoSyncDivision.cyclesPerBeat)
            }
            if cachedLfo2TempoSync {
                lfo2.syncPhase(beat: beatPosition, rateInCyclesPerBeat: cachedLfo2SyncDivision.cyclesPerBeat)
            }
        }
    }

    private func sortMIDISchedule(_ count: Int) {
        guard count > 1 else { return }
        var i = 1
        while i < count {
            let key = midiSchedule[i]
            var j = i - 1
            while j >= 0 && midiSchedule[j].offset > key.offset {
                midiSchedule[j + 1] = midiSchedule[j]
                j -= 1
            }
            midiSchedule[j + 1] = key
            i += 1
        }
    }

    /// R12-3: member channels of an MPE zone. Lower: master ch1 (0), members 2…1+N (1…N).
    /// Upper: master ch16 (15), members 15−N…14 (0-based). N = 0 → no members.
    @inline(__always)
    public static func isMPEMemberChannel(_ channel: UInt8, zone: MPEZone, memberCount: Int) -> Bool {
        let n = max(0, min(15, memberCount))
        guard n > 0 else { return false }
        let ch = Int(channel & 15)
        if zone == .lower { return ch >= 1 && ch <= n }
        return ch >= 15 - n && ch <= 14
    }

    public static func command(for message: MIDIMessage, mpeEnabled: Bool = false,
                               zone: MPEZone = .lower, memberCount: Int = 15) -> AudioCommand? {
        switch message {
        case let .noteOn(note, velocity, channel):
            if mpeEnabled && isMPEMemberChannel(channel, zone: zone, memberCount: memberCount) {
                return .mpeKeyDown(midiNote: Int(note), velocity: velocity, channel: channel)
            }
            return .keyDown(midiNote: Int(note), velocity: velocity)
        case let .noteOff(note, channel):
            if mpeEnabled && isMPEMemberChannel(channel, zone: zone, memberCount: memberCount) {
                return .mpeKeyUp(midiNote: Int(note), channel: channel)
            }
            return .keyUp(midiNote: Int(note))
        case let .pitchBend(value, channel):
            if mpeEnabled && isMPEMemberChannel(channel, zone: zone, memberCount: memberCount) {
                return .mpePitchBend(channel: channel, value: value)
            }
            return .setPitchBend(value)
        case let .modWheel(value, _):
            return .setModWheel(value)
        case let .sustain(down, _):
            return .setSustain(down)
        case .allNotesOff:
            return .allNotesOff
        case .allSoundOff:
            return .clearAll
        case .programChange:
            return nil
        case let .channelPressure(pressure, channel):
            if mpeEnabled && isMPEMemberChannel(channel, zone: zone, memberCount: memberCount) {
                return .mpePressure(channel: channel, value: pressure)
            }
            return .setAftertouch(pressure)
        case let .polyPressure(note, pressure, _):
            return .setPolyAftertouch(midiNote: Int(note), pressure: pressure)
        case let .controlChange(controller, value, channel):
            if mpeEnabled && controller == 74 && isMPEMemberChannel(channel, zone: zone, memberCount: memberCount) {
                let norm = Float(value) / 127.0
                return .mpeTimbre(channel: channel, value: norm)
            }
            // R12-2: RPN CCs belong to the MPE path only while MPE is on; otherwise they stay
            // plain CCs (MIDI-learn / CC maps unchanged, a DAW's RPN 0 cannot touch MPE state).
            if mpeEnabled && (controller == 100 || controller == 101 || controller == 6 || controller == 38)
                && (channel & 15 == 0 || channel & 15 == 15   // SYNT_16 R13-2: MCM on either zone master
                    || isMPEMasterChannel(channel, zone: zone) || isMPEMemberChannel(channel, zone: zone, memberCount: memberCount)) {
                return .mpeControlChange(channel: channel, cc: controller, value: value)
            }
            return .controlChange(cc: controller, value: value)
        case .clock:
            return .midiClock
        case .songStart:
            return .midiStart
        case .songContinue:
            return .midiContinue
        case .songStop:
            return .midiStop
        case .ignored:
            return nil
        }
    }
}
