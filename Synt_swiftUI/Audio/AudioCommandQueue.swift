//
//  AudioCommandQueue.swift
//  Synt_swiftUI
//
//  Lock-free Single-Producer Single-Consumer (SPSC) queue for audio commands.
//  UI thread pushes, Audio thread pops.
//
//  SPSC rule: only the producer stores `head`; only the consumer stores `tail`.
//  When the ring is full, critical commands (noteOff / clearAll / arpKeyUp) are
//  recorded on atomic side-channel state instead of stealing the consumer's tail.
//

import Foundation
import Synchronization

enum AudioCommand: Equatable {
    case noteOn(midiNote: Int, velocity: Float)
    case noteOff(midiNote: Int)
    case clearAll
    case arpKeyDown(midiNote: Int)
    case arpKeyUp(midiNote: Int)

    var isCritical: Bool {
        switch self {
        case .noteOff, .clearAll, .arpKeyUp:
            return true
        case .noteOn, .arpKeyDown:
            return false
        }
    }
}

final class AudioCommandQueue: @unchecked Sendable {
    private let capacity: Int
    private var buffer: [AudioCommand?]

    // Atomic indices for lock-free SPSC ring (producer owns head, consumer owns tail)
    private let head = Atomic<Int>(0)
    private let tail = Atomic<Int>(0)

    // Side-channel for critical overflow — producer never advances tail.
    // MIDI notes 0..127 → two UInt64 bitsets.
    private let pendingNoteOffLo = Atomic<UInt64>(0)
    private let pendingNoteOffHi = Atomic<UInt64>(0)
    private let pendingArpKeyUpLo = Atomic<UInt64>(0)
    private let pendingArpKeyUpHi = Atomic<UInt64>(0)
    private let pendingClearAll = Atomic<Bool>(false)

    init(capacity: Int = 256) {
        self.capacity = max(2, capacity)
        self.buffer = Array(repeating: nil, count: self.capacity)
    }

    /// Push a command (UI / non-audio producer thread only).
    /// Returns true if accepted into the ring or critical side-channel.
    /// Non-critical commands return false when the ring is full.
    @inline(__always)
    func push(_ command: AudioCommand) -> Bool {
        if tryPushRing(command) {
            return true
        }

        guard command.isCritical else {
            return false
        }

        // Ring full: park critical work on atomics (producer never stores tail).
        switch command {
        case .noteOff(let midiNote):
            orNoteOffBit(clampedMIDI(midiNote))
            return true
        case .arpKeyUp(let midiNote):
            orArpKeyUpBit(clampedMIDI(midiNote))
            return true
        case .clearAll:
            pendingClearAll.store(true, ordering: .releasing)
            return true
        case .noteOn, .arpKeyDown:
            return false
        }
    }

    @inline(__always)
    private func tryPushRing(_ command: AudioCommand) -> Bool {
        let currentHead = head.load(ordering: .relaxed)
        let nextHead = (currentHead + 1) % capacity

        if nextHead == tail.load(ordering: .acquiring) {
            return false
        }

        buffer[currentHead] = command
        head.store(nextHead, ordering: .releasing)
        return true
    }

    @inline(__always)
    private func clampedMIDI(_ midiNote: Int) -> Int {
        max(0, min(127, midiNote))
    }

    @inline(__always)
    private func orNoteOffBit(_ n: Int) {
        if n < 64 {
            let mask = UInt64(1) << n
            while true {
                let current = pendingNoteOffLo.load(ordering: .relaxed)
                let (ok, _) = pendingNoteOffLo.compareExchange(
                    expected: current,
                    desired: current | mask,
                    ordering: .acquiringAndReleasing
                )
                if ok { return }
            }
        } else {
            let mask = UInt64(1) << (n - 64)
            while true {
                let current = pendingNoteOffHi.load(ordering: .relaxed)
                let (ok, _) = pendingNoteOffHi.compareExchange(
                    expected: current,
                    desired: current | mask,
                    ordering: .acquiringAndReleasing
                )
                if ok { return }
            }
        }
    }

    @inline(__always)
    private func orArpKeyUpBit(_ n: Int) {
        if n < 64 {
            let mask = UInt64(1) << n
            while true {
                let current = pendingArpKeyUpLo.load(ordering: .relaxed)
                let (ok, _) = pendingArpKeyUpLo.compareExchange(
                    expected: current,
                    desired: current | mask,
                    ordering: .acquiringAndReleasing
                )
                if ok { return }
            }
        } else {
            let mask = UInt64(1) << (n - 64)
            while true {
                let current = pendingArpKeyUpHi.load(ordering: .relaxed)
                let (ok, _) = pendingArpKeyUpHi.compareExchange(
                    expected: current,
                    desired: current | mask,
                    ordering: .acquiringAndReleasing
                )
                if ok { return }
            }
        }
    }

    /// Pop one ring command (audio consumer thread only). Side-channel is drained via `drain`.
    @inline(__always)
    func pop() -> AudioCommand? {
        let currentTail = tail.load(ordering: .relaxed)

        if currentTail == head.load(ordering: .acquiring) {
            return nil
        }

        let command = buffer[currentTail]
        buffer[currentTail] = nil

        let nextTail = (currentTail + 1) % capacity
        tail.store(nextTail, ordering: .releasing)

        return command
    }

    /// Drain ring + critical side-channel (audio consumer thread only).
    /// Order: pending clearAll first, then ring FIFO, then pending noteOff / arpKeyUp bits.
    /// On clearAll (side-channel or ring), remaining ring commands are discarded
    /// (tail advanced to head) so pre-clear noteOn/arpKeyDown cannot recreate voices.
    @inline(__always)
    func drain(limit: Int = 64, body: (AudioCommand) -> Void) {
        var count = 0
        var didClearAll = false

        if pendingClearAll.exchange(false, ordering: .acquiringAndReleasing) {
            body(.clearAll)
            count += 1
            didClearAll = true
            clearCriticalSideChannelBits()
            discardRingContents()
        }

        if !didClearAll {
            while count < limit, let command = pop() {
                if case .clearAll = command {
                    body(.clearAll)
                    count += 1
                    didClearAll = true
                    clearCriticalSideChannelBits()
                    // Drop any commands still queued after panic clear
                    discardRingContents()
                    break
                }
                body(command)
                count += 1
            }
        }

        // Offs after a clear are redundant; only emit if we did not panic-clear.
        if !didClearAll && count < limit {
            let bitsLo = pendingNoteOffLo.exchange(0, ordering: .acquiringAndReleasing)
            let bitsHi = pendingNoteOffHi.exchange(0, ordering: .acquiringAndReleasing)
            count = emitBits(
                bitsLo: bitsLo,
                bitsHi: bitsHi,
                limit: limit,
                count: count,
                body: body,
                make: { AudioCommand.noteOff(midiNote: $0) },
                restoreLo: { [self] rem in self.orNoteOffBitRangeLo(rem) },
                restoreHi: { [self] rem in self.orNoteOffBitRangeHi(rem) }
            )
        }

        if !didClearAll && count < limit {
            let bitsLo = pendingArpKeyUpLo.exchange(0, ordering: .acquiringAndReleasing)
            let bitsHi = pendingArpKeyUpHi.exchange(0, ordering: .acquiringAndReleasing)
            _ = emitBits(
                bitsLo: bitsLo,
                bitsHi: bitsHi,
                limit: limit,
                count: count,
                body: body,
                make: { AudioCommand.arpKeyUp(midiNote: $0) },
                restoreLo: { [self] rem in self.orArpKeyUpBitRangeLo(rem) },
                restoreHi: { [self] rem in self.orArpKeyUpBitRangeHi(rem) }
            )
        }
    }

    /// Consumer-only: advance tail to head, discarding unread ring slots.
    @inline(__always)
    private func discardRingContents() {
        var currentTail = tail.load(ordering: .relaxed)
        let currentHead = head.load(ordering: .acquiring)
        while currentTail != currentHead {
            buffer[currentTail] = nil
            currentTail = (currentTail + 1) % capacity
        }
        tail.store(currentHead, ordering: .releasing)
    }

    @inline(__always)
    private func clearCriticalSideChannelBits() {
        pendingNoteOffLo.store(0, ordering: .relaxed)
        pendingNoteOffHi.store(0, ordering: .relaxed)
        pendingArpKeyUpLo.store(0, ordering: .relaxed)
        pendingArpKeyUpHi.store(0, ordering: .relaxed)
    }

    private func orNoteOffBitRangeLo(_ value: UInt64) {
        guard value != 0 else { return }
        while true {
            let current = pendingNoteOffLo.load(ordering: .relaxed)
            let (ok, _) = pendingNoteOffLo.compareExchange(
                expected: current,
                desired: current | value,
                ordering: .acquiringAndReleasing
            )
            if ok { return }
        }
    }

    private func orNoteOffBitRangeHi(_ value: UInt64) {
        guard value != 0 else { return }
        while true {
            let current = pendingNoteOffHi.load(ordering: .relaxed)
            let (ok, _) = pendingNoteOffHi.compareExchange(
                expected: current,
                desired: current | value,
                ordering: .acquiringAndReleasing
            )
            if ok { return }
        }
    }

    private func orArpKeyUpBitRangeLo(_ value: UInt64) {
        guard value != 0 else { return }
        while true {
            let current = pendingArpKeyUpLo.load(ordering: .relaxed)
            let (ok, _) = pendingArpKeyUpLo.compareExchange(
                expected: current,
                desired: current | value,
                ordering: .acquiringAndReleasing
            )
            if ok { return }
        }
    }

    private func orArpKeyUpBitRangeHi(_ value: UInt64) {
        guard value != 0 else { return }
        while true {
            let current = pendingArpKeyUpHi.load(ordering: .relaxed)
            let (ok, _) = pendingArpKeyUpHi.compareExchange(
                expected: current,
                desired: current | value,
                ordering: .acquiringAndReleasing
            )
            if ok { return }
        }
    }

    private func emitBits(
        bitsLo bitsLoIn: UInt64,
        bitsHi bitsHiIn: UInt64,
        limit: Int,
        count: Int,
        body: (AudioCommand) -> Void,
        make: (Int) -> AudioCommand,
        restoreLo: (UInt64) -> Void,
        restoreHi: (UInt64) -> Void
    ) -> Int {
        var emitted = count
        var bitsLo = bitsLoIn
        var bitsHi = bitsHiIn

        var note = 0
        while bitsLo != 0 && emitted < limit {
            if (bitsLo & 1) != 0 {
                body(make(note))
                emitted += 1
            }
            bitsLo >>= 1
            note += 1
        }
        if bitsLo != 0 {
            restoreLo(bitsLo << note)
        }

        note = 64
        while bitsHi != 0 && emitted < limit {
            if (bitsHi & 1) != 0 {
                body(make(note))
                emitted += 1
            }
            bitsHi >>= 1
            note += 1
        }
        if bitsHi != 0 {
            restoreHi(bitsHi << (note - 64))
        }

        return emitted
    }

    /// True when ring is empty AND no critical side-channel work is pending.
    var isEmpty: Bool {
        let ringEmpty = tail.load(ordering: .acquiring) == head.load(ordering: .acquiring)
        guard ringEmpty else { return false }
        if pendingClearAll.load(ordering: .acquiring) { return false }
        if pendingNoteOffLo.load(ordering: .acquiring) != 0 { return false }
        if pendingNoteOffHi.load(ordering: .acquiring) != 0 { return false }
        if pendingArpKeyUpLo.load(ordering: .acquiring) != 0 { return false }
        if pendingArpKeyUpHi.load(ordering: .acquiring) != 0 { return false }
        return true
    }

    /// Approximate ring occupancy (side-channel not included).
    var count: Int {
        let h = head.load(ordering: .relaxed)
        let t = tail.load(ordering: .relaxed)
        return (h - t + capacity) % capacity
    }

    /// Test helper: whether a noteOff is parked on the critical side-channel.
    func hasPendingNoteOffForTesting(_ midiNote: Int) -> Bool {
        let n = clampedMIDI(midiNote)
        if n < 64 {
            return (pendingNoteOffLo.load(ordering: .acquiring) & (UInt64(1) << n)) != 0
        }
        return (pendingNoteOffHi.load(ordering: .acquiring) & (UInt64(1) << (n - 64))) != 0
    }

    /// Test helper: clearAll side-channel flag.
    var hasPendingClearAllForTesting: Bool {
        pendingClearAll.load(ordering: .acquiring)
    }
}
