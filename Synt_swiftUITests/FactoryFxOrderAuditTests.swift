//
//  FactoryFxOrderAuditTests.swift
//  SYNT_46: non-default fxOrder floors by category + Bass stereoMonoBassHz 80–150 band / 10 Hz buckets.
//  Init/Default/Template excluded and must keep the default order.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryFxOrderAuditTests {
    static var all: [SynthPreset] { FactorySoftCapAuditTests.all }

    static let floors: [PresetCategory: Int] = [
        .bass: 2, .lead: 2, .pad: 2, .strings: 1, .keys: 2, .pluck: 2, .fx: 4,
    ]
    static let helpers: [[FXSlotID]] = [FactoryAuthoring.orderDirtLast, FactoryAuthoring.orderDelayFirst, FactoryAuthoring.orderVerbEarly]

    static func custom(_ p: SynthPreset) -> Bool { p.fxOrder != FXSlotID.defaultOrder }

    static func log(_ s: String) {
        print(s)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("synt46_audit.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data((s + "\n").utf8)); try? h.close() }
        else { try? Data((s + "\n").utf8).write(to: url) }
    }

    static func helperName(_ o: [FXSlotID]) -> String {
        switch o {
        case FactoryAuthoring.orderDirtLast: return "DirtLast"
        case FactoryAuthoring.orderDelayFirst: return "DelayFirst"
        case FactoryAuthoring.orderVerbEarly: return "VerbEarly"
        case FXSlotID.defaultOrder: return "default"
        default: return "other"
        }
    }

    static var bass: [SynthPreset] { all.filter { $0.category == .bass } }

    @Test func inventory() {
        for c in PresetCategory.allCases {
            let ps = Self.all.filter { $0.category == c }
            guard !ps.isEmpty else { continue }
            let hist = Dictionary(grouping: ps.filter(Self.custom), by: { Self.helperName($0.fxOrder) }).mapValues(\.count)
            Self.log("SYNT_46 FXORDER | \(c.rawValue) | n \(ps.count) | custom \(ps.filter(Self.custom).count) | \(hist.sorted { $0.key < $1.key })")
        }
        Self.log("SYNT_46 FXORDER | global \(Self.all.filter(Self.custom).count)")
        let hz = Dictionary(grouping: Self.bass, by: { Int($0.stereoMonoBassHz) / 10 * 10 }).mapValues(\.count)
        Self.log("SYNT_46 MONOBASS | n \(Self.bass.count) | buckets \(hz.sorted { $0.key < $1.key })")
    }

    @Test func fxOrderFloors() {
        for (c, f) in Self.floors {
            let n = Self.all.filter { $0.category == c && Self.custom($0) }.count
            #expect(n >= f, "\(c.rawValue) fxOrder \(n) < \(f)")
        }
        #expect(Self.all.filter(Self.custom).count >= 14)
        let used = Set(Self.all.filter(Self.custom).map { Self.helperName($0.fxOrder) }).subtracting(["other"])
        #expect(used.count >= 2, "helpers \(used)")
    }

    @Test func initKeepsDefaultOrder() {
        #expect(SynthPreset.defaultPreset.fxOrder == FXSlotID.defaultOrder)
    }

    @Test func bassMonoBassBand() {
        let band = Self.bass.filter { (80...150).contains($0.stereoMonoBassHz) }
        #expect(Float(band.count) >= Float(Self.bass.count) * 0.85, "bass band \(band.count)/\(Self.bass.count)")
        #expect(Set(band.map { Int($0.stereoMonoBassHz) / 10 }).count >= 3)
    }
}
