//
//  EffectsView.swift
//  Synt_swiftUI
//
//  Chorus, delay, and reverb. These have no enable flag: a mix above zero
//  counts as "on" only for the default expanded state.
//

import SwiftUI

struct EffectsView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(spacing: 10) {
            FXSlotCard(
                title: "Chorus",
                accent: theme.aFx,
                storageName: "chorus",
                startsExpanded: preset.chorusMix > 0.001,
                menu: { FXPresetMenu(kind: .chorus, preset: $preset) }
            ) {
                HStack(spacing: 8) {
                    KnobView(value: $preset.chorusRate, range: 0.1...5.0, label: "Rate", format: "%.1fHz")
                    KnobView(value: $preset.chorusDepth, range: 0...1, label: "Depth")
                    KnobView(value: $preset.chorusMix, range: 0...1, label: "Mix")
                }
            }

            FXSlotCard(
                title: "Delay",
                accent: theme.aFx,
                storageName: "delay",
                startsExpanded: preset.delayMix > 0.001,
                menu: { FXPresetMenu(kind: .delay, preset: $preset) }
            ) {
                HStack(spacing: 8) {
                    KnobView(value: $preset.delayTime, range: 0.01...1.0, label: "Time", format: "%.2fs")
                    KnobView(value: $preset.delayFeedback, range: 0...0.9, label: "Feedback")
                    KnobView(value: $preset.delayMix, range: 0...1, label: "Mix")
                }
            }

            FXSlotCard(
                title: "Reverb",
                accent: theme.aFx,
                storageName: "reverb",
                startsExpanded: preset.reverbMix > 0.001,
                menu: { FXPresetMenu(kind: .reverb, preset: $preset) }
            ) {
                HStack(spacing: 8) {
                    KnobView(value: $preset.reverbMix, range: 0...1, label: "Mix")
                    KnobView(value: $preset.reverbRoomSize, range: 0...1, label: "Room")
                }
            }
        }
    }
}

#Preview {
    EffectsView(preset: .constant(.defaultPreset))
        .frame(width: 240)
        .padding()
        .background(Theme.baseline.bg)
}
