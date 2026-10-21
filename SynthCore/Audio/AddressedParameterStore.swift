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
    /// Covers every `SynthParameterAddress` (raw values reach 139). An address
    /// outside the store used to read back 0 and drop writes (auval failures).
    public static let capacity = 256
    private static let dirtyWords = capacity / 64
    private let bits: UnsafeMutablePointer<Atomic<UInt32>>
    private let dirty: UnsafeMutablePointer<Atomic<UInt64>>

    public init() {
        precondition(SynthParameterAddress.allCases.allSatisfy { $0.rawValue < UInt64(Self.capacity) },
                     "AddressedParameterStore.capacity must cover every parameter address")
        bits = .allocate(capacity: Self.capacity)
        for i in 0..<Self.capacity { (bits + i).initialize(to: Atomic<UInt32>(0)) }
        dirty = .allocate(capacity: Self.dirtyWords)
        for i in 0..<Self.dirtyWords { (dirty + i).initialize(to: Atomic<UInt64>(0)) }
    }

    deinit {
        bits.deinitialize(count: Self.capacity)
        bits.deallocate()
        dirty.deinitialize(count: Self.dirtyWords)
        dirty.deallocate()
    }

    /// Any thread. Stores the value and marks it for the render thread.
    public func set(_ address: UInt64, _ value: Float) {
        guard address < UInt64(Self.capacity) else { return }
        record(address, value)
        (dirty + Int(address >> 6)).pointee.bitwiseOr(UInt64(1) << (address & 63), ordering: .releasing)
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
        for w in 0..<Self.dirtyWords {
            var word = (dirty + w).pointee.exchange(0, ordering: .acquiringAndReleasing)
            while word != 0 {
                let i = UInt64(w * 64 + word.trailingZeroBitCount)
                word &= word - 1
                body(i, value(i))
            }
        }
    }
}
