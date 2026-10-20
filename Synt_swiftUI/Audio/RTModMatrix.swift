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

struct RTModSlot {
    var source: ModSource
    var destination: ModDestination
    var amount: Float
}

final class RTModMatrix: @unchecked Sendable {
    static let capacity = 16

    private let buffers: UnsafeMutablePointer<RTModSlot>
    private let countA = Atomic<Int>(0)
    private let countB = Atomic<Int>(0)
    private let active = Atomic<Int>(0)

    init() {
        buffers = .allocate(capacity: Self.capacity * 2)
        buffers.initialize(
            repeating: RTModSlot(source: .velocity, destination: .amp, amount: 0),
            count: Self.capacity * 2
        )
    }

    deinit {
        buffers.deinitialize(count: Self.capacity * 2)
        buffers.deallocate()
    }

    /// Main thread. Entries past `capacity` are dropped (UI never authors that many).
    func publish(_ entries: [ModMatrixEntry]) {
        let target = 1 - active.load(ordering: .acquiring)
        let base = buffers + target * Self.capacity
        let n = min(Self.capacity, entries.count)
        for i in 0..<n {
            base[i] = RTModSlot(
                source: entries[i].source,
                destination: entries[i].destination,
                amount: entries[i].amount
            )
        }
        if target == 0 {
            countA.store(n, ordering: .releasing)
        } else {
            countB.store(n, ordering: .releasing)
        }
        active.store(target, ordering: .releasing)
    }

    /// Render thread. Valid for the current sample.
    @inline(__always)
    func snapshot() -> (UnsafeMutablePointer<RTModSlot>, Int) {
        let idx = active.load(ordering: .acquiring)
        let n = idx == 0
            ? countA.load(ordering: .acquiring)
            : countB.load(ordering: .acquiring)
        return (buffers + idx * Self.capacity, n)
    }

    var publishedCount: Int { snapshot().1 }
}
