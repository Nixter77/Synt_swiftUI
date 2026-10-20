//
//  AddressedParameterStore.swift
//  SynthCore
//
//  One value per parameter address, readable and writable from any thread.
//  The Audio Unit's single source of truth for host-addressed parameters:
//  the tree observer writes here, the render drains dirty slots at the start
//  of each buffer, and fullState / the value provider read from here.
//

import Foundation
import Synchronization

public final class AddressedParameterStore: @unchecked Sendable {
    public static let capacity = 128
    private let bits: UnsafeMutablePointer<Atomic<UInt32>>
    private let dirtyLo = Atomic<UInt64>(0)
    private let dirtyHi = Atomic<UInt64>(0)

    public init() {
        bits = .allocate(capacity: Self.capacity)
        for i in 0..<Self.capacity { (bits + i).initialize(to: Atomic<UInt32>(0)) }
    }

    deinit {
        bits.deinitialize(count: Self.capacity)
        bits.deallocate()
    }

    /// Any thread. Stores the value and marks it for the render thread.
    public func set(_ address: UInt64, _ value: Float) {
        guard address < UInt64(Self.capacity) else { return }
        record(address, value)
        let bit = UInt64(1) << (address & 63)
        if address < 64 {
            dirtyLo.bitwiseOr(bit, ordering: .releasing)
        } else {
            dirtyHi.bitwiseOr(bit, ordering: .releasing)
        }
    }

    /// Any thread. Stores the value without asking the render to apply it
    /// (the render already did, e.g. a scheduled host event).
    public func record(_ address: UInt64, _ value: Float) {
        guard address < UInt64(Self.capacity) else { return }
        (bits + Int(address)).pointee.store(value.bitPattern, ordering: .releasing)
    }

    public func value(_ address: UInt64) -> Float {
        guard address < UInt64(Self.capacity) else { return 0 }
        return Float(bitPattern: (bits + Int(address)).pointee.load(ordering: .acquiring))
    }

    /// Render thread. Calls `body` for every slot written since the last drain.
    @inline(__always)
    public func drain(_ body: (UInt64, Float) -> Void) {
        var lo = dirtyLo.exchange(0, ordering: .acquiringAndReleasing)
        var hi = dirtyHi.exchange(0, ordering: .acquiringAndReleasing)
        while lo != 0 {
            let i = UInt64(lo.trailingZeroBitCount)
            lo &= lo - 1
            body(i, value(i))
        }
        while hi != 0 {
            let i = UInt64(hi.trailingZeroBitCount) + 64
            hi &= hi - 1
            body(i, value(i))
        }
    }
}
