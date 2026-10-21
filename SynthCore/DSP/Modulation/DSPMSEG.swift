//
//  DSPMSEG.swift
//  SynthCore
//
//  Multi-Stage Envelope Generator (MSEG) engine.
//  Supports up to 32 points, per-segment curvature, loop/sustain points,
//  Hz or beat sync, and one-shot/retrigger modes.
//  Includes a Codable pure model and a zero-allocation render-safe tick().
//

import Foundation
import Synchronization

public struct DSPMSEGPoint: Codable, Equatable, Hashable, Sendable {
    public var time: Float   // Normalized time 0.0 ... 1.0 (or beat progress)
    public var value: Float  // Amplitude -1.0 ... 1.0 (or 0.0 ... 1.0)
    public var curve: Float  // Curvature: -1.0 (concave/log) ... 0.0 (linear) ... 1.0 (convex/exp)

    public init(time: Float, value: Float, curve: Float = 0.0) {
        self.time = max(0.0, min(1.0, time))
        self.value = max(-1.0, min(1.0, value))
        self.curve = max(-1.0, min(1.0, curve))
    }
}

public enum DSPMSEGSyncMode: String, Codable, Hashable, Sendable, CaseIterable {
    case hz = "Hz"
    case beats = "Beats"
}

public enum DSPMSEGTriggerMode: String, Codable, Hashable, Sendable, CaseIterable {
    case retrigger = "Retrigger"
    case continuous = "Continuous"
}

public struct DSPMSEGModel: Codable, Equatable, Sendable {
    public static let maxPoints: Int = 32

    public var points: [DSPMSEGPoint]
    public var isOneShot: Bool
    public var syncMode: DSPMSEGSyncMode
    public var rateHz: Float
    public var syncBeats: Float
    public var triggerMode: DSPMSEGTriggerMode
    public var loopStartIndex: Int?
    public var loopEndIndex: Int?
    public var sustainIndex: Int?

    public init(
        points: [DSPMSEGPoint] = [
            DSPMSEGPoint(time: 0.0, value: 0.0, curve: 0.0),
            DSPMSEGPoint(time: 0.2, value: 1.0, curve: -0.3),
            DSPMSEGPoint(time: 0.5, value: 0.7, curve: 0.2),
            DSPMSEGPoint(time: 0.8, value: 0.7, curve: 0.0),
            DSPMSEGPoint(time: 1.0, value: 0.0, curve: 0.3)
        ],
        isOneShot: Bool = false,
        syncMode: DSPMSEGSyncMode = .hz,
        rateHz: Float = 1.0,
        syncBeats: Float = 1.0,
        triggerMode: DSPMSEGTriggerMode = .retrigger,
        loopStartIndex: Int? = nil,
        loopEndIndex: Int? = nil,
        sustainIndex: Int? = 2
    ) {
        var sorted = points.sorted { $0.time < $1.time }
        if sorted.count > Self.maxPoints {
            sorted = Array(sorted.prefix(Self.maxPoints))
        }
        if sorted.isEmpty {
            sorted = [DSPMSEGPoint(time: 0.0, value: 0.0), DSPMSEGPoint(time: 1.0, value: 1.0)]
        }
        self.points = sorted
        self.isOneShot = isOneShot
        self.syncMode = syncMode
        self.rateHz = max(0.01, min(100.0, rateHz))
        self.syncBeats = max(0.0625, min(32.0, syncBeats))
        self.triggerMode = triggerMode
        self.loopStartIndex = loopStartIndex
        self.loopEndIndex = loopEndIndex
        self.sustainIndex = sustainIndex
    }

    private enum CodingKeys: String, CodingKey {
        case points, isOneShot, syncMode, rateHz, syncBeats, triggerMode
        case loopStartIndex, loopEndIndex, sustainIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedPoints = try container.decodeIfPresent([DSPMSEGPoint].self, forKey: .points) ?? []
        var clamped = decodedPoints.map {
            DSPMSEGPoint(time: $0.time, value: $0.value, curve: $0.curve)
        }
        clamped.sort { $0.time < $1.time }
        if clamped.count > Self.maxPoints {
            clamped = Array(clamped.prefix(Self.maxPoints))
        }
        if clamped.isEmpty {
            clamped = [DSPMSEGPoint(time: 0.0, value: 0.0), DSPMSEGPoint(time: 1.0, value: 1.0)]
        }
        let last = clamped.count - 1
        func clampIndex(_ index: Int?) -> Int? {
            guard let index else { return nil }
            return max(0, min(last, index))
        }
        self.points = clamped
        self.isOneShot = try container.decodeIfPresent(Bool.self, forKey: .isOneShot) ?? false
        self.syncMode = try container.decodeIfPresent(DSPMSEGSyncMode.self, forKey: .syncMode) ?? .hz
        let rate = try container.decodeIfPresent(Float.self, forKey: .rateHz) ?? 1.0
        self.rateHz = max(0.01, min(100.0, rate))
        let beats = try container.decodeIfPresent(Float.self, forKey: .syncBeats) ?? 1.0
        self.syncBeats = max(0.0625, min(32.0, beats))
        self.triggerMode = try container.decodeIfPresent(DSPMSEGTriggerMode.self, forKey: .triggerMode) ?? .retrigger
        self.loopStartIndex = clampIndex(try container.decodeIfPresent(Int.self, forKey: .loopStartIndex))
        self.loopEndIndex = clampIndex(try container.decodeIfPresent(Int.self, forKey: .loopEndIndex))
        self.sustainIndex = clampIndex(try container.decodeIfPresent(Int.self, forKey: .sustainIndex))
    }
}

/// Preset-side MSEG. Empty points are the default. Unlike `DSPMSEGModel`, a missing
/// list stays empty so an old preset does not grow the demo curve.
public struct MSEGPreset: Codable, Equatable, Hashable, Sendable {
    public var points: [DSPMSEGPoint] = []
    public var isOneShot: Bool = false
    public var syncMode: DSPMSEGSyncMode = .hz
    public var rateHz: Float = 1
    public var syncBeats: Float = 1
    public var triggerMode: DSPMSEGTriggerMode = .retrigger
    public var loopStartIndex: Int?
    public var loopEndIndex: Int?
    public var sustainIndex: Int?

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case points, isOneShot, syncMode, rateHz, syncBeats, triggerMode
        case loopStartIndex, loopEndIndex, sustainIndex
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var clamped = (try container.decodeIfPresent([DSPMSEGPoint].self, forKey: .points) ?? []).map {
            DSPMSEGPoint(time: $0.time, value: $0.value, curve: $0.curve)
        }
        clamped.sort { $0.time < $1.time }
        if clamped.count > DSPMSEGModel.maxPoints {
            clamped = Array(clamped.prefix(DSPMSEGModel.maxPoints))
        }
        points = clamped
        isOneShot = try container.decodeIfPresent(Bool.self, forKey: .isOneShot) ?? false
        syncMode = try container.decodeIfPresent(DSPMSEGSyncMode.self, forKey: .syncMode) ?? .hz
        rateHz = max(0.01, min(100, try container.decodeIfPresent(Float.self, forKey: .rateHz) ?? 1))
        syncBeats = max(0.0625, min(32, try container.decodeIfPresent(Float.self, forKey: .syncBeats) ?? 1))
        triggerMode = try container.decodeIfPresent(DSPMSEGTriggerMode.self, forKey: .triggerMode) ?? .retrigger
        if clamped.isEmpty {
            loopStartIndex = nil
            loopEndIndex = nil
            sustainIndex = nil
        } else {
            let last = clamped.count - 1
            func clampIndex(_ index: Int?) -> Int? {
                guard let index else { return nil }
                return max(0, min(last, index))
            }
            loopStartIndex = clampIndex(try container.decodeIfPresent(Int.self, forKey: .loopStartIndex))
            loopEndIndex = clampIndex(try container.decodeIfPresent(Int.self, forKey: .loopEndIndex))
            sustainIndex = clampIndex(try container.decodeIfPresent(Int.self, forKey: .sustainIndex))
        }
    }
}

public final class DSPMSEG {
    private struct PublishedBank {
        var pointCount: Int = 0
        var isOneShot: Bool = false
        var beats: Bool = false
        var rateHz: Float = 1
        var syncBeats: Float = 1
        var retrigger: Bool = true
        var loopStart: Int = -1
        var loopEnd: Int = -1
        var sustain: Int = -1
    }

    /// Writer-side copy. `tick` does not read this.
    public var model: DSPMSEGModel {
        didSet { publish(model) }
    }

    private var sampleRate: Double = 44100.0

    /// Three banks. The writer fills a bank the reader is not in, then release-stores the index.
    /// No acknowledgement and no wait: a stalled reader keeps its bank, and the latest publish wins.
    private static let bankCount = 3
    private let times: UnsafeMutablePointer<Float>
    private let values: UnsafeMutablePointer<Float>
    private let curves: UnsafeMutablePointer<Float>
    private var bankMeta0 = PublishedBank()
    private var bankMeta1 = PublishedBank()
    private var bankMeta2 = PublishedBank()
    private let activeBank = Atomic<Int>(0)
    /// Bank `tick` is reading, or -1 between ticks.
    private let readingBank = Atomic<Int>(-1)

    public private(set) var phase: Float = 0.0
    public private(set) var currentValue: Float = 0.0
    public private(set) var isRunning: Bool = false
    public private(set) var isSustaining: Bool = false

    public init(model: DSPMSEGModel = DSPMSEGModel(), sampleRate: Double = 44100.0) {
        let slots = DSPMSEGModel.maxPoints * Self.bankCount
        times = .allocate(capacity: slots)
        values = .allocate(capacity: slots)
        curves = .allocate(capacity: slots)
        times.initialize(repeating: 0, count: slots)
        values.initialize(repeating: 0, count: slots)
        curves.initialize(repeating: 0, count: slots)
        self.model = model
        self.sampleRate = max(1.0, sampleRate)
        publish(model)
        currentValue = sample(0, bank: activeBank.load(ordering: .acquiring))
    }

    deinit {
        let slots = DSPMSEGModel.maxPoints * Self.bankCount
        times.deinitialize(count: slots)
        values.deinitialize(count: slots)
        curves.deinitialize(count: slots)
        times.deallocate()
        values.deallocate()
        curves.deallocate()
    }

    public func prepare(sampleRate: Double, maxFrames: Int = 512) {
        self.sampleRate = max(1.0, sampleRate)
    }

    /// Bank that is neither the published index nor the one `tick` is reading.
    private func claimIdleBank() -> Int {
        let published = activeBank.load(ordering: .acquiring)
        let inUse = readingBank.load(ordering: .acquiring)
        var candidate = (published + 1) % Self.bankCount
        if candidate == inUse {
            candidate = (candidate + 1) % Self.bankCount
        }
        return candidate
    }

    private func meta(at bank: Int) -> PublishedBank {
        switch bank {
        case 0: return bankMeta0
        case 1: return bankMeta1
        default: return bankMeta2
        }
    }

    private func setMeta(_ meta: PublishedBank, at bank: Int) {
        switch bank {
        case 0: bankMeta0 = meta
        case 1: bankMeta1 = meta
        default: bankMeta2 = meta
        }
    }

    /// Main thread. Copies a finished model into an idle bank and publishes it. Does not wait.
    public func publish(_ model: DSPMSEGModel) {
        let idle = claimIdleBank()
        let base = idle * DSPMSEGModel.maxPoints
        let count = min(DSPMSEGModel.maxPoints, model.points.count)
        for i in 0..<count {
            times[base + i] = model.points[i].time
            values[base + i] = model.points[i].value
            curves[base + i] = model.points[i].curve
        }
        var meta = PublishedBank()
        meta.pointCount = count
        meta.isOneShot = model.isOneShot
        meta.beats = model.syncMode == .beats
        meta.rateHz = model.rateHz
        meta.syncBeats = model.syncBeats
        meta.retrigger = model.triggerMode == .retrigger
        meta.loopStart = model.loopStartIndex ?? -1
        meta.loopEnd = model.loopEndIndex ?? -1
        meta.sustain = model.sustainIndex ?? -1
        setMeta(meta, at: idle)
        activeBank.store(idle, ordering: .releasing)
    }

    /// No points. The render thread skips the generator while nothing is routed.
    /// Does not rewrite `model`.
    public func publishEmpty() {
        let idle = claimIdleBank()
        var meta = meta(at: idle)
        meta.pointCount = 0
        setMeta(meta, at: idle)
        activeBank.store(idle, ordering: .releasing)
    }

    public var hasPoints: Bool {
        currentMeta().pointCount > 0
    }

    public func reset() {
        let meta = currentMeta()
        let bank = activeBank.load(ordering: .acquiring)
        phase = 0
        currentValue = meta.pointCount > 0 ? sample(0, bank: bank) : 0
        isRunning = false
        isSustaining = false
    }

    public func trigger() {
        let meta = currentMeta()
        if meta.retrigger || !isRunning {
            phase = 0
            isSustaining = false
        }
        isRunning = true
    }

    public func release() {
        isSustaining = false
    }

    /// Real-time sample. Reads the published bank only.
    @inline(__always)
    public func tick(gate: Bool = true, bpm: Double = 120.0) -> Float {
        let bank = activeBank.load(ordering: .acquiring)
        readingBank.store(bank, ordering: .releasing)
        let output = sampleTick(gate: gate, bpm: bpm, bank: bank)
        readingBank.store(-1, ordering: .releasing)
        return output
    }

    @inline(__always)
    private func sampleTick(gate: Bool, bpm: Double, bank: Int) -> Float {
        let meta = meta(at: bank)
        guard meta.pointCount > 0 else {
            currentValue = 0
            return 0
        }
        guard isRunning else { return currentValue }

        let totalDurationSeconds: Float
        if meta.beats {
            let secondsPerBeat = Float(60.0 / max(20.0, bpm))
            totalDurationSeconds = max(0.001, meta.syncBeats * secondsPerBeat)
        } else {
            totalDurationSeconds = max(0.001, 1.0 / max(0.01, meta.rateHz))
        }
        let dt = 1.0 / (Float(sampleRate) * totalDurationSeconds)

        if gate && !meta.isOneShot && meta.sustain >= 0 && meta.sustain < meta.pointCount {
            let susTime = sampleTime(meta.sustain, bank: bank)
            if phase >= susTime {
                isSustaining = true
                phase = susTime
                currentValue = sample(meta.sustain, bank: bank)
                return currentValue
            }
        } else {
            isSustaining = false
        }

        phase += dt

        let loopOK = !meta.isOneShot
            && meta.loopStart >= 0
            && meta.loopEnd < meta.pointCount
            && meta.loopStart < meta.loopEnd
        if loopOK {
            let startTime = sampleTime(meta.loopStart, bank: bank)
            let endTime = sampleTime(meta.loopEnd, bank: bank)
            if phase >= endTime {
                let loopLen = max(1.0e-5, endTime - startTime)
                phase = startTime + (phase - endTime).truncatingRemainder(dividingBy: loopLen)
            }
        } else if phase >= 1 {
            if meta.isOneShot || meta.sustain >= 0 {
                phase = 1
                isRunning = false
                currentValue = sample(meta.pointCount - 1, bank: bank)
                return currentValue
            }
            phase = phase.truncatingRemainder(dividingBy: 1)
        }

        currentValue = evaluate(at: phase, bank: bank)
        return currentValue
    }

    @inline(__always)
    public func evaluate(at t: Float) -> Float {
        evaluate(at: t, bank: activeBank.load(ordering: .acquiring))
    }

    @inline(__always)
    private func evaluate(at t: Float, bank: Int) -> Float {
        let count = meta(at: bank).pointCount
        guard count > 0 else { return 0 }
        let clampedT = max(0, min(1, t))
        if clampedT <= sampleTime(0, bank: bank) { return sample(0, bank: bank) }
        if clampedT >= sampleTime(count - 1, bank: bank) { return sample(count - 1, bank: bank) }

        var i = 0
        while i < count - 1 {
            if clampedT <= sampleTime(i + 1, bank: bank) { break }
            i += 1
        }
        let t0 = sampleTime(i, bank: bank)
        let t1 = sampleTime(i + 1, bank: bank)
        let v0 = sample(i, bank: bank)
        let v1 = sample(i + 1, bank: bank)
        let c = sampleCurve(i, bank: bank)
        let span = max(1.0e-6, t1 - t0)
        let normalizedProgress = max(0, min(1, (clampedT - t0) / span))
        let curvedProgress: Float
        if abs(c) < 1.0e-4 {
            curvedProgress = normalizedProgress
        } else if c > 0 {
            curvedProgress = pow(normalizedProgress, 1 + 4 * c)
        } else {
            curvedProgress = 1 - pow(1 - normalizedProgress, 1 - 4 * c)
        }
        return v0 + curvedProgress * (v1 - v0)
    }

    @inline(__always)
    private func currentMeta() -> PublishedBank {
        meta(at: activeBank.load(ordering: .acquiring))
    }

    @inline(__always)
    private func sampleTime(_ index: Int, bank: Int) -> Float {
        times[bank * DSPMSEGModel.maxPoints + index]
    }

    @inline(__always)
    private func sample(_ index: Int, bank: Int) -> Float {
        values[bank * DSPMSEGModel.maxPoints + index]
    }

    @inline(__always)
    private func sampleCurve(_ index: Int, bank: Int) -> Float {
        curves[bank * DSPMSEGModel.maxPoints + index]
    }
}
