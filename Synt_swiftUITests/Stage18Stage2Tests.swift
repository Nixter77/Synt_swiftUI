//
//  Stage18Stage2Tests.swift
//  SYNT_18 Stage 2: R15-1 — table switches that run on render (applyPresetDSP via
//  pullPresetSnapshotRT) take no lock and free nothing; main mirrors them afterwards.
//

import XCTest
import Synchronization
@testable import SynthCore

final class Stage18Stage2Tests: XCTestCase {

    private func userTable() -> Wavetable {
        var frames: [[Float]] = []
        for f in 0..<4 {
            var fr = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 { fr[i] = (2 * Float(i) / 2048 - 1) * (0.5 + 0.1 * Float(f)) }
            frames.append(fr)
        }
        return Wavetable(name: "S18User", frames: frames)
    }

    func testR15_1_UserToBuiltinSwitchOnRenderTakesNoLockAndFreesNothing() {
        let engine = AudioEngine()
        engine.wavetableEngine1.loadWavetable(userTable())
        engine.preset.osc1Waveform = .wavetable
        engine.preset.osc1WavetableIndex = 5
        engine.applyPreset()
        let userCompiled = engine.wavetableEngine1.activeCompiled
        XCTAssertTrue(userCompiled === engine.wavetableEngine1.instanceUserCompiled)

        // Now "render" is active; main only publishes the snapshot.
        engine.isRenderingActive.store(true, ordering: .releasing)
        engine.preset.osc1WavetableIndex = 0
        engine.applyPreset()

        final class Box: @unchecked Sendable { var n = 0 }
        let freed = Box()
        CompiledMipData.onDeinitForTesting = { freed.n += 1 }
        defer { CompiledMipData.onDeinitForTesting = nil }
        let locksBefore = WavetableOscillator.publishLockCountForTesting.load(ordering: .relaxed)
        engine.pullPresetSnapshotRT()   // render path → applyPresetDSP → loadBuiltinRT
        let locksAfter = WavetableOscillator.publishLockCountForTesting.load(ordering: .relaxed)
        XCTAssertEqual(locksAfter, locksBefore, "render-side table switch must not take writeLock")
        XCTAssertEqual(freed.n, 0, "render-side table switch must not free a table")
        XCTAssertEqual(engine.wavetableEngine1.rtPendingIndex.load(ordering: .relaxed), 0)

        // Audio already follows builtin 0.
        let ref = WavetableOscillator()
        ref.loadBuiltin(index: 0)
        ref.pullNewWavetableRT()
        ref.targetFramePosition = engine.wavetableEngine1.targetFramePosition
        ref.reset()
        engine.wavetableEngine1.reset()
        let inc = 2 * Double.pi * 220 / 44100
        for k in 0..<32 {
            let ph = Double(k) * 0.1
            XCTAssertEqual(engine.wavetableEngine1.generateSample(phase: ph, phaseIncrement: inc).bitPattern,
                           ref.generateSample(phase: ph, phaseIncrement: inc).bitPattern)
        }

        // Main takes over the retain/release later.
        engine.isRenderingActive.store(false, ordering: .releasing)
        engine.wavetableEngine1.syncFromRenderMain()
        XCTAssertTrue(engine.wavetableEngine1.activeCompiled === ref.activeCompiled)
        XCTAssertEqual(engine.wavetableEngine1.rtPendingIndex.load(ordering: .relaxed), -1)
        XCTAssertTrue(engine.wavetableEngine1.instanceUserCompiled === userCompiled, "user table kept alive on main")
    }

    func testR15_1_RenderSwitchBackToUserTableUsesUserView() {
        let osc = WavetableOscillator()
        osc.loadWavetable(userTable())
        let user = osc.instanceUserCompiled
        osc.loadBuiltin(index: 2)
        osc.pullNewWavetableRT()
        let locksBefore = WavetableOscillator.publishLockCountForTesting.load(ordering: .relaxed)
        osc.loadBuiltinRT(index: 5)
        XCTAssertEqual(WavetableOscillator.publishLockCountForTesting.load(ordering: .relaxed), locksBefore)
        XCTAssertEqual(osc.lfoShapeBits.load(ordering: .relaxed), Int(bitPattern: user!.lfoShape))
        osc.syncFromRenderMain()
        XCTAssertTrue(osc.activeCompiled === user)
    }
}
