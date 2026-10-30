//
//  FactoryVelocitySoftHardTests.swift
//  SYNT_35 S3: vel 100 is louder than vel 30 on Soft and Hard factory presets.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryVelocitySoftHardTests {
    private typealias A = FactoryAuthoring

    static func rms(_ preset: SynthPreset, velocity: Float) -> Float {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: velocity)
        engine.processCommandsForTesting()
        var sum: Double = 0
        for _ in 0..<6000 {
            let (l, r) = engine.renderOneSample()
            sum += Double(l * l + r * r)
        }
        return Float((sum / 12000).squareRoot())
    }

    static var picks: [SynthPreset] {
        let ps = FactoryCharacterAuditTests.all.filter { $0.name != "Init" && $0.category != .fx }
        let hard = Array(ps.filter { A.has($0, A.hardWords) }.prefix(4))
        let soft = ps.filter { A.has($0, A.softWords) && !A.has($0, A.hardWords) }.prefix(8 - hard.count)
        return Array(soft) + hard
    }

    @Test func hardIsLouderThanSoft() {
        let ps = Self.picks
        #expect(ps.count == 8)
        var lines: [String] = []
        for p in ps {
            let lo = Self.rms(p, velocity: 0.30), hi = Self.rms(p, velocity: 1.0)
            lines.append(String(format: "SYNT_35 SOFTHARD | %@ | %@ | v30 %.4f | v100 %.4f", p.category.rawValue, p.name, lo, hi))
            #expect(hi > lo * 1.05, "\(p.name) v100 \(hi) ≤ v30 \(lo)")
        }
        print(lines.joined(separator: "\n"))
        try? lines.joined(separator: "\n").write(toFile: "/tmp/synt35_softhard.txt", atomically: true, encoding: .utf8)
    }
}
