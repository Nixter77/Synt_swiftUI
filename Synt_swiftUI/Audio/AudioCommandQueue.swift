//
//  AudioCommandQueue.swift
//  Synt_swiftUI
//
//  Lock-free Single-Producer Single-Consumer (SPSC) queue for audio commands.
//  UI thread pushes, Audio thread pops.
//

import Foundation
import Synchronization

enum AudioCommand {
    case noteOn(midiNote: Int, velocity: Float)
    case noteOff(midiNote: Int)
    case clearAll
    case arpKeyDown(midiNote: Int)
    case arpKeyUp(midiNote: Int)
}

final class AudioCommandQueue: @unchecked Sendable {
    private let capacity: Int
    private var buffer: [AudioCommand?]

    // Atomic indices for lock-free operation
    private let head = Atomic<Int>(0)  // Write position (producer)
    private let tail = Atomic<Int>(0)  // Read position (consumer)

    init(capacity: Int = 256) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }

    /// Push a command to the queue (UI thread)
    /// Returns true if successful, false if queue is full
    @inline(__always)
    func push(_ command: AudioCommand) -> Bool {
        let currentHead = head.load(ordering: .relaxed)
        let nextHead = (currentHead + 1) % capacity

        // Check if queue is full
        if nextHead == tail.load(ordering: .acquiring) {
            return false // Queue full
        }

        // Write command
        buffer[currentHead] = command

        // Publish the new head
        head.store(nextHead, ordering: .releasing)

        return true
    }

    /// Pop a command from the queue (Audio thread)
    /// Returns nil if queue is empty
    @inline(__always)
    func pop() -> AudioCommand? {
        let currentTail = tail.load(ordering: .relaxed)

        // Check if queue is empty
        if currentTail == head.load(ordering: .acquiring) {
            return nil // Queue empty
        }

        // Read command
        let command = buffer[currentTail]
        buffer[currentTail] = nil // Clear for safety

        // Advance tail
        let nextTail = (currentTail + 1) % capacity
        tail.store(nextTail, ordering: .releasing)

        return command
    }

    /// Check if queue is empty (safe to call from any thread)
    var isEmpty: Bool {
        tail.load(ordering: .acquiring) == head.load(ordering: .acquiring)
    }

    /// Approximate count (may be slightly off due to concurrent access)
    var count: Int {
        let h = head.load(ordering: .relaxed)
        let t = tail.load(ordering: .relaxed)
        return (h - t + capacity) % capacity
    }
}
