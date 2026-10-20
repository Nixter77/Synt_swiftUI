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
    /// Sample-rate and block size. Allocations for the schedule already happened in `init`.
    public func prepare(sampleRate: Double, maxFrames: Int) {
        preparedMaxFrames = max(1, maxFrames)
        applySampleRate(sampleRate, rebuildGraph: false)
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
            guard let command = Self.command(for: message) else { continue }
            guard midiScheduleCount < 512 else { return }
            midiSchedule[midiScheduleCount] = ScheduledMIDI(offset: offset, command: command)
            midiScheduleCount += 1
        }
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
        let scheduled = midiScheduleCount
        processCommandQueue()
        guard scheduled > 0 else {
            renderBlock(intoL: intoL, intoR: intoR, frameCount: frames)
            return
        }
        sortMIDISchedule(scheduled)
        var cursor = 0
        var index = 0
        while cursor < frames {
            let next = index < scheduled ? min(frames, max(cursor, Int(midiSchedule[index].offset))) : frames
            if next > cursor {
                let right = intoR?.advanced(by: cursor)
                renderBlock(intoL: intoL.advanced(by: cursor), intoR: right, frameCount: next - cursor)
                cursor = next
            }
            while index < scheduled && Int(midiSchedule[index].offset) <= cursor {
                handleCommand(midiSchedule[index].command)
                index += 1
            }
            if index >= scheduled && cursor < frames && next == cursor {
                let right = intoR?.advanced(by: cursor)
                renderBlock(intoL: intoL.advanced(by: cursor), intoR: right, frameCount: frames - cursor)
                cursor = frames
            }
        }
        if index > 0 {
            trimAbandonedTails()
        }
        var kept = 0
        for i in index..<scheduled {
            var event = midiSchedule[i]
            event.offset -= Int32(frames)
            if event.offset < 0 { event.offset = 0 }
            midiSchedule[kept] = event
            kept += 1
        }
        midiScheduleCount = kept
    }

    /// Known addresses are filled in with the parameter tree. Unknown ids do nothing.
    func applyAddressedParameterRT(id: UInt64, value: Float) {
        _ = (id, value)
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

    private static func command(for message: MIDIMessage) -> AudioCommand? {
        switch message {
        case let .noteOn(note, velocity, _):
            return .keyDown(midiNote: Int(note), velocity: velocity)
        case let .noteOff(note, _):
            return .keyUp(midiNote: Int(note))
        case let .pitchBend(value, _):
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
        case let .channelPressure(pressure, _):
            return .setAftertouch(pressure)
        case let .polyPressure(note, pressure, _):
            return .setPolyAftertouch(midiNote: Int(note), pressure: pressure)
        case let .controlChange(controller, value, _):
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
