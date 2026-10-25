#if DEBUG // SYNT_28: uses DEBUG-only test hooks; excluded from Release test builds
import XCTest
import Darwin
@testable import SynthCore

/// SYNT_27 R20-4: LFO shapes are carved from a never-freed arena, so no shape pointer owns a heap
/// block that could be `deallocate()`d. On old code each shape (and its samples) was its own malloc
/// block (`malloc_size` 16 / 256+ at the shape pointer) and `ShapeArena` did not exist.
final class Stage27ShapeArenaTests: XCTestCase {
    func testShapePointersAreNotHeapBlockStarts() {
        for seed in 0..<40 {
            let frame = (0..<(64 + seed * 37)).map { Float(sin(Double($0 * (seed + 1)) * 0.013)) + Float(seed) * 1e-3 }
            let p = LFOShapeTable.interned(frame)
            XCTAssertTrue(ShapeArena.ownsInteriorForTesting(UnsafeRawPointer(p)), "shape header must be arena-interior")
            XCTAssertTrue(ShapeArena.ownsInteriorForTesting(UnsafeRawPointer(p.pointee.data)), "shape samples must be arena-interior")
            XCTAssertEqual(Int(bitPattern: p) % MemoryLayout<LFOShapeTable>.alignment, 0)
            XCTAssertEqual(Int(bitPattern: p.pointee.data) % MemoryLayout<Float>.alignment, 0)
        }
        // Larger than a chunk still goes through the arena (dedicated chunk, offset header).
        let big = [Float](repeating: 0.5, count: 80_000)
        let q = LFOShapeTable.makeImmortal(big)
        XCTAssertTrue(ShapeArena.ownsInteriorForTesting(UnsafeRawPointer(q)))
        XCTAssertEqual(q.pointee.count, 80_000)
        XCTAssertEqual(q.pointee.data[79_999], 1, "normalised to peak 1")
    }
}

#endif
