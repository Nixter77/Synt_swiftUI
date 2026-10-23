//
//  Stage15Stage1Tests.swift
//  SYNT_15 Stage 1: R12-1 (RPN/MCM on render thread must not touch preset/applyPreset),
//  R12-8 (LFO .wavetable has no side effects on the oscillator engine).
//

import XCTest
@testable import SynthCore

final class Stage15Stage1Tests: XCTestCase {

    private func sendRPN(_ engine: AudioEngine, channel: UInt8, rpn: UInt8, value: UInt8) {
        engine.handleCommand(.mpeControlChange(channel: channel, cc: 101, value: 0))
        engine.handleCommand(.mpeControlChange(channel: channel, cc: 100, value: rpn))
        engine.handleCommand(.mpeControlChange(channel: channel, cc: 6, value: value))
    }

    /// R12-1: RPN driven from a non-main (render-like) thread must not call applyPreset or write the preset.
    func testR12_1_RPNOnRenderThreadDoesNotApplyPresetAndPublishesViaMailbox() {
        let engine = AudioEngine(coreOnly: true)
        engine.cachedMpeEnabled = true
        let before = engine.applyPresetCallCountForTesting
        let presetRangeBefore = engine.preset.mpePitchBendRange
        let presetCountBefore = engine.preset.mpeMemberChannelCount

        let done = expectation(description: "render-thread RPN")
        let renderQueue = DispatchQueue(label: "fake.render", qos: .userInteractive)
        renderQueue.async {
            XCTAssertFalse(Thread.isMainThread)
            self.sendRPN(engine, channel: 0, rpn: 6, value: 10)   // MCM lower zone, 10 members
            self.sendRPN(engine, channel: 1, rpn: 0, value: 24)   // member bend range 24
            done.fulfill()
        }
        wait(for: [done], timeout: 5)

        XCTAssertEqual(engine.applyPresetCallCountForTesting, before, "RPN on render thread must not run applyPreset()")
        XCTAssertEqual(engine.preset.mpePitchBendRange, presetRangeBefore, "preset must not be written from render")
        XCTAssertEqual(engine.preset.mpeMemberChannelCount, presetCountBefore)
        // Render-side state is live immediately.
        XCTAssertEqual(engine.cachedMpePitchBendRange, 24)
        XCTAssertEqual(engine.cachedMpeMemberChannelCount, 10)

        engine.pollMPEConfigMailbox()   // main
        // SYNT_17 R14-1 (design change): controller values are runtime only — main mirrors them
        // in `controllerMPEMain` / the routing mirror, the preset (user settings) stays unchanged.
        XCTAssertEqual(engine.preset.mpePitchBendRange, presetRangeBefore)
        XCTAssertEqual(engine.preset.mpeMemberChannelCount, presetCountBefore)
        XCTAssertEqual(engine.controllerMPEMain.memberRange, 24)
        XCTAssertEqual(engine.controllerMPEMain.memberCount, 10)
        XCTAssertEqual(engine.controllerMPEMain.enabled, true)
        XCTAssertEqual(engine.mpePitchBendRange, 24)
        XCTAssertEqual(engine.mpeMemberChannelCount, 10)
        XCTAssertEqual(engine.applyPresetCallCountForTesting, before, "main publish must be display-only")

        // Mailbox is drained: a second poll is a no-op.
        engine.updatePresetDisplayOnly { $0.mpePitchBendRange = 7 }
        engine.pollMPEConfigMailbox()
        XCTAssertEqual(engine.preset.mpePitchBendRange, 7)
    }

    /// R12-8: an LFO pointed at an oscillator engine must not advance that engine's morph smoothing.
    func testR12_8_WavetableLFODoesNotMutateOscillatorMorph() {
        let a = WavetableOscillator()
        let b = WavetableOscillator()
        a.targetFramePosition = 1.0
        b.targetFramePosition = 1.0
        let lfo = LFO()
        lfo.waveform = .wavetable
        lfo.rate = 3
        lfo.wavetableEngine = a
        for _ in 0..<4096 {
            _ = lfo.nextRawValue(sampleRate: 44100)
            _ = lfo.sampleWaveform(at: 1.0)
        }
        XCTAssertEqual(a.framePosition, b.framePosition, "LFO must not advance the oscillator's morph")
        var phase = 0.0
        let inc = AudioMath.twoPi * 220 / 44100
        for _ in 0..<512 {
            XCTAssertEqual(a.generateSample(phase: phase, phaseIncrement: inc), b.generateSample(phase: phase, phaseIncrement: inc))
            phase += inc
            if phase >= AudioMath.twoPi { phase -= AudioMath.twoPi }
        }
    }

    /// R12-8: value at every phase (incl. zero crossings) equals an independent interpolation of the table;
    /// no substitution by another table, even with an engine attached.
    func testR12_8_WavetableLFOMatchesIndependentTableReference() {
        let table = LFO.defaultWavetable
        let engine = WavetableOscillator()
        engine.targetFramePosition = 0.7
        let lfo = LFO()
        lfo.waveform = .wavetable
        lfo.wavetableEngine = engine
        let n = table.count
        for k in 0..<997 {
            let norm = Double(k) / 997.0
            let pos = norm * Double(n)
            let i0 = Int(pos) % n, i1 = (i0 + 1) % n
            let f = Float(pos - Double(Int(pos)))
            let ref = table[i0] + (table[i1] - table[i0]) * f
            XCTAssertEqual(lfo.sampleWaveform(at: norm * AudioMath.twoPi), ref, accuracy: 1e-5, "phase \(norm)")
        }
    }
}
