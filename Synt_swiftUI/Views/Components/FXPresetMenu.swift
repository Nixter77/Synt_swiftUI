//
//  FXPresetMenu.swift
//  Synt_swiftUI
//
//  Factory and user presets for one effect. The label is the matching name,
//  or "—" when the knobs no longer match a saved preset.
//

import SwiftUI

struct FXPresetMenu: View {
    @Environment(\.theme) private var theme
    @ObservedObject var manager: FXPresetManager
    let kind: FXKind
    @Binding var preset: SynthPreset

    @State private var saveName = ""
    @State private var showSave = false
    @State private var showError = false
    @State private var errorMessage = ""

    init(kind: FXKind, preset: Binding<SynthPreset>, manager: FXPresetManager = .shared) {
        self.kind = kind
        self._preset = preset
        self.manager = manager
    }

    var body: some View {
        let match = matched
        Menu {
            Section("Factory") {
                ForEach(factory) { item in
                    Button(item.name) { apply(item) }
                }
            }
            if !user.isEmpty {
                Section("Mine") {
                    ForEach(user) { item in
                        Button(item.name) { apply(item) }
                    }
                }
            }
            Divider()
            Button("Save as…") {
                saveName = ""
                showSave = true
            }
            Button("Delete", role: .destructive) {
                if let match, !match.isFactory {
                    manager.delete(id: match.id)
                }
            }
            .disabled(match == nil || match?.isFactory == true)
        } label: {
            Text(match?.name ?? "—")
                .font(theme.captionFont(size: 9))
                .foregroundColor(theme.textDim)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 48, alignment: .trailing)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .controlSize(.small)
        .frame(maxWidth: 56, alignment: .trailing)
        .help(match?.name ?? "Edited")
        .accessibilityIdentifier("fx.preset.\(kind.rawValue)")
        .accessibilityLabel("\(kindTitle) preset")
        .accessibilityValue(match?.name ?? "—")
        .alert("Save \(kindTitle) preset", isPresented: $showSave) {
            TextField("Name", text: $saveName)
            Button("Save") { commitSave() }
                .disabled(saveName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button("Cancel", role: .cancel) { saveName = "" }
        } message: {
            Text("Stored with this effect, not inside the patch.")
        }
        .alert("Could not save", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var factory: [FXPreset] {
        manager.presets(for: kind).filter(\.isFactory)
    }

    private var user: [FXPreset] {
        manager.presets(for: kind).filter { !$0.isFactory }
    }

    private var matched: FXPreset? {
        let current = FXPreset.capture(kind: kind, from: preset)
        return manager.presets(for: kind).first { $0.matches(current) }
    }

    private var kindTitle: String {
        switch kind {
        case .distortion: return "Distortion"
        case .eq: return "EQ"
        case .phaser: return "Phaser"
        case .chorus: return "Chorus"
        case .delay: return "Delay"
        case .reverb: return "Reverb"
        }
    }

    private func apply(_ item: FXPreset) {
        var next = preset
        item.apply(to: &next)
        preset = next
    }

    private func commitSave() {
        let trimmed = saveName.trimmingCharacters(in: .whitespacesAndNewlines)
        let saved = manager.save(kind: kind, name: saveName, from: preset)
        saveName = ""
        guard !saved else { return }
        errorMessage = trimmed.isEmpty ? "Enter a name." : "That name is already used."
        showError = true
    }
}
