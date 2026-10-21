//
//  AtomicKeyBits.swift
//  Synt_swiftUI
//
//  128 lock-free key bits. The CoreMIDI thread sets / clears them; main polls
//  them for the keyboard highlight. No allocation, no queue hop per note.
//

import Synchronization

public final class AtomicKeyBits: @unchecked Sendable {
    private let lo = Atomic<UInt64>(0)
    private let hi = Atomic<UInt64>(0)

    /// Any thread.
    public func insert(_ note: Int) {
        guard note >= 0, note < 128 else { return }
        if note < 64 {
            lo.bitwiseOr(UInt64(1) << note, ordering: .relaxed)
        } else {
            hi.bitwiseOr(UInt64(1) << (note - 64), ordering: .relaxed)
        }
    }

    /// Any thread.
    public func remove(_ note: Int) {
        guard note >= 0, note < 128 else { return }
        if note < 64 {
            lo.bitwiseAnd(~(UInt64(1) << note), ordering: .relaxed)
        } else {
            hi.bitwiseAnd(~(UInt64(1) << (note - 64)), ordering: .relaxed)
        }
    }

    /// Any thread.
    public func removeAll() {
        lo.store(0, ordering: .relaxed)
        hi.store(0, ordering: .relaxed)
    }

    /// Raw bits (lo = notes 0…63, hi = 64…127).
    public var bits: (lo: UInt64, hi: UInt64) {
        (lo.load(ordering: .relaxed), hi.load(ordering: .relaxed))
    }

    public static func notes(lo: UInt64, hi: UInt64) -> Set<Int> {
        var out = Set<Int>()
        for i in 0..<64 {
            if lo & (UInt64(1) << i) != 0 { out.insert(i) }
            if hi & (UInt64(1) << i) != 0 { out.insert(i + 64) }
        }
        return out
    }
}
