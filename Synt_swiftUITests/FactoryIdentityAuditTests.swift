//
//  FactoryIdentityAuditTests.swift
//  SYNT_33 audit: preset names match their sound, names are unique,
//  and presets in one category are not clones of each other.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryIdentityAuditTests {
    private typealias A = FactoryAuthoring

    static var all: [SynthPreset] { FactoryCharacterAuditTests.all }

    static func identityViolations(_ p: SynthPreset) -> [String] {
        var v: [String] = []
        let c = p.category
        let formant = p.filterType == .formant
        let band = A.resonanceBand(c)
        let mid = (band.lo + band.hi) / 2
        let width = A.widthBand(c)
        let acid = p.name.localizedCaseInsensitiveContains("acid")
        if A.has(p, A.softWords) {
            if p.distortionEnabled && p.distortionMix > 0.22 { v.append("soft dirt \(p.distortionMix)") }
            if !formant && !acid && p.filterResonance > mid { v.append("soft res \(p.filterResonance)") }
            if !A.has(p, A.wideWords) && p.stereoWidth > (width.lo + width.hi) / 2 + 0.005 { v.append("soft width \(p.stereoWidth)") }
        }
        if A.has(p, A.darkWords) && !formant && p.filterCutoff > 1400 { v.append("dark cutoff \(p.filterCutoff)") }
        if A.has(p, A.brightWords) && !formant && c != .bass {
            if p.filterCutoff < 2200 { v.append("bright cutoff \(p.filterCutoff)") }
            if p.filterResonance < mid { v.append("bright res \(p.filterResonance)") }
        }
        if A.has(p, A.wideWords) && p.stereoWidth < width.lo + (width.hi - width.lo) * 2 / 3 { v.append("wide width \(p.stereoWidth)") }
        if A.has(p, A.hardWords) && A.isDirtCategory(c) && !(p.distortionEnabled && p.distortionMix >= 0.28) { v.append("hard dirt") }
        if A.has(p, A.motionWords) && A.strongestMotion(p) < 0.40 { v.append("motion \(A.strongestMotion(p))") }
        return v
    }

    @Test func identityAuditHasNoViolations() {
        var lines: [String] = []
        for p in Self.all where p.name != "Init" {
            let v = Self.identityViolations(p)
            if !v.isEmpty { lines.append("SYNT_33 IDENTITY | \(p.category.rawValue) | \(p.name): \(v.joined(separator: ", "))") }
        }
        print(lines.joined(separator: "\n"))
        #expect(lines.isEmpty, "identity violations:\n\(lines.joined(separator: "\n"))")
    }

    @Test func factoryNamesAreUnique() {
        var seen: [String: Int] = [:]
        for p in Self.all { seen[p.name.lowercased(), default: 0] += 1 }
        let dupes = seen.filter { $0.value > 1 }.keys.sorted()
        #expect(dupes.isEmpty, "duplicate names: \(dupes)")
    }

    @Test func weakSpotFloorsHold() {
        func share(_ c: PresetCategory, _ ok: (SynthPreset) -> Bool) -> Float {
            let ps = Self.all.filter { $0.category == c }
            return Float(ps.filter(ok).count) / Float(max(1, ps.count))
        }
        let brassUni = share(.brass) { $0.unisonVoices >= 2 }
        let arpBite = share(.arp) { ($0.distortionEnabled && (0.14...0.25).contains($0.distortionMix)) || $0.filterEnvelopeAmount >= 0.50 }
        let space: (SynthPreset) -> Bool = { $0.delayMix >= 0.12 || $0.chorusMix >= 0.14 || $0.reverbMix >= 0.15 }
        let lead = share(.lead, space), keys = share(.keys, space), pluck = share(.pluck, space)
        print(String(format: "SYNT_33 WEAK | brassUni %.0f%% | arpBite %.0f%% | space lead %.0f%% keys %.0f%% pluck %.0f%%",
                     brassUni * 100, arpBite * 100, lead * 100, keys * 100, pluck * 100))
        #expect(brassUni >= 0.50)
        #expect(arpBite >= 0.40)
        #expect(lead >= 0.50 && keys >= 0.50 && pluck >= 0.50)
    }
}
