//
//  FlagsOffInvarianceTests.swift
//  SYNT_34: every experimental / optional DSP gate defaults off, and
//  the default-constructed preset renders bit-identical to Init golden.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FlagsOffInvarianceTests {
    static let initGolden: UInt64 = 0xd1b3635203a4799e

    @Test func experimentalGatesDefaultOff() {
        for p in [SynthPreset.defaultPreset, SynthPreset(name: "Init", category: .lead)] {
            #expect(p.filter2Routing == .off)
            #expect(p.filterType != .formant)
            #expect(p.mseg.points.isEmpty)
            #expect(p.mseg2.points.isEmpty)
            #expect(p.character == .off)
            #expect(!p.rotaryEnabled)
            #expect(!p.transientEnabled)
            #expect(!p.frequencyShifterEnabled)
            #expect(!p.mpeEnabled)
            #expect(!p.fmRatioEnabled)
            #expect(!p.tranceGateEnabled)
            #expect(!p.dspReverbEnabled)
            #expect(!p.sceneHPFEnabled)
            #expect(!p.oscSyncEnabled)
        }
    }

    @Test func defaultsRenderInitGolden() {
        #expect(InitGoldenTests.renderHash(.defaultPreset) == Self.initGolden)
        // Fresh value-identical Init. Same id as the engine's boot preset so the
        // harness does not hit the patch-switch fade (identity, not a flag).
        var fresh = SynthPreset(name: "Init", category: .lead)
        fresh.id = SynthPreset.defaultPreset.id
        #expect(InitGoldenTests.renderHash(fresh) == Self.initGolden)
    }

    @Test func sanitizedDefaultsStayInitGolden() {
        let p = SynthPreset.defaultPreset
        let data = try! JSONEncoder().encode(p)
        let round = try! JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(InitGoldenTests.renderHash(round) == Self.initGolden)
    }
}
