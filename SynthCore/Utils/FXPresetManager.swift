//
//  FXPresetManager.swift
//  Synt_swiftUI
//
//  User effect presets live next to the session, not inside the patch:
//  Application Support/Home.Synt-swiftUI/FXPresets/<kind>.json
//

import Foundation

public final class FXPresetManager: ObservableObject {
    public static let shared = FXPresetManager()

    @Published private(set) var userPresets: [FXPreset] = []

    public let directory: URL

    public init(directory: URL? = nil) {
        self.directory = directory ?? Self.defaultDirectory()
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        reload()
    }

    public static func defaultDirectory() -> URL {
        PresetManager.applicationSupportDirectory()
            .appendingPathComponent("FXPresets", isDirectory: true)
    }

    public func presets(for kind: FXKind) -> [FXPreset] {
        FactoryFXPresets.presets(for: kind) + userPresets.filter { $0.kind == kind }
    }

    public func matchingName(kind: FXKind, in preset: SynthPreset) -> String? {
        let current = FXPreset.capture(kind: kind, from: preset)
        return presets(for: kind).first { $0.matches(current) }?.name
    }

    /// False when the name is empty or already used by a factory or user preset of this kind.
    @discardableResult
    public func save(kind: FXKind, name: String, from preset: SynthPreset) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if presets(for: kind).contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return false
        }
        var captured = FXPreset.capture(kind: kind, from: preset)
        captured.name = trimmed
        captured.isFactory = false
        captured.id = UUID()
        userPresets.append(captured)
        write(kind)
        return true
    }

    /// Factory presets cannot be deleted. Returns false when the id is missing or factory.
    @discardableResult
    public func delete(id: UUID) -> Bool {
        guard let preset = userPresets.first(where: { $0.id == id }), !preset.isFactory else { return false }
        userPresets.removeAll { $0.id == id }
        write(preset.kind)
        return true
    }

    public func reload() {
        var loaded: [FXPreset] = []
        for kind in FXKind.allCases {
            loaded.append(contentsOf: read(kind))
        }
        userPresets = loaded
    }

    private func file(for kind: FXKind) -> URL {
        directory.appendingPathComponent("\(kind.rawValue).json")
    }

    private func read(_ kind: FXKind) -> [FXPreset] {
        let url = file(for: kind)
        guard let data = try? Data(contentsOf: url) else { return [] }
        guard let decoded = try? JSONDecoder().decode([FXPreset].self, from: data) else { return [] }
        return decoded.filter { !$0.isFactory }.map { item in
            var copy = item
            copy.kind = kind
            copy.isFactory = false
            copy.values = FXPreset.clamp(kind: kind, values: item.values)
            copy.ints = FXPreset.clampInts(kind: kind, ints: item.ints)
            return copy
        }
    }

    private func write(_ kind: FXKind) {
        let items = userPresets.filter { $0.kind == kind }
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: file(for: kind), options: .atomic)
    }
}
