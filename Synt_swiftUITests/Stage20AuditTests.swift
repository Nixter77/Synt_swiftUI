//
//  Stage20AuditTests.swift
//  SYNT_20: nightly audit SYNT_14..19 fixes. Every test fails on 42b418c.
//

import XCTest
import AudioToolbox
import Synchronization
@testable import SynthCore

final class Stage20AuditTests: XCTestCase {
    static let desc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
                                                componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)

    // MARK: P1-1 — AU pulls the snapshot before engine.render: must still take the RT path.

    func testP1_1_PullOutsideEngineRenderUsesRTTableSwitch() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        let engine = unit.engine
        try unit.allocateRenderResources()
        defer { unit.deallocateRenderResources() }
        var p = engine.preset
        p.osc1Waveform = .wavetable
        p.osc1WavetableIndex = engine.loadedWTIndex1 == 3 ? 2 : 3
        engine.rtPresetBuffer.publish(RTPresetSnapshot(from: p, rendersAllDelayInDSP: true))
        let before = engine.wavetableEngine1.activeCompiled
        // Exactly what SyntRenderContext.render does before engine.render (isRenderingActive == false).
        engine.pullPresetSnapshotRT()
        XCTAssertEqual(engine.wavetableEngine1.rtPendingIndex.load(ordering: .relaxed), p.osc1WavetableIndex,
                       "render must switch the table through loadBuiltinRT")
        XCTAssertTrue(engine.wavetableEngine1.activeCompiled === before, "no main-side publish (lock/ARC) on render")
    }

    // MARK: P1-2 — while the AU is allocated, main must not write DSP state.

    func testP1_2_MainDoesNotApplyDSPWhileRenderAllocated() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        let engine = unit.engine
        try unit.allocateRenderResources()
        let old = engine.oscillator1.volume
        let target: Float = old > 0.5 ? 0.2 : 0.8
        engine.preset.osc1Volume = target
        engine.applyPreset()
        XCTAssertEqual(engine.oscillator1.volume, old, "main wrote DSP while render may run")
        engine.processCommandsForTesting()           // render applies the snapshot
        XCTAssertEqual(engine.oscillator1.volume, target, accuracy: 1e-6)

        unit.deallocateRenderResources()             // nothing renders: main applies directly
        engine.preset.osc1Volume = old
        engine.applyPreset()
        XCTAssertEqual(engine.oscillator1.volume, old, accuracy: 1e-6)
    }
}
