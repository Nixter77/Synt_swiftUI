//
//  Stage15Stage4Tests.swift
//  SYNT_15 Stage 4: R12-6, R12-7, R12-9 + strengthened R9-2 / R11-1 / R7-10 tests.
//

import XCTest
import Foundation
import Synchronization
@testable import SynthCore

final class Stage15Stage4Tests: XCTestCase {

    private func userTable() -> Wavetable {
        // Distinct from builtins: rich saw-ish frames.
        var frames: [[Float]] = []
        for f in 0..<4 {
            var fr = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 {
                let ph = Float(i) / 2048
                fr[i] = (2 * ph - 1) * (0.5 + 0.1 * Float(f))
            }
            frames.append(fr)
        }
        return Wavetable(name: "S15User", frames: frames)
    }

    // MARK: R12-6 / R11-1 real path: setSampleRate -> user table (index 5)

    func testR12_6_UserTableRecompiledForNewSampleRateViaIndex5() {
        let osc = WavetableOscillator()
        osc.setSampleRate(44_100)
        let t = userTable()
        osc.loadWavetable(t)
        osc.loadBuiltin(index: 5)   // engine path for a preset with user WT
        XCTAssertEqual(osc.currentBuiltinIndex, 5)
        XCTAssertEqual(osc.activeCompiled?.sampleRate, 44_100)

        osc.setSampleRate(96_000)
        XCTAssertEqual(osc.currentBuiltinIndex, 5)
        XCTAssertEqual(osc.activeCompiled?.sampleRate, 96_000)
        XCTAssertEqual(osc.activeCompiled?.wavetable.contentHash, t.contentHash)
        XCTAssertEqual(osc.mipMaxHarmonicForTesting(0),
                       WavetableOscillator.maxHarmonic(forOctave: 0, sampleRate: 96_000))
        XCTAssertEqual(osc.instanceUserCompiled?.sampleRate, 96_000)
    }

    // MARK: R12-7 / R11-4: no static fallback into another instance's audio

    func testR12_7_Index5NeverFallsBackToStaticUserTable() {
        let a = WavetableOscillator()
        a.setSampleRate(44_100)
        a.loadWavetable(userTable())
        let foreign = a.activeCompiled
        let savedC = WavetableOscillator.userCompiledWavetable
        let savedT = WavetableOscillator.userWavetable
        defer {
            WavetableOscillator.userCompiledWavetable = savedC
            WavetableOscillator.userWavetable = savedT
        }
        WavetableOscillator.userCompiledWavetable = foreign
        WavetableOscillator.userWavetable = foreign?.wavetable

        let b = WavetableOscillator()
        b.setSampleRate(44_100)
        b.loadBuiltin(index: 5)
        XCTAssertFalse(b.activeCompiled === foreign, "B must not play A's table via the static")
        XCTAssertNotEqual(b.activeCompiled?.wavetable.contentHash, foreign?.wavetable.contentHash)
        XCTAssertNil(b.instanceUserCompiled)
    }

    // MARK: R12-9: WTZ1 header hash is not trusted; legacy hashes memoised

    func testR12_9_ForgedWTZ1HeaderHashIsIgnored() {
        let a = WavetableOscillator.basicWavetables[0]
        let b = WavetableOscillator.basicWavetables[1]
        var data = a.compressedSerializedData()
        var forged = b.contentHash
        withUnsafeBytes(of: &forged) { data.replaceSubrange(8..<16, with: $0) }
        XCTAssertEqual(Wavetable.canonicalContentHash(for: data), a.contentHash)
        XCTAssertNotEqual(Wavetable.canonicalContentHash(for: data), b.contentHash)
    }

    func testR12_9_LegacyHashDecodedOncePerBlob() {
        let raw = userTable().serializedData()
        let before = Wavetable.canonicalHashDecodeCountForTesting.load(ordering: .relaxed)
        let h1 = Wavetable.canonicalContentHash(for: raw)
        for _ in 0..<5 { XCTAssertEqual(Wavetable.canonicalContentHash(for: raw), h1) }
        let after = Wavetable.canonicalHashDecodeCountForTesting.load(ordering: .relaxed)
        XCTAssertEqual(after - before, 1, "Repeated applyPreset must not re-decode the same blob")
        XCTAssertEqual(h1, userTable().contentHash)
    }

    // MARK: R9-2 strengthened: real reverb signal in the send

    func testR9_2_SendFadeWithRealTailIsClickFree() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        var p = SynthPreset.defaultPreset
        p.release = 0.001
        p.sendA = 0.8
        p.sendB = 0
        p.reverbRoomSize = 0.9
        engine.preset = p
        engine.handleNoteOn(midiNote: 60, velocity: 1.0)
        for _ in 0..<2000 { _ = engine.renderOneSample() }
        engine.handleNoteOff(midiNote: 60)
        // Let the dry voice die; what remains is the send tail.
        var prev: Float = 0
        var preDiff: Float = 0
        var tailPeak: Float = 0
        for i in 0..<3000 {
            let s = engine.renderOneSample().0
            if i >= 2000 {
                preDiff = max(preDiff, abs(s - prev))
                tailPeak = max(tailPeak, abs(s))
            }
            prev = s
        }
        XCTAssertGreaterThan(tailPeak, 1e-3, "Test needs an audible tail in the send")
        XCTAssertGreaterThan(engine.sendFadeA, 0.5)

        engine.cachedSendA = 0
        var dropDiff: Float = 0
        var n = 0
        while engine.sendFadeA > 0 && n < 4000 {
            let s = engine.renderOneSample().0
            dropDiff = max(dropDiff, abs(s - prev))
            prev = s
            n += 1
        }
        XCTAssertEqual(engine.sendFadeA, 0)
        let ms = Double(n) / 44.1
        XCTAssertGreaterThanOrEqual(ms, 10); XCTAssertLessThanOrEqual(ms, 20)
        // A hard cut would jump by ~tailPeak; the fade must stay near natural slope.
        XCTAssertLessThan(dropDiff, max(preDiff * 1.5, tailPeak * 0.25))
    }

    // MARK: R7-10 through the engine (render on a non-main thread)

    func testR7_10_EngineWavetableLFORendersFromTableWithoutTouchingOsc() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.lfo.waveform = .wavetable
        engine.lfo.wavetableEngine = engine.wavetableEngine1
        engine.handleNoteOn(midiNote: 60, velocity: 1.0)
        let posBefore = engine.wavetableEngine1.targetFramePosition
        let done = expectation(description: "render")
        var nan = 0
        DispatchQueue.global(qos: .userInteractive).async {
            nan = engine.renderFramesForTesting(4096).nanCount
            done.fulfill()
        }
        wait(for: [done], timeout: 30)
        XCTAssertEqual(nan, 0)
        XCTAssertEqual(engine.wavetableEngine1.targetFramePosition, posBefore)
        let table = LFO.defaultWavetable
        let n = table.count
        for k in 0..<64 {
            let norm = Double(k) / 64.0
            let pos = norm * Double(n)
            let i0 = Int(pos) % n, i1 = (i0 + 1) % n
            let f = Float(pos - Double(Int(pos)))
            let ref = table[i0] * (1 - f) + table[i1] * f
            XCTAssertEqual(engine.lfo.sampleWaveform(at: norm * 2 * .pi), ref, accuracy: 1e-4)
        }
    }
}
