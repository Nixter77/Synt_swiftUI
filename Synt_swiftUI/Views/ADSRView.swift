//
//  ADSRView.swift
//  Synt_swiftUI
//

import SwiftUI

struct ADSRView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            AppleSectionHeader(title: "ENVELOPE", accent: theme.aEnv, icon: "chart.xyaxis.line")

            ADSRGraph(attack: preset.attack, decay: preset.decay, sustain: preset.sustain, release: preset.release)
                .frame(height: 60)
                .padding(2)
                .appleInset()

            HStack(spacing: 8) {
                KnobView(value: $preset.attack, range: 0.001...2.0, label: "Attack", format: "%.2fs")
                KnobView(value: $preset.decay, range: 0.001...2.0, label: "Decay", format: "%.2fs")
                KnobView(value: $preset.sustain, range: 0...1, label: "Sustain", format: "%.0f%%")
                KnobView(value: $preset.release, range: 0.001...3.0, label: "Release", format: "%.2fs")
            }
        }
        .padding(6)
        .appleCard(accent: theme.aEnv)
    }
}

struct ADSRGraph: View {
    @Environment(\.theme) private var theme
    let attack: Float
    let decay: Float
    let sustain: Float
    let release: Float

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let totalTime = attack + decay + 0.3 + release
            let attackEnd = CGFloat(attack / totalTime) * width
            let decayEnd = attackEnd + CGFloat(decay / totalTime) * width
            let sustainEnd = decayEnd + CGFloat(0.3 / totalTime) * width

            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: attackEnd, y: 0))
                path.addLine(to: CGPoint(x: decayEnd, y: height * CGFloat(1 - sustain)))
                path.addLine(to: CGPoint(x: sustainEnd, y: height * CGFloat(1 - sustain)))
                path.addLine(to: CGPoint(x: width, y: height))
            }
            .stroke(
                LinearGradient(
                    colors: [theme.aEnv, theme.aLFO],
                    startPoint: .leading, endPoint: .trailing
                ),
                lineWidth: 2.5
            )

            Path { path in
                path.move(to: CGPoint(x: 0, y: height))
                path.addLine(to: CGPoint(x: attackEnd, y: 0))
                path.addLine(to: CGPoint(x: decayEnd, y: height * CGFloat(1 - sustain)))
                path.addLine(to: CGPoint(x: sustainEnd, y: height * CGFloat(1 - sustain)))
                path.addLine(to: CGPoint(x: width, y: height))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [theme.aEnv.opacity(0.2), theme.aLFO.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }
}

#Preview {
    ADSRView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(Theme.baseline.bg)
}
