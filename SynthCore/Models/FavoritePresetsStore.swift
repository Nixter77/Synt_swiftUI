//
//  FavoritePresetsStore.swift
//  Synt_swiftUI
//
//  Stores and manages favorite preset names in UserDefaults.
//

import Foundation

public final class FavoritePresetsStore: ObservableObject {
    public static let shared = FavoritePresetsStore()

    private let storageKey = "favoritePresetNames"

    @Published public var favorites: Set<String> = []

    public init() {
        loadFavorites()
    }

    public func isFavorite(name: String) -> Bool {
        favorites.contains(name)
    }

    public func toggleFavorite(name: String) {
        if favorites.contains(name) {
            favorites.remove(name)
        } else {
            favorites.insert(name)
        }
        saveFavorites()
    }

    public func setFavorite(name: String, isFav: Bool) {
        if isFav {
            favorites.insert(name)
        } else {
            favorites.remove(name)
        }
        saveFavorites()
    }

    public func clearFavorites() {
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
