//
//  FactoryDynamicsAuditTests.swift
//  SYNT_66: non-FX factory / expansion / MPE presets have a real velocity range,
//  a brighter hard hit, and a monotonic pre-bus curve. Same probe as D0.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
@Suite(.serialized)
struct FactoryDynamicsAuditTests {
    static var played: [SynthPreset] {
        FactoryCharacterAuditTests.all.filter { $0.name != "Init" && $0.category != .fx }
    }

    private static func row(_ p: SynthPreset, _ source: ModSource, _ destination: ModDestination) -> Float {
        p.modMatrix.filter { $0.source == source && $0.destination == destination }.map { abs($0.amount) }.max() ?? 0
    }

    @Test func authoredDynamicsMatchTheCategoryRecipe() {
        let presets = Self.played
        #expect(!presets.isEmpty)
        var misses: [String] = []
        for p in presets {
            if p.velocityCurve != .decibel { misses.append("\(p.name) curve") }
            if p.velocityToVolume < 1 { misses.append("\(p.name) toVolume \(p.velocityToVolume)") }
            if p.velocityCurveShape != 0 { misses.append("\(p.name) shape") }
            if p.envelopeModel == .legacy { misses.append("\(p.name) envModel legacy") }
            if !p.respondToExpressionCC { misses.append("\(p.name) CC11 off") }
            if !(0.25...0.40).contains(p.aftertouchCurve) { misses.append("\(p.name) atCurve \(p.aftertouchCurve)") }
            if !(0.04...0.06).contains(p.aftertouchDeadzone) { misses.append("\(p.name) atDeadzone \(p.aftertouchDeadzone)") }
            if p.unisonVoices > 1 && !p.keepUnisonThroughTails { misses.append("\(p.name) keepUnison off") }
            if (p.voiceMode == .mono || p.voiceMode == .legato) && !p.legatoUpdatesVelocity { misses.append("\(p.name) legatoVel off") }
            if p.voiceMode == .legato && p.ampRetriggerMode != .legatoNoRetrigger { misses.append("\(p.name) legatoRetrigger") }
            if p.globalVoiceSourcePolicy == .loudest && p.category != .bass { misses.append("\(p.name) globalPolicy loudest") }
            if !(0.08...0.40).contains(p.envKeyTrack) { misses.append("\(p.name) keyTrack \(p.envKeyTrack)") }
            if !(0.15...0.35).contains(p.releaseVelToRelease) { misses.append("\(p.name) relVelToRel \(p.releaseVelToRelease)") }
            switch p.category {
            case .keys, .pluck, .bass, .lead:
                if !(24...36).contains(p.velocityRangeDb) { misses.append("\(p.name) range \(p.velocityRangeDb)") }
                if p.velToAttack != 0.20 { misses.append("\(p.name) velToAttack \(p.velToAttack)") }
                if p.filterDecayCurve != -0.35 { misses.append("\(p.name) decayCurve \(p.filterDecayCurve)") }
                if p.filterReleaseCurve != -0.25 { misses.append("\(p.name) relCurve \(p.filterReleaseCurve)") }
                if !(-0.16 ... -0.08).contains(p.velToDecay) { misses.append("\(p.name) velToDecay \(p.velToDecay)") }
                if Self.row(p, .velocity, .drive) < 0.15 { misses.append("\(p.name) drive \(Self.row(p, .velocity, .drive)) matrix \(p.modMatrix.count)") }
            case .pad, .strings:
                if !(13...18).contains(p.velocityRangeDb) { misses.append("\(p.name) range \(p.velocityRangeDb)") }
                if p.velToAttack != 0.15 { misses.append("\(p.name) velToAttack \(p.velToAttack)") }
                if p.filterAttackCurve != 0.25 { misses.append("\(p.name) attCurve \(p.filterAttackCurve)") }
                if p.filterReleaseCurve != -0.20 { misses.append("\(p.name) relCurve \(p.filterReleaseCurve)") }
                if !p.respondToExpressionCC { misses.append("\(p.name) CC11 off") }
            case .brass:
                if !(24...36).contains(p.velocityRangeDb) { misses.append("\(p.name) range \(p.velocityRangeDb)") }
                if !(0.24...0.34).contains(p.velToAttack) { misses.append("\(p.name) velToAttack \(p.velToAttack)") }
                if p.ampHold < 0.020 || p.filterEnvHold < 0.020 { misses.append("\(p.name) hold \(p.ampHold) \(p.filterEnvHold)") }
                if p.velocityToEnvAmount < 0.55 { misses.append("\(p.name) velEnv \(p.velocityToEnvAmount)") }
            case .arp:
                if !(20...32).contains(p.velocityRangeDb) { misses.append("\(p.name) range \(p.velocityRangeDb)") }
                if p.velToAttack != 0.18 { misses.append("\(p.name) velToAttack \(p.velToAttack)") }
                if Self.row(p, .velocity, .drive) < 0.15 { misses.append("\(p.name) drive \(Self.row(p, .velocity, .drive)) matrix \(p.modMatrix.count)") }
                if p.filterType != .formant && Self.row(p, .velocity, .cutoff) < 0.20 && p.velocityToCutoff < 0.28 {
                    misses.append("\(p.name) arp cutoff")
                }
            default:
                misses.append("\(p.name) unexpected \(p.category.rawValue)")
            }
            if p.category == .pluck && !(0.20...0.40).contains(p.envKeyTrack) {
                misses.append("\(p.name) keyTrack \(p.envKeyTrack)")
            }
            if p.filterType == .formant {
                if Self.row(p, .velocity, .vowel) < 0.15 { misses.append("\(p.name) vowel \(Self.row(p, .velocity, .vowel)) matrix \(p.modMatrix.count)") }
            } else if p.velocityToCutoff < 0.28 && Self.row(p, .velocity, .cutoff) < 0.20 {
                misses.append("\(p.name) bright \(p.velocityToCutoff)")
            }
            if p.arpMode != .off && !p.arpUsesInputVelocity { misses.append("\(p.name) arp vel off") }
            if p.mpeEnabled {
                if Self.row(p, .mpePressure, .amp) < 0.15 { misses.append("\(p.name) pressure amp") }
                let release = Self.row(p, .releaseVelocity, .ampRelease)
                if release < 0.15 { misses.append("\(p.name) release vel \(release) matrix \(p.modMatrix.count)") }
                let pressureTone = p.filterType == .formant ? Self.row(p, .mpePressure, .vowel) : Self.row(p, .mpePressure, .cutoff)
                if pressureTone < 0.15 { misses.append("\(p.name) pressure tone") }
            }
            if p.modMatrix.contains(where: { abs($0.amount) < 0.15 }) { misses.append("\(p.name) row<0.15") }
        }
        let fx = FactoryCharacterAuditTests.all.filter { $0.category == .fx }
        for p in fx {
            if p.velocityRangeDb != 0 || p.velToAttack != 0 || p.respondToExpressionCC || p.arpUsesInputVelocity {
                misses.append("fx touched \(p.name)")
            }
        }
        let initPreset = SynthPreset.defaultPreset
        #expect(initPreset.velocityRangeDb == 0)
        #expect(initPreset.velToAttack == 0)
        #expect(initPreset.velocityCurve != .decibel)
        #expect(initPreset.respondToExpressionCC == false)
        #expect(misses.isEmpty, "\(misses.prefix(24).joined(separator: " | "))")
    }

    /// C4, pre-CleanBus RMS, MIDI 1…127. VelBright is centroid(127) / centroid(32).
    @Test(.timeLimit(.minutes(40)))
    func voiceRangeIsAtLeast12dBBrightAndMonotonic() {
        var failures: [String] = []
        for p in Self.played {
            var patch = p
            patch.arpMode = .off
            let engine = AudioEngine()
            engine.preset = patch
            engine.applyPresetForTesting()
            var takes: [DynamicsProbe.Take] = []
            var nan = false
            for midi in DynamicsProbe.midiVelocities {
                let take = DynamicsProbe.render(engine: engine, notes: [(60, DynamicsProbe.midi(midi))])
                if take.nonFinite { nan = true }
                takes.append(take)
            }
            let preDB = takes.map { DynamicsProbe.dbfs($0.preRMS) }
            let range = preDB.last! - preDB.first!
            let c32 = takes[2].centroidHz
            let c127 = takes.last!.centroidHz
            let bright: Float = c32 > 1 ? c127 / c32 : 0
            let mono = DynamicsProbe.monotonic(preDB, tolerance: 0.5)
            if nan || range < 12 || bright < 1.1 || !mono {
                var line = String(
                    format: "%@ [%@] range %.2f bright %.3f mono %@ nan %@",
                    p.name, p.category.rawValue, range, bright, mono ? "Y" : "N", nan ? "Y" : "N"
                )
                if !mono {
                    line += " preDB " + preDB.map { String(format: "%.1f", $0) }.joined(separator: ",")
                }
                failures.append(line)
            }
        }
        print(failures.joined(separator: "\n"))
        #expect(failures.isEmpty, "dynamics \(failures.count): \(failures.prefix(16).joined(separator: " | "))")
    }
}
