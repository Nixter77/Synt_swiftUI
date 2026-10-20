//
//  RuntimeEnvironment.swift
//  Synt_swiftUI
//
//  The unit-test bundle is hosted by the app. Under XCTest the app must not
//  open the audio output or subscribe to real MIDI sources: a test run would
//  make sound and a live keyboard would change test results.
//

import Foundation

enum RuntimeEnvironment {
    /// True when the process is the XCTest host (xcodebuild test / Xcode ⌘U).
    static let isUnitTestHost: Bool = {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil
            || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
            || NSClassFromString("XCTestCase") != nil
    }()
}
