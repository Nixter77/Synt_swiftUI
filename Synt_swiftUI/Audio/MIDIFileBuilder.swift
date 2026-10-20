//
//  MIDIFileBuilder.swift
//  Synt_swiftUI
//
//  Builds Standard MIDI Files (SMF Type 0) from 16-step sequencer patterns
//  with tempo, velocity, gate length, and tie/legato articulation.
//

import Foundation

enum MIDIFileBuilder {
    private struct TimedEvent {
        let tick: UInt32
        let bytes: [UInt8]
        let isNoteOff: Bool
    }

    /// Generates a Standard MIDI File (SMF Type 0) from a sequencer pattern.
    static func buildSMF(
        steps: [SequencerStep],
        rootNote: Int = 60,
        bpm: Float = 120.0,
        length: Int = 16,
        ppqn: UInt16 = 480
    ) -> Data {
        var timedEvents: [TimedEvent] = []
        let ticksPerStep: UInt32 = UInt32(ppqn) / 4 // 120 ticks for a 16th note

        // 1. Setup events at tick 0: Tempo and Time Signature
        let safeBpm = max(20.0, min(bpm, 300.0))
        let usPerBeat = UInt32(60_000_000.0 / Double(safeBpm))
        let b1 = UInt8((usPerBeat >> 16) & 0xFF)
        let b2 = UInt8((usPerBeat >> 8) & 0xFF)
        let b3 = UInt8(usPerBeat & 0xFF)
        timedEvents.append(TimedEvent(tick: 0, bytes: [0xFF, 0x51, 0x03, b1, b2, b3], isNoteOff: false))
        timedEvents.append(TimedEvent(tick: 0, bytes: [0xFF, 0x58, 0x04, 0x04, 0x02, 0x18, 0x08], isNoteOff: false))

        func midiPitch(for step: SequencerStep) -> UInt8 {
            let raw = rootNote + step.noteOffset + step.octave * 12
            return UInt8(max(0, min(127, raw)))
        }

        // 2. Note events
        let stepCount = min(steps.count, max(1, min(16, length)))
        var i = 0
        while i < stepCount {
            let step = steps[i]
            if step.isActive {
                let note = midiPitch(for: step)
                let velocity = UInt8(clamping: Int(max(0.05, min(step.velocity, 1.0)) * 127.0))
                let startTick = UInt32(i) * ticksPerStep

                let rCount = max(1, min(4, step.ratchet))
                if rCount > 1 {
                    let subTicks = ticksPerStep / UInt32(rCount)
                    for r in 0..<rCount {
                        let subStart = startTick + UInt32(r) * subTicks
                        let subGate = max(0.05, min(step.gate, 1.0))
                        let subDuration = max(5, UInt32(Float(subTicks) * subGate))
                        let subEnd = subStart + subDuration
                        timedEvents.append(TimedEvent(tick: subStart, bytes: [0x90, note, velocity], isNoteOff: false))
                        timedEvents.append(TimedEvent(tick: subEnd, bytes: [0x80, note, 0x40], isNoteOff: true))
                    }
                    i += 1
                    continue
                }

                var lookahead = i
                // Merge consecutive active tied steps that share the same pitch
                while lookahead + 1 < stepCount
                    && steps[lookahead + 1].isActive
                    && (steps[lookahead].tie || steps[lookahead + 1].tie)
                    && midiPitch(for: steps[lookahead + 1]) == note {
                    lookahead += 1
                }

                let spannedSteps = UInt32(lookahead - i)
                let lastStep = steps[lookahead]
                let slidesIntoDifferentPitch = (lookahead + 1 < stepCount)
                    && steps[lookahead + 1].isActive
                    && (lastStep.tie || steps[lookahead + 1].tie)

                let tailGate: Float = slidesIntoDifferentPitch ? 1.0 : max(0.05, min(lastStep.gate, 1.0))
                let duration = spannedSteps * ticksPerStep + UInt32(Float(ticksPerStep) * tailGate)

                let endTick = startTick + max(10, duration)
                timedEvents.append(TimedEvent(tick: startTick, bytes: [0x90, note, velocity], isNoteOff: false))
                timedEvents.append(TimedEvent(tick: endTick, bytes: [0x80, note, 0x40], isNoteOff: true))

                i = lookahead + 1
            } else {
                i += 1
            }
        }

        // Sort events chronologically. For same tick, put note-off before note-on.
        timedEvents.sort {
            if $0.tick != $1.tick {
                return $0.tick < $1.tick
            }
            if $0.isNoteOff != $1.isNoteOff {
                return $0.isNoteOff && !$1.isNoteOff
            }
            return false
        }

        // 3. Serialize track data with Variable Length Quantity (VLQ) deltas
        var trackData = Data()
        var lastTick: UInt32 = 0

        for event in timedEvents {
            let delta = event.tick >= lastTick ? event.tick - lastTick : 0
            writeVLQ(delta, into: &trackData)
            trackData.append(contentsOf: event.bytes)
            lastTick = event.tick
        }

        // End of track marker
        writeVLQ(0, into: &trackData)
        trackData.append(contentsOf: [0xFF, 0x2F, 0x00])

        // 4. Assemble final file: MThd header + MTrk track
        var smf = Data()
        // "MThd"
        smf.append(contentsOf: [0x4D, 0x54, 0x68, 0x64])
        // Header length (6)
        smf.append(contentsOf: [0x00, 0x00, 0x00, 0x06])
        // Format 0 (single track)
        smf.append(contentsOf: [0x00, 0x00])
        // 1 track
        smf.append(contentsOf: [0x00, 0x01])
        // Division: PPQN big-endian
        smf.append(contentsOf: [UInt8((ppqn >> 8) & 0xFF), UInt8(ppqn & 0xFF)])

        // "MTrk"
        smf.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B])
        // Track length
        let trackLength = UInt32(trackData.count)
        smf.append(contentsOf: [
            UInt8((trackLength >> 24) & 0xFF),
            UInt8((trackLength >> 16) & 0xFF),
            UInt8((trackLength >> 8) & 0xFF),
            UInt8(trackLength & 0xFF)
        ])
        smf.append(trackData)

        return smf
    }

    private static func writeVLQ(_ value: UInt32, into data: inout Data) {
        var buffer: [UInt8] = []
        var v = value
        buffer.append(UInt8(v & 0x7F))
        v >>= 7
        while v > 0 {
            buffer.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }
        for byte in buffer.reversed() {
            data.append(byte)
        }
    }
}
