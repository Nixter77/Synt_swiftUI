//
//  ArpeggiatorEngine.swift
//  Synt_swiftUI
//
//  RT-safe arpeggiator state machine. All mode decisions use cached fields only.
//

import Foundation

/// Pure arpeggiator sequencer: holds sorted notes + mode cursor, no audio I/O.
struct ArpeggiatorEngine {
    var mode: ArpeggiatorMode = .off
    /// Always stored ascending (low → high). Mode only affects index motion.
    var sortedNotes: [Int] = []
    var noteIndex: Int = 0
    /// +1 = ascending, -1 = descending (used by upDown)
    var direction: Int = 1
    var currentNote: Int? = nil
    /// After setHeldKeys, first advanceTick should play index 0 (or last for down).
    private var needsPriming: Bool = true

    mutating func setHeldKeys(_ keys: Set<Int>) {
        sortedNotes = Array(keys).sorted()
        if noteIndex >= sortedNotes.count {
            noteIndex = 0
        }
        if sortedNotes.isEmpty {
            noteIndex = 0
            direction = 1
            currentNote = nil
            needsPriming = true
        } else {
            // Next tick should emit the mode's starting note without skipping it.
            needsPriming = true
            switch mode {
            case .down:
                noteIndex = sortedNotes.count - 1
                direction = -1
            case .up, .upDown, .random, .off:
                noteIndex = 0
                direction = 1
            }
        }
    }

    /// Advance one tick and return the note to play (nil if idle).
    mutating func advanceTick(randomSource: inout UInt32) -> Int? {
        guard mode != .off, !sortedNotes.isEmpty else {
            currentNote = nil
            return nil
        }

        if needsPriming {
            needsPriming = false
            // Emit current index first (start of sequence / restart after key change)
            switch mode {
            case .down:
                noteIndex = sortedNotes.count - 1
            case .random:
                randomSource = randomSource &* 1664525 &+ 1013904223
                noteIndex = Int(randomSource % UInt32(sortedNotes.count))
            case .up, .upDown, .off:
                noteIndex = min(noteIndex, sortedNotes.count - 1)
            }
            let note = sortedNotes[noteIndex]
            currentNote = note
            return note
        }

        switch mode {
        case .off:
            currentNote = nil
            return nil

        case .up:
            noteIndex = (noteIndex + 1) % sortedNotes.count

        case .down:
            if noteIndex <= 0 {
                noteIndex = sortedNotes.count - 1
            } else {
                noteIndex -= 1
            }

        case .upDown:
            if sortedNotes.count == 1 {
                noteIndex = 0
            } else {
                noteIndex += direction
                if noteIndex >= sortedNotes.count {
                    direction = -1
                    noteIndex = sortedNotes.count - 2
                } else if noteIndex < 0 {
                    direction = 1
                    noteIndex = min(1, sortedNotes.count - 1)
                }
            }

        case .random:
            // Deterministic LCG — no Foundation random (which can lock / allocate).
            randomSource = randomSource &* 1664525 &+ 1013904223
            noteIndex = Int(randomSource % UInt32(sortedNotes.count))
        }

        let note = sortedNotes[noteIndex]
        currentNote = note
        return note
    }

    mutating func reset() {
        sortedNotes = []
        noteIndex = 0
        direction = 1
        currentNote = nil
        needsPriming = true
    }
}
