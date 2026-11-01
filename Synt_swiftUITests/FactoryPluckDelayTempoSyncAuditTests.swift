//
//  FactoryPluckDelayTempoSyncAuditTests.swift
//  SYNT_52: hard gate — non-Init Pluck with delayMix >= 0.12 must set delayTempoSync.
//  Factory + expansion + MPE; Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryPluckDelayTempoSyncAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    static var participants: [SynthPreset] { all.filter { $0.category == .pluck && $0.delayMix >= 0.12 } }
    static var misses: [SynthPreset] { participants.filter { !$0.delayTempoSync } }

    @Test func inventory() {
        FactoryDirtDriveAuditTests.log("SYNT_52 PLUCKSYNC | total \(Self.all.count) | pluck delay>=0.12 \(Self.participants.count) | misses \(Self.misses.count)")
        for p in Self.misses {
            FactoryDirtDriveAuditTests.log("SYNT_52 MISS | \(p.name) | mix \(p.delayMix)")
        }
    }

    @Test func gate() {
        for p in Self.misses {
            #expect(Bool(false), "pluck delayTempoSync miss \(p.name) mix \(p.delayMix)")
        }
        #expect(Self.misses.isEmpty, "misses \(Self.misses.count)")
    }
}
