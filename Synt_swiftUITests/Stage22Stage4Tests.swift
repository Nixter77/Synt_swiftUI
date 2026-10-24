//
//  Stage22Stage4Tests.swift
//  SYNT_22 Stage 4: R18-3 lossy fxOrder decode, R18-4 DEBUG log on tolerant fallback.
//

import Testing
import Foundation
@testable import SynthCore

@Suite(.serialized)
struct Stage22Stage4Tests {

    /// Encode the default preset, then replace its fxOrder with `order` (raw strings).
    static func presetJSON(fxOrder order: Any) throws -> Data {
        let data = try JSONEncoder().encode(SynthPreset.defaultPreset)
        var obj = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj["fxOrder"] = order
        return try JSONSerialization.data(withJSONObject: obj)
    }

    /// Old code: one unknown slot ID → the whole order fell back to defaultOrder.
    @Test func testR18_3_UnknownFXSlotIsDroppedNotWholeOrder() throws {
        let data = try Self.presetJSON(fxOrder: ["reverb", "futureFX", "delay"])
        let p = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(p.fxOrder == [.reverb, .delay, .eq, .distortion, .phaser, .chorus])
    }

    @Test func testR18_3_AllUnknownOrWrongTypeFallsBackToDefault() throws {
        let p1 = try JSONDecoder().decode(SynthPreset.self, from: Self.presetJSON(fxOrder: ["x", "y"]))
        #expect(p1.fxOrder == FXSlotID.defaultOrder)
        let p2 = try JSONDecoder().decode(SynthPreset.self, from: Self.presetJSON(fxOrder: 42))
        #expect(p2.fxOrder == FXSlotID.defaultOrder)
    }

    /// Old code: tolerant() was a silent try?, nothing recorded.
    @Test func testR18_4_TolerantFallbackIsLoggedInDebug() throws {
        #if DEBUG
        TolerantDecodeLog.resetForTesting()
        _ = try JSONDecoder().decode(SynthPreset.self, from: Self.presetJSON(fxOrder: 42))
        #expect(TolerantDecodeLog.fallbackKeysForTesting().contains("fxOrder"))
        TolerantDecodeLog.resetForTesting()
        _ = try JSONDecoder().decode(SynthPreset.self, from: JSONEncoder().encode(SynthPreset.defaultPreset))
        #expect(TolerantDecodeLog.fallbackKeysForTesting().isEmpty, "clean preset must not log")
        #endif
    }
}
