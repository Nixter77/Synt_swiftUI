//
//  Stage21Stage4Tests.swift
//  SYNT_21 Stage 4: R17-5 — unknown enum cases no longer fail the whole preset.
//

import XCTest
@testable import SynthCore

final class Stage21Stage4Tests: XCTestCase {

    private func json(_ p: SynthPreset) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(p)) as? [String: Any])
    }
    private func decode(_ obj: [String: Any]) throws -> SynthPreset {
        try JSONDecoder().decode(SynthPreset.self, from: JSONSerialization.data(withJSONObject: obj))
    }

    func testR17_5_UnknownWaveformAndFilterFallBackToDefaults() throws {
        var p = SynthPreset(name: "W")
        p.osc1Waveform = .square
        p.osc2Volume = 0.33
        var obj = try json(p)
        obj["osc1Waveform"] = "Hyperwave"
        obj["filterType"] = "Quantum"
        obj["lfoTarget"] = 42
        let d = try decode(obj)
        XCTAssertEqual(d.osc1Waveform, .sawtooth)
        XCTAssertEqual(d.filterType, .lowPass)
        XCTAssertEqual(d.lfoTarget, .pitch)
        XCTAssertEqual(d.osc2Volume, 0.33, accuracy: 1e-6, "other fields still decode")
    }

    func testR17_5_UnknownModSourceDropsOnlyThatRouting() throws {
        var p = SynthPreset(name: "M")
        let dest = ModDestination.allCases[0]
        p.modMatrix = [ModMatrixEntry(source: ModSource.allCases[0], destination: dest, amount: 0.5),
                       ModMatrixEntry(source: ModSource.allCases[1], destination: dest, amount: 0.25)]
        var obj = try json(p)
        var mm = try XCTUnwrap(obj["modMatrix"] as? [[String: Any]])
        mm[0]["source"] = "Telepathy"
        obj["modMatrix"] = mm
        let d = try decode(obj)
        XCTAssertEqual(d.modMatrix.count, 1)
        XCTAssertEqual(d.modMatrix.first?.amount ?? 0, 0.25, accuracy: 1e-6)
        XCTAssertEqual(d.modMatrix.first?.source, ModSource.allCases[1])
    }
}
