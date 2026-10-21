//
//  CCCoalescer.swift
//  Synt_swiftUI
//
//  CoreMIDI thread → main, for the *display* side of CC (preset fields the UI
//  shows, Apple AU effects). The DSP side goes through `midiQueue` only.
//  Latest value per CC lives in atomics; at most one main hop is outstanding,
//  so an encoder sweep publishes `preset` once per hop instead of per tick.
//

import Foundation
import SynthCore
import Synchronization

final class CCCoalescer: @unchecked Sendable {
    /// 128 CC values, 8 per word (one byte each).
    private let values: UnsafeMutablePointer<Atomic<UInt64>>
    private let dirtyLo = Atomic<UInt64>(0)
    private let dirtyHi = Atomic<UInt64>(0)
    private let scheduled = Atomic<Bool>(false)

    init() {
        values = .allocate(capacity: 16)
        for i in 0..<16 { (values + i).initialize(to: Atomic<UInt64>(0)) }
    }

    deinit {
        values.deinitialize(count: 16)
        values.deallocate()
    }

    /// CoreMIDI thread: record the value. Returns true when the caller should
    /// schedule a main-thread drain (none is outstanding yet).
    func post(cc: UInt8, value: UInt8) -> Bool {
        let n = Int(cc & 127)
        let shift = UInt64((n & 7) * 8)
        let mask = UInt64(0xFF) << shift
        let word = values + (n >> 3)
        while true {
            let old = word.pointee.load(ordering: .relaxed)
            let new = (old & ~mask) | (UInt64(value & 127) << shift)
            if word.pointee.compareExchange(expected: old, desired: new, ordering: .releasing).exchanged { break }
        }
        if n < 64 {
            dirtyLo.bitwiseOr(UInt64(1) << n, ordering: .releasing)
        } else {
            dirtyHi.bitwiseOr(UInt64(1) << (n - 64), ordering: .releasing)
        }
        return !scheduled.exchange(true, ordering: .acquiringAndReleasing)
    }

    /// Main thread: latest value of every CC that moved since the last drain.
    func drain() -> [(cc: UInt8, value: UInt8)] {
        scheduled.store(false, ordering: .releasing)
        let lo = dirtyLo.exchange(0, ordering: .acquiringAndReleasing)
        let hi = dirtyHi.exchange(0, ordering: .acquiringAndReleasing)
        guard lo != 0 || hi != 0 else { return [] }
        var out: [(cc: UInt8, value: UInt8)] = []
        for n in 0..<128 {
            let bit = n < 64 ? (lo >> UInt64(n)) & 1 : (hi >> UInt64(n - 64)) & 1
            guard bit != 0 else { continue }
            let word = (values + (n >> 3)).pointee.load(ordering: .acquiring)
            out.append((UInt8(n), UInt8((word >> UInt64((n & 7) * 8)) & 0x7F)))
        }
        return out
    }
}
