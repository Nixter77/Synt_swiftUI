//
//  AtomicMeteringState.swift
//  Synt_swiftUI
//
//  Lock-free metering state using atomics.
//  Audio thread writes, UI thread reads via polling.
//

import Foundation
import Synchronization

final class AtomicMeteringState: @unchecked Sendable {
    // Atomic storage for levels (stored as UInt32 bit patterns for atomic ops)
    private let outputLevelBits = Atomic<UInt32>(0)
    private let peakLevelBits = Atomic<UInt32>(0)

    // Triple buffer for scope data
    private let scopeBufferSize = 512
    private var scopeBuffers: [[Float]]
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(1)

    init() {
        scopeBuffers = [
            Array(repeating: 0.0, count: scopeBufferSize),
            Array(repeating: 0.0, count: scopeBufferSize),
            Array(repeating: 0.0, count: scopeBufferSize)
        ]
    }

    // MARK: - Audio Thread (Writer)

    @inline(__always)
    func setOutputLevel(_ value: Float) {
        outputLevelBits.store(value.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    func setPeakLevel(_ value: Float) {
        peakLevelBits.store(value.bitPattern, ordering: .relaxed)
    }

    func writeScopeBuffer(_ data: UnsafeBufferPointer<Float>) {
        let currentWrite = writeIndex.load(ordering: .relaxed)
        let nextWrite = (currentWrite + 1) % 3

        // Don't overwrite the buffer currently being read
        let currentRead = readIndex.load(ordering: .acquiring)
        if nextWrite == currentRead {
            return // Drop this frame
        }

        // Copy data to write buffer
        for i in 0..<min(data.count, scopeBufferSize) {
            scopeBuffers[currentWrite][i] = data[i]
        }

        // Publish the new buffer
        writeIndex.store(nextWrite, ordering: .releasing)
    }

    func writeScopeBuffer(_ data: [Float]) {
        data.withUnsafeBufferPointer { buffer in
            writeScopeBuffer(buffer)
        }
    }

    // MARK: - UI Thread (Reader)

    @inline(__always)
    func getOutputLevel() -> Float {
        Float(bitPattern: outputLevelBits.load(ordering: .relaxed))
    }

    @inline(__always)
    func getPeakLevel() -> Float {
        Float(bitPattern: peakLevelBits.load(ordering: .relaxed))
    }

    func readScopeBuffer() -> [Float] {
        // Find the latest completed buffer
        let latestWrite = (writeIndex.load(ordering: .acquiring) + 2) % 3

        // Update read index
        readIndex.store(latestWrite, ordering: .releasing)

        return scopeBuffers[latestWrite]
    }
}
