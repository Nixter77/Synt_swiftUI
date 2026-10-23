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

public enum AudioCommand: Equatable {
    case noteOn(midiNote: Int, velocity: Float)
    case noteOff(midiNote: Int)
    case clearAll
    case arpKeyDown(midiNote: Int)
    case arpKeyUp(midiNote: Int)
    /// -1…1, center 0. Full throw is `pitchBendRange` semitones.
    case setPitchBend(Float)
    /// 0…1. Adds LFO depth on top of the preset. 0 leaves the preset alone.
    case setModWheel(Float)
    case setSustain(Bool)
    /// MIDI key. The audio thread routes it to the arp or a voice (it owns arp mode).
    case keyDown(midiNote: Int, velocity: Float)
    /// MIDI key up. Goes to the arp if the arp holds the key, otherwise note off.
    case keyUp(midiNote: Int)
    /// New patch: zero the render-owned DSP state (filters, chorus, drive, EQ,
    /// phaser, LFO, smoothers). Apple Delay/Reverb are reset on main via the AU API.
    case resetPatchState
    /// MIDI CC123: a note-off for every key (arp keys dropped). With the pedal
    /// down, voices stay pedal-held until it lifts. Unlike `clearAll` it keeps
    /// tails, filters, bend and LFO.
    case allNotesOff
    /// SYNT_18 R15-8: drop every controller MPE override on render (back to the user's settings).
    case clearMPEControllerOverrides
    /// MIDI Control Change 0…127 (controller, value 0…127)
    case controlChange(cc: UInt8, value: UInt8)
    /// Aftertouch (Channel Pressure 0…1)
    case setAftertouch(Float)
    /// Polyphonic Aftertouch (Key Pressure 0…1)
    case setPolyAftertouch(midiNote: Int, pressure: Float)
    /// MIDI timing clock, 24 per quarter note. Not critical: a full ring drops one tick.
    case midiClock
    /// MIDI 0xFA. Critical so a full ring cannot lose the downbeat.
    case midiStart
    /// MIDI 0xFB.
    case midiContinue
    /// MIDI 0xFC.
    case midiStop
    /// Host or UI parameter. The producer is never the audio thread.
    case setAddressedParameter(id: UInt64, value: Float)
    /// Reordered FX chain applied lock-free at buffer boundary.
    case setFXOrder(table: FXOrderTable)
    /// MPE (MIDI Polyphonic Expression) commands
    case mpeKeyDown(midiNote: Int, velocity: Float, channel: UInt8)
    case mpeKeyUp(midiNote: Int, channel: UInt8)
    case mpePitchBend(channel: UInt8, value: Float)
    case mpePressure(channel: UInt8, value: Float)
    case mpeTimbre(channel: UInt8, value: Float)
    case mpeControlChange(channel: UInt8, cc: UInt8, value: UInt8)

    public var isCritical: Bool {
        switch self {
        case .noteOff, .clearAll, .arpKeyUp, .setSustain, .keyUp, .resetPatchState, .allNotesOff,
             .midiStart, .midiContinue, .midiStop, .mpeKeyUp:
            return true
        case .noteOn, .arpKeyDown, .setPitchBend, .setModWheel, .keyDown, .controlChange, .setAftertouch, .setPolyAftertouch,
             .midiClock, .setAddressedParameter, .setFXOrder,
             .mpeKeyDown, .mpePitchBend, .mpePressure, .mpeTimbre, .mpeControlChange, .clearMPEControllerOverrides:
            return false
        }
    }
}

public final class AudioCommandQueue: @unchecked Sendable {
    private let capacity: Int
    /// Raw slots: producer writes `buffer[head]`, consumer reads `buffer[tail]`.
    /// A Swift array here would run uniqueness / exclusivity checks on both
    /// threads (and is a formal data race on the array storage).
    /// `AudioCommand` is a trivial enum, so slots need no deinit or `nil`.
    private let buffer: UnsafeMutablePointer<AudioCommand>

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
    /// 0 = none, 1 = pedal up, 2 = pedal down. Latest wins when the ring is full.
    private let pendingSustain = Atomic<Int8>(0)
    private let pendingResetPatch = Atomic<Bool>(false)
    /// 0 = none, 1 = start, 2 = continue, 3 = stop. Latest wins when the ring is full.
    private let pendingMIDITransport = Atomic<Int8>(0)

    // Per-channel MPE note-off side channel (16 channels x 128 notes)
    private let pendingMpeKeyUpLo: UnsafeMutablePointer<Atomic<UInt64>>
    private let pendingMpeKeyUpHi: UnsafeMutablePointer<Atomic<UInt64>>

    public init(capacity: Int = 256) {
        self.capacity = max(2, capacity)
        self.buffer = UnsafeMutablePointer<AudioCommand>.allocate(capacity: self.capacity)
        self.buffer.initialize(repeating: .clearAll, count: self.capacity)
        self.pendingMpeKeyUpLo = UnsafeMutablePointer<Atomic<UInt64>>.allocate(capacity: 16)
        self.pendingMpeKeyUpHi = UnsafeMutablePointer<Atomic<UInt64>>.allocate(capacity: 16)
        for i in 0..<16 {
            (self.pendingMpeKeyUpLo + i).initialize(to: Atomic<UInt64>(0))
            (self.pendingMpeKeyUpHi + i).initialize(to: Atomic<UInt64>(0))
        }
    }

    deinit {
        for i in 0..<16 {
            (pendingMpeKeyUpLo + i).deinitialize(count: 1)
            (pendingMpeKeyUpHi + i).deinitialize(count: 1)
        }
        pendingMpeKeyUpLo.deallocate()
        pendingMpeKeyUpHi.deallocate()
        buffer.deinitialize(count: capacity)
        buffer.deallocate()
    }

    /// Push a command (UI / non-audio producer thread only).
    /// Returns true if accepted into the ring or critical side-channel.
    /// Non-critical commands return false when the ring is full.
    @inline(__always)
    public func push(_ command: AudioCommand) -> Bool {
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
        case .setSustain(let down):
            pendingSustain.store(down ? 2 : 1, ordering: .releasing)
            return true
        case .resetPatchState:
            pendingResetPatch.store(true, ordering: .releasing)
            return true
        case .keyUp(let midiNote):
            // Route is unknown here. Park both; each is a no-op if that side is idle.
            orNoteOffBit(clampedMIDI(midiNote))
            orArpKeyUpBit(clampedMIDI(midiNote))
            return true
        case .allNotesOff:
            // Ring full: park an off for every key on both routes.
            orNoteOffBitRangeLo(.max)
            orNoteOffBitRangeHi(.max)
            orArpKeyUpBitRangeLo(.max)
            orArpKeyUpBitRangeHi(.max)
            return true
        case .midiStart:
            pendingMIDITransport.store(1, ordering: .releasing)
            return true
        case .midiContinue:
            pendingMIDITransport.store(2, ordering: .releasing)
            return true
        case .midiStop:
            pendingMIDITransport.store(3, ordering: .releasing)
            return true
        case .mpeKeyUp(let midiNote, let channel):
            orMpeKeyUpBit(clampedMIDI(midiNote), channel: Int(channel & 15))
            return true
        case .noteOn, .arpKeyDown, .setPitchBend, .setModWheel, .keyDown, .controlChange, .setAftertouch, .setPolyAftertouch,
             .midiClock, .setAddressedParameter, .setFXOrder,
             .mpeKeyDown, .mpePitchBend, .mpePressure, .mpeTimbre, .mpeControlChange, .clearMPEControllerOverrides:
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

    @inline(__always)
    private func orMpeKeyUpBit(_ n: Int, channel: Int) {
        let ch = channel & 15
        if n < 64 {
            let mask = UInt64(1) << n
            let ptr = pendingMpeKeyUpLo + ch
            while true {
                let current = ptr.pointee.load(ordering: .relaxed)
                let (ok, _) = ptr.pointee.compareExchange(
                    expected: current,
                    desired: current | mask,
                    ordering: .acquiringAndReleasing
                )
                if ok { return }
            }
        } else {
            let mask = UInt64(1) << (n - 64)
            let ptr = pendingMpeKeyUpHi + ch
            while true {
                let current = ptr.pointee.load(ordering: .relaxed)
                let (ok, _) = ptr.pointee.compareExchange(
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
    public func pop() -> AudioCommand? {
        let currentTail = tail.load(ordering: .relaxed)

        if currentTail == head.load(ordering: .acquiring) {
            return nil
        }

        let command = buffer[currentTail]

        let nextTail = (currentTail + 1) % capacity
        tail.store(nextTail, ordering: .releasing)

        return command
    }

    /// Drain ring + critical side-channel (audio consumer thread only).
    /// Order: pending clearAll first, then ring FIFO, then pending noteOff / arpKeyUp bits.
    /// On clearAll (side-channel or ring), remaining ring commands are discarded
    /// (tail advanced to head) so pre-clear noteOn/arpKeyDown cannot recreate voices.
    @inline(__always)
    public func drain(limit: Int = 64, body: (AudioCommand) -> Void) {
        var count = 0
        var didClearAll = false

        if pendingClearAll.exchange(false, ordering: .acquiringAndReleasing) {
            body(.clearAll)
            count += 1
            didClearAll = true
            clearCriticalSideChannelBits()
            discardRingContents()
        }
        // Parked only when the ring was full; it always follows its clearAll.
        if pendingResetPatch.exchange(false, ordering: .acquiringAndReleasing) {
            body(.resetPatchState)
            count += 1
        }

        if !didClearAll {
            while count < limit, let command = pop() {
                if case .clearAll = command {
                    body(.clearAll)
                    count += 1
                    clearCriticalSideChannelBits()
                    // Keep commands pushed *after* this clearAll (new notes after a preset change).
                    continue
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
            let transport = pendingMIDITransport.exchange(0, ordering: .acquiringAndReleasing)
            switch transport {
            case 1: body(.midiStart); count += 1
            case 2: body(.midiContinue); count += 1
            case 3: body(.midiStop); count += 1
            default: break
            }
        }

        if !didClearAll && count < limit {
            let sustainCode = pendingSustain.exchange(0, ordering: .acquiringAndReleasing)
            if sustainCode != 0 {
                body(.setSustain(sustainCode == 2))
                count += 1
            }
        }

        if !didClearAll && count < limit {
            let bitsLo = pendingArpKeyUpLo.exchange(0, ordering: .acquiringAndReleasing)
            let bitsHi = pendingArpKeyUpHi.exchange(0, ordering: .acquiringAndReleasing)
            count = emitBits(
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

        if !didClearAll && count < limit {
            for ch in 0..<16 {
                guard count < limit else { break }
                let bitsLo = (pendingMpeKeyUpLo + ch).pointee.exchange(0, ordering: .acquiringAndReleasing)
                let bitsHi = (pendingMpeKeyUpHi + ch).pointee.exchange(0, ordering: .acquiringAndReleasing)
                if bitsLo == 0 && bitsHi == 0 { continue }
                count = emitBits(
                    bitsLo: bitsLo,
                    bitsHi: bitsHi,
                    limit: limit,
                    count: count,
                    body: body,
                    make: { AudioCommand.mpeKeyUp(midiNote: $0, channel: UInt8(ch)) },
                    restoreLo: { [self] rem in self.orMpeKeyUpBitRangeLo(rem, channel: ch) },
                    restoreHi: { [self] rem in self.orMpeKeyUpBitRangeHi(rem, channel: ch) }
                )
            }
        }
    }

    /// Consumer-only: drop every unread ring command and parked side-channel bit
    /// (a reset releases everything right after, so dropped offs are redundant).
    public func discardPendingRT() {
        discardRingContents()
        clearCriticalSideChannelBits()
        pendingSustain.store(0, ordering: .relaxed)
        pendingMIDITransport.store(0, ordering: .relaxed)
    }

    /// Consumer-only: advance tail to head, discarding unread ring slots.
    @inline(__always)
    private func discardRingContents() {
        let currentHead = head.load(ordering: .acquiring)
        tail.store(currentHead, ordering: .releasing)
    }

    @inline(__always)
    private func clearCriticalSideChannelBits() {
        pendingNoteOffLo.store(0, ordering: .relaxed)
        pendingNoteOffHi.store(0, ordering: .relaxed)
        pendingArpKeyUpLo.store(0, ordering: .relaxed)
        pendingArpKeyUpHi.store(0, ordering: .relaxed)
        pendingMIDITransport.store(0, ordering: .relaxed)
        for i in 0..<16 {
            (pendingMpeKeyUpLo + i).pointee.store(0, ordering: .relaxed)
            (pendingMpeKeyUpHi + i).pointee.store(0, ordering: .relaxed)
        }
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

    private func orMpeKeyUpBitRangeLo(_ value: UInt64, channel: Int) {
        guard value != 0 else { return }
        let ptr = pendingMpeKeyUpLo + (channel & 15)
        while true {
            let current = ptr.pointee.load(ordering: .relaxed)
            let (ok, _) = ptr.pointee.compareExchange(
                expected: current,
                desired: current | value,
                ordering: .acquiringAndReleasing
            )
            if ok { return }
        }
    }

    private func orMpeKeyUpBitRangeHi(_ value: UInt64, channel: Int) {
        guard value != 0 else { return }
        let ptr = pendingMpeKeyUpHi + (channel & 15)
        while true {
            let current = ptr.pointee.load(ordering: .relaxed)
            let (ok, _) = ptr.pointee.compareExchange(
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
    public var isEmpty: Bool {
        let ringEmpty = tail.load(ordering: .acquiring) == head.load(ordering: .acquiring)
        guard ringEmpty else { return false }
        if pendingClearAll.load(ordering: .acquiring) { return false }
        if pendingResetPatch.load(ordering: .acquiring) { return false }
        if pendingNoteOffLo.load(ordering: .acquiring) != 0 { return false }
        if pendingNoteOffHi.load(ordering: .acquiring) != 0 { return false }
        if pendingArpKeyUpLo.load(ordering: .acquiring) != 0 { return false }
        if pendingArpKeyUpHi.load(ordering: .acquiring) != 0 { return false }
        for i in 0..<16 {
            if (pendingMpeKeyUpLo + i).pointee.load(ordering: .acquiring) != 0 { return false }
            if (pendingMpeKeyUpHi + i).pointee.load(ordering: .acquiring) != 0 { return false }
        }
        return true
    }

    /// Approximate ring occupancy (side-channel not included).
    public var count: Int {
        let h = head.load(ordering: .relaxed)
        let t = tail.load(ordering: .relaxed)
        return (h - t + capacity) % capacity
    }

    /// Test helper: whether a noteOff is parked on the critical side-channel.
    public func hasPendingNoteOffForTesting(_ midiNote: Int) -> Bool {
        let n = clampedMIDI(midiNote)
        if n < 64 {
            return (pendingNoteOffLo.load(ordering: .acquiring) & (UInt64(1) << n)) != 0
        }
        return (pendingNoteOffHi.load(ordering: .acquiring) & (UInt64(1) << (n - 64))) != 0
    }

    /// Test helper: whether an mpeKeyUp is parked on the critical side-channel.
    public func hasPendingMpeKeyUpForTesting(_ midiNote: Int, channel: UInt8) -> Bool {
        let n = clampedMIDI(midiNote)
        let ch = Int(channel & 15)
        if n < 64 {
            return ((pendingMpeKeyUpLo + ch).pointee.load(ordering: .acquiring) & (UInt64(1) << n)) != 0
        }
        return ((pendingMpeKeyUpHi + ch).pointee.load(ordering: .acquiring) & (UInt64(1) << (n - 64))) != 0
    }

    /// Test helper: clearAll side-channel flag.
    public var hasPendingClearAllForTesting: Bool {
        pendingClearAll.load(ordering: .acquiring)
    }
}
