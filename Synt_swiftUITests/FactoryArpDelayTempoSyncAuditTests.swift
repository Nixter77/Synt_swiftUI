//
//  FactoryArpDelayTempoSyncAuditTests.swift
//  SYNT_53: hard gate — non-Init Arp with delayMix >= 0.12 must set delayTempoSync.
//  Factory + expansion + MPE; Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryArpDelayTempoSyncAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    static var participants: [SynthPreset] { all.filter { $0.category == .arp && $0.delayMix >= 0.12 } }
    static var misses: [SynthPreset] { participants.filter { !$0.delayTempoSync } }

    @Test func inventory() {
        FactoryDirtDriveAuditTests.log("SYNT_53 ARPSYNC | total \(Self.all.count) | arp delay>=0.12 \(Self.participants.count) | misses \(Self.misses.count)")
        for p in Self.misses {
            FactoryDirtDriveAuditTests.log("SYNT_53 MISS | \(p.name) | mix \(p.delayMix)")
        }
    }

    @Test func gate() {
        for p in Self.misses {
            #expect(Bool(false), "arp delayTempoSync miss \(p.name) mix \(p.delayMix)")
        }
        #expect(Self.misses.isEmpty, "misses \(Self.misses.count)")
    }
}
