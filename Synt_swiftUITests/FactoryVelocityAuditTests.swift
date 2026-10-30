//
//  FactoryVelocityAuditTests.swift
//  SYNT_35 audit: factory presets answer velocity (soft vs hard readable).
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryVelocityAuditTests {
    static var all: [SynthPreset] { FactoryCharacterAuditTests.all.filter { $0.name != "Init" } }

    static func velAmp(_ p: SynthPreset) -> Float {
        p.modMatrix.filter { $0.source == .velocity && $0.destination == .amp }.map { abs($0.amount) }.max() ?? 0
    }

    /// Formant ignores cutoff, so velocity→cutoff does not count there.
    static func velCut(_ p: SynthPreset) -> Float {
        guard p.filterType != .formant else { return 0 }
        let row = p.modMatrix.filter { $0.source == .velocity && $0.destination == .cutoff }.map { abs($0.amount) }.max() ?? 0
        return max(row, p.velocityToCutoff)
    }

    static func audible(_ p: SynthPreset) -> Bool { max(velAmp(p), velCut(p)) >= 0.15 }

    static let floorCategories: [PresetCategory] = [.bass, .lead, .keys, .pluck]

    static func share(_ c: PresetCategory) -> (hit: Int, total: Int) {
        let ps = all.filter { $0.category == c }
        return (ps.filter(audible).count, ps.count)
    }

    @Test func velocityInventory() {
        var lines: [String] = []
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c }
            let amp = ps.filter { Self.velAmp($0) >= 0.15 }.count
            let cut = ps.filter { Self.velCut($0) >= 0.15 }.count
            let env = ps.filter { $0.velocityToEnvAmount >= 0.15 }.count
            let none = ps.filter { !Self.audible($0) }.count
            lines.append("SYNT_35 VEL | \(c.rawValue) | n \(ps.count) | amp \(amp) | cutoff \(cut) | filterEnv \(env) | none \(none) | audible \(ps.count - none)")
        }
        print(lines.joined(separator: "\n"))
        try? lines.joined(separator: "\n").write(toFile: "/tmp/synt35_velocity.txt", atomically: true, encoding: .utf8)
    }

    @Test func padStringsVelocityStaysSoft() {
        for p in Self.all where p.category == .pad || p.category == .strings {
            #expect(Self.velAmp(p) <= 0.35, "\(p.name) vel→amp \(Self.velAmp(p))")
        }
        for p in Self.all where FactoryAuthoring.has(p, ["soft", "velvet", "whisper"]) {
            #expect(!(p.distortionEnabled && p.distortionMix > 0.22), "\(p.name) soft dirt")
        }
    }
}
