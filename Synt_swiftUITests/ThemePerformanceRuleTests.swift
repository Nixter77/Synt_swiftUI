//
//  ThemePerformanceRuleTests.swift
//  Views stay flat: no blur, no materials, one shadow per modifier chain.
//

import Foundation
@testable import SynthCore
import Testing

struct ThemePerformanceRuleTests {

    @Test func viewsStayFlatAndUseOneShadowPerChain() throws {
        let views = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Synt_swiftUI/Views", isDirectory: true)
        let files = try swiftFiles(under: views)
        #expect(!files.isEmpty)

        var violations: [String] = []
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let relative = file.lastPathComponent
            if text.contains(".blur(") {
                violations.append("\(relative) contains .blur(")
            }
            if text.contains("Material") {
                violations.append("\(relative) contains Material")
            }
            if text.contains("AppleTheme.") {
                violations.append("\(relative) contains AppleTheme.")
            }
            violations.append(contentsOf: adjacentShadows(in: text, file: relative))
        }
        #expect(violations.isEmpty, Comment(rawValue: violations.joined(separator: "\n")))
    }
}

private func swiftFiles(under root: URL) throws -> [URL] {
    let keys: [URLResourceKey] = [.isRegularFileKey]
    guard let enumerator = FileManager.default.enumerator(
        at: root,
        includingPropertiesForKeys: keys
    ) else {
        return []
    }
    var files: [URL] = []
    for case let url as URL in enumerator {
        let values = try url.resourceValues(forKeys: Set(keys))
        if values.isRegularFile == true, url.pathExtension == "swift" {
            files.append(url)
        }
    }
    return files.sorted { $0.path < $1.path }
}

/// A second `.shadow(` counts only when whitespace is all that separates it
/// from the previous call. Other modifiers between the two are a different element.
private func adjacentShadows(in text: String, file: String) -> [String] {
    var violations: [String] = []
    var search = text.startIndex
    while search < text.endIndex,
          let open = text.range(of: ".shadow(", range: search..<text.endIndex) {
        let paren = text.index(before: open.upperBound)
        guard let close = closingParen(in: text, openParen: paren) else {
            violations.append("\(file) has an unmatched .shadow(")
            break
        }
        var next = text.index(after: close)
        while next < text.endIndex, text[next].isWhitespace {
            next = text.index(after: next)
        }
        if text[next...].hasPrefix(".shadow(") {
            let line = text[..<next].reduce(1) { $1 == "\n" ? $0 + 1 : $0 }
            violations.append("\(file):\(line) has two .shadow( calls in one chain")
        }
        search = text.index(after: close)
    }
    return violations
}

private func closingParen(in text: String, openParen: String.Index) -> String.Index? {
    var depth = 0
    var index = openParen
    while index < text.endIndex {
        switch text[index] {
        case "(":
            depth += 1
        case ")":
            depth -= 1
            if depth == 0 { return index }
        default:
            break
        }
        index = text.index(after: index)
    }
    return nil
}
