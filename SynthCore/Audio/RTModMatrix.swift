//
//  RTModMatrix.swift
//  Synt_swiftUI
//
//  Fixed-capacity mod matrix the render thread can read without ARC.
//  Main writes the idle buffer, then flips an atomic index. No arrays,
//  no retain/release, no allocation on the audio side.
//

import Foundation
import Synchronization

public struct RTModSlot {
    public var source: ModSource
    public var destination: ModDestination
    public var amount: Float
    public var curve: ModCurve = .linear
    public var tableBank: Int = 0
}

public final class RTModMatrix: @unchecked Sendable {
    public static let capacity = 16
    public static let tableSize = 256

    private let buffers: UnsafeMutablePointer<RTModSlot>
    private let tables: UnsafeMutablePointer<Float>
    private let countA = Atomic<Int>(0)
    private let countB = Atomic<Int>(0)
    private let active = Atomic<Int>(0)
    private let tableBankActive = Atomic<Int>(0)

    public init() {
        buffers = .allocate(capacity: Self.capacity * 2)
        buffers.initialize(
            repeating: RTModSlot(source: .velocity, destination: .amp, amount: 0),
            count: Self.capacity * 2
        )
        let tableCount = 2 * Self.capacity * Self.tableSize
        tables = .allocate(capacity: tableCount)
        tables.initialize(repeating: 0, count: tableCount)
    }

    deinit {
        buffers.deinitialize(count: Self.capacity * 2)
        buffers.deallocate()
        tables.deinitialize(count: 2 * Self.capacity * Self.tableSize)
        tables.deallocate()
    }

    /// Main thread. Builds non-linear tables into the idle bank, then flips the slot buffer.
    public func publish(_ entries: [ModMatrixEntry]) {
        let target = 1 - active.load(ordering: .acquiring)
        let bank = 1 - tableBankActive.load(ordering: .acquiring)
        let base = buffers + target * Self.capacity
        let n = min(Self.capacity, entries.count)
        for i in 0..<n {
            let curve = entries[i].curve
            if curve != .linear {
                fillTable(bank: bank, slot: i, curve: curve)
            }
            base[i] = RTModSlot(
                source: entries[i].source,
                destination: entries[i].destination,
                amount: entries[i].amount,
                curve: curve,
                tableBank: curve == .linear ? 0 : bank
            )
        }
        if target == 0 {
            countA.store(n, ordering: .releasing)
        } else {
            countB.store(n, ordering: .releasing)
        }
        tableBankActive.store(bank, ordering: .releasing)
        active.store(target, ordering: .releasing)
    }

    /// Render thread. Linear rows do not call this.
    @inline(__always)
    public func lookup(bank: Int, slot: Int, source: Float) -> Float {
        let b = bank & 1
        let s = slot < 0 ? 0 : min(slot, Self.capacity - 1)
        var x = source
        if x < -1 { x = -1 }
        if x > 1 { x = 1 }
        let last = Float(Self.tableSize - 1)
        var scaled = (x + 1) * 0.5 * last
        if scaled < 0 { scaled = 0 }
        if scaled > last { scaled = last }
        let i0 = Int(scaled)
        let i1 = i0 >= Self.tableSize - 1 ? Self.tableSize - 1 : i0 + 1
        let frac = scaled - Float(i0)
        let base = (b * Self.capacity + s) * Self.tableSize
        let a = tables[base + i0]
        let c = tables[base + i1]
        return a + (c - a) * frac
    }

    private func fillTable(bank: Int, slot: Int, curve: ModCurve) {
        let base = (bank * Self.capacity + slot) * Self.tableSize
        let last = Float(Self.tableSize - 1)
        for i in 0..<Self.tableSize {
            let x = Float(i) / last * 2 - 1
            tables[base + i] = curve.remap(x)
        }
    }

    /// Render thread. Valid for the current sample.
    @inline(__always)
    public func snapshot() -> (UnsafeMutablePointer<RTModSlot>, Int) {
        let idx = active.load(ordering: .acquiring)
        let n = idx == 0
            ? countA.load(ordering: .acquiring)
            : countB.load(ordering: .acquiring)
        return (buffers + idx * Self.capacity, n)
    }

    public var publishedCount: Int { snapshot().1 }
}
