//
//  Stage17Stage4Tests.swift
//  SYNT_17 Stage 4: R13-7, standalone CoreMIDI thread reads MPE routing through one atomic word.
//
import XCTest
import Foundation
import Synchronization
@testable import SynthCore

final class Stage17Stage4Tests: XCTestCase {

    /// Fails on old code (no `standaloneMPERouting`): main writes are published atomically.
    func testR13_7_MainWritesPublishAtomicSnapshot() {
        let e = AudioEngine(coreOnly: true)
        XCTAssertFalse(e.standaloneMPESnapshot().enabled)
        XCTAssertEqual(e.standaloneMPESnapshot().memberCount, 15)
        e.mpeEnabled = true
        e.mpeZone = .upper
        e.mpeMemberChannelCount = 4
        let r = e.standaloneMPESnapshot()
        XCTAssertTrue(r.enabled); XCTAssertEqual(r.zone, .upper); XCTAssertEqual(r.memberCount, 4)
        XCTAssertTrue(e.isStandaloneMPEMember(14))
        XCTAssertTrue(e.isStandaloneMPEMember(11))
        XCTAssertFalse(e.isStandaloneMPEMember(10))
    }

    /// Fails on old code: the MIDI-thread helpers read the plain vars, not the atomic word.
    func testR13_7_MIDIThreadHelpersReadOnlyTheAtomic() {
        let e = AudioEngine(coreOnly: true)
        e.standaloneMPERouting.store(1 | (3 << 2), ordering: .releasing) // on, lower, 3 members
        XCTAssertFalse(e.mpeEnabled, "vars untouched")
        XCTAssertTrue(e.isStandaloneMPEMember(1))
        XCTAssertFalse(e.isStandaloneMPEMember(5))
        XCTAssertTrue(e.midiMPEControlChange(controller: 74, value: 64, channel: 2))
    }

    /// Concurrent main writes vs a MIDI-thread reader: every snapshot is one of the written configs.
    func testR13_7_ConcurrentSnapshotsAreConsistent() {
        let e = AudioEngine(coreOnly: true)
        let stop = Atomic<Bool>(false)
        let bad = Atomic<Int>(0)
        let done = expectation(description: "reader")
        DispatchQueue.global(qos: .userInteractive).async {
            while !stop.load(ordering: .relaxed) {
                let r = e.standaloneMPESnapshot()
                if r.memberCount > 15 { bad.add(1, ordering: .relaxed) }
                _ = e.isStandaloneMPEMember(3)
            }
            done.fulfill()
        }
        for i in 0..<20_000 {
            e.mpeEnabled = i & 1 == 0
            e.mpeZone = i & 2 == 0 ? .lower : .upper
            e.mpeMemberChannelCount = i % 16
        }
        stop.store(true, ordering: .relaxed)
        wait(for: [done], timeout: 10)
        XCTAssertEqual(bad.load(ordering: .relaxed), 0)
    }
}
