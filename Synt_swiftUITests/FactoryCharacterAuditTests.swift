//
//  FactoryCharacterAuditTests.swift
//  SYNT_32 audit: scans the shipped banks for the PRESET_TASTE floors
//  (rule blocks A–E) and dead paths. Prints a per-category table.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryCharacterAuditTests {
    private typealias A = FactoryAuthoring

    static var all: [SynthPreset] {
        SynthPreset.factoryPresets + SynthPreset.expansionPresets + SynthPreset.mpeFactoryPresets
    }

    static func fxWet(_ p: SynthPreset) -> Float { max(p.reverbMix, p.delayMix, p.chorusMix) }

    static func upperCount(_ p: SynthPreset) -> Int {
        let band = A.resonanceBand(p.category)
        var n = 0
        if p.filterType != .formant {
            if p.filterResonance >= band.lo + (band.hi - band.lo) * 2 / 3 { n += 1 }
            if p.filterEnvelopeAmount >= 0.50 { n += 1 }
        }
        if p.distortionEnabled && p.distortionMix >= 0.29 { n += 1 }
        if A.strongestMotion(p) >= 0.40 { n += 1 }
        if fxWet(p) >= 0.26 { n += 1 }
        return n
    }

    static func slowPadMotion(_ p: SynthPreset) -> Bool {
        let dests: Set<ModDestination> = p.filterType == .formant ? [.vowel] : [.cutoff, .wtMorph1, .wtMorph2, .vowel]
        func slow(_ r: Float) -> Bool { (0.05...0.30).contains(r) }
        if p.lfoEnabled && p.lfoTarget == .filter && p.filterType != .formant && p.lfoDepth >= 0.30 && slow(p.lfoRate) { return true }
        if p.lfo2Enabled && p.lfo2Target == .filter && p.filterType != .formant && p.lfo2Depth >= 0.30 && slow(p.lfo2Rate) { return true }
        return p.modMatrix.contains { e in
            guard dests.contains(e.destination), abs(e.amount) >= 0.30 else { return false }
            switch e.source {
            case .lfo1: return !p.lfoTempoSync && slow(p.lfoRate)
            case .lfo2: return !p.lfo2TempoSync && slow(p.lfo2Rate)
            case .mseg: return !p.mseg.points.isEmpty && slow(p.mseg.rateHz)
            case .mseg2: return !p.mseg2.points.isEmpty && slow(p.mseg2.rateHz)
            default: return false
            }
        }
    }

    /// Per-preset rule violations.
    static func violations(_ p: SynthPreset) -> [String] {
        var v: [String] = []
        let c = p.category
        let fxRelaxed = c == .fx
        for e in p.modMatrix {
            if A.isDeadRow(e) { v.append("dead \(e.source.rawValue)→\(e.destination.rawValue)") }
            if abs(e.amount) < 0.15 { v.append("row<0.15 \(e.source.rawValue)→\(e.destination.rawValue) \(e.amount)") }
        }
        if A.strongestMotion(p) < 0.30 { v.append("motion \(A.strongestMotion(p))") }
        if p.distortionEnabled && p.distortionMix < 0.12 { v.append("dirt on <0.12") }
        if p.distortionEnabled && p.distortionMix > 0.35 { v.append("dirt >0.35") }
        if p.filterResonance > 0.70 { v.append("res >0.70") }
        if p.delayMix > (fxRelaxed ? 0.30 : 0.22) { v.append("delay cap") }
        if p.chorusMix > (fxRelaxed ? 0.30 : 0.22) { v.append("chorus cap") }
        if p.reverbMix > (fxRelaxed ? 0.45 : 0.35) { v.append("reverb cap") }
        if p.name.localizedCaseInsensitiveContains("acid") {
            if p.filterResonance < 0.60 || p.filterEnvelopeAmount < 0.55 { v.append("acid res/env") }
            if !(0.02...0.08).contains(p.portamento) { v.append("acid porta") }
            if !(p.distortionEnabled && p.distortionMix >= 0.20) { v.append("acid dirt") }
        }
        switch c {
        case .pad, .strings:
            if !slowPadMotion(p) { v.append("pad slow motion") }
            if !(0.20...0.30).contains(p.reverbMix) || !p.dspReverbEnabled { v.append("pad reverb \(p.reverbMix)") }
            if p.chorusMix < 0.14 { v.append("chorus <0.14") }
            if p.unisonVoices > 2 { v.append("pad unison >2") }
        case .keys:
            if p.chorusMix < 0.14 { v.append("chorus <0.14") }
            if p.fmAmount > 0 && p.fmAmount < 0.15 { v.append("fm <0.15") }
            if !(p.velocityToCutoff >= 0.15 || p.modMatrix.contains { $0.source == .velocity && $0.destination == .cutoff }) { v.append("vel→cutoff") }
            if !p.modMatrix.contains(where: { $0.source == .velocity && $0.destination == .amp }) { v.append("vel→amp") }
        case .lead:
            if p.delayMix < 0.12 { v.append("lead delay") }
            if p.lfoEnabled && p.lfoTarget == .pitch && p.lfoDepth < 0.10 { v.append("vibrato") }
        case .arp:
            if p.delayMix < 0.12 { v.append("arp delay") }
            if !(0.3...0.6).contains(p.arpGateLength) { v.append("arp gate") }
        case .pluck:
            if p.delayMix > 0 && p.delayMix < 0.12 { v.append("pluck delay") }
            if p.sustain > 0.25 { v.append("pluck sustain") }
        case .fx:
            if fxWet(p) < 0.30 { v.append("fx wet") }
        case .brass:
            if p.filterType != .formant && p.filterEnvelopeAmount < 0.40 { v.append("brass env") }
        case .bass:
            break
        }
        if p.name.localizedCaseInsensitiveContains("bell") && p.fmAmount > 0 && p.fmAmount < 0.15 { v.append("bell fm") }
        if p.reverbMix > 0 && p.modMatrix.contains(where: { $0.destination == .reverbMix }) && !p.dspReverbEnabled {
            v.append("reverb matrix w/o dsp")
        }
        return v
    }

    static func median(_ xs: [Float]) -> Float {
        guard !xs.isEmpty else { return 0 }
        let s = xs.sorted()
        return s[s.count / 2]
    }

    @Test func characterAuditHasNoViolations() {
        let presets = Self.all.filter { A.characterCategories.contains($0.category) }
        var lines = ["SYNT_32 AUDIT | cat | n | upper% | dirt% | uni2% | minMod | width lo–hi | maxWidthBucket | violations"]
        var total = 0
        for c in PresetCategory.allCases where A.characterCategories.contains(c) {
            let ps = presets.filter { $0.category == c }
            guard !ps.isEmpty else { continue }
            let n = Float(ps.count)
            let upper = Float(ps.filter { Self.upperCount($0) >= 2 }.count) / n
            let dirt = Float(ps.filter { $0.distortionEnabled && (0.18...0.35).contains($0.distortionMix) }.count) / n
            let uni = Float(ps.filter { $0.unisonVoices >= 2 }.count) / n
            let minMod = ps.map(A.strongestMotion).min() ?? 0
            var buckets: [Int: Int] = [:]
            for p in ps { buckets[Int((p.stereoWidth / 0.02).rounded()), default: 0] += 1 }
            let maxBucket = buckets.values.max() ?? 0
            var catViolations: [String] = []
            if upper < 0.30 { catViolations.append("A upper \(upper)") }
            if [.bass, .lead, .brass].contains(c) && dirt < 0.60 { catViolations.append("B dirt \(dirt)") }
            if [.bass, .lead].contains(c) && uni < 0.50 { catViolations.append("E unison \(uni)") }
            if maxBucket > 3 { catViolations.append("E width bucket \(maxBucket)") }
            for p in ps {
                let v = Self.violations(p)
                if !v.isEmpty { catViolations.append("\(p.name): \(v.joined(separator: ", "))") }
            }
            total += catViolations.count
            let widths = ps.map(\.stereoWidth)
            lines.append(String(
                format: "SYNT_32 AUDIT | %@ | %d | %.0f | %.0f | %.0f | %.2f | %.2f–%.2f | %d | %d",
                c.rawValue, ps.count, upper * 100, dirt * 100, uni * 100, minMod,
                widths.min() ?? 0, widths.max() ?? 0, maxBucket, catViolations.count
            ))
            for item in catViolations { lines.append("SYNT_32 VIOLATION | \(c.rawValue) | \(item)") }
        }
        let dirtOn = presets.filter(\.distortionEnabled).map(\.distortionMix)
        lines.append(String(
            format: "SYNT_32 MEDIANS | res %.2f | dirtMix %.2f (on %d/%d) | delay %.2f | chorus %.2f | reverb %.2f | mod %.2f | unison2 %d | dead %d",
            Self.median(presets.map(\.filterResonance)), Self.median(dirtOn), dirtOn.count, presets.count,
            Self.median(presets.map(\.delayMix)), Self.median(presets.map(\.chorusMix)),
            Self.median(presets.map(\.reverbMix)), Self.median(presets.map(A.strongestMotion)),
            presets.filter { $0.unisonVoices >= 2 }.count,
            presets.flatMap(\.modMatrix).filter(A.isDeadRow).count
        ))
        print(lines.joined(separator: "\n"))
        #expect(total == 0, "SYNT_32 audit violations: \(total)")
    }

    @Test func characterPresetsDoNotClip() {
        for preset in Self.all where A.characterCategories.contains(preset.category) {
            var patch = preset
            patch.arpMode = .off
            let engine = AudioEngine()
            engine.preset = patch
            engine.applyPresetForTesting()
            engine.clearAllNotes()
            engine.processCommandsForTesting()
            engine.noteOn(midiNote: 48, velocity: 1.0)
            engine.noteOn(midiNote: 55, velocity: 1.0)
            engine.noteOn(midiNote: 60, velocity: 1.0)
            engine.processCommandsForTesting()
            let m = engine.renderFramesMetricsForTesting(44_100)
            print(String(format: "SYNT_32 PEAK | %@ | %@ | peak %.3f | preClip %.3f | nearClip %d", preset.category.rawValue, preset.name, m.peak, m.preClipPeak, m.nearClipCount))
            #expect(m.nanCount == 0, "\(preset.name) NaN")
            #expect(m.peak > 0.005, "\(preset.name) silent")
            #expect(m.nearClipCount == 0, "\(preset.name) clips \(m.nearClipCount) samples (preClip \(m.preClipPeak))")
        }
    }
}
