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
}
