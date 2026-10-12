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
    
    // MARK: - File session and .synthpreset

    static let sessionFileName = "last_session.json"
    static let presetPathExtension = "synthpreset"

    static func applicationSupportDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = base.appendingPathComponent("Home.Synt-swiftUI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func lastSessionURL(in directory: URL? = nil) -> URL {
        let dir = directory ?? applicationSupportDirectory()
        return dir.appendingPathComponent(sessionFileName)
    }

    /// Off the audio thread. Corrupt or missing files return nil so the caller keeps Init.
    static func loadLastSession(from url: URL? = nil) -> SynthPreset? {
        let file = url ?? lastSessionURL()
        guard let data = try? Data(contentsOf: file),
              data.count <= SynthPreset.maxImportBytes else { return nil }
        return (try? JSONDecoder().decode(SynthPreset.self, from: data))?.sanitized()
    }

    static func saveLastSession(_ preset: SynthPreset, to url: URL? = nil) {
        let file = url ?? lastSessionURL()
        guard let data = try? JSONEncoder().encode(preset) else { return }
        try? data.write(to: file, options: .atomic)
    }

    static func exportPreset(_ preset: SynthPreset, to url: URL) throws {
        let data = try JSONEncoder().encode(preset)
        try data.write(to: url, options: .atomic)
    }

    /// Untrusted file: size cap, decode, clamp, and a fresh id (no clash with a library preset).
    static func importPreset(from url: URL) throws -> SynthPreset {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > SynthPreset.maxImportBytes { throw PresetImportError.tooLarge(size) }
        guard let data = try? Data(contentsOf: url) else { throw PresetImportError.unreadable }
        if data.count > SynthPreset.maxImportBytes { throw PresetImportError.tooLarge(data.count) }
        return try decodeImported(data)
    }

    static func decodeImported(_ data: Data) throws -> SynthPreset {
        let decoded: SynthPreset
        do {
            decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        } catch {
            throw PresetImportError.notAPreset(error.localizedDescription)
        }
        var preset = decoded.sanitized()
        preset.id = UUID()
        return preset
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
