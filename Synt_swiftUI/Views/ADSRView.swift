//
//  ADSRView.swift
//  Synt_swiftUI
//

import SwiftUI

struct ADSRView: View {
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppleSectionHeader(title: "ENVELOPE", accent: AppleTheme.accentEnvelope, icon: "chart.xyaxis.line")

            ADSRGraph(attack: preset.attack, decay: preset.decay, sustain: preset.sustain, release: preset.release)
                .frame(height: 60)
                .padding(6)
                .appleInset()

            HStack(spacing: 12) {
                KnobView(value: $preset.attack, range: 0.001...2.0, label: "Attack", format: "%.2fs")
                KnobView(value: $preset.decay, range: 0.001...2.0, label: "Decay", format: "%.2fs")
                KnobView(value: $preset.sustain, range: 0...1, label: "Sustain", format: "%.0f%%")
                KnobView(value: $preset.release, range: 0.001...3.0, label: "Release", format: "%.2fs")
            }
        }
        .padding()
        .appleCard(accent: AppleTheme.accentEnvelope)
    }
}

struct ADSRGraph: View {
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
                    colors: [AppleTheme.accentEnvelope, AppleTheme.accentLFO],
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
                    colors: [AppleTheme.accentEnvelope.opacity(0.2), AppleTheme.accentLFO.opacity(0.05)],
                    startPoint: .top, endPoint: .bottom
                )
            )
        }
    }
}

#Preview {
    ADSRView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(AppleTheme.windowBackground)
}
