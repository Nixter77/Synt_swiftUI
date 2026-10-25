//
//  Stage26AuditTests.swift
//  SYNT_26: nightly audit SYNT25 fixes. Every test fails (or traps) on eabdaee.
//

import XCTest
import AudioToolbox
import Synchronization
@testable import SynthCore

final class Stage26AuditTests: XCTestCase {
    static let desc = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice, componentSubType: 0x5379_6E74,
                                                componentManufacturer: 0x4E69_7872, componentFlags: 0, componentFlagsMask: 0)

    // MARK: P1-1 (R22-1) — hosts build the AU off main; DEBUG strict check must not trap.

    func testP1_1_AUConstructedOffMainDoesNotTripStrictCheck() throws {
        #if DEBUG
        XCTAssertTrue(AudioEngine.strictMainThreadApplyPreset, "strict check is the DEBUG default")
        #endif
        let done = expectation(description: "built")
        nonisolated(unsafe) var unit: SyntAudioUnit?
        DispatchQueue.global(qos: .userInitiated).async {
            unit = try? SyntAudioUnit(componentDescription: Self.desc)
            done.fulfill()
        }
        wait(for: [done], timeout: 10)
        let au = try XCTUnwrap(unit)
        #if DEBUG
        XCTAssertEqual(au.engine.applyPresetOffMainCountForTesting, 0)
        #endif
        XCTAssertTrue(au.engine.rendersAllReverbInDSP)
        XCTAssertTrue(au.engine.rendersAllDelayInDSP)
        XCTAssertTrue(au.engine.usesHostTransport)
        XCTAssertTrue(au.engine.cachedDSPReverb, "initial apply already saw the AU flags")
    }

    // MARK: P1-2 — snapshot buffers: one writer at a time, render's slot never written.

    func testP1_2_PresetBufferNeverTornUnderTwoWritersAndReader() {
        let buffer = RTPresetBuffer()
        let stop = Atomic<Bool>(false)
        let torn = Atomic<Int>(0)
        let pulls = Atomic<Int>(0)
        let group = DispatchGroup()
        for w in 0..<2 {
            DispatchQueue.global().async(group: group) {
                var n: Float = Float(w)
                while !stop.load(ordering: .relaxed) {
                    var snap = RTPresetSnapshot()
                    snap.osc1Volume = n
                    snap.frequencyShifterFeedback = n
                    buffer.publish(snap)
                    n += 2
                }
            }
        }
        DispatchQueue.global().async(group: group) {
            while !stop.load(ordering: .relaxed) {
                if let s = buffer.pullNewSnapshot() {
                    pulls.add(1, ordering: .relaxed)
                    if s.osc1Volume != s.frequencyShifterFeedback { torn.add(1, ordering: .relaxed) }
                }
            }
        }
        Thread.sleep(forTimeInterval: 1.0)
        stop.store(true, ordering: .relaxed)
        group.wait()
        XCTAssertGreaterThan(pulls.load(ordering: .relaxed), 100)
        XCTAssertEqual(torn.load(ordering: .relaxed), 0, "render pulled a mix of two publishes")
    }

    #if DEBUG
    func testP1_2_WriterNeverTargetsRenderSlot() {
        let buffer = RTPresetBuffer()
        buffer.publish(RTPresetSnapshot())
        XCTAssertNotNil(buffer.pullNewSnapshot())
        for _ in 0..<5 {
            let slots = buffer.slotsForTesting
            XCTAssertNotEqual(slots.read, slots.write)
            buffer.publish(RTPresetSnapshot())
        }
        let matrix = RTModMatrix()
        matrix.publish([ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 1, curve: .exponential)])
        let (slots, count) = matrix.snapshot()
        XCTAssertEqual(count, 1)
        let held = slots[0].tableBank
        XCTAssertEqual(held, matrix.readBankForTesting)
        for _ in 0..<5 {
            XCTAssertNotEqual(matrix.writeBankForTesting, held, "writer would overwrite render's tables")
            matrix.publish([ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.5, curve: .logarithmic)])
        }
        XCTAssertEqual(matrix.lookup(bank: held, slot: 0, source: 0.5), ModCurve.exponential.remap(0.5), accuracy: 0.02)
    }
    #endif

    func testP1_2_ModMatrixNeverTornUnderTwoWritersAndReader() {
        let matrix = RTModMatrix()
        let stop = Atomic<Bool>(false)
        let torn = Atomic<Int>(0)
        let group = DispatchGroup()
        for w in 0..<2 {
            DispatchQueue.global().async(group: group) {
                var n: Float = Float(w)
                while !stop.load(ordering: .relaxed) {
                    let count = w == 0 ? RTModMatrix.capacity : RTModMatrix.capacity / 2
                    matrix.publish((0..<count).map { _ in ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: n) })
                    n += 2
                }
            }
        }
        DispatchQueue.global().async(group: group) {
            while !stop.load(ordering: .relaxed) {
                let (slots, count) = matrix.snapshot()
                guard count > 0 else { continue }
                let first = slots[0].amount
                let expectedCount = Int(first) % 2 == 0 ? RTModMatrix.capacity : RTModMatrix.capacity / 2
                var bad = count != expectedCount
                for i in 0..<count where slots[i].amount != first { bad = true }
                if bad { torn.add(1, ordering: .relaxed) }
            }
        }
        Thread.sleep(forTimeInterval: 1.0)
        stop.store(true, ordering: .relaxed)
        group.wait()
        XCTAssertEqual(torn.load(ordering: .relaxed), 0, "render saw a bank being rewritten")
    }

    // MARK: P2-3 / P2-5 — adopt hop: only the newest applies; host automation survives it.

    static func drainMain() {
        let done = XCTestExpectation(description: "main drained")
        DispatchQueue.main.async { done.fulfill() }
        _ = XCTWaiter.wait(for: [done], timeout: 5)
    }

    func testP2_3_OlderHopDoesNotApplyBeforeNewest() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        let presets = SyntAudioUnit.factoryPresetsForTesting
        XCTAssertGreaterThan(presets.count, 2)
        let initialName = unit.engine.preset.name
        let (a, b) = (presets[1], presets[2])
        XCTAssertNotEqual(a.name, initialName)
        nonisolated(unsafe) var seenBetween = ""
        let queued = expectation(description: "queued")
        DispatchQueue.global().async {
            unit.currentPreset = a                       // hop A queued
            DispatchQueue.main.async { seenBetween = unit.engine.preset.name }
            unit.currentPreset = b                       // hop B queued
            queued.fulfill()
        }
        wait(for: [queued], timeout: 5)
        Self.drainMain()
        XCTAssertNotEqual(seenBetween, PresetBrowser.list[a.number].name, "stale hop A applied before B")
        XCTAssertEqual(unit.engine.preset.name, PresetBrowser.list[b.number].name)
    }

    func testP2_5_HopKeepsHostAutomationFromAfterAdopt() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        let target = SyntAudioUnit.factoryPresetsForTesting[1]
        let param = try XCTUnwrap(unit.parameterTree?.parameter(withAddress: SynthParameterAddress.filterCutoff.rawValue))
        let automated: AUValue = PresetBrowser.list[target.number].filterCutoff > 3000 ? 1200 : 6000
        let queued = expectation(description: "queued")
        DispatchQueue.global().async {
            unit.currentPreset = target                  // store <- preset; hop queued
            param.setValue(automated, originator: nil)   // host automation, before the hop
            queued.fulfill()
        }
        wait(for: [queued], timeout: 5)
        Self.drainMain()
        XCTAssertEqual(param.value, automated, accuracy: 0.5, "hop rolled host automation back")
    }

    // MARK: P2-4 — host-thread getters do not read main-owned engine.preset.

    func testP2_4_OffMainGettersSeeAdoptBeforeHop() throws {
        let unit = try SyntAudioUnit(componentDescription: Self.desc)
        let initialTail = unit.tailTime
        let list = PresetBrowser.list
        let idx = try XCTUnwrap(list.indices.dropFirst().first { SyntAudioUnit.tailTime(for: list[$0]) != initialTail })
        let target = SyntAudioUnit.factoryPresetsForTesting[idx]
        nonisolated(unsafe) var tail: TimeInterval = 0
        nonisolated(unsafe) var current: Int?
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            unit.currentPreset = target                  // hop cannot run: main is blocked below
            tail = unit.tailTime
            current = unit.currentPreset?.number
            done.signal()
        }
        done.wait()                                       // block main: engine.preset still old
        XCTAssertEqual(tail, SyntAudioUnit.tailTime(for: list[idx]), accuracy: 1e-9)
        XCTAssertEqual(current, idx)
        Self.drainMain()
    }

    // MARK: P2-6 — setFXOrder off main must not block on main.

    func testP2_6_SetFXOrderOffMainDoesNotWaitForMain() {
        let engine = AudioEngine(coreOnly: true)
        let order = Array(SynthPreset.defaultPreset.fxOrder.reversed())
        let done = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            engine.setFXOrder(order)
            done.signal()
        }
        // Main is blocked here; the old main.sync could not finish until this wait timed out.
        XCTAssertEqual(done.wait(timeout: .now() + 2), .success, "setFXOrder waited for main (deadlock risk)")
        Self.drainMain()
        XCTAssertEqual(engine.preset.fxOrder, SynthPreset.sanitizeFXOrder(order))
    }
}
