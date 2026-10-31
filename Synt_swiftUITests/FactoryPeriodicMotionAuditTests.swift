//
//  FactoryPeriodicMotionAuditTests.swift
//  SYNT_43: periodic-motion floors (PRESET_TASTE "C — Motion"). Velocity / keyTrack / env-only
//  motion and pitch-only vibrato do NOT count. Init/Default/Template exempt.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryPeriodicMotionAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }

    static let periodicSources: Set<ModSource> = [.lfo1, .lfo2, .mseg, .mseg2, .smoothRandom]

    /// Destination families of every periodic modulator on the preset.
    static func families(_ p: SynthPreset) -> Set<String> {
        var out = Set<String>()
        for e in p.modMatrix where periodicSources.contains(e.source) && abs(e.amount) >= 0.30 {
            if FactoryAuthoring.isDeadRow(e) || FactoryAuthoring.isFormantDeadRow(e, p) { continue }
            if FactoryAuthoring.pitchDestinations.contains(e.destination) { continue }
            if (e.source == .mseg && p.mseg.points.isEmpty) || (e.source == .mseg2 && p.mseg2.points.isEmpty) { continue }
            out.insert(family(e.destination))
        }
        func lfo(_ on: Bool, _ t: LFOTarget, _ d: Float) {
            guard on, t != .none, t != .pitch, d >= 0.30 else { return }
            if p.filterType == .formant && t == .filter { return }
            out.insert(t == .filter ? "cutoff" : t == .amplitude ? "amp" : "pan")
        }
        lfo(p.lfoEnabled, p.lfoTarget, p.lfoDepth)
        lfo(p.lfo2Enabled, p.lfo2Target, p.lfo2Depth)
        return out
    }

    static func family(_ d: ModDestination) -> String {
        switch d {
        case .cutoff, .resonance: return "cutoff"
        case .wtMorph1, .wtMorph2: return "wtMorph"
        case .vowel: return "vowel"
        case .amp: return "amp"
        case .pan: return "pan"
        case .pwm1, .pwm2: return "pwm"
        case .fm: return "fm"
        case .mix: return "mix"
        case .chorusMix, .delayMix, .reverbMix: return "fx"
        default: return d.rawValue
        }
    }

    static func hasPeriodic(_ p: SynthPreset) -> Bool { !families(p).isEmpty }

    static let targets: [PresetCategory: Float] = [
        .bass: 0.50, .lead: 0.60, .pad: 0.80, .strings: 0.80, .keys: 0.45, .pluck: 0.45,
        .brass: 0.40, .arp: 0.40, .fx: 0.40,
    ]

    static func log(_ s: String) {
        print(s)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synt43_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    @Test func periodicMotionFloors() {
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c && !["Init", "Default", "Template"].contains($0.name) }
            guard !ps.isEmpty else { continue }
            let miss = ps.filter { !Self.hasPeriodic($0) }
            let velOnly = miss.filter { FactoryAuthoring.strongestMotion($0) >= 0.30 }
            let pct = Float(ps.count - miss.count) / Float(ps.count)
            Self.log(String(format: "SYNT_43 PERIODIC | %@ | n %d | periodic %d | %.1f%% | nonPeriodicResidual %d",
                            c.rawValue, ps.count, ps.count - miss.count, pct * 100, velOnly.count))
            Self.log("SYNT_43 PERIODIC | \(c.rawValue) | miss \(miss.map(\.name))")
            if let t = Self.targets[c] { #expect(pct >= t, "\(c.rawValue) periodic \(pct) < \(t)") }
        }
    }

    @Test func destinationVariety() {
        for c in [PresetCategory.bass, .lead, .keys, .pad, .strings, .pluck] {
            var counts: [String: Int] = [:]
            for p in Self.all where p.category == c { for f in Self.families(p) { counts[f, default: 0] += 1 } }
            Self.log("SYNT_43 DEST | \(c.rawValue) | \(counts.sorted { $0.key < $1.key })")
            if [.bass, .lead, .keys].contains(c) { #expect(counts.keys.count >= 2, "\(c.rawValue) mono-destination \(counts)") }
        }
    }

    @Test func padStringsUnisonNotForced() {
        for p in Self.all where p.category == .pad || p.category == .strings {
            #expect(p.unisonVoices <= 2, "\(p.name) unison \(p.unisonVoices)")
        }
    }
}
