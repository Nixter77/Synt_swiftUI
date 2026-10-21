//
//  AtomicMeteringState.swift
//  Synt_swiftUI
//
//  Lock-free metering state using atomics.
//  Audio thread writes, UI thread reads via polling.
//

import Foundation
import Synchronization

public final class AtomicMeteringState: @unchecked Sendable {
    // Atomic storage for levels (stored as UInt32 bit patterns for atomic ops)
    private let outputLevelBits = Atomic<UInt32>(0)
    private let peakLevelBits = Atomic<UInt32>(0)

    // Lock-free ring buffer for scope / spectrum output data
    public static let defaultScopeBufferSize = 512
    private let scopeBufferSize: Int
    private let ringSlotCount: Int = 4
    private let rawStorage: UnsafeMutablePointer<Float>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(3)

    public init(bufferSize: Int = defaultScopeBufferSize) {
        self.scopeBufferSize = bufferSize
        let total = ringSlotCount * bufferSize
        rawStorage = .allocate(capacity: total)
        rawStorage.initialize(repeating: 0.0, count: total)
        writeIndex.store(0, ordering: .relaxed)
        readIndex.store(ringSlotCount - 1, ordering: .relaxed)
    }

    deinit {
        let total = ringSlotCount * scopeBufferSize
        rawStorage.deinitialize(count: total)
        rawStorage.deallocate()
    }

    // MARK: - Audio Thread (Writer)

    @inline(__always)
    public func setOutputLevel(_ value: Float) {
        outputLevelBits.store(value.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func setPeakLevel(_ value: Float) {
        peakLevelBits.store(value.bitPattern, ordering: .relaxed)
    }

    public func writeScopeBuffer(_ data: UnsafeBufferPointer<Float>) {
        let currentWrite = writeIndex.load(ordering: .relaxed)
        let nextWrite = (currentWrite + 1) % ringSlotCount

        // Don't overwrite the buffer currently being read
        let currentRead = readIndex.load(ordering: .acquiring)
        if nextWrite == currentRead {
            return // Drop this frame (render does not wait)
        }

        // Copy data to write buffer (raw memory copy, zero allocations / zero locks)
        let dest = rawStorage + currentWrite * scopeBufferSize
        let count = min(data.count, scopeBufferSize)
        if let base = data.baseAddress {
            dest.update(from: base, count: count)
        }

        // Publish the new buffer
        writeIndex.store(nextWrite, ordering: .releasing)
    }

    public func writeScopeBuffer(_ data: [Float]) {
        data.withUnsafeBufferPointer { buffer in
            writeScopeBuffer(buffer)
        }
    }

    // MARK: - UI Thread (Reader)

    @inline(__always)
    public func getOutputLevel() -> Float {
        Float(bitPattern: outputLevelBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getPeakLevel() -> Float {
        Float(bitPattern: peakLevelBits.load(ordering: .relaxed))
    }

    public func readScopeBuffer() -> [Float] {
        // Find the latest completed buffer
        let latestWrite = (writeIndex.load(ordering: .acquiring) + ringSlotCount - 1) % ringSlotCount

        // Update read index
        readIndex.store(latestWrite, ordering: .releasing)

        let src = rawStorage + latestWrite * scopeBufferSize
        return Array(UnsafeBufferPointer(start: src, count: scopeBufferSize))
    }
}
