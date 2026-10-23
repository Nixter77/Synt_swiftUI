//
//  Stage18Stage3Tests.swift
//  SYNT_18 Stage 3: R14-5/R15-5 (LFO gate from render-owned state + crossfade on shape switch),
//  R15-3 (render-side clearing of a controller override reaches main).
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage18Stage3Tests: XCTestCase {

    private func sawOsc() -> WavetableOscillator {
        var frames: [[Float]] = []
        for _ in 0..<4 {
            var fr = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 { fr[i] = 2 * Float(i) / 2048 - 1 }
            frames.append(fr)
        }
        let o = WavetableOscillator()
        o.loadWavetable(Wavetable(name: "S18Saw", frames: frames))
        return o
    }

    /// A racy main-thread write of `oscillator1.waveform` must not flip the render-side LFO gate.
    func testR15_5_LFOGateReadsRenderOwnedStateNotOscillatorWaveform() {
        let engine = AudioEngine()
        engine.preset.osc1Waveform = .wavetable
        engine.preset.osc1WavetableIndex = 1
        engine.applyPreset()
        engine.lfo.waveform = .wavetable
        engine.oscillator1.waveform = .sine   // simulated main-thread write (R13-7 class race)
        let l = UnsafeMutablePointer<Float>.allocate(capacity: 64); defer { l.deallocate() }
        let r = UnsafeMutablePointer<Float>.allocate(capacity: 64); defer { r.deallocate() }
        engine.renderBlock(intoL: l, intoR: r, frameCount: 64)

        let ref = LFO(); ref.waveform = .wavetable
        ref.adoptShape(bits: engine.wavetableEngine1.lfoShapeBits.load(ordering: .relaxed))
        let def = LFO(); def.waveform = .wavetable
        let p = 1.1
        XCTAssertNotEqual(ref.sampleWaveform(at: p), def.sampleWaveform(at: p), "precondition: table 1 shape differs from default")
        XCTAssertEqual(engine.lfo.sampleWaveform(at: p), ref.sampleWaveform(at: p))
    }

    /// Switching the LFO shape (table or osc mode switch) must not jump; it fades over ~5 ms.
    func testR15_5_ShapeSwitchIsCrossfadedNotAJump() {
        let saw = sawOsc()
        let lfo = LFO()
        lfo.waveform = .wavetable
        lfo.rate = 1
        lfo.startPhaseDegrees = 45
        lfo.trigger()
        lfo.adoptShape(bits: saw.lfoShapeBits.load(ordering: .relaxed))
        let sr = 44100.0
        var last: Float = 0
        for _ in 0..<16 { last = lfo.nextRawValue(sampleRate: sr) }
        lfo.adoptShape(bits: 0)   // e.g. osc1 leaves wavetable mode
        var maxStep: Float = 0
        var prev = last
        for _ in 0..<Int(sr * 0.01) {
            let v = lfo.nextRawValue(sampleRate: sr)
            maxStep = max(maxStep, abs(v - prev))
            prev = v
        }
        XCTAssertLessThan(maxStep, 0.02, "shape switch must be smoothed (old code jumped)")
        XCTAssertEqual(lfo.shapeFade, 1)
    }

    /// Render drops the controller member count when the host sends a different value;
    /// main must hear about it (it used to keep showing the controller value).
    func testR15_3_RenderClearingOfOverrideReachesMain() {
        let engine = AudioEngine()
        engine.handleRPN(channel: 0, rpn: 6, value: 5)
        XCTAssertTrue(engine.pollMPEConfigMailbox())
        XCTAssertEqual(engine.controllerMPEMain.memberCount, 5)
        XCTAssertEqual(engine.controllerMPEMain.masterRange, 2)

        engine.adoptHostMPEMemberCount(7)
        engine.adoptHostMasterBendRange(12)
        XCTAssertTrue(engine.pollMPEConfigMailbox(), "render must publish the cleared override")
        XCTAssertNil(engine.controllerMPEMain.memberCount)
        XCTAssertEqual(engine.mpeMemberChannelCount, 7)
        XCTAssertNil(engine.controllerMPEMain.masterRange)
        XCTAssertNil(engine.controllerMasterPitchBendRange)
        XCTAssertEqual(engine.controllerMPEMain.zone, .lower, "untouched overrides stay")
    }
}
