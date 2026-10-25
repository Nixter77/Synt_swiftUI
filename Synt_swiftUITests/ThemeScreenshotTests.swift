//
//  ThemeScreenshotTests.swift
//  The window shots in docs/design/screens are real captures.
//  ImageRenderer left the panels blank, so this test only checks the files.
//

import AppKit
@testable import SynthCore
import Testing

@MainActor
struct ThemeScreenshotTests {

    @Test func savedSkinsAreNonEmptyPictures() throws {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/design/screens", isDirectory: true)
        let names = [
            "baseline.png", "baseline_seq.png",
            "studio.png", "studio_seq.png",
            "retro.png", "retro_seq.png",
        ]
        for name in names {
            let url = directory.appendingPathComponent(name)
            let data = try Data(contentsOf: url)
            #expect(data.count > 40_000, "\(name) is \(data.count) bytes")
            let image = NSImage(data: data)
            let size = image?.size ?? .zero
            #expect(size.width >= 1000, "\(name) width \(size.width)")
            #expect(size.height >= 700, "\(name) height \(size.height)")
            #expect(distinctColors(in: image) > 6, "\(name) looks flat")
        }
    }
}

private func distinctColors(in image: NSImage?) -> Int {
    guard let image, let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return 0 }
    var colors = Set<Int>()
    let stepX = max(rep.pixelsWide / 24, 1)
    let stepY = max(rep.pixelsHigh / 24, 1)
    let limitY = max(rep.pixelsHigh / 2, 1)
    for y in stride(from: 0, to: limitY, by: stepY) {
        for x in stride(from: 0, to: rep.pixelsWide, by: stepX) {
            guard let color = rep.colorAt(x: x, y: y) else { continue }
            let key = (Int(color.redComponent * 15) << 8)
                | (Int(color.greenComponent * 15) << 4)
                | Int(color.blueComponent * 15)
            colors.insert(key)
        }
    }
    return colors.count
}
