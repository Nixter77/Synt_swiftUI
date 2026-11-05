//
//  ADSRView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

struct ADSRView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    var metering: AtomicMeteringState? = nil
    @State private var selectedEnv: Int = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                AppleSectionHeader(title: "ENVELOPE", accent: theme.aEnv, icon: "chart.xyaxis.line")
                Spacer()
                ThemeSegmented(
                    options: [(1, "AMP"), (2, "FLT")],
                    selection: $selectedEnv,
                    accent: theme.aEnv
                )
                .frame(width: 76)
                if selectedEnv == 2 {
                    ThemeToggle(isOn: $preset.filterEnvUseDedicatedADSR)
                }
            }

            if selectedEnv == 1 {
                ADSRGraph(attack: preset.attack, decay: preset.decay, sustain: preset.sustain, release: preset.release)
                    .frame(height: 40)
                    .padding(2)
                    .appleInset()

                HStack(spacing: 8) {
                    KnobView(value: $preset.attack, range: 0.001...2.0, label: "Attack", format: "%.2fs")
                    KnobView(value: $preset.decay, range: 0.001...2.0, label: "Decay", format: "%.2fs")
                    KnobView(value: $preset.sustain, range: 0...1, label: "Sustain", format: "%.0f%%")
                    KnobView(value: $preset.release, range: 0.001...3.0, label: "Release", format: "%.2fs")
                }

                velocityRow
                timingRow(
                    delay: $preset.ampDelay,
                    hold: $preset.ampHold,
                    extras: [
                        ("Vel", $preset.velToAttack, -1...1),
                        ("Dcy", $preset.velToDecay, -1...1),
                        ("Key", $preset.envKeyTrack, -1...1)
                    ]
                )
            } else {
                ADSRGraph(attack: preset.filterAttack, decay: preset.filterDecay, sustain: preset.filterSustain, release: preset.filterRelease)
                    .frame(height: 40)
                    .padding(2)
                    .appleInset()

                HStack(spacing: 8) {
                    KnobView(value: $preset.filterAttack, range: 0.001...2.0, label: "Attack", format: "%.2fs", target: .filterAttack)
                    KnobView(value: $preset.filterDecay, range: 0.001...2.0, label: "Decay", format: "%.2fs", target: .filterDecay)
                    KnobView(value: $preset.filterSustain, range: 0...1, label: "Sustain", format: "%.0f%%", target: .filterSustain)
                    KnobView(value: $preset.filterRelease, range: 0.001...3.0, label: "Release", format: "%.2fs", target: .filterRelease)
                }

                timingRow(
                    delay: $preset.filterEnvDelay,
                    hold: $preset.filterEnvHold,
                    extras: [
                        ("Atk", $preset.filterAttackCurve, -1...1),
                        ("Dcy", $preset.filterDecayCurve, -1...1),
                        ("Rel", $preset.filterReleaseCurve, -1...1)
                    ]
                )
            }
        }
        .padding(6)
        .appleCard(accent: theme.aEnv)
    }

    private var velocityRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Picker("Curve", selection: $preset.velocityCurve) {
                    ForEach(VelocityCurve.allCases, id: \.self) { curve in
                        Text(curve.shortTitle).tag(curve)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityIdentifier("velocityCurve")

                if preset.velocityCurve == .decibel {
                    Text(String(format: "Vel Sens: %.0f dB", preset.velocityRangeDb))
                        .themeCaption(theme, size: 8)
                        .foregroundColor(theme.textDim)
                        .lineLimit(1)
                    ThemeSlider(value: $preset.velocityRangeDb, range: 0...60)
                        .help("Velocity range in dB. 0 makes every velocity gain 1.")
                    Text("Shape")
                        .themeCaption(theme, size: 8)
                        .foregroundColor(theme.textDim)
                    ThemeSlider(value: $preset.velocityCurveShape, range: -1...1)
                        .frame(maxWidth: 70)
                        .help("Curve bend, −1 log to +1 exp.")
                } else {
                    Text("Vel")
                        .themeCaption(theme, size: 8)
                        .foregroundColor(theme.textDim)
                    ThemeSlider(value: $preset.velocityToVolume, range: 0...1)
                        .help("How much the velocity curve moves the level.")
                }
            }
            velocityGraph
        }
    }

    @ViewBuilder
    private var velocityGraph: some View {
        if let metering {
            TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { _ in
                VelocityCurveGraph(
                    curve: preset.velocityCurve,
                    toVolume: preset.velocityToVolume,
                    rangeDb: preset.velocityRangeDb,
                    curveShape: preset.velocityCurveShape,
                    played: metering.getPlayedVelocity()
                )
            }
        } else {
            VelocityCurveGraph(
                curve: preset.velocityCurve,
                toVolume: preset.velocityToVolume,
                rangeDb: preset.velocityRangeDb,
                curveShape: preset.velocityCurveShape,
                played: 0
            )
        }
    }

    private func timingRow(
        delay: Binding<Float>,
        hold: Binding<Float>,
        extras: [(String, Binding<Float>, ClosedRange<Float>)]
    ) -> some View {
        HStack(spacing: 4) {
            Picker("Model", selection: $preset.envelopeModel) {
                ForEach(EnvelopeModel.allCases, id: \.self) { model in
                    Text(model.rawValue).tag(model)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .accessibilityIdentifier("envelopeModel")
            miniSlider("Dly", delay, 0...4)
            miniSlider("Hold", hold, 0...4)
            ForEach(Array(extras.enumerated()), id: \.offset) { _, item in
                miniSlider(item.0, item.1, item.2)
            }
        }
    }

    private func miniSlider(_ title: String, _ value: Binding<Float>, _ range: ClosedRange<Float>) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .themeCaption(theme, size: 8)
                .foregroundColor(theme.textDim)
                .lineLimit(1)
            ThemeSlider(value: value, range: range)
        }
    }
}

/// Amp law from velocity 0 to 1, with a dot at the last touch-shaped velocity.
struct VelocityCurveGraph: View {
    @Environment(\.theme) private var theme
    let curve: VelocityCurve
    let toVolume: Float
    let rangeDb: Float
    let curveShape: Float
    let played: Float

    var body: some View {
        Canvas { context, size in
            var path = Path()
            let steps = 32
            for i in 0...steps {
                let v = Float(i) / Float(steps)
                let gain = AudioEngine.legacyVelocityGain(
                    velocity: v,
                    curve: curve,
                    toVolume: toVolume,
                    rangeDb: rangeDb,
                    curveShape: curveShape
                )
                let point = CGPoint(x: CGFloat(v) * size.width, y: yPosition(gain, height: size.height))
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(theme.aEnv), lineWidth: 1.5)

            let clamped = min(1, max(0, played))
            let dotGain = AudioEngine.legacyVelocityGain(
                velocity: clamped,
                curve: curve,
                toVolume: toVolume,
                rangeDb: rangeDb,
                curveShape: curveShape
            )
            let dot = CGPoint(
                x: CGFloat(clamped) * size.width,
                y: yPosition(dotGain, height: size.height)
            )
            let rect = CGRect(x: dot.x - 2.5, y: dot.y - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: rect), with: .color(theme.accent))
        }
        .frame(height: 28)
        .accessibilityIdentifier("velSensGraph")
    }

    private func yPosition(_ gain: Float, height: CGFloat) -> CGFloat {
        let y = min(1, max(0, gain))
        return height - CGFloat(y) * height
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
