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
    /// Even epoch: the slot holds a finished frame. Odd: the writer is filling it.
    private let slotEpoch: UnsafeMutablePointer<Atomic<UInt32>>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(3)

    public init(bufferSize: Int = defaultScopeBufferSize) {
        self.scopeBufferSize = bufferSize
        let total = ringSlotCount * bufferSize
        rawStorage = .allocate(capacity: total)
        rawStorage.initialize(repeating: 0.0, count: total)
        slotEpoch = .allocate(capacity: ringSlotCount)
        for i in 0..<ringSlotCount {
            (slotEpoch + i).initialize(to: Atomic<UInt32>(0))
        }
        writeIndex.store(0, ordering: .relaxed)
        readIndex.store(ringSlotCount - 1, ordering: .relaxed)
    }

    deinit {
        let total = ringSlotCount * scopeBufferSize
        rawStorage.deinitialize(count: total)
        rawStorage.deallocate()
        slotEpoch.deinitialize(count: ringSlotCount)
        slotEpoch.deallocate()
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
        // A short copy would leave a stale tail and publish a torn frame.
        guard data.count >= scopeBufferSize, let base = data.baseAddress else { return }

        let currentWrite = writeIndex.load(ordering: .relaxed)
        let nextWrite = (currentWrite + 1) % ringSlotCount

        // Don't overwrite the buffer currently being read
        let currentRead = readIndex.load(ordering: .acquiring)
        if nextWrite == currentRead {
            return // Drop this frame (render does not wait)
        }

        let epochPtr = slotEpoch + currentWrite
        let epoch = epochPtr.pointee.load(ordering: .relaxed)
        epochPtr.pointee.store(epoch &+ 1, ordering: .releasing)

        let dest = rawStorage + currentWrite * scopeBufferSize
        dest.update(from: base, count: scopeBufferSize)

        epochPtr.pointee.store(epoch &+ 2, ordering: .releasing)
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
        for _ in 0..<4 {
            let latestWrite = (writeIndex.load(ordering: .acquiring) + ringSlotCount - 1) % ringSlotCount
            let e1 = (slotEpoch + latestWrite).pointee.load(ordering: .acquiring)
            if e1 & 1 == 1 { continue }
            readIndex.store(latestWrite, ordering: .releasing)
            let src = rawStorage + latestWrite * scopeBufferSize
            let frame = Array(UnsafeBufferPointer(start: src, count: scopeBufferSize))
            let e2 = (slotEpoch + latestWrite).pointee.load(ordering: .acquiring)
            if e1 == e2 { return frame }
        }
        return Array(repeating: 0, count: scopeBufferSize)
    }
}
