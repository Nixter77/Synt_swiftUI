//
//  EnumCaseEqualityTests.swift
//  The case-tag `==` in EnumCaseEquality.swift must agree with raw-value equality
//  for every pair of cases, and every enum must stay a 1-byte payload-free tag.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct EnumCaseEqualityTests {
    static func check<E: CaseIterable & RawRepresentable & Equatable & Hashable>(_ type: E.Type) where E.RawValue == String {
        #expect(MemoryLayout<E>.size == 1, "\(E.self) must stay a 1-byte case tag")
        let all = Array(E.allCases)
        #expect(all.count >= 2)
        #expect(Set(all.map(\.rawValue)).count == all.count, "\(E.self) raw values must be unique")
        for a in all {
            for b in all {
                #expect((a == b) == (a.rawValue == b.rawValue), "\(E.self).\(a.rawValue) vs \(b.rawValue)")
                if a == b { #expect(a.hashValue == b.hashValue) }
            }
            #expect(E(rawValue: a.rawValue) == a)
            let optional: E? = a
            #expect(optional == a)
        }
        #expect(Set(all).count == all.count)
    }

    @Test func caseTagEqualityMatchesRawValueEquality() {
        Self.check(AmpRetriggerMode.self)
        Self.check(ArpeggiatorMode.self)
        Self.check(CharacterMode.self)
        Self.check(ChordMode.self)
        Self.check(ChorusMode.self)
        Self.check(DSPMSEGSyncMode.self)
        Self.check(DSPMSEGTriggerMode.self)
        Self.check(DistortionType.self)
        Self.check(DualFilterRouting.self)
        Self.check(EnvelopeModel.self)
        Self.check(FMRoute.self)
        Self.check(FilterType.self)
        Self.check(GlideMode.self)
        Self.check(GlobalVoiceSourcePolicy.self)
        Self.check(LFOMode.self)
        Self.check(LFOTarget.self)
        Self.check(ModCurve.self)
        Self.check(ModDestination.self)
        Self.check(ModSource.self)
        Self.check(MonoPriority.self)
        Self.check(NoiseColor.self)
        Self.check(OscPhaseMode.self)
        Self.check(PhaserMode.self)
        Self.check(SyncSource.self)
        Self.check(TimeDivision.self)
        Self.check(VelocityCurve.self)
        Self.check(VoiceMode.self)
        Self.check(WaveformType.self)
        Self.check(MPEZone.self)
    }

    @Test func codableRoundTripStillUsesRawValues() throws {
        let data = try JSONEncoder().encode([LFOTarget.pan, LFOTarget.filter])
        let back = try JSONDecoder().decode([LFOTarget].self, from: data)
        #expect(back == [LFOTarget.pan, LFOTarget.filter])
        #expect(String(decoding: data, as: UTF8.self).contains(LFOTarget.pan.rawValue))
    }
}
