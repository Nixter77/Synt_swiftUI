#if DEBUG // SYNT_28: uses DEBUG-only test hooks; excluded from Release test builds
//
//  Stage28AuditTests.swift
//  Synt_swiftUITests
//
//  NIGHTLY_AUDIT_SYNT27 fixes: P2-1 set-atomic render adoption, P2-2 no global observer mute.
//

import XCTest
import AudioToolbox
import Synchronization
@testable import SynthCore

final class Stage28AuditTests: XCTestCase {
    static let desc = Stage27AuditTests.desc

    #if DEBUG
    // MARK: P2-1 — a render pull mid-publish keeps the previous set whole.

    func testP2_1_RenderPullMidPublishKeepsPreviousSetWhole() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        let engine = unit.engine
        var a = SynthPreset.defaultPreset
        a.osc1Volume = 0.11
        a.modMatrix = [ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.1)]
        a.mseg.points = []
        var b = SynthPreset.defaultPreset
        b.osc1Volume = 0.22
        b.modMatrix = (0..<3).map { _ in ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.2) }
        b.mseg.points = [DSPMSEGPoint(time: 0, value: 0), DSPMSEGPoint(time: 1, value: 1)]

        unit.adoptPresetForTesting(a)
        engine.pullPresetSnapshotRT()
        XCTAssertEqual(engine.oscillator1.volume, a.osc1Volume)
        XCTAssertEqual(engine.rtModMatrix.snapshot().1, 1)
        XCTAssertFalse(engine.mseg.hasPoints)

        nonisolated(unsafe) var midVolume: Float = -1
        nonisolated(unsafe) var midCount = -1
        nonisolated(unsafe) var midMSEG = true
        unit.adoptPublishHookForTesting = {
            // Stand in for one render block landing in the middle of the publication.
            engine.pullPresetSnapshotRT()
            midVolume = engine.oscillator1.volume
            midCount = engine.rtModMatrix.snapshot().1
            midMSEG = engine.mseg.hasPoints
        }
        unit.adoptPresetForTesting(b)
        unit.adoptPublishHookForTesting = nil
        XCTAssertEqual(midVolume, a.osc1Volume, "render adopted part of the new set mid-publish")
        XCTAssertEqual(midCount, 1, "render adopted part of the new set mid-publish")
        XCTAssertFalse(midMSEG, "render adopted the new MSEG with the old snapshot/matrix")

        engine.pullPresetSnapshotRT()
        XCTAssertEqual(engine.oscillator1.volume, b.osc1Volume)
        XCTAssertEqual(engine.rtModMatrix.snapshot().1, 3)
        XCTAssertTrue(engine.mseg.hasPoints)
        Stage27AuditTests.drainMain()
    }

    // MARK: P2-2 — host automation during a tree refresh is not dropped.

    func testP2_2_BackgroundSetValueDuringRefreshIsKept() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        Stage27AuditTests.drainMain()
        let tree = try XCTUnwrap(unit.parameterTree)
        let address = SynthParameterAddress.filterCutoff
        let param = try XCTUnwrap(tree.parameter(withAddress: address.rawValue))
        let target = address.clamped(param.minValue + (param.maxValue - param.minValue) * 0.37)
        XCTAssertNotEqual(unit.parameters.value(address.rawValue), target)

        let fired = Atomic<Bool>(false)
        unit.refreshLoopHookForTesting = { _ in
            guard !fired.exchange(true, ordering: .relaxed) else { return }
            let done = DispatchSemaphore(value: 0)
            DispatchQueue.global().async { param.value = target; done.signal() }
            done.wait()
        }
        unit.refreshParameterTreeFromStoreForTesting()
        unit.refreshLoopHookForTesting = nil
        XCTAssertEqual(unit.parameters.value(address.rawValue), target, "host automation lost during refresh")
        Stage27AuditTests.drainMain()
    }
    #endif
}

#endif
