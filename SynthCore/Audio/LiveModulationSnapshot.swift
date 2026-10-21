//
//  LiveModulationSnapshot.swift
//  SynthCore
//
//  Lock-free snapshot of instantaneous modulation values per destination.
//  The audio thread stores modulated values; UI polls at ~30 Hz.
//  Zero allocations, zero locks, real-time safe.
//

import Foundation
import Synchronization

public final class LiveModulationSnapshot: @unchecked Sendable {
    public static let slotCount = 32
    private let bits: UnsafeMutablePointer<Atomic<UInt32>>

    public init() {
        bits = .allocate(capacity: Self.slotCount)
        for i in 0..<Self.slotCount {
            (bits + i).initialize(to: Atomic<UInt32>(0))
        }
    }

    deinit {
        bits.deinitialize(count: Self.slotCount)
        bits.deallocate()
    }

    @inline(__always)
    public static func slot(for destination: ModDestination) -> Int {
        switch destination {
        case .pitch1: return 0
        case .pitch2: return 1
        case .cutoff: return 2
        case .resonance: return 3
        case .amp: return 4
        case .pan: return 5
        case .pwm1: return 6
        case .pwm2: return 7
        case .wtMorph1: return 8
        case .wtMorph2: return 9
        case .lfoRate: return 10
        case .lfoDepth: return 11
        case .mix: return 12
        case .finePitch: return 13
        case .fm: return 14
        case .chorusMix: return 15
        case .delayMix: return 16
        case .reverbMix: return 17
        case .vowel: return 18
        }
    }

    @inline(__always)
    public func store(_ value: Float, for destination: ModDestination) {
        let s = Self.slot(for: destination)
        (bits + s).pointee.store(value.bitPattern, ordering: .relaxed)
    }

    @inline(__always)
    public func value(for destination: ModDestination) -> Float {
        let s = Self.slot(for: destination)
        return Float(bitPattern: (bits + s).pointee.load(ordering: .relaxed))
    }

    public func reset() {
        for i in 0..<Self.slotCount {
            (bits + i).pointee.store(0, ordering: .relaxed)
        }
    }
}
