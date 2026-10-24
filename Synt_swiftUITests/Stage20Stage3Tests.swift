//
//  Stage20Stage3Tests.swift
//  SYNT_20 Stage 3: R16-5 (LFO shape switch during a running fade) and
//  R16-6 (stale MPE mailbox entry after "Reset to my settings").
//

import XCTest
import AudioToolbox
@testable import SynthCore

final class Stage20Stage3Tests: XCTestCase {

    private func bits(_ frame: [Float]) -> Int { Int(bitPattern: LFOShapeTable.makeImmortal(frame)) }

    /// A second shape switch while the first crossfade is still running must not jump:
    /// the new fade starts from the current mixed output.
    func testR16_5_SwitchDuringRunningFadeDoesNotJump() {
        let up = bits([Float](repeating: 1, count: 64))
        let down = bits([Float](repeating: -1, count: 64))
        let lfo = LFO()
        lfo.waveform = .wavetable
        lfo.rate = 0.01
        lfo.trigger()
        lfo.adoptShape(bits: up)
        let sr = 44100.0
        var last: Float = 0
        for _ in 0..<8 { last = lfo.nextRawValue(sampleRate: sr) }
        XCTAssertEqual(last, 1, accuracy: 1e-4)
        lfo.adoptShape(bits: down)                       // fade 1 → -1 starts
        for _ in 0..<60 { last = lfo.nextRawValue(sampleRate: sr) }
        XCTAssertGreaterThan(lfo.shapeFade, 0.1)
        XCTAssertLessThan(lfo.shapeFade, 0.9)
        lfo.adoptShape(bits: up)                         // switch back mid-fade
        var maxStep: Float = 0
        var prev = last
        for _ in 0..<Int(sr * 0.02) {
            let v = lfo.nextRawValue(sampleRate: sr)
            maxStep = max(maxStep, abs(v - prev))
            prev = v
        }
        XCTAssertLessThan(maxStep, 0.05, "mid-fade switch jumped by \(maxStep)")
        XCTAssertEqual(prev, 1, accuracy: 1e-4, "fade must land on the new shape")
    }

    /// Outside wavetable mode a pending fade is finished, so it cannot resume later.
    func testR16_5_FadeDoesNotStallOutsideWavetableMode() {
        let lfo = LFO()
        lfo.waveform = .wavetable
        lfo.adoptShape(bits: bits([Float](repeating: 1, count: 64)))
        lfo.adoptShape(bits: bits([Float](repeating: -1, count: 64)))
        XCTAssertLessThan(lfo.shapeFade, 1)
        lfo.waveform = .sine
        for _ in 0..<1000 { _ = lfo.nextRawValue(sampleRate: 44100) }
        lfo.adoptShape(bits: bits([Float](repeating: 0.5, count: 64)))
        XCTAssertEqual(lfo.shapeFade, 1)
    }

    /// A controller change render published before it applied the reset must not
    /// bring the override back on main.
    func testR16_6_StaleMailboxAfterResetIsIgnored() throws {
        let description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
                                                    componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)
        let au = try SyntAudioUnit(componentDescription: description)
        let e = au.engine
        e.mpeEnabled = true
        e.cachedMpeEnabled = true
        e.cachedMpeZone = .lower
        e.cachedMpeMemberChannelCount = 15
        e.cachedMpePitchBendRange = 48
        e.cachedPitchBendRange = 2
        e.handleRPN(channel: 15, rpn: 6, value: 5)
        au.drainControllerMPEConfig()
        XCTAssertNotNil(au.controllerMPEOverrideSummary)

        e.handleRPN(channel: 15, rpn: 6, value: 7)     // render publishes, main has not polled yet
        au.resetControllerMPEOverrides()
        XCTAssertNil(au.controllerMPEOverrideSummary)
        au.drainControllerMPEConfig()                  // stale entry
        XCTAssertNil(au.controllerMPEOverrideSummary, "stale mailbox entry restored the override")
        e.processCommandsForTesting()                  // render applies the reset and acks
        au.drainControllerMPEConfig()
        XCTAssertNil(au.controllerMPEOverrideSummary)

        e.handleRPN(channel: 15, rpn: 6, value: 3)     // a new controller change after the ack still shows
        au.drainControllerMPEConfig()
        XCTAssertEqual(au.controllerMPEOverrideSummary?.contains("3 members"), true)
    }
}

final class Stage20AuditP3Tests: XCTestCase {
    /// Audit P3-9: an unknown MPE zone in a preset must not fail the whole decode.
    func testP3_9_UnknownMPEZoneFallsBackToLower() throws {
        var p = SynthPreset(name: "Z")
        p.mpeZone = .upper
        let data = try JSONEncoder().encode(p)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj["mpeZone"] = "middle"
        let bad = try JSONSerialization.data(withJSONObject: obj)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: bad)
        XCTAssertEqual(decoded.mpeZone, .lower)
    }
}
