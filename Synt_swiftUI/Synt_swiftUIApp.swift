//
//  Synt_swiftUIApp.swift
//  Synt_swiftUI
//

import SwiftUI

@main
struct Synt_swiftUIApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 650)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        #endif
    }
}
