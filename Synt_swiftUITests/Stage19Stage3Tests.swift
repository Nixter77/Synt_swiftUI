//
//  Stage19Stage3Tests.swift
//  SYNT_19 Stage 3: R16-2 — setSampleRate adopts a render-side table switch first;
//  R16-4 — behavioural version of the R15-1 "render frees nothing" check.
//

import XCTest
import AudioToolbox
import Synchronization
@testable import SynthCore

final class Stage19Stage3Tests: XCTestCase {

    func testR16_2_RenderSwitchThenSampleRateChangePlaysRenderChoice() {
        let osc = WavetableOscillator()
        osc.loadBuiltin(index: 2)
        osc.pullNewWavetableRT()
        osc.loadBuiltinRT(index: 4)           // host snapshot switched the table on render
        osc.setSampleRate(48_000)             // main, before any applyPreset
        XCTAssertEqual(osc.currentBuiltinIndex, 4, "R16-2: SR rebuild must use render's table")
        osc.pullNewWavetableRT()

        let ref = WavetableOscillator()
        ref.setSampleRate(48_000)
        ref.loadBuiltin(index: 4)
        ref.pullNewWavetableRT()
        ref.targetFramePosition = osc.targetFramePosition
        ref.reset(); osc.reset()
        let inc = 2 * Double.pi * 330 / 48_000
        for k in 0..<32 {
            let ph = Double(k) * 0.17
            XCTAssertEqual(osc.generateSample(phase: ph, phaseIncrement: inc, sampleRate: 48_000).bitPattern,
                           ref.generateSample(phase: ph, phaseIncrement: inc, sampleRate: 48_000).bitPattern)
        }
    }

    func testR16_2_AUMainTimerMirrorsRenderSwitch() throws {
        let description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
                                                    componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)
        let au = try SyntAudioUnit(componentDescription: description)
        let osc = au.engine.wavetableEngine1
        osc.loadBuiltin(index: 1)
        osc.loadBuiltinRT(index: 3)
        au.syncWavetablesFromRender()
        XCTAssertEqual(osc.currentBuiltinIndex, 3)
        XCTAssertEqual(osc.rtPendingIndex.load(ordering: .relaxed), -1)
    }

    /// R16-4: the user table has no other owner (not cached, no test reference). Render switches
    /// user → builtin; the table must still be alive after the render calls and is freed only by
    /// main-thread work afterwards.
    func testR16_4_RenderSwitchFreesNothingUnownedTableFreedLaterOnMain() {
        let osc = WavetableOscillator()
        weak var weakU: CompiledMipData?
        do {
            var fr = [Float](repeating: 0, count: 2048)
            for i in 0..<2048 { fr[i] = Float(i % 512) / 256 - 1 }
            let u = WavetableOscillator.compile(wavetable: Wavetable(name: "S19-R16-4", frames: [fr, fr]))
            weakU = u
            osc.instanceUserCompiled = u
            osc.loadBuiltin(index: 5)           // main publishes U into a slot
        }
        osc.pullNewWavetableRT()                // render reads U from its slot
        osc.instanceUserCompiled = nil          // main drops its own reference (U retired, slot holds it)
        osc.loadBuiltinRT(index: 0)             // render switch
        XCTAssertNotNil(weakU, "render-side switch must not free the table")

        final class Box: @unchecked Sendable { var mainOnly = true; var n = 0 }
        let box = Box()
        CompiledMipData.onDeinitForTesting = { if !Thread.isMainThread { box.mainOnly = false }; box.n += 1 }
        defer { CompiledMipData.onDeinitForTesting = nil }
        osc.syncFromRenderMain()                // main mirrors builtin 0 (publish #1)
        for _ in 0..<3 {                        // render adopts, main publishes: slot rotation
            osc.pullNewWavetableRT()
            osc.loadBuiltin(index: 0)
        }
        XCTAssertNil(weakU, "the unowned table is freed once main has rotated it out")
        XCTAssertTrue(box.mainOnly)
    }
}
