//
//  Stage27AuditTests.swift
//  Synt_swiftUITests
//
//  NIGHTLY_AUDIT_SYNT26 fixes (SYNT_27): P2-1 publication set, P2-2 preset mirror, P3-3 setFXOrder.
//

import XCTest
import AudioToolbox
import Synchronization
@testable import SynthCore

final class Stage27AuditTests: XCTestCase {
    static let desc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                componentSubType: 0x5379_6E74,
                                                componentManufacturer: 0x4E69_7872,
                                                componentFlags: 0, componentFlagsMask: 0)

    static func drainMain() {
        let done = XCTestExpectation(description: "main drained")
        DispatchQueue.main.async { done.fulfill() }
        _ = XCTWaiter.wait(for: [done], timeout: 5)
    }

    // MARK: P2-1 — two parallel adopts leave render with a coherent preset/matrix pair.

    #if DEBUG
    func testP2_1_ParallelAdoptsLeaveCoherentPresetMatrixPair() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        var a = SynthPreset.defaultPreset
        a.osc1Volume = 0.11
        a.modMatrix = [ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.1)]
        var b = SynthPreset.defaultPreset
        b.osc1Volume = 0.22
        b.modMatrix = (0..<3).map { _ in ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.2) }

        let aInside = DispatchSemaphore(value: 0)
        let bDone = DispatchSemaphore(value: 0)
        let first = Atomic<Bool>(true)
        // Adopt A pauses between its snapshot and matrix publishes until B finished (or 0.5 s,
        // when B is correctly held off by the publication lock).
        unit.adoptPublishHookForTesting = {
            guard first.exchange(false, ordering: .relaxed) else { return }
            aInside.signal()
            _ = bDone.wait(timeout: .now() + 0.5)
        }
        let group = DispatchGroup()
        DispatchQueue.global().async(group: group) { unit.adoptPresetForTesting(a) }
        aInside.wait()
        DispatchQueue.global().async(group: group) { unit.adoptPresetForTesting(b); bDone.signal() }
        XCTAssertEqual(group.wait(timeout: .now() + 5), .success)
        unit.adoptPublishHookForTesting = nil

        let snap = try XCTUnwrap(unit.engine.rtPresetBuffer.pullNewSnapshot())
        let (_, count) = unit.engine.rtModMatrix.snapshot()
        let expectedCount = snap.osc1Volume == b.osc1Volume ? 3 : 1
        XCTAssertEqual(count, expectedCount, "render holds preset \(snap.osc1Volume) with another preset's matrix")
        Self.drainMain()
    }
    #endif

    // MARK: P2-2 — off-main readers see main-side preset edits (mirror kept current).

    func testP2_2_OffMainTailSeesMainPresetEditAfterAdopt() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        unit.currentPreset = SyntAudioUnit.factoryPresetsForTesting[1]   // fills the mirror
        Self.drainMain()
        unit.engine.preset.release = unit.engine.preset.release + 3.0    // UI edit on main
        let expected = SyntAudioUnit.tailTime(for: unit.engine.preset)
        nonisolated(unsafe) var tail: TimeInterval = 0
        let done = expectation(description: "off main")
        DispatchQueue.global().async { tail = unit.tailTime; done.fulfill() }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(tail, expected, accuracy: 1e-9, "off-main reader saw a stale preset")
    }

    // MARK: P3-3 — setFXOrder off main has no window where render's order rolls back.

    func testP3_3_OffMainSetFXOrderNeverRolledBackByMainApply() {
        let engine = AudioEngine(coreOnly: true)
        let old = engine.cachedFXOrder
        let order = Array(SynthPreset.defaultPreset.fxOrder.reversed())
        let newTable = FXOrderTable(order: SynthPreset.sanitizeFXOrder(order))
        XCTAssertNotEqual(old, newTable)
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { engine.setFXOrder(order); done.signal() }
        XCTAssertEqual(done.wait(timeout: .now() + 2), .success)
        let afterCall = engine.cachedFXOrder
        engine.applyPreset()                         // main apply before the hop runs
        let afterApply = engine.cachedFXOrder
        if afterCall == newTable {
            XCTAssertEqual(afterApply, newTable, "main applyPreset rolled the FX order back")
        }
        Self.drainMain()
        XCTAssertEqual(engine.cachedFXOrder, newTable)
        XCTAssertEqual(engine.preset.fxOrder, SynthPreset.sanitizeFXOrder(order))
    }
}
