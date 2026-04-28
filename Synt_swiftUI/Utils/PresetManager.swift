//
//  PresetManager.swift
//  Synt_swiftUI
//
//  Manages saving and loading user presets using UserDefaults
//

import Foundation
import SwiftUI

class PresetManager: ObservableObject {
    static let shared = PresetManager()
    
    private let userPresetsKey = "userPresets"
    
    @Published var userPresets: [SynthPreset] = []
    
    private init() {
        loadPresets()
    }
    
    // MARK: - Load Presets
    
    func loadPresets() {
        guard let data = UserDefaults.standard.data(forKey: userPresetsKey) else {
            userPresets = []
            return
        }
        
        do {
            let decoder = JSONDecoder()
            userPresets = try decoder.decode([SynthPreset].self, from: data)
        } catch {
            print("Error loading presets: \(error)")
            userPresets = []
        }
    }
    
    // MARK: - Save Presets
    
    func savePresets() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(userPresets)
            UserDefaults.standard.set(data, forKey: userPresetsKey)
        } catch {
            print("Error saving presets: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func addPreset(_ preset: SynthPreset) {
        var newPreset = preset
        newPreset.id = UUID() // Ensure unique ID
        userPresets.append(newPreset)
        savePresets()
    }
    
    func updatePreset(_ preset: SynthPreset) {
        if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
            userPresets[index] = preset
            savePresets()
        }
    }
    
    func deletePreset(_ preset: SynthPreset) {
        userPresets.removeAll { $0.id == preset.id }
        savePresets()
    }
    
    func deletePreset(at indexSet: IndexSet) {
        userPresets.remove(atOffsets: indexSet)
        savePresets()
    }
    
    func renamePreset(_ preset: SynthPreset, newName: String) {
        if let index = userPresets.firstIndex(where: { $0.id == preset.id }) {
            userPresets[index].name = newName
            savePresets()
        }
    }
    
    /// Check if preset name already exists in user presets
    func nameExists(_ name: String) -> Bool {
        return userPresets.contains { $0.name == name }
    }
    
    /// Generate unique name for preset
    func generateUniqueName(baseName: String) -> String {
        var name = baseName
        var counter = 1
        
        while nameExists(name) {
            name = "\(baseName) \(counter)"
            counter += 1
        }
        
        return name
    }
}
