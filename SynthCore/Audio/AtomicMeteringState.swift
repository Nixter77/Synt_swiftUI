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
    private let outputLevelLBits = Atomic<UInt32>(0)
    private let outputLevelRBits = Atomic<UInt32>(0)
    private let peakLevelLBits = Atomic<UInt32>(0)
    private let peakLevelRBits = Atomic<UInt32>(0)
    /// Last raw key velocity, release velocity, and aftertouch. 0 means no event yet.
    private let inputVelocityBits = Atomic<UInt32>(0)
    private let releaseVelocityBits = Atomic<UInt32>(0)
    private let aftertouchBits = Atomic<UInt32>(0)
    /// Velocity after the app touch curve. The amp graph draws its dot here.
    private let playedVelocityBits = Atomic<UInt32>(0)

    // Lock-free ring buffer for scope / spectrum output data
    public static let defaultScopeBufferSize = 512
    private let scopeBufferSize: Int
    private let ringSlotCount: Int = 4
    private let rawStorage: UnsafeMutablePointer<Float>
    /// Even epoch: the slot holds a finished frame. Odd: the writer is filling it.
    private let slotEpoch: UnsafeMutablePointer<Atomic<UInt32>>
    private let writeIndex = Atomic<Int>(0)
    private let readIndex = Atomic<Int>(3)

    // Lock-free ring buffer for true stereo scope + phase correlation
    private let stereoStorageL: UnsafeMutablePointer<Float>
    private let stereoStorageR: UnsafeMutablePointer<Float>
    private let stereoSlotEpoch: UnsafeMutablePointer<Atomic<UInt32>>
    private let stereoWriteIndex = Atomic<Int>(0)
    private let stereoReadIndex = Atomic<Int>(3)
    private let phaseCorrelationBits = Atomic<UInt32>(Float(1.0).bitPattern)
    private let hasStereoScopeBits = Atomic<Bool>(false)

    public init(bufferSize: Int = defaultScopeBufferSize) {
        self.scopeBufferSize = bufferSize
        let total = ringSlotCount * bufferSize
        rawStorage = .allocate(capacity: total)
        rawStorage.initialize(repeating: 0.0, count: total)
        slotEpoch = .allocate(capacity: ringSlotCount)
        stereoStorageL = .allocate(capacity: total)
        stereoStorageL.initialize(repeating: 0.0, count: total)
        stereoStorageR = .allocate(capacity: total)
        stereoStorageR.initialize(repeating: 0.0, count: total)
        stereoSlotEpoch = .allocate(capacity: ringSlotCount)
        for i in 0..<ringSlotCount {
            (slotEpoch + i).initialize(to: Atomic<UInt32>(0))
            (stereoSlotEpoch + i).initialize(to: Atomic<UInt32>(0))
        }
        writeIndex.store(0, ordering: .relaxed)
        readIndex.store(ringSlotCount - 1, ordering: .relaxed)
        stereoWriteIndex.store(0, ordering: .relaxed)
        stereoReadIndex.store(ringSlotCount - 1, ordering: .relaxed)
    }

    deinit {
        let total = ringSlotCount * scopeBufferSize
        rawStorage.deinitialize(count: total)
        rawStorage.deallocate()
        slotEpoch.deinitialize(count: ringSlotCount)
        slotEpoch.deallocate()
        stereoStorageL.deinitialize(count: total)
        stereoStorageL.deallocate()
        stereoStorageR.deinitialize(count: total)
        stereoStorageR.deallocate()
        stereoSlotEpoch.deinitialize(count: ringSlotCount)
        stereoSlotEpoch.deallocate()
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

    @inline(__always)
    public func setOutputLevelStereo(left: Float, right: Float) {
        outputLevelLBits.store(left.bitPattern, ordering: .relaxed)
        outputLevelRBits.store(right.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func setPeakLevelStereo(left: Float, right: Float) {
        peakLevelLBits.store(left.bitPattern, ordering: .relaxed)
        peakLevelRBits.store(right.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func setInputVelocity(_ value: Float) {
        inputVelocityBits.store(value.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func setReleaseVelocity(_ value: Float) {
        releaseVelocityBits.store(value.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func setAftertouch(_ value: Float) {
        aftertouchBits.store(value.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func setPlayedVelocity(_ value: Float) {
        playedVelocityBits.store(value.bitPattern, ordering: .relaxed)
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

    public func writeStereoScopeBuffer(left: UnsafeBufferPointer<Float>, right: UnsafeBufferPointer<Float>) {
        guard left.count >= scopeBufferSize,
              right.count >= scopeBufferSize,
              let baseL = left.baseAddress,
              let baseR = right.baseAddress else { return }

        // Compute Pearson correlation: sum(L*R) / sqrt(sum(L^2) * sum(R^2)), defaulting to 1.0 on silence/non-finite.
        var sumLR: Double = 0
        var sumL2: Double = 0
        var sumR2: Double = 0
        for i in 0..<scopeBufferSize {
            let l = Double(baseL[i])
            let r = Double(baseR[i])
            sumLR += l * r
            sumL2 += l * l
            sumR2 += r * r
        }
        let denom = sqrt(sumL2 * sumR2)
        let correlation: Float
        if denom > 1e-12 && denom.isFinite && sumLR.isFinite {
            let c = sumLR / denom
            correlation = c.isFinite ? Float(max(-1.0, min(1.0, c))) : 1.0
        } else {
            correlation = 1.0
        }
        phaseCorrelationBits.store(correlation.bitPattern, ordering: .relaxed)
        hasStereoScopeBits.store(true, ordering: .releasing)

        let currentWrite = stereoWriteIndex.load(ordering: .relaxed)
        let nextWrite = (currentWrite + 1) % ringSlotCount

        let currentRead = stereoReadIndex.load(ordering: .acquiring)
        if nextWrite == currentRead {
            return
        }

        let epochPtr = stereoSlotEpoch + currentWrite
        let epoch = epochPtr.pointee.load(ordering: .relaxed)
        epochPtr.pointee.store(epoch &+ 1, ordering: .releasing)

        let destL = stereoStorageL + currentWrite * scopeBufferSize
        let destR = stereoStorageR + currentWrite * scopeBufferSize
        destL.update(from: baseL, count: scopeBufferSize)
        destR.update(from: baseR, count: scopeBufferSize)

        epochPtr.pointee.store(epoch &+ 2, ordering: .releasing)
        stereoWriteIndex.store(nextWrite, ordering: .releasing)
    }

    public func writeStereoScopeBuffer(left: [Float], right: [Float]) {
        left.withUnsafeBufferPointer { bufL in
            right.withUnsafeBufferPointer { bufR in
                writeStereoScopeBuffer(left: bufL, right: bufR)
            }
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

    @inline(__always)
    public func getOutputLevelL() -> Float {
        Float(bitPattern: outputLevelLBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getOutputLevelR() -> Float {
        Float(bitPattern: outputLevelRBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getPeakLevelL() -> Float {
        Float(bitPattern: peakLevelLBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getPeakLevelR() -> Float {
        Float(bitPattern: peakLevelRBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getInputVelocity() -> Float {
        Float(bitPattern: inputVelocityBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getReleaseVelocity() -> Float {
        Float(bitPattern: releaseVelocityBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getAftertouch() -> Float {
        Float(bitPattern: aftertouchBits.load(ordering: .relaxed))
    }

    @inline(__always)
    public func getPlayedVelocity() -> Float {
        Float(bitPattern: playedVelocityBits.load(ordering: .relaxed))
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

    public var hasStereoScopeData: Bool {
        hasStereoScopeBits.load(ordering: .acquiring)
    }

    @inline(__always)
    public func getPhaseCorrelation() -> Float {
        Float(bitPattern: phaseCorrelationBits.load(ordering: .relaxed))
    }

    public func readStereoScopeBuffer() -> (left: [Float], right: [Float]) {
        for _ in 0..<4 {
            let latestWrite = (stereoWriteIndex.load(ordering: .acquiring) + ringSlotCount - 1) % ringSlotCount
            let epochPtr = stereoSlotEpoch + latestWrite
            let e1 = epochPtr.pointee.load(ordering: .acquiring)
            if e1 & 1 == 1 { continue }
            stereoReadIndex.store(latestWrite, ordering: .releasing)
            let srcL = stereoStorageL + latestWrite * scopeBufferSize
            let srcR = stereoStorageR + latestWrite * scopeBufferSize
            let frameL = Array(UnsafeBufferPointer(start: srcL, count: scopeBufferSize))
            let frameR = Array(UnsafeBufferPointer(start: srcR, count: scopeBufferSize))
            let e2 = epochPtr.pointee.load(ordering: .acquiring)
            if e1 == e2 { return (left: frameL, right: frameR) }
        }
        return (
            left: Array(repeating: 0, count: scopeBufferSize),
            right: Array(repeating: 0, count: scopeBufferSize)
        )
    }
}
