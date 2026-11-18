//
//  AudioMeterModel.swift
//  Synt_swiftUI
//
//  UI-only levels. ContentView does not observe this object, so a meter
//  tick does not redraw the knobs. The scope trace is not published here:
//  the oscilloscope reads AtomicMeteringState from its own timeline.
//

import Foundation
import Combine

public final class AudioMeterModel: ObservableObject {
    /// A 30 Hz poll plus one jitter slot still stays at or under 31 publishes per second.
    public static let minimumPublishInterval: TimeInterval = 1.0 / 31.0
    /// One VU segment is 1/20. Ignore smaller moves.
    public static let levelChangeThreshold: Float = 0.015

    @Published public private(set) var outputLevel: Float = 0
    @Published public private(set) var peakLevel: Float = 0
    @Published public private(set) var outputLevelL: Float = 0
    @Published public private(set) var outputLevelR: Float = 0
    @Published public private(set) var peakLevelL: Float = 0
    @Published public private(set) var peakLevelR: Float = 0

    private(set) var publishCount = 0
    private var lastOutput: Float = -1
    private var lastPeak: Float = -1
    private var lastOutputL: Float = -1
    private var lastOutputR: Float = -1
    private var lastPeakL: Float = -1
    private var lastPeakR: Float = -1
    private var lastPublishTime: TimeInterval = -.infinity

    /// Main-thread poll. `now` is injectable so a test can simulate one second.
    @discardableResult
    public func ingest(
        output: Float,
        peak: Float,
        outputL: Float? = nil,
        outputR: Float? = nil,
        peakL: Float? = nil,
        peakR: Float? = nil,
        now: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        let outL = outputL ?? output
        let outR = outputR ?? output
        let pkL = peakL ?? peak
        let pkR = peakR ?? peak
        let moved = abs(output - lastOutput) > Self.levelChangeThreshold
            || abs(peak - lastPeak) > Self.levelChangeThreshold
            || abs(outL - lastOutputL) > Self.levelChangeThreshold
            || abs(outR - lastOutputR) > Self.levelChangeThreshold
            || abs(pkL - lastPeakL) > Self.levelChangeThreshold
            || abs(pkR - lastPeakR) > Self.levelChangeThreshold
        guard moved else { return false }
        guard now - lastPublishTime >= Self.minimumPublishInterval else { return false }

        lastOutput = output
        lastPeak = peak
        lastOutputL = outL
        lastOutputR = outR
        lastPeakL = pkL
        lastPeakR = pkR
        lastPublishTime = now
        outputLevel = output
        peakLevel = peak
        outputLevelL = outL
        outputLevelR = outR
        peakLevelL = pkL
        peakLevelR = pkR
        publishCount += 1
        return true
    }

    public func resetDisplay() {
        lastOutput = 0
        lastPeak = 0
        lastOutputL = 0
        lastOutputR = 0
        lastPeakL = 0
        lastPeakR = 0
        outputLevel = 0
        peakLevel = 0
        outputLevelL = 0
        outputLevelR = 0
        peakLevelL = 0
        peakLevelR = 0
    }
}
