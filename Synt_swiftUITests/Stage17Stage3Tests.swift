//
//  Stage17Stage3Tests.swift
//  SYNT_17 Stage 3: R14-6 (stale dataMSB), R14-7 (ch1/ch16 outside zone), R14-8 (master bend UI),
//  R14-5 (LFO follows osc1 only in wavetable mode; normalized shape), plus RPN 96/97.
//
import XCTest
import Foundation
import Combine
@testable import SynthCore

final class Stage17Stage3Tests: XCTestCase {

    private func mpeEngine(zone: MPEZone = .lower, count: Int = 15) -> AudioEngine {
        let e = AudioEngine(coreOnly: true)
        e.mpeEnabled = true
        e.cachedMpeEnabled = true
        e.cachedMpeZone = zone
        e.cachedMpeMemberChannelCount = count
        e.cachedMpePitchBendRange = 48
        e.cachedPitchBendRange = 2
        return e
    }

    private func cc(_ e: AudioEngine, _ ch: UInt8, _ c: UInt8, _ v: UInt8) {
        e.handleCommand(.mpeControlChange(channel: ch, cc: c, value: v))
    }

    /// Fails on old code: the MCM's dataMSB 15 survived the RPN 0 reselect, so a lone CC 38 set 15.xx.
    func testR14_6_LoneCC38AfterReselectIsIgnored() {
        let e = mpeEngine()
        cc(e, 0, 101, 0); cc(e, 0, 100, 6); cc(e, 0, 6, 15)   // MCM lower, 15 members
        XCTAssertEqual(e.cachedMpePitchBendRange, 48)
        cc(e, 1, 101, 0); cc(e, 1, 100, 0)                     // select RPN 0 on member ch2
        e.rpnStates[1].dataMSB = 15                            // stale value from an earlier RPN
        cc(e, 1, 101, 0); cc(e, 1, 100, 0)                     // reselect clears it
        cc(e, 1, 38, 50)                                       // lone LSB
        XCTAssertEqual(e.cachedMpePitchBendRange, 48, "lone CC 38 must not use a stale MSB")
        XCTAssertNil(e.rpnStates[1].dataMSB)
    }

    /// Fails on old code: null RPN (127/127) kept dataMSB.
    func testR14_6_NullRPNClearsDataMSB() {
        let e = mpeEngine()
        cc(e, 1, 101, 0); cc(e, 1, 100, 0); cc(e, 1, 6, 24)
        XCTAssertEqual(e.rpnStates[1].dataMSB, 24)
        cc(e, 1, 101, 127); cc(e, 1, 100, 127)
        XCTAssertNil(e.rpnStates[1].dataMSB)
        cc(e, 1, 38, 10)
        XCTAssertEqual(e.cachedMpePitchBendRange, 24, accuracy: 1e-6)
    }

    /// Fails on old code: data entry on ch16 (outside a Lower zone, N=7) was swallowed by the MPE path.
    func testR14_7_DataEntryOutsideZoneReachesCCMap() {
        let e = mpeEngine(zone: .lower, count: 7)
        MIDICCLearnStore.shared.attachEngine(e)
        MIDICCLearnStore.shared.clearMappings()
        defer { MIDICCLearnStore.shared.clearMappings() }
        MIDICCLearnStore.shared.map(cc: 6, to: .macro1)
        e.processCommandsForTesting()
        let before = e.cachedMacro1
        cc(e, 15, 99, 1); cc(e, 15, 98, 2)   // device's own NRPN
        cc(e, 15, 6, 127)
        XCTAssertNotEqual(e.cachedMacro1, before, "CC 6 on ch16 outside the zone must stay a plain CC")
        XCTAssertEqual(e.cachedMpePitchBendRange, 48)
        XCTAssertEqual(e.cachedMpeZone, .lower)
    }

    /// Guard (R13-2 still holds): an MCM on ch16 outside the zone still switches zones.
    func testR14_7_MCMOutsideZoneStillAccepted() {
        let e = mpeEngine(zone: .lower, count: 7)
        cc(e, 15, 101, 0); cc(e, 15, 100, 6); cc(e, 15, 6, 5)
        XCTAssertEqual(e.cachedMpeZone, .upper)
        XCTAssertEqual(e.cachedMpeMemberChannelCount, 5)
    }

    /// Fails on old code (no label / no published consumer).
    func testR14_8_MasterBendLabel() {
        XCTAssertNil(MPEControllerOverride.masterBendLabel(nil))
        XCTAssertEqual(MPEControllerOverride.masterBendLabel(2), "Controller Master Bend: ±2 st")
        XCTAssertEqual(MPEControllerOverride.masterBendLabel(3.25), "Controller Master Bend: ±3.25 st")
        let e = mpeEngine()
        var fired = false
        let c = e.$controllerMasterPitchBendRange.dropFirst().sink { _ in fired = true }
        cc(e, 0, 101, 0); cc(e, 0, 100, 0); cc(e, 0, 6, 7)
        e.pollMPEConfigMailbox()
        XCTAssertTrue(fired, "UI must be notified of the controller master range")
        XCTAssertEqual(e.controllerMasterPitchBendRange, 7)
        c.cancel()
    }

    private func renderOffMain(_ engine: AudioEngine, _ frames: Int) {
        let done = expectation(description: "render")
        DispatchQueue.global(qos: .userInteractive).async {
            _ = engine.renderFramesForTesting(frames); done.fulfill()
        }
        wait(for: [done], timeout: 30)
    }

    private func ref(_ t: [Float], _ norm: Double) -> Float {
        let n = t.count, pos = norm * Double(n)
        let i0 = Int(pos) % n, i1 = (i0 + 1) % n, f = Float(pos - Double(Int(pos)))
        return t[i0] * (1 - f) + t[i1] * f
    }

    /// Fails on old code: the LFO followed table 2 although osc1 was a sawtooth.
    func testR14_5_LFOUsesDefaultWhenOsc1NotWavetable() {
        let e = AudioEngine(coreOnly: true)
        e.prepare(sampleRate: 44_100, maxFrames: 256)
        e.lfo.waveform = .wavetable
        e.oscillator1.waveform = .sawtooth
        e.wavetableEngine1.loadBuiltin(index: 2)
        renderOffMain(e, 256)
        for k in 0..<32 {
            let n = Double(k) / 32
            XCTAssertEqual(e.lfo.sampleWaveform(at: n * 2 * .pi), ref(LFO.defaultWavetable, n), accuracy: 1e-4)
        }
    }

    /// Fails on old code: a quiet table (peak 0.25) gave a quarter-depth LFO.
    func testR14_5_LFOShapeIsNormalized() {
        let frame = (0..<64).map { 0.25 * Float(sin(Double($0) / 64 * 2 * .pi)) }
        let p = LFOShapeTable.makeImmortal(frame)
        var peak: Float = 0
        for i in 0..<p.pointee.count { peak = max(peak, abs(p.pointee.data[i])) }
        XCTAssertEqual(peak, 1, accuracy: 1e-5)
        XCTAssertEqual(p.pointee.data[16], 1, accuracy: 1e-5)
    }

    /// Fails on old code: CC 96/97 were ignored.
    func testRPN96_97IncrementDecrementBendRange() {
        let e = mpeEngine()
        cc(e, 1, 101, 0); cc(e, 1, 100, 0); cc(e, 1, 6, 24)
        cc(e, 1, 96, 0)
        XCTAssertEqual(e.cachedMpePitchBendRange, 25)
        cc(e, 1, 97, 0); cc(e, 1, 97, 0)
        XCTAssertEqual(e.cachedMpePitchBendRange, 23)
        // master channel, without prior data entry: steps from the current range (2 → 3)
        cc(e, 0, 101, 0); cc(e, 0, 100, 0); cc(e, 0, 96, 0)
        XCTAssertEqual(e.cachedPitchBendRange, 3)
        // routed into the MPE path while MPE is on
        let cmd = AudioEngine.command(for: .controlChange(controller: 96, value: 0, channel: 1), mpeEnabled: true)
        if case .mpeControlChange = cmd {} else { XCTFail("CC 96 must route to MPE path, got \(String(describing: cmd))") }
    }
}
