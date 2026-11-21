//
//  PresetManager.swift
//  Synt_swiftUI
//
//  Manages saving and loading user presets using UserDefaults
//

import Combine
import Foundation
import SwiftUI

public class PresetManager: ObservableObject, @unchecked Sendable {
    public static let shared = PresetManager()
    public static let appGroupID = "group.com.nixter.synt"

    public let objectWillChange = ObservableObjectPublisher()

    public var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }
    
    private let userPresetsKey = "userPresets"
    private let lock = NSLock()
    private var _userPresets: [SynthPreset] = []

    public var userPresets: [SynthPreset] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _userPresets
        }
        set {
            lock.lock()
            _userPresets = newValue
            lock.unlock()
            notifyChangeOnMain()
        }
    }
    
    private init() {
        _userPresets = loadFromDefaultsLocked()
    }

    private func notifyChangeOnMain() {
        PluginMainThread.perform { [weak self] in
            self?.objectWillChange.send()
        }
    }

    private func loadFromDefaultsLocked() -> [SynthPreset] {
        guard let data = defaults.data(forKey: userPresetsKey) else {
            return []
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([SynthPreset].self, from: data).map { $0.sanitized() }
        } catch {
            print("Error loading presets: \(error)")
            return []
        }
    }

    private func savePresetsLocked() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(_userPresets)
            defaults.set(data, forKey: userPresetsKey)
        } catch {
            print("Error saving presets: \(error)")
        }
    }
    
    // MARK: - Load Presets
    
    public func loadPresets() {
        lock.lock()
        _userPresets = loadFromDefaultsLocked()
        lock.unlock()
        notifyChangeOnMain()
    }
    
    // MARK: - Save Presets
    
    public func savePresets() {
        lock.lock()
        savePresetsLocked()
        lock.unlock()
    }
    
    public func saveUserPreset(_ preset: SynthPreset) {
        lock.lock()
        if let idx = _userPresets.firstIndex(where: { $0.name == preset.name }) {
            _userPresets[idx] = preset
        } else {
            _userPresets.append(preset)
        }
        savePresetsLocked()
        lock.unlock()
        notifyChangeOnMain()
    }

    public func deleteUserPreset(name: String) {
        lock.lock()
        _userPresets.removeAll { $0.name == name }
        savePresetsLocked()
        lock.unlock()
        notifyChangeOnMain()
    }
    
    // MARK: - CRUD Operations
    
    public func addPreset(_ preset: SynthPreset) {
        var newPreset = preset
        newPreset.id = UUID() // Ensure unique ID
        lock.lock()
        _userPresets.append(newPreset)
        savePresetsLocked()
        lock.unlock()
        notifyChangeOnMain()
    }
    
    public func updatePreset(_ preset: SynthPreset) {
        lock.lock()
        let updated: Bool
        if let index = _userPresets.firstIndex(where: { $0.id == preset.id }) {
            _userPresets[index] = preset
            savePresetsLocked()
            updated = true
        } else {
            updated = false
        }
        lock.unlock()
        if updated {
            notifyChangeOnMain()
        }
    }
    
    public func deletePreset(_ preset: SynthPreset) {
        lock.lock()
        _userPresets.removeAll { $0.id == preset.id }
        savePresetsLocked()
        lock.unlock()
        notifyChangeOnMain()
    }
    
    public func deletePreset(at indexSet: IndexSet) {
        lock.lock()
        _userPresets.remove(atOffsets: indexSet)
        savePresetsLocked()
        lock.unlock()
        notifyChangeOnMain()
    }
    
    public func renamePreset(_ preset: SynthPreset, newName: String) {
        lock.lock()
        let renamed: Bool
        if let index = _userPresets.firstIndex(where: { $0.id == preset.id }) {
            _userPresets[index].name = newName
            savePresetsLocked()
            renamed = true
        } else {
            renamed = false
        }
        lock.unlock()
        if renamed {
            notifyChangeOnMain()
        }
    }
    
    /// Check if preset name already exists in user presets
    public func nameExists(_ name: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return _userPresets.contains { $0.name == name }
    }
    
    // MARK: - File session and .synthpreset

    public static let sessionFileName = "last_session.json"
    public static let presetPathExtension = "synthpreset"

    public static func applicationSupportDirectory() -> URL {
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

    public static func lastSessionURL(in directory: URL? = nil) -> URL {
        let dir = directory ?? applicationSupportDirectory()
        return dir.appendingPathComponent(sessionFileName)
    }

    /// Off the audio thread. Corrupt or missing files return nil so the caller keeps Init.
    public static func loadLastSession(from url: URL? = nil) -> SynthPreset? {
        let file = url ?? lastSessionURL()
        guard let data = try? Data(contentsOf: file),
              data.count <= SynthPreset.maxImportBytes else { return nil }
        return (try? JSONDecoder().decode(SynthPreset.self, from: data))?.sanitized()
    }

    public static func saveLastSession(_ preset: SynthPreset, to url: URL? = nil) {
        let file = url ?? lastSessionURL()
        guard let data = try? JSONEncoder().encode(preset) else { return }
        try? data.write(to: file, options: .atomic)
    }

    public static func exportPreset(_ preset: SynthPreset, to url: URL) throws {
        let data = try JSONEncoder().encode(preset)
        try data.write(to: url, options: .atomic)
    }

    /// Untrusted file: size cap, decode, clamp, and a fresh id (no clash with a library preset).
    public static func importPreset(from url: URL) throws -> SynthPreset {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if size > SynthPreset.maxImportBytes { throw PresetImportError.tooLarge(size) }
        guard let data = try? Data(contentsOf: url) else { throw PresetImportError.unreadable }
        if data.count > SynthPreset.maxImportBytes { throw PresetImportError.tooLarge(data.count) }
        return try decodeImported(data)
    }

    public static func decodeImported(_ data: Data) throws -> SynthPreset {
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
    public func generateUniqueName(baseName: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        var name = baseName
        var counter = 1
        
        while _userPresets.contains(where: { $0.name == name }) {
            name = "\(baseName) \(counter)"
            counter += 1
        }
        
        return name
    }
}
