//
//  FactoryDspReverbEnableAuditTests.swift
//  SYNT_51: hard gate — any non-Init preset with reverbMix > 0 must set dspReverbEnabled.
//  Factory + expansion + MPE; Init/Default/Template excluded.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryDspReverbEnableAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }
    static var misses: [SynthPreset] { all.filter { $0.reverbMix > 0 && !$0.dspReverbEnabled } }

    @Test func inventory() {
        let wet = Self.all.filter { $0.reverbMix > 0 }.count
        FactoryDirtDriveAuditTests.log("SYNT_51 REV | total \(Self.all.count) | reverbMix>0 \(wet) | misses \(Self.misses.count)")
        for p in Self.misses {
            FactoryDirtDriveAuditTests.log("SYNT_51 MISS | \(p.name) | \(p.category.rawValue) | mix \(p.reverbMix)")
        }
    }

    @Test func gate() {
        for p in Self.misses {
            #expect(Bool(false), "dspReverb miss \(p.name) mix \(p.reverbMix)")
        }
        #expect(Self.misses.isEmpty, "misses \(Self.misses.count)")
    }
}
