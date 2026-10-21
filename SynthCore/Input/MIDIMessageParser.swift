//
//  MIDIMessageParser.swift
//  Synt_swiftUI
//
//  Pure MIDI 1.0 decoding: a byte-stream parser (running status, SysEx,
//  realtime bytes) and a UMP decoder for MIDI 1.0 channel-voice words.
//  No CoreMIDI, no engine, no allocation: safe on the CoreMIDI thread.
//

import Foundation

/// The subset of MIDI the synth reacts to. Everything else is `.ignored`.
public enum MIDIMessage: Equatable {
    /// Velocity 1…127 mapped to 0…1. Velocity 0 is decoded as `.noteOff`.
    case noteOn(note: UInt8, velocity: Float, channel: UInt8)
    case noteOff(note: UInt8, channel: UInt8)
    /// -1…1, center (8192) = 0.
    case pitchBend(Float, channel: UInt8)
    /// CC1, 0…1.
    case modWheel(Float, channel: UInt8)
    /// CC64, down when value ≥ 64.
    case sustain(down: Bool, channel: UInt8)
    /// CC123 (and the mode messages CC124–127, which imply it).
    case allNotesOff(channel: UInt8)
    /// CC120: silence now.
    case allSoundOff(channel: UInt8)
    /// Program Change 0…127 (selects factory preset N+1 when N < 100).
    case programChange(program: UInt8, channel: UInt8)
    /// Channel Pressure 0…1 (status 0xD0).
    case channelPressure(Float, channel: UInt8)
    /// Polyphonic Key Pressure 0…1 (status 0xA0).
    case polyPressure(note: UInt8, pressure: Float, channel: UInt8)
    /// Any other controller (kept for display / future mapping).
    case controlChange(controller: UInt8, value: UInt8, channel: UInt8)
    /// 0xF8. Twenty-four of these make one quarter note.
    case clock
    /// 0xFA. Reset the transport and run.
    case songStart
    /// 0xFB. Run without resetting the phase.
    case songContinue
    /// 0xFC. Stop. Phase stays where it is.
    case songStop
    case ignored
}

public enum MIDIDecode {
    /// 14-bit bend → -1…1, symmetric around 8192 so both ends reach exactly ±1.
    @inline(__always)
    public static func normalizedPitchBend(lsb: UInt8, msb: UInt8) -> Float {
        let value = (Int(msb & 0x7F) << 7) | Int(lsb & 0x7F)
        return value >= 8192
            ? Float(value - 8192) / 8191
            : Float(value - 8192) / 8192
    }

    /// One complete MIDI 1.0 channel-voice message.
    @inline(__always)
    public static func channelMessage(status: UInt8, d1: UInt8, d2: UInt8) -> MIDIMessage {
        let channel = status & 0x0F
        let d1 = d1 & 0x7F
        let d2 = d2 & 0x7F
        switch status & 0xF0 {
        case 0x90:
            return d2 > 0
                ? .noteOn(note: d1, velocity: Float(d2) / 127, channel: channel)
                : .noteOff(note: d1, channel: channel)
        case 0x80:
            return .noteOff(note: d1, channel: channel)
        case 0xA0:
            return .polyPressure(note: d1, pressure: Float(d2) / 127.0, channel: channel)
        case 0xC0:
            return .programChange(program: d1, channel: channel)
        case 0xD0:
            return .channelPressure(Float(d1) / 127.0, channel: channel)
        case 0xE0:
            return .pitchBend(normalizedPitchBend(lsb: d1, msb: d2), channel: channel)
        case 0xB0:
            switch d1 {
            case 1: return .modWheel(Float(d2) / 127, channel: channel)
            case 64: return .sustain(down: d2 >= 64, channel: channel)
            case 120: return .allSoundOff(channel: channel)
            case 123, 124, 125, 126, 127: return .allNotesOff(channel: channel)
            default: return .controlChange(controller: d1, value: d2, channel: channel)
            }
        default:
            return .ignored
        }
    }

    /// One UMP word of message type 0x2 (MIDI 1.0 channel voice, 32 bit).
    /// Other message types (utility, system, SysEx, MIDI 2.0) → `.ignored`.
    @inline(__always)
    public static func ump(_ word: UInt32) -> MIDIMessage {
        guard (word >> 28) & 0xF == 0x2 else { return .ignored }
        let status = UInt8((word >> 16) & 0xFF)
        guard status & 0x80 != 0, status < 0xF0 else { return .ignored }
        return channelMessage(status: status,
                              d1: UInt8((word >> 8) & 0x7F),
                              d2: UInt8(word & 0x7F))
    }

    /// Number of 32-bit words in a UMP packet, from its message type nibble.
    @inline(__always)
    public static func umpWordCount(firstWord: UInt32) -> Int {
        switch (firstWord >> 28) & 0xF {
        case 0x0, 0x1, 0x2, 0x6, 0x7: return 1
        case 0x3, 0x4, 0x8, 0x9, 0xA: return 2
        case 0xB, 0xC: return 3
        default: return 4
        }
    }
}

/// MIDI 1.0 byte stream → messages. Value type; one instance per stream.
public struct MIDIByteParser {
    /// Channel-voice status kept for running status. 0 = none.
    private(set) var runningStatus: UInt8 = 0
    private var inSysEx = false
    private var data0: UInt8 = 0
    private var dataCount = 0

    public init() {}

    /// Returns a message when `byte` completes one, otherwise `nil`.
    public mutating func feed(_ b: UInt8) -> MIDIMessage? {
        // Realtime bytes may arrive mid-message, including inside SysEx.
        // They must not touch running status, the data count, or the SysEx flag.
        if b >= 0xF8 {
            switch b {
            case 0xF8: return .clock
            case 0xFA: return .songStart
            case 0xFB: return .songContinue
            case 0xFC: return .songStop
            default: return nil
            }
        }
        if b == 0xF0 { inSysEx = true; runningStatus = 0; dataCount = 0; return nil }
        if b == 0xF7 { inSysEx = false; return nil }
        if b & 0x80 != 0 {
            inSysEx = false
            dataCount = 0
            // System common (F1–F6) cancels running status; its data is dropped.
            runningStatus = b < 0xF0 ? b : 0
            return nil
        }
        if inSysEx || runningStatus == 0 { return nil }

        let command = runningStatus & 0xF0
        let needed = (command == 0xC0 || command == 0xD0) ? 1 : 2
        if dataCount == 0 && needed == 2 {
            data0 = b
            dataCount = 1
            return nil
        }
        let d1 = needed == 2 ? data0 : b
        let d2 = needed == 2 ? b : 0
        dataCount = 0
        return MIDIDecode.channelMessage(status: runningStatus, d1: d1, d2: d2)
    }

    /// Convenience for tests and tools: all messages in `bytes`, in order.
    public mutating func parse(_ bytes: [UInt8]) -> [MIDIMessage] {
        var out: [MIDIMessage] = []
        for b in bytes {
            if let m = feed(b) { out.append(m) }
        }
        return out
    }
}
