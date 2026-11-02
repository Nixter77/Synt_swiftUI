//
//  FactoryStringsLfoStaggerAuditTests.swift
//  SYNT_56: Strings primary slow-motion rate stagger — max 0.01 bucket <= 40%, >= 5 distinct, slowPadMotion 12/12.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryStringsLfoStaggerAuditTests {
    static var strings: [SynthPreset] { FactorySoftCapAuditTests.all.filter { $0.category == .strings } }
    static func primaryRate(_ p: SynthPreset) -> Float? {
        func slow(_ r: Float) -> Bool { (0.05...0.30).contains(r) }
        if p.lfoEnabled && p.lfoTarget == .filter && p.filterType != .formant && p.lfoDepth >= 0.30 && slow(p.lfoRate) { return p.lfoRate }
        if p.lfo2Enabled && p.lfo2Target == .filter && p.filterType != .formant && p.lfo2Depth >= 0.30 && slow(p.lfo2Rate) { return p.lfo2Rate }
        let dests: Set<ModDestination> = p.filterType == .formant ? [.vowel] : [.cutoff, .wtMorph1, .wtMorph2, .vowel]
        for e in p.modMatrix where dests.contains(e.destination) && abs(e.amount) >= 0.30 {
            switch e.source {
            case .lfo1 where !p.lfoTempoSync && slow(p.lfoRate): return p.lfoRate
            case .lfo2 where !p.lfo2TempoSync && slow(p.lfo2Rate): return p.lfo2Rate
            case .mseg where !p.mseg.points.isEmpty && slow(p.mseg.rateHz): return p.mseg.rateHz
            case .mseg2 where !p.mseg2.points.isEmpty && slow(p.mseg2.rateHz): return p.mseg2.rateHz
            default: continue
            }
        }
        return nil
    }
    static var hist: [Int: Int] {
        var h: [Int: Int] = [:]
        for p in strings { if let r = primaryRate(p) { h[Int((r * 100).rounded()), default: 0] += 1 } }
        return h
    }

    @Test func inventory() {
        FactoryDirtDriveAuditTests.log("SYNT_56 STRLFO | n \(Self.strings.count) | hist \(Self.hist.sorted { $0.key < $1.key })")
        for p in Self.strings { FactoryDirtDriveAuditTests.log("SYNT_56 ROW | \(p.name) | \(Self.primaryRate(p).map { String(format: "%.2f", $0) } ?? "-")") }
    }
    @Test func slowPadMotionAll() {
        for p in Self.strings { #expect(FactoryCharacterAuditTests.slowPadMotion(p), "slow miss \(p.name)") }
    }
    @Test func maxBucket() {
        let n = Self.strings.count, m = Self.hist.values.max() ?? 0
        #expect(Double(m) <= 0.40 * Double(n), "max bucket \(m)/\(n)")
    }
    @Test func distinct() { #expect(Self.hist.count >= 5, "distinct \(Self.hist.count)") }
}
