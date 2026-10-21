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

public struct DSPMSEGPoint: Codable, Equatable, Sendable {
    public var time: Float   // Normalized time 0.0 ... 1.0 (or beat progress)
    public var value: Float  // Amplitude -1.0 ... 1.0 (or 0.0 ... 1.0)
    public var curve: Float  // Curvature: -1.0 (concave/log) ... 0.0 (linear) ... 1.0 (convex/exp)

    public init(time: Float, value: Float, curve: Float = 0.0) {
        self.time = max(0.0, min(1.0, time))
        self.value = max(-1.0, min(1.0, value))
        self.curve = max(-1.0, min(1.0, curve))
    }
}

public enum DSPMSEGSyncMode: String, Codable, Sendable, CaseIterable {
    case hz = "Hz"
    case beats = "Beats"
}

public enum DSPMSEGTriggerMode: String, Codable, Sendable, CaseIterable {
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
        let decodedPoints = try container.decodeIfPresent([DSPMSEGPoint].self, forKey: .points) ?? [
            DSPMSEGPoint(time: 0.0, value: 0.0),
            DSPMSEGPoint(time: 1.0, value: 1.0)
        ]
        self.points = Array(decodedPoints.prefix(Self.maxPoints))
        self.isOneShot = try container.decodeIfPresent(Bool.self, forKey: .isOneShot) ?? false
        self.syncMode = try container.decodeIfPresent(DSPMSEGSyncMode.self, forKey: .syncMode) ?? .hz
        self.rateHz = try container.decodeIfPresent(Float.self, forKey: .rateHz) ?? 1.0
        self.syncBeats = try container.decodeIfPresent(Float.self, forKey: .syncBeats) ?? 1.0
        self.triggerMode = try container.decodeIfPresent(DSPMSEGTriggerMode.self, forKey: .triggerMode) ?? .retrigger
        self.loopStartIndex = try container.decodeIfPresent(Int.self, forKey: .loopStartIndex)
        self.loopEndIndex = try container.decodeIfPresent(Int.self, forKey: .loopEndIndex)
        self.sustainIndex = try container.decodeIfPresent(Int.self, forKey: .sustainIndex)
    }
}

public final class DSPMSEG {
    // Model configuration
    public var model: DSPMSEGModel {
        didSet { syncRTData() }
    }

    // Audio rate parameters
    private var sampleRate: Double = 44100.0

    // Render-side fixed tables (up to 32 points) for zero-allocation tick()
    private var pointCount: Int = 0
    private var times: [Float] = Array(repeating: 0, count: DSPMSEGModel.maxPoints)
    private var values: [Float] = Array(repeating: 0, count: DSPMSEGModel.maxPoints)
    private var curves: [Float] = Array(repeating: 0, count: DSPMSEGModel.maxPoints)

    // Playback state
    public private(set) var phase: Float = 0.0
    public private(set) var currentValue: Float = 0.0
    public private(set) var isRunning: Bool = false
    public private(set) var isSustaining: Bool = false

    public init(model: DSPMSEGModel = DSPMSEGModel(), sampleRate: Double = 44100.0) {
        self.model = model
        self.sampleRate = max(1.0, sampleRate)
        syncRTData()
    }

    public func prepare(sampleRate: Double, maxFrames: Int = 512) {
        self.sampleRate = max(1.0, sampleRate)
        syncRTData()
    }

    private func syncRTData() {
        let pts = model.points
        pointCount = min(DSPMSEGModel.maxPoints, pts.count)
        for i in 0..<pointCount {
            times[i] = pts[i].time
            values[i] = pts[i].value
            curves[i] = pts[i].curve
        }
    }

    public func reset() {
        phase = 0.0
        currentValue = pointCount > 0 ? values[0] : 0.0
        isRunning = false
        isSustaining = false
    }

    public func trigger() {
        if model.triggerMode == .retrigger || !isRunning {
            phase = 0.0
            isSustaining = false
        }
        isRunning = true
    }

    public func release() {
        isSustaining = false
    }

    /// Real-time sample-by-sample update. Completely lock-free, zero heap allocations, zero ARC.
    @inline(__always)
    public func tick(gate: Bool = true, bpm: Double = 120.0) -> Float {
        guard pointCount > 0 else { return 0.0 }
        guard isRunning else {
            return values[0]
        }

        // Calculate phase increment
        let totalDurationSeconds: Float
        switch model.syncMode {
        case .hz:
            totalDurationSeconds = max(0.001, 1.0 / max(0.01, model.rateHz))
        case .beats:
            let secondsPerBeat = Float(60.0 / max(20.0, bpm))
            totalDurationSeconds = max(0.001, model.syncBeats * secondsPerBeat)
        }

        let dt = 1.0 / (Float(sampleRate) * totalDurationSeconds)

        // Check sustain
        if gate && !model.isOneShot, let susIdx = model.sustainIndex, susIdx >= 0 && susIdx < pointCount {
            let susTime = times[susIdx]
            if phase >= susTime {
                isSustaining = true
                phase = susTime
                currentValue = values[susIdx]
                return currentValue
            }
        } else {
            isSustaining = false
        }

        // Advance phase
        phase += dt

        // Check loop
        if !model.isOneShot,
           let lStart = model.loopStartIndex,
           let lEnd = model.loopEndIndex,
           lStart >= 0 && lEnd < pointCount && lStart < lEnd {
            let startTime = times[lStart]
            let endTime = times[lEnd]
            if phase >= endTime {
                let loopLen = max(1.0e-5, endTime - startTime)
                phase = startTime + (phase - endTime).truncatingRemainder(dividingBy: loopLen)
            }
        } else if phase >= 1.0 {
            if model.isOneShot {
                phase = 1.0
                isRunning = false
                currentValue = values[pointCount - 1]
                return currentValue
            } else {
                // Free loop 0..1
                phase = phase.truncatingRemainder(dividingBy: 1.0)
            }
        }

        currentValue = evaluate(at: phase)
        return currentValue
    }

    @inline(__always)
    public func evaluate(at t: Float) -> Float {
        guard pointCount > 0 else { return 0.0 }
        let clampedT = max(0.0, min(1.0, t))

        if clampedT <= times[0] { return values[0] }
        if clampedT >= times[pointCount - 1] { return values[pointCount - 1] }

        // Find segment (times is sorted, pointCount <= 32)
        var i = 0
        while i < pointCount - 1 {
            if clampedT <= times[i + 1] {
                break
            }
            i += 1
        }

        let t0 = times[i]
        let t1 = times[i + 1]
        let v0 = values[i]
        let v1 = values[i + 1]
        let c = curves[i]

        let span = max(1.0e-6, t1 - t0)
        let normalizedProgress = max(0.0, min(1.0, (clampedT - t0) / span))

        let curvedProgress: Float
        if abs(c) < 1.0e-4 {
            curvedProgress = normalizedProgress
        } else if c > 0.0 {
            // Convex / exponential curve
            let power = 1.0 + 4.0 * c
            curvedProgress = pow(normalizedProgress, power)
        } else {
            // Concave / logarithmic curve
            let power = 1.0 - 4.0 * c
            curvedProgress = 1.0 - pow(1.0 - normalizedProgress, power)
        }

        return v0 + curvedProgress * (v1 - v0)
    }
}
