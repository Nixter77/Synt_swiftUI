//
//  PresetView.swift
//  Synt_swiftUI
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PresetView: View {
    @Environment(\.theme) private var theme
    @Binding var currentPreset: SynthPreset
    @StateObject private var presetManager = PresetManager.shared
    @ObservedObject private var favoritesStore = FavoritePresetsStore.shared
    @State private var showingPresetList = false
    @State private var showingSaveDialog = false
    @State private var showingMacrosPopover = false
    @State private var newPresetName = ""
    @State private var compareSnapshot: SynthPreset? = nil
    @State private var workingPresetB: SynthPreset? = nil
    @State private var isComparingA = false
    @State private var macros = PerformanceMacros()
    @State private var macroBasePreset: SynthPreset? = nil
    
    var body: some View {
        HStack(spacing: 8) {
            presetStepper

            Menu {
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    Menu(category.rawValue) {
                        ForEach(PresetBrowser.presets(in: category)) { preset in
                            Button(preset.name) { selectListedPreset(preset) }
                        }
                    }
                }
                Menu("Expansion") {
                    ForEach(SynthPreset.expansionPresets) { preset in
                        Button(preset.name) { selectListedPreset(preset) }
                    }
                }
                Menu("★ Favorites") {
                    let favorites = PresetBrowser.favoritePresets(
                        named: favoritesStore.favorites,
                        userPresets: presetManager.userPresets
                    )
                    if favorites.isEmpty {
                        Button("No favorites") {}
                            .disabled(true)
                    } else {
                        ForEach(favorites) { preset in
                            Button(preset.name) { selectListedPreset(preset) }
                        }
                    }
                }
                Divider()
                Button("Browse All…") { showingPresetList = true }
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(theme.aMod)
                    Text(currentPreset.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
                    Text(PresetBrowser.counterLabel(for: currentPreset))
                        .font(theme.monoFont(size: 11, weight: .regular))
                        .foregroundColor(theme.textDim)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityIdentifier("presetCounter")
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .foregroundColor(theme.textFaint)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.panel)
                        .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
                )
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(theme.border, lineWidth: 0.5))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityIdentifier("presetCategoryMenu")
            .popover(isPresented: $showingPresetList) {
                PresetListView(currentPreset: $currentPreset, isPresented: $showingPresetList, presetManager: presetManager)
            }

            // Smart Mutate (🎲)
            Button {
                if compareSnapshot == nil {
                    compareSnapshot = currentPreset
                }
                currentPreset = PresetMutator.mutate(preset: currentPreset)
                workingPresetB = currentPreset
                macroBasePreset = currentPreset
                macros = PerformanceMacros()
                isComparingA = false
            } label: {
                Image(systemName: "die.face.5.fill")
                    .foregroundColor(theme.aLFO)
            }
            .buttonStyle(.plain)
            .help("Smart Mutate: smoothly vary parameters ±15% with safe headroom")

            // A/B Compare
            Button {
                toggleABCompare()
            } label: {
                Text(compareButtonLabel)
                    .font(theme.monoFont(size: 10, weight: .bold))
                    .foregroundColor(isComparingA ? theme.accent : (compareSnapshot != nil ? theme.text : theme.textFaint))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isComparingA ? theme.accent.opacity(0.2) : (compareSnapshot != nil ? theme.panel : Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(compareSnapshot != nil ? (isComparingA ? theme.accent : theme.border) : theme.border.opacity(0.3), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Store Current Sound as A") {
                    compareSnapshot = currentPreset
                    workingPresetB = currentPreset
                    isComparingA = false
                }
                if compareSnapshot != nil {
                    Button("Clear A/B Snapshot") {
                        resetComparisonAndMacros()
                    }
                }
            }
            .help(compareTooltip)

            // 4 Performance Macros
            Button {
                if macroBasePreset == nil {
                    macroBasePreset = currentPreset
                }
                showingMacrosPopover.toggle()
            } label: {
                Text("MACRO")
                    .font(theme.monoFont(size: 10, weight: .bold))
                    .foregroundColor(!macros.isNeutral ? theme.accent2 : theme.textFaint)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(!macros.isNeutral ? theme.accent2.opacity(0.2) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(!macros.isNeutral ? theme.accent2 : theme.border.opacity(0.3), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .help("4 Performance Macros (Brightness, Timbre, Movement, Space)")
            .popover(isPresented: $showingMacrosPopover) {
                PerformanceMacrosPopover(
                    macros: $macros,
                    onReset: {
                        macros = PerformanceMacros()
                        if let base = macroBasePreset {
                            currentPreset = base
                        }
                    }
                )
            }
            .onChange(of: macros) { _, newMacros in
                if macroBasePreset == nil {
                    macroBasePreset = currentPreset
                }
                if let base = macroBasePreset {
                    currentPreset = newMacros.apply(to: base)
                }
            }
            .onChange(of: currentPreset.id) { _, _ in
                resetComparisonAndMacros()
            }
            
            Button {
                newPresetName = presetManager.generateUniqueName(baseName: "My Preset")
                showingSaveDialog = true
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .foregroundColor(theme.positive)
            }
            .buttonStyle(.plain).help("Save as new preset")
            
            Button {
                resetComparisonAndMacros()
                currentPreset = .defaultPreset
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .foregroundColor(theme.textFaint)
            }
            .buttonStyle(.plain).help("Reset to default")

            Button {
                exportPresetFile()
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain).help("Export preset")

            Button {
                importPresetFile()
            } label: {
                Image(systemName: "tray.and.arrow.down")
                    .foregroundColor(theme.accent)
            }
            .buttonStyle(.plain).help("Import preset")
        }
        .sheet(isPresented: $showingSaveDialog) {
            SavePresetSheet(presetName: $newPresetName, currentPreset: currentPreset, presetManager: presetManager, isPresented: $showingSaveDialog)
        }
    }

    private func selectListedPreset(_ preset: SynthPreset) {
        resetComparisonAndMacros()
        currentPreset = preset
    }

    private func resetComparisonAndMacros() {
        compareSnapshot = nil
        workingPresetB = nil
        isComparingA = false
        macros = PerformanceMacros()
        macroBasePreset = nil
    }

    private var compareButtonLabel: String {
        if compareSnapshot == nil {
            return "A/B"
        }
        return isComparingA ? "A" : "B"
    }

    private var compareTooltip: String {
        if compareSnapshot == nil {
            return "A/B Compare: click to snapshot current sound as A (Right-click to reset)"
        }
        return isComparingA ? "Listening to original (A) - click to switch to tweaked (B)" : "Listening to tweaked (B) - click to switch to original (A)"
    }

    private func toggleABCompare() {
        if compareSnapshot == nil {
            compareSnapshot = currentPreset
            workingPresetB = currentPreset
            isComparingA = false
        } else if isComparingA {
            if let b = workingPresetB {
                currentPreset = b
            }
            isComparingA = false
        } else {
            workingPresetB = currentPreset
            if let a = compareSnapshot {
                currentPreset = a
            }
            isComparingA = true
        }
    }

    /// ▲ previous / ▼ next factory preset (popover order), wrapping at the ends.
    private var presetStepper: some View {
        VStack(spacing: 2) {
            stepButton(systemName: "chevron.up", delta: -1, help: "Previous preset")
            stepButton(systemName: "chevron.down", delta: 1, help: "Next preset")
        }
        .accessibilityIdentifier("presetStepper")
    }

    private func stepButton(systemName: String, delta: Int, help: String) -> some View {
        Button {
            resetComparisonAndMacros()
            currentPreset = PresetBrowser.step(from: currentPreset, by: delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.aMod)
                .frame(width: 22, height: 15)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(theme.panel)
                        .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
                )
                .overlay(RoundedRectangle(cornerRadius: 5).stroke(theme.border, lineWidth: 0.5))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func exportPresetFile() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [synthpresetType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = safeFileName(currentPreset.name) + ".synthpreset"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try PresetManager.exportPreset(currentPreset, to: url)
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func importPresetFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [synthpresetType]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            currentPreset = try PresetManager.importPreset(from: url)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn't import preset"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private var synthpresetType: UTType {
        UTType(filenameExtension: PresetManager.presetPathExtension) ?? .json
    }

    private func safeFileName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.replacingOccurrences(of: "/", with: "-")
        return cleaned.isEmpty ? "Preset" : cleaned
    }
}

// MARK: - Save Preset Sheet

struct SavePresetSheet: View {
    @Environment(\.theme) private var theme
    @Binding var presetName: String
    let currentPreset: SynthPreset
    let presetManager: PresetManager
    @Binding var isPresented: Bool
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Preset")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(theme.text)
            VStack(alignment: .leading, spacing: 8) {
                Text("Preset Name").font(.caption).foregroundColor(theme.textDim)
                TextField("Enter preset name", text: $presetName)
                    .textFieldStyle(.roundedBorder).frame(width: 250)
                if showError {
                    Text("Preset name already exists").font(.caption).foregroundColor(theme.destructive)
                }
            }
            HStack(spacing: 16) {
                Button("Cancel") { isPresented = false }.keyboardShortcut(.cancelAction)
                Button("Save") { savePreset() }.keyboardShortcut(.defaultAction)
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .background(theme.bg)
        .frame(minWidth: 300, minHeight: 150)
    }
    
    private func savePreset() {
        let trimmedName = presetName.trimmingCharacters(in: .whitespaces)
        if presetManager.nameExists(trimmedName) { showError = true; return }
        var newPreset = currentPreset
        newPreset.name = trimmedName
        presetManager.addPreset(newPreset)
        isPresented = false
    }
}

// MARK: - Preset List View

struct PresetListView: View {
    @Environment(\.theme) private var theme
    @Binding var currentPreset: SynthPreset
    @Binding var isPresented: Bool
    @ObservedObject var presetManager: PresetManager
    @ObservedObject private var favoritesStore = FavoritePresetsStore.shared
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var presetToDelete: SynthPreset?
    @State private var showDeleteConfirmation = false

    private func filterPresets(_ presets: [SynthPreset]) -> [SynthPreset] {
        presets.filter { preset in
            let matchesSearch = searchText.isEmpty || preset.name.localizedCaseInsensitiveContains(searchText)
            let matchesFav = !showFavoritesOnly || favoritesStore.isFavorite(name: preset.name)
            return matchesSearch && matchesFav
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and Favorites bar
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(theme.textFaint)
                        .font(.system(size: 11))
                    TextField("Search presets...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11))
                        .foregroundColor(theme.text)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(theme.textFaint)
                                .font(.system(size: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(theme.inset)
                .cornerRadius(6)

                Button {
                    showFavoritesOnly.toggle()
                } label: {
                    Image(systemName: showFavoritesOnly ? "star.fill" : "star")
                        .font(.system(size: 12))
                        .foregroundColor(showFavoritesOnly ? .yellow : theme.textFaint)
                        .padding(4)
                        .background(showFavoritesOnly ? Color.yellow.opacity(0.15) : theme.inset)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("Show Favorites Only (★)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let filteredUser = filterPresets(presetManager.userPresets)
                    if !filteredUser.isEmpty {
                        SectionHeader(title: "💾 My Presets")
                        ForEach(filteredUser) { preset in
                            PresetRow(
                                preset: preset,
                                isSelected: preset.id == currentPreset.id,
                                isUserPreset: true,
                                isFavorite: favoritesStore.isFavorite(name: preset.name),
                                onToggleFavorite: { favoritesStore.toggleFavorite(name: preset.name) },
                                onSelect: { currentPreset = preset; isPresented = false },
                                onDelete: { presetToDelete = preset; showDeleteConfirmation = true }
                            )
                        }
                        Divider().padding(.vertical, 8)
                    }

                    let filteredExp = filterPresets(SynthPreset.expansionPresets)
                    if !filteredExp.isEmpty {
                        SectionHeader(title: "✨ Expansion Pack (+50)")
                        ForEach(filteredExp) { preset in
                            PresetRow(
                                preset: preset,
                                isSelected: preset.name == currentPreset.name,
                                isUserPreset: false,
                                isFavorite: favoritesStore.isFavorite(name: preset.name),
                                onToggleFavorite: { favoritesStore.toggleFavorite(name: preset.name) },
                                onSelect: { currentPreset = preset; isPresented = false },
                                onDelete: nil
                            )
                        }
                        Divider().padding(.vertical, 8)
                    }

                    ForEach(PresetCategory.allCases, id: \.self) { category in
                        let categoryPresets = SynthPreset.factoryPresets.filter { $0.category == category }
                        let filteredCat = filterPresets(categoryPresets)
                        if !filteredCat.isEmpty {
                            SectionHeader(title: category.rawValue)
                            ForEach(filteredCat) { preset in
                                PresetRow(
                                    preset: preset,
                                    isSelected: preset.name == currentPreset.name,
                                    isUserPreset: false,
                                    isFavorite: favoritesStore.isFavorite(name: preset.name),
                                    onToggleFavorite: { favoritesStore.toggleFavorite(name: preset.name) },
                                    onSelect: { currentPreset = preset; isPresented = false },
                                    onDelete: nil
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(minWidth: 280, maxWidth: 300, maxHeight: 420)
        .background(theme.card)
        .confirmationDialog("Delete Preset", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let preset = presetToDelete { presetManager.deletePreset(preset) } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Are you sure you want to delete \"\(presetToDelete?.name ?? "")\"?") }
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    @Environment(\.theme) private var theme
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(theme.textDim)
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 6)
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    @Environment(\.theme) private var theme
    let preset: SynthPreset
    let isSelected: Bool
    let isUserPreset: Bool
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 2) {
            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 11))
                    .foregroundColor(isFavorite ? .yellow : theme.textFaint.opacity(0.4))
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
            .help(isFavorite ? "Remove from Favorites" : "Add to Favorites")

            Button(action: onSelect) {
                HStack {
                    Text(preset.name)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundColor(theme.text)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(theme.accent)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            if isUserPreset && isHovering, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundColor(theme.destructive.opacity(0.8))
                }
                .buttonStyle(.plain).padding(.trailing, 10)
            }
        }
        .background(isSelected ? theme.accent.opacity(0.1) : isHovering ? theme.panel : Color.clear)
        .onHover { hovering in isHovering = hovering }
    }
}

// MARK: - 4 Performance Macros Popover

struct PerformanceMacrosPopover: View {
    @Environment(\.theme) private var theme
    @Binding var macros: PerformanceMacros
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("PERFORMANCE MACROS")
                    .font(theme.monoFont(size: 11, weight: .bold))
                    .foregroundColor(theme.accent2)
                Spacer()
                Button("Reset") {
                    onReset()
                }
                .buttonStyle(.plain)
                .font(theme.monoFont(size: 10, weight: .semibold))
                .foregroundColor(theme.textDim)
            }
            HStack(spacing: 14) {
                KnobView(value: $macros.brightness, range: -1...1, label: "Bright", format: "%+.2f")
                KnobView(value: $macros.timbre, range: -1...1, label: "Timbre", format: "%+.2f")
                KnobView(value: $macros.movement, range: -1...1, label: "Motion", format: "%+.2f")
                KnobView(value: $macros.space, range: -1...1, label: "Space", format: "%+.2f")
            }
            .padding(8)
            .appleInset(cornerRadius: 10)
        }
        .padding(12)
        .background(theme.card)
    }
}

#Preview {
    PresetView(currentPreset: .constant(.defaultPreset))
        .padding()
        .background(Theme.baseline.bg)
}
