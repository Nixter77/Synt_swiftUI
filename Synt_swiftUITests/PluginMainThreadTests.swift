//
//  PluginMainThreadTests.swift
//  Regression: Logic "Failed to load Audio Unit Synt" (2026-10-21). createAudioUnit
//  runs on the XPC queue and set preferredContentSize there; AppKit asserts and
//  the NSException crashes the extension. AppKit work must hop to main.
//

import Foundation
import Testing
@testable import SynthCore

struct PluginMainThreadTests {
    @Test func workFromABackgroundQueueRunsOnMain() async {
        let ranOnMain: Bool = await withCheckedContinuation { done in
            DispatchQueue.global().async {
                PluginMainThread.perform { done.resume(returning: Thread.isMainThread) }
            }
        }
        #expect(ranOnMain)
    }

    @Test func viewControllerNeverSizesOffMain() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("SyntAUv3/SyntAUViewController.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "func createAudioUnit("))
        let end = try #require(source.range(of: "return unit", range: start.upperBound..<source.endIndex))
        let body = String(source[start.upperBound..<end.lowerBound])
        // Every AppKit call in createAudioUnit sits inside the main hop.
        let hop = try #require(body.range(of: "PluginMainThread.perform"))
        let beforeHop = String(body[..<hop.lowerBound])
        for call in ["applyPreferredSize()", "preferredContentSize", "installHostingView("] {
            #expect(!beforeHop.contains(call), "\(call) runs on the XPC queue before the main hop")
        }
        #expect(source.contains("dispatchPrecondition(condition: .onQueue(.main))"))
    }
}
