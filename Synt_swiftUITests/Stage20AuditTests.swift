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

    // MARK: P1-3 — host blocks: one box read without ARC, kept alive across a re-allocate.

    static func renderOnce(_ unit: SyntAudioUnit, frames: Int = 64) -> AUAudioUnitStatus {
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        let bytes = frames * MemoryLayout<Float>.size
        for i in 0..<2 {
            list[i] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(bytes),
                                  mData: UnsafeMutableRawPointer.allocate(byteCount: bytes, alignment: 16))
        }
        defer {
            for i in 0..<2 { list[i].mData?.deallocate() }
            list.unsafeMutablePointer.deallocate()
        }
        var flags = AudioUnitRenderActionFlags()
        var time = AudioTimeStamp()
        time.mFlags = .sampleTimeValid
        return unit.internalRenderBlock(&flags, &time, AUAudioFrameCount(frames), 0, list.unsafeMutablePointer, nil, nil)
    }

    func testP1_3_HostBlocksReadOnRenderAndOldBlockOutlivesReallocate() throws {
        final class Token {}
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        weak var firstToken: Token?
        do {
            let token = Token()
            firstToken = token
            unit.musicalContextBlock = { bpm, _, _, beat, _, _ in
                withExtendedLifetime(token) {}
                bpm?.pointee = 97
                beat?.pointee = 0
                return true
            }
        }
        try unit.allocateRenderResources()
        XCTAssertEqual(Self.renderOnce(unit), noErr)
        XCTAssertEqual(unit.engine.cachedBPM, 97, accuracy: 1e-4, "render read the installed musical-context block")

        // Re-allocate with a new block while a render of the old allocation could still be finishing:
        // the old block must not be released under it.
        unit.deallocateRenderResources()
        unit.musicalContextBlock = { bpm, _, _, _, _, _ in bpm?.pointee = 133; return true }
        try unit.allocateRenderResources()
        XCTAssertNotNil(firstToken, "previous host block released while render may still call it")
        XCTAssertEqual(Self.renderOnce(unit), noErr)
        XCTAssertEqual(unit.engine.cachedBPM, 133, accuracy: 1e-4)

        // Bounded: the allocation after next releases it.
        unit.deallocateRenderResources()
        unit.musicalContextBlock = nil
        try unit.allocateRenderResources()
        XCTAssertNil(firstToken)
        unit.deallocateRenderResources()
    }

    // MARK: P2-4 — a stale main mirror must not override a newer render switch.

    static func samples(_ osc: WavetableOscillator) -> [UInt32] {
        osc.reset()
        let inc = 2 * Double.pi * 220 / 44100
        return (0..<32).map { osc.generateSample(phase: Double($0) * 0.19, phaseIncrement: inc).bitPattern }
    }

    func testP2_4_StaleMirrorDoesNotOverrideNewerRenderSwitch() {
        let osc = WavetableOscillator()
        osc.pullNewWavetableRT()
        osc.loadBuiltinRT(index: 1)                       // render: A
        osc.afterTakeForTesting = { osc.loadBuiltinRT(index: 2) }   // render: B, after main took A
        osc.syncFromRenderMain()                          // main publishes the mirror of A
        osc.afterTakeForTesting = nil
        osc.pullNewWavetableRT()                          // render sees A's publish

        let ref = WavetableOscillator()
        ref.loadBuiltin(index: 2)
        ref.pullNewWavetableRT()
        XCTAssertEqual(Self.samples(osc), Self.samples(ref), "render must keep playing B")
        XCTAssertEqual(osc.rtPendingIndex.load(ordering: .relaxed), 2, "B still awaits its mirror")

        osc.syncFromRenderMain()                          // mirror of B
        osc.pullNewWavetableRT()
        XCTAssertEqual(osc.rtPendingIndex.load(ordering: .relaxed), -1)
        XCTAssertTrue(osc.activeCompiled === ref.activeCompiled)
        XCTAssertEqual(Self.samples(osc), Self.samples(ref))
    }

    // MARK: P2-6 — main never writes framePosition; render resets it on adopting a main publish.

    func testP2_6_MainLoadDoesNotWriteFramePosition() {
        let osc = WavetableOscillator()
        osc.pullNewWavetableRT()
        XCTAssertEqual(osc.framePosition, 0)
        osc.targetFramePosition = 0.7
        osc.loadBuiltin(index: 1)                         // main
        XCTAssertEqual(osc.framePosition, 0, "main wrote the render-owned morph state")
        osc.pullNewWavetableRT()                          // render adopts the publish
        XCTAssertEqual(osc.framePosition, 0.7, accuracy: 1e-6)
    }

    // MARK: P2-5 — retire list is safe off main; standalone mirrors render switches.

    func testP2_5_UserTableSetAndDrainFromManyThreads() {
        let osc = WavetableOscillator()
        osc.loadBuiltin(index: 0)
        let tables = (1...4).map { i -> CompiledMipData in
            osc.loadBuiltin(index: i); return osc.activeCompiled!
        }
        DispatchQueue.concurrentPerform(iterations: 8) { worker in
            for n in 0..<2000 {
                if worker % 2 == 0 { osc.instanceUserCompiled = tables[(n + worker) % 4] }
                else { osc.drainRetiredUserTablesMain() }
            }
        }
        osc.instanceUserCompiled = nil
        osc.drainRetiredUserTablesMain()
        XCTAssertEqual(osc.retiredUserTableCountForTesting, 0)
    }

    func testP2_5_StandalonePollMirrorsRenderSwitch() {
        let engine = AudioEngine()
        engine.wavetableEngine1.loadBuiltinRT(index: 3)
        engine.wavetableEngine2.loadBuiltinRT(index: 2)
        engine.pollMetering()
        XCTAssertEqual(engine.wavetableEngine1.rtPendingIndex.load(ordering: .relaxed), -1)
        XCTAssertEqual(engine.wavetableEngine2.rtPendingIndex.load(ordering: .relaxed), -1)
        XCTAssertEqual(engine.wavetableEngine1.currentBuiltinIndex, 3)
    }
}
