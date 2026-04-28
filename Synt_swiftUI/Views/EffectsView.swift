//
//  EffectsView.swift
//  Synt_swiftUI
//

import SwiftUI

struct EffectsView: View {
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AppleSectionHeader(title: "EFFECTS", accent: AppleTheme.accentEffects, icon: "sparkles")

            VStack(alignment: .leading, spacing: 8) {
                Text("Reverb")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppleTheme.textPrimary)
                HStack(spacing: 16) {
                    KnobView(value: $preset.reverbMix, range: 0...1, label: "Mix")
                    KnobView(value: $preset.reverbRoomSize, range: 0...1, label: "Room")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Chorus")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppleTheme.textPrimary)
                HStack(spacing: 12) {
                    KnobView(value: $preset.chorusRate, range: 0.1...5.0, label: "Rate", format: "%.1fHz")
                    KnobView(value: $preset.chorusDepth, range: 0...1, label: "Depth")
                    KnobView(value: $preset.chorusMix, range: 0...1, label: "Mix")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Delay")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(AppleTheme.textPrimary)
                HStack(spacing: 12) {
                    KnobView(value: $preset.delayTime, range: 0.01...1.0, label: "Time", format: "%.2fs")
                    KnobView(value: $preset.delayFeedback, range: 0...0.9, label: "Feedback")
                    KnobView(value: $preset.delayMix, range: 0...1, label: "Mix")
                }
            }
        }
        .padding()
        .appleCard(accent: AppleTheme.accentEffects)
    }
}

#Preview {
    EffectsView(preset: .constant(.defaultPreset))
        .frame(width: 280).padding()
        .background(AppleTheme.windowBackground)
}
