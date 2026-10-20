//
//  Synt_swiftUIApp.swift
//  Synt_swiftUI
//

import SwiftUI

@main
struct Synt_swiftUIApp: App {
    /// Window-level skin. AudioEngine stays a StateObject inside ContentView.
    @StateObject private var themeStore = ThemeStore()

    var body: some Scene {
        WindowGroup {
            let chrome = Theme.all[themeStore.id].chromeWidth
            if RuntimeEnvironment.isUnitTestHost {
                // Test host: no AudioEngine, no CoreMIDI client, no sound.
                Color.clear.frame(width: 1, height: 1)
            } else {
                ContentView()
                    .frame(minWidth: 900 + chrome * 2, minHeight: 650)
                    .environment(\.theme, Theme.all[themeStore.id])
                    .environmentObject(themeStore)
                    .preferredColorScheme(themeStore.id == .studio ? .dark : .light)
            }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000 + Theme.all[themeStore.id].chromeWidth * 2, height: 700)
        #endif
    }
}
