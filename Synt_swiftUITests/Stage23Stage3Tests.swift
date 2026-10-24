//
//  Stage23Stage3Tests.swift
//  SYNT_23 Stage 3: R19-2 deterministic "shapes are never freed" guard, R19-3 NaN-safe interning.
//

import XCTest
@testable import SynthCore

final class Stage23Stage3Tests: XCTestCase {

    /// R19-3 (fails on old code): a frame containing NaN never equalled itself as [Float], so each
    /// intern allocated a new immortal shape. Bit-pattern keys share one.
    func testR19_3_NaNFrameInternsToOneShape() {
        let frame: [Float] = [0.25, .nan, -0.5, Float(Int.random(in: 1...1_000_000)) / 1e6]
        let before = LFOShapeTable.internedCountForTesting
        let a = LFOShapeTable.interned(frame)
        let b = LFOShapeTable.interned(frame)
        XCTAssertEqual(a, b, "same NaN frame must reuse the interned shape")
        XCTAssertEqual(LFOShapeTable.internedCountForTesting - before, 1)
    }

    /// R19-2 guard (no bug existed, so it cannot fail on old code; rationale as R18-1).
    /// Deterministic: does not re-read possibly freed memory. Every shape a freed table used is
    /// still in the allocation registry (there is no free path), and deinit asserts the same.
    func testR19_2_ShapesOfFreedTablesStayRegistered() {
        #if DEBUG
        var shapes: [UnsafePointer<LFOShapeTable>] = []
        weak var weakTable: CompiledMipData?
        autoreleasepool {
            let t = Wavetable(name: "R19-2", frames: (0..<4).map { f in
                (0..<256).map { i in Float(sin(Double(i) / 256 * 2 * .pi * Double(f + 1))) * 0.9 + Float(Double.random(in: 0...1e-4)) }
            })
            let c = WavetableOscillator.compile(wavetable: t, sampleRate: 44100)
            shapes.append(c.lfoShape)
            weakTable = c
        }
        XCTAssertNil(weakTable, "table must be freed for the guard to mean anything")
        for s in shapes { XCTAssertTrue(LFOShapeTable.isRegisteredForTesting(s)) }
        XCTAssertGreaterThan(LFOShapeTable.allocatedCountForTesting, 0)
        #endif
    }
}
