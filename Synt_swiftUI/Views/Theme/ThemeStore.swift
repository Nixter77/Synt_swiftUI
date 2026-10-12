//
//  ThemeStore.swift
//  The selected skin. Lives next to the window, not inside AudioEngine.
//

import SwiftUI

final class ThemeStore: ObservableObject {
    static let storageKey = "ui.theme"

    @Published var id: ThemeID {
        didSet { defaults.set(id.rawValue, forKey: Self.storageKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        self.id = ThemeID(rawValue: raw) ?? .baseline
    }
}

struct ThemePickerMenu: View {
    @EnvironmentObject private var store: ThemeStore

    var body: some View {
        Menu {
            ForEach(ThemeID.allCases) { id in
                Button {
                    store.id = id
                } label: {
                    if store.id == id {
                        Label(Theme.all[id].displayName, systemImage: "checkmark")
                    } else {
                        Text(Theme.all[id].displayName)
                    }
                }
            }
        } label: {
            Label(Theme.all[store.id].displayName, systemImage: "paintpalette")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .labelStyle(.titleAndIcon)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Theme")
    }
}
