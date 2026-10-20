//
//  ArpeggiatorEngine.swift
//  Synt_swiftUI
//
//  RT-safe arpeggiator state machine. All mode decisions use cached fields only.
//

import Foundation

/// 128-bit set of MIDI keys. No heap, safe on the render thread.
public struct MIDIKeySet: Equatable {
    public var lo: UInt64 = 0
    public var hi: UInt64 = 0

    @inline(__always) public func contains(_ n: Int) -> Bool {
        guard n >= 0, n < 128 else { return false }
        return n < 64 ? (lo >> UInt64(n)) & 1 != 0 : (hi >> UInt64(n - 64)) & 1 != 0
    }
    @inline(__always) public mutating func insert(_ n: Int) {
        guard n >= 0, n < 128 else { return }
        if n < 64 { lo |= 1 << UInt64(n) } else { hi |= 1 << UInt64(n - 64) }
    }
    @inline(__always) public mutating func remove(_ n: Int) {
        guard n >= 0, n < 128 else { return }
        if n < 64 { lo &= ~(1 << UInt64(n)) } else { hi &= ~(1 << UInt64(n - 64)) }
    }
    public mutating func removeAll() { lo = 0; hi = 0 }
    public var isEmpty: Bool { lo == 0 && hi == 0 }
    public var count: Int { lo.nonzeroBitCount + hi.nonzeroBitCount }
}

/// Pure arpeggiator sequencer: holds sorted notes + mode cursor, no audio I/O.
public struct ArpeggiatorEngine {
    public var mode: ArpeggiatorMode = .off
    public var octaves: Int = 1
    /// Always stored ascending (low → high). Mode only affects index motion.
    /// Capacity reserved once (128) so refills on the audio thread never allocate.
    public var sortedNotes: [Int] = {
        var a: [Int] = []
        a.reserveCapacity(128)
        return a
    }()
    public var noteIndex: Int = 0
    /// +1 = ascending, -1 = descending (used by upDown)
    public var direction: Int = 1
    public var currentNote: Int? = nil
    /// After setHeldKeys, first advanceTick should play index 0 (or last for down).
    private var needsPriming: Bool = true

    /// Test / UI convenience. The render thread uses the MIDIKeySet overload.
    public mutating func setHeldKeys(_ keys: Set<Int>) {
        var set = MIDIKeySet()
        for k in keys { set.insert(k) }
        setHeldKeys(set)
    }

    /// Ascending by construction (bit order), no sort, no allocation.
    public mutating func setHeldKeys(_ keys: MIDIKeySet) {
        sortedNotes.removeAll(keepingCapacity: true)
        let octCount = max(1, min(3, octaves))
        for o in 0..<octCount {
            let offset = o * 12
            for n in 0..<128 where keys.contains(n) {
                let note = n + offset
                if note <= 127 {
                    sortedNotes.append(note)
                }
            }
        }
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
    public mutating func advanceTick(randomSource: inout UInt32) -> Int? {
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

    public mutating func reset() {
        sortedNotes.removeAll(keepingCapacity: true)
        noteIndex = 0
        direction = 1
        currentNote = nil
        needsPriming = true
    }
}
