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
    @State private var showingPresetList = false
    @State private var showingSaveDialog = false
    @State private var newPresetName = ""
    
    var body: some View {
        HStack(spacing: 8) {
            Button {
                showingPresetList.toggle()
            } label: {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(theme.aMod)
                    Text(currentPreset.name)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(theme.text)
                        .lineLimit(1)
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
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.6), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPresetList) {
                PresetListView(currentPreset: $currentPreset, isPresented: $showingPresetList, presetManager: presetManager)
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
    @State private var presetToDelete: SynthPreset?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if !presetManager.userPresets.isEmpty {
                    SectionHeader(title: "💾 My Presets")
                    ForEach(presetManager.userPresets) { preset in
                        PresetRow(preset: preset, isSelected: preset.id == currentPreset.id, isUserPreset: true,
                            onSelect: { currentPreset = preset; isPresented = false },
                            onDelete: { presetToDelete = preset; showDeleteConfirmation = true })
                    }
                    Divider().padding(.vertical, 8)
                }
                ForEach(PresetCategory.allCases, id: \.self) { category in
                    let categoryPresets = SynthPreset.factoryPresets.filter { $0.category == category }
                    if !categoryPresets.isEmpty {
                        SectionHeader(title: category.rawValue)
                        ForEach(categoryPresets) { preset in
                            PresetRow(preset: preset, isSelected: preset.name == currentPreset.name, isUserPreset: false,
                                onSelect: { currentPreset = preset; isPresented = false }, onDelete: nil)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .frame(minWidth: 250, maxWidth: 250, maxHeight: 400)
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
    let onSelect: () -> Void
    let onDelete: (() -> Void)?
    @State private var isHovering = false
    
    var body: some View {
        HStack {
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
                .padding(.horizontal, 12).padding(.vertical, 7)
            }
            .buttonStyle(.plain)
            if isUserPreset && isHovering, let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash").font(.system(size: 11)).foregroundColor(theme.destructive.opacity(0.8))
                }
                .buttonStyle(.plain).padding(.trailing, 12)
            }
        }
        .background(isSelected ? theme.accent.opacity(0.1) : isHovering ? theme.panel : Color.clear)
        .onHover { hovering in isHovering = hovering }
    }
}

#Preview {
    PresetView(currentPreset: .constant(.defaultPreset))
        .padding()
        .background(Theme.baseline.bg)
}
