//
//  PresetBrowser.swift
//  Synt_swiftUI
//
//  Factory presets in browse order (the popover order: category, then
//  library order inside it). Up / down arrows, the "042 / 100" counter and
//  MIDI Program Change all use this one list, so number N is the same
//  patch everywhere. Pure; main thread.
//

import Foundation

enum PresetBrowser {
    /// Factory library grouped by `PresetCategory.allCases`, stable inside a group.
    static let list: [SynthPreset] = PresetCategory.allCases.flatMap { category in
        SynthPreset.factoryPresets.filter { $0.category == category }
    }

    static var count: Int { list.count }

    /// Factory presets of one category, in the same order as `list`.
    static func presets(in category: PresetCategory) -> [SynthPreset] {
        list.filter { $0.category == category }
    }

    /// Favorites in browse order: factory list, then Expansion, then user presets.
    /// The first name wins, so a user copy does not hide the numbered factory patch.
    static func favoritePresets(named names: Set<String>, userPresets: [SynthPreset] = []) -> [SynthPreset] {
        guard !names.isEmpty else { return [] }
        var seen = Set<String>()
        var result: [SynthPreset] = []
        for preset in list + SynthPreset.expansionPresets + userPresets {
            if names.contains(preset.name), seen.insert(preset.name).inserted {
                result.append(preset)
            }
        }
        return result
    }

    /// Position of `preset` in `list`, matched by name (an edited factory
    /// patch keeps its name and its number). `nil` for Init / user presets.
    static func index(of preset: SynthPreset) -> Int? {
        list.firstIndex { $0.name == preset.name }
    }

    /// `delta` steps through `list` (or `expansionPresets` when currently on an
    /// expansion patch), wrapping at both ends. From a preset that is in neither,
    /// +1 goes to the first factory preset and -1 to the last.
    static func step(from preset: SynthPreset, by delta: Int) -> SynthPreset {
        let exp = SynthPreset.expansionPresets
        if !exp.isEmpty, let expIdx = exp.firstIndex(where: { $0.name == preset.name }) {
            let m = exp.count
            let next = ((expIdx + delta) % m + m) % m
            return exp[next]
        }
        guard !list.isEmpty else { return preset }
        let n = list.count
        let next: Int
        if let i = index(of: preset) {
            next = ((i + delta) % n + n) % n
        } else {
            next = delta >= 0 ? (delta - 1) % n : ((n + delta) % n + n) % n
        }
        return list[next]
    }

    /// "042 / 100", "E01 / 050" for Expansion Pack, or "— / 100" for Init and user presets.
    static func counterLabel(for preset: SynthPreset) -> String {
        let total = String(format: "%03d", count)
        if let i = index(of: preset) {
            return String(format: "%03d", i + 1) + " / " + total
        }
        let exp = SynthPreset.expansionPresets
        if let expIdx = exp.firstIndex(where: { $0.name == preset.name }) {
            return String(format: "E%02d / %03d", expIdx + 1, exp.count)
        }
        return "— / \(total)"
    }

    /// MIDI Program Change 0…count-1 → preset; out of range → nil.
    static func preset(forProgram program: Int) -> SynthPreset? {
        list.indices.contains(program) ? list[program] : nil
    }
}
