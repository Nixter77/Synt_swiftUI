//
//  ThemeStoreTests.swift
//  The skin id is stored under "ui.theme" and publishes changes.
//

import Combine
@testable import SynthCore
import Foundation
import Testing
@testable import Synt_swiftUI

struct ThemeStoreTests {

    @Test func savesAndReadsTheSelectedTheme() {
        let defaults = freshDefaults()
        let store = ThemeStore(defaults: defaults)
        store.id = .studio
        #expect(defaults.string(forKey: ThemeStore.storageKey) == ThemeID.studio.rawValue)
        let restored = ThemeStore(defaults: defaults)
        #expect(restored.id == .studio)

        store.id = .retro
        #expect(ThemeStore(defaults: defaults).id == .retro)
    }

    @Test func unknownValueFallsBackToBaseline() {
        let defaults = freshDefaults()
        defaults.set("synthwave", forKey: ThemeStore.storageKey)
        #expect(ThemeStore(defaults: defaults).id == .baseline)

        defaults.set("", forKey: ThemeStore.storageKey)
        #expect(ThemeStore(defaults: defaults).id == .baseline)

        defaults.removeObject(forKey: ThemeStore.storageKey)
        #expect(ThemeStore(defaults: defaults).id == .baseline)
    }

    @Test func changingIdPublishes() {
        let store = ThemeStore(defaults: freshDefaults())
        var publications = 0
        let subscription = store.objectWillChange.sink { publications += 1 }
        store.id = .retro
        #expect(store.id == .retro)
        #expect(publications >= 1)
        _ = subscription
    }
}

private func freshDefaults() -> UserDefaults {
    let name = "ThemeStoreTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return defaults
}
