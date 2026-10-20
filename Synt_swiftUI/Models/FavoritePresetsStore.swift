//
//  FavoritePresetsStore.swift
//  Synt_swiftUI
//
//  Stores and manages favorite preset names in UserDefaults.
//

import Foundation

final class FavoritePresetsStore: ObservableObject {
    static let shared = FavoritePresetsStore()

    private let storageKey = "favoritePresetNames"

    @Published var favorites: Set<String> = []

    init() {
        loadFavorites()
    }

    func isFavorite(name: String) -> Bool {
        favorites.contains(name)
    }

    func toggleFavorite(name: String) {
        if favorites.contains(name) {
            favorites.remove(name)
        } else {
            favorites.insert(name)
        }
        saveFavorites()
    }

    func setFavorite(name: String, isFav: Bool) {
        if isFav {
            favorites.insert(name)
        } else {
            favorites.remove(name)
        }
        saveFavorites()
    }

    func clearFavorites() {
        favorites.removeAll()
        saveFavorites()
    }

    private func loadFavorites() {
        if let array = UserDefaults.standard.stringArray(forKey: storageKey) {
            favorites = Set(array)
        }
    }

    private func saveFavorites() {
        UserDefaults.standard.set(Array(favorites), forKey: storageKey)
    }
}
