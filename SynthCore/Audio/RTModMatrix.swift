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

/// SYNT_26 P1-2: triple buffer. Each bank holds its slots, count and curve tables, so render
/// never sees a bank a writer is filling. Writers (main or a host thread) are serialized by
/// `writerLock`, which render never takes. Render owns `readBank` and swaps only in `snapshot()`.
public final class RTModMatrix: @unchecked Sendable {
    public static let capacity = 16
    public static let tableSize = 256
    static let bankCount = 3
    private static let hasNewDataFlag = 0x80

    private let buffers: UnsafeMutablePointer<RTModSlot>
    private let tables: UnsafeMutablePointer<Float>
    private let counts: UnsafeMutablePointer<Int>
    private let sharedBank = Atomic<Int>(2)
    private let writerLock = Mutex(())
    /// Writer-owned (under `writerLock`).
    private var writeBank = 0
    private let lastPublishedCount = Atomic<Int>(0)
    /// Render-owned.
    private var readBank = 1

    public init() {
        buffers = .allocate(capacity: Self.capacity * Self.bankCount)
        buffers.initialize(
            repeating: RTModSlot(source: .velocity, destination: .amp, amount: 0),
            count: Self.capacity * Self.bankCount
        )
        let tableCount = Self.bankCount * Self.capacity * Self.tableSize
        tables = .allocate(capacity: tableCount)
        tables.initialize(repeating: 0, count: tableCount)
        counts = .allocate(capacity: Self.bankCount)
        counts.initialize(repeating: 0, count: Self.bankCount)
    }

    deinit {
        buffers.deinitialize(count: Self.capacity * Self.bankCount)
        buffers.deallocate()
        tables.deinitialize(count: Self.bankCount * Self.capacity * Self.tableSize)
        tables.deallocate()
        counts.deinitialize(count: Self.bankCount)
        counts.deallocate()
    }

    /// Any non-render thread. Fills the writer's bank (slots + tables), then shares it.
    public func publish(_ entries: [ModMatrixEntry]) {
        writerLock.withLock { _ in
            let bank = writeBank
            let base = buffers + bank * Self.capacity
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
                    tableBank: bank
                )
            }
            counts[bank] = n
            lastPublishedCount.store(n, ordering: .relaxed)
            let previous = sharedBank.exchange(bank | Self.hasNewDataFlag, ordering: .acquiringAndReleasing)
            writeBank = previous & 0x03
        }
    }

    /// Render thread. Linear rows do not call this.
    @inline(__always)
    public func lookup(bank: Int, slot: Int, source: Float) -> Float {
        let b = bank < 0 ? 0 : min(bank, Self.bankCount - 1)
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

    /// SYNT_27 P2-1: when true (the engine's matrix), `snapshot()` never swaps on its own;
    /// render adopts a new bank only through `pullRT()`, with the rest of the preset set.
    public var pullsAsPublicationSet = false

    /// Render thread: true when a publish is waiting.
    @inline(__always)
    public var hasPendingRT: Bool { (sharedBank.load(ordering: .acquiring) & Self.hasNewDataFlag) != 0 }

    /// Render thread: adopt the newest published bank, if any.
    @inline(__always)
    public func pullRT() {
        if (sharedBank.load(ordering: .acquiring) & Self.hasNewDataFlag) != 0 {
            let previous = sharedBank.exchange(readBank, ordering: .acquiringAndReleasing)
            readBank = previous & 0x03
        }
    }

    /// Render thread (single reader). Adopts the newest bank, if any. The returned slots (and
    /// their `tableBank`) stay valid until render's next call.
    @inline(__always)
    public func snapshot() -> (UnsafeMutablePointer<RTModSlot>, Int) {
        if !pullsAsPublicationSet { pullRT() }
        return (buffers + readBank * Self.capacity, counts[readBank])
    }

    /// Any thread: count of the latest publish (does not touch render's bank).
    public var publishedCount: Int { lastPublishedCount.load(ordering: .relaxed) }

    #if DEBUG
    var readBankForTesting: Int { readBank }
    var writeBankForTesting: Int { writerLock.withLock { _ in writeBank } }
    #endif
}
