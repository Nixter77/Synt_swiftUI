//
//  ModMatrixView.swift
//  Synt_swiftUI
//

import SwiftUI

struct ModMatrixView: View {
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                AppleSectionHeader(title: "MODULATION MATRIX", accent: AppleTheme.accentModulation, icon: "arrow.triangle.branch")
                Spacer()
                Button(action: addEntry) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(AppleTheme.accentPositive)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach($preset.modMatrix) { $entry in
                        HStack(spacing: 8) {
                            Picker("", selection: $entry.source) {
                                ForEach(ModSource.allCases, id: \.self) { source in
                                    Text(source.rawValue).tag(source)
                                }
                            }
                            .pickerStyle(.menu).frame(maxWidth: .infinity).labelsHidden()

                            Image(systemName: "arrow.right")
                                .font(.system(size: 10))
                                .foregroundColor(AppleTheme.textTertiary)

                            Picker("", selection: $entry.destination) {
                                ForEach(ModDestination.allCases, id: \.self) { dest in
                                    Text(dest.rawValue).tag(dest)
                                }
                            }
                            .pickerStyle(.menu).frame(maxWidth: .infinity).labelsHidden()

                            KnobView(value: $entry.amount, range: -1...1, label: "Amt", format: "%.1f")
                                .scaleEffect(0.8).frame(width: 40, height: 50)

                            Button(action: { removeEntry(entry.id) }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppleTheme.accentDestructive)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(6)
                        .background(AppleTheme.surfaceSecondary)
                        .cornerRadius(6)
                    }
                    
                    if preset.modMatrix.isEmpty {
                        Text("No patches")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundColor(AppleTheme.textTertiary)
                            .padding()
                    }
                }
            }
            .frame(height: 120)
        }
        .padding(8)
        .appleCard(accent: AppleTheme.accentModulation)
    }

    private func addEntry() {
        let newEntry = ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.0)
        preset.modMatrix.append(newEntry)
    }

    private func removeEntry(_ id: UUID) {
        preset.modMatrix.removeAll { $0.id == id }
    }
}
