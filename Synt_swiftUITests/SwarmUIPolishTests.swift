//
//  SwarmUIPolishTests.swift
//  Synt_swiftUITests
//
//  Verification tests for Wave 1 UI polish changes:
//  - KnobView fine drag & reset helpers and LargeKnobView target resolution
//  - OscilloscopeView vDSP spectrum band mapping, 45° M/S goniometer math & correlation
//  - ContentView safe WAV recording file save/replace semantics
//

import Foundation
import SwiftUI
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
struct SwarmUIPolishTests {

    // MARK: - KnobView & LargeKnobView

    @Test func knobDragNormalVsFineIsFiveTimesMorePrecise() {
        let range: ClosedRange<Float> = 0...1
        let start: Float = 0.5

        let coarseUp = knobDragValue(start: start, translationY: -30, range: range)
        let fineUp = knobDragValue(start: start, translationY: -30, range: range, fine: true)

        let coarseDelta = coarseUp - start
        let fineDelta = fineUp - start
        #expect(abs(coarseDelta - 0.2) < 1e-5)
        #expect(abs(fineDelta - 0.04) < 1e-5)
        #expect(abs((coarseDelta / fineDelta) - 5.0) < 1e-4)

        // Fine drag still sweeps smoothly and clamps cleanly on wide ranges.
        let wideRange: ClosedRange<Float> = -100...100
        let fineDown = knobDragValue(start: 0, translationY: 150, range: wideRange, fine: true)
        #expect(abs(fineDown - (-40.0)) < 1e-4)
        #expect(knobDragValue(start: 99, translationY: -100, range: wideRange, fine: true) == 100)
        #expect(knobDragValue(start: -99, translationY: 100, range: wideRange, fine: true) == -100)
    }

    @Test func knobResetValueHandlesBipolarExplicitAndUnipolar() {
        #expect(knobResetValue(defaultValue: nil, range: -1...1) == 0)
        #expect(knobResetValue(defaultValue: nil, range: -12...12) == 0)
        #expect(knobResetValue(defaultValue: nil, range: 0...1) == nil)
        #expect(knobResetValue(defaultValue: 0.55, range: 0...1) == 0.55)
        #expect(knobResetValue(defaultValue: 2.0, range: 0...1) == 1.0)
    }

    @Test func largeKnobViewMasterLabelDoesNotResolveToCutoff() {
        var val: Float = 0.55
        let binding = Binding(get: { val }, set: { val = $0 })

        let masterKnob = LargeKnobView(value: binding, range: 0...1, label: "Master")
        #expect(masterKnob.destination == nil)
        #expect(masterKnob.resolvedTarget != .cutoff)
        #expect(masterKnob.resolvedTarget == .amp)

        let customKnob = LargeKnobView(value: binding, range: 0...1, label: "Output")
        #expect(customKnob.resolvedTarget == nil)

        let cutoffKnob = LargeKnobView(value: binding, range: 20...20000, label: "Cutoff")
        #expect(cutoffKnob.resolvedTarget == .cutoff)

        let explicitKnob = LargeKnobView(
            value: binding,
            range: 0...1,
            label: "Master",
            target: .reverbMix
        )
        #expect(explicitKnob.resolvedTarget == .reverbMix)
    }

    // MARK: - OscilloscopeView Goniometer & Spectrum

    @Test func oscilloscopePhaseScopeGoniometerRotationMath() {
        // L == R maps strictly along the vertical Mid axis (x = 0, y = L).
        let midNorm = OscilloscopeView.phaseScopeNormalized(left: 0.75, right: 0.75)
        #expect(abs(midNorm.x) < 1e-6)
        #expect(abs(midNorm.y - 0.75) < 1e-6)

        let size = CGSize(width: 200, height: 100)
        let midPt = OscilloscopeView.phaseScopePoint(left: 0.75, right: 0.75, size: size)
        #expect(abs(midPt.x - 100) < 1e-6)
        #expect(midPt.y < 50)

        // L == -R maps strictly along the horizontal Side axis (y = 0, |x| = |L|).
        let sideNorm = OscilloscopeView.phaseScopeNormalized(left: 0.6, right: -0.6)
        #expect(abs(sideNorm.y) < 1e-6)
        #expect(abs(abs(sideNorm.x) - 0.6) < 1e-6)

        let sidePt = OscilloscopeView.phaseScopePoint(left: 0.6, right: -0.6, size: size)
        #expect(abs(sidePt.y - 50) < 1e-6)
        #expect(abs(sidePt.x - 100) > 10)

        // Pure Left goes top-left; pure Right goes top-right.
        let leftOnly = OscilloscopeView.phaseScopePoint(left: 1.0, right: 0.0, size: size)
        let rightOnly = OscilloscopeView.phaseScopePoint(left: 0.0, right: 1.0, size: size)
        #expect(leftOnly.x < 100 && leftOnly.y < 50)
        #expect(rightOnly.x > 100 && rightOnly.y < 50)

        // Non-finite samples sanitize cleanly to center.
        let badPt = OscilloscopeView.phaseScopePoint(left: .nan, right: .infinity, size: size)
        #expect(badPt.x.isFinite && badPt.y.isFinite)
    }

    @Test func oscilloscopePhaseCorrelationMeasuresMonoAntiPhaseAndSilence() {
        let mono = (0..<128).map { sin(Float($0) * 0.1) }
        let inverted = mono.map { -$0 }
        let silence = [Float](repeating: 0, count: 128)

        #expect(abs(OscilloscopeView.phaseCorrelation(left: mono, right: mono) - 1.0) < 1e-5)
        #expect(abs(OscilloscopeView.phaseCorrelation(left: mono, right: inverted) + 1.0) < 1e-5)
        #expect(OscilloscopeView.phaseCorrelation(left: silence, right: silence) == 0)
    }

    @Test func outputSpectrumCalculatorAndLogBandsCompatibility() {
        let calc = OutputSpectrumCalculator.shared
        let n = 512
        let sampleRate = 44_100.0

        let lowSine = (0..<n).map { Float(sin(2.0 * Double.pi * 250.0 * Double($0) / sampleRate)) }
        let highSine = (0..<n).map { Float(sin(2.0 * Double.pi * 6000.0 * Double($0) / sampleRate)) }

        let lowMags = calc.computeMagnitudes(from: lowSine)
        let highMags = calc.computeMagnitudes(from: highSine)
        #expect(lowMags.count == 256)
        #expect(highMags.count == 256)

        let lowBands = OscilloscopeView.spectrumBands(from: lowMags, bandCount: 32)
        let highBands = OscilloscopeView.spectrumBands(from: highMags, bandCount: 32)
        #expect(lowBands.count == 32)
        #expect(highBands.count == 32)
        #expect(lowBands.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })
        #expect(highBands.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 })

        let lowPeakBand = lowBands.enumerated().max(by: { $0.element < $1.element })?.offset ?? -1
        let highPeakBand = highBands.enumerated().max(by: { $0.element < $1.element })?.offset ?? -1
        #expect(lowPeakBand >= 0 && lowPeakBand < 15)
        #expect(highPeakBand > lowPeakBand + 10)
    }

    // MARK: - ContentView Recording Safe Replace

    @Test func contentViewSaveRecordingFileCreatesOverwritesAndPreservesOnFailure() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("SwarmUIPolishTests-\(UUID().uuidString)")
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        let temp1 = dir.appendingPathComponent("temp1.wav")
        let dest = dir.appendingPathComponent("recording.wav")
        try Data("new-audio-1".utf8).write(to: temp1)

        // 1. Fresh destination creation
        try ContentView.saveRecordingFile(from: temp1, to: dest)
        #expect(try Data(contentsOf: dest) == Data("new-audio-1".utf8))

        // 2. Safe overwrite of existing destination
        let temp2 = dir.appendingPathComponent("temp2.wav")
        try Data("new-audio-2".utf8).write(to: temp2)
        try ContentView.saveRecordingFile(from: temp2, to: dest)
        #expect(try Data(contentsOf: dest) == Data("new-audio-2".utf8))

        // 3. Failed source copy must leave existing user file intact
        let missing = dir.appendingPathComponent("does-not-exist.wav")
        var didThrow = false
        do {
            try ContentView.saveRecordingFile(from: missing, to: dest)
        } catch {
            didThrow = true
        }
        #expect(didThrow)
        #expect(try Data(contentsOf: dest) == Data("new-audio-2".utf8))
    }
}
