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
                ADSRGraph(
                    attack: preset.attack,
                    decay: preset.decay,
                    sustain: preset.sustain,
                    release: preset.release,
                    delay: preset.ampDelay,
                    hold: preset.ampHold,
                    attackCurve: preset.attackCurve,
                    decayCurve: preset.decayCurve,
                    releaseCurve: preset.releaseCurve,
                    envelopeModel: preset.envelopeModel
                )
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
                ADSRGraph(
                    attack: preset.filterAttack,
                    decay: preset.filterDecay,
                    sustain: preset.filterSustain,
                    release: preset.filterRelease,
                    delay: preset.filterEnvDelay,
                    hold: preset.filterEnvHold,
                    attackCurve: preset.filterAttackCurve,
                    decayCurve: preset.filterDecayCurve,
                    releaseCurve: preset.filterReleaseCurve,
                    envelopeModel: preset.envelopeModel
                )
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
            .fixedSize()
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
            var refPath = Path()
            refPath.move(to: CGPoint(x: 0, y: size.height))
            refPath.addLine(to: CGPoint(x: size.width, y: 0))
            context.stroke(
                refPath,
                with: .color(theme.border.opacity(0.35)),
                style: StrokeStyle(lineWidth: 0.6, dash: [2, 2])
            )

            var path = Path()
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: 0, y: size.height))
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
                fillPath.addLine(to: point)
            }
            fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [theme.aEnv.opacity(0.18), theme.aEnv.opacity(0.02)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
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
        .background(
            RoundedRectangle(cornerRadius: theme.rSmall)
                .fill(theme.scopeBg)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.rSmall))
        .overlay(
            RoundedRectangle(cornerRadius: theme.rSmall)
                .stroke(theme.border.opacity(0.7), lineWidth: 0.75)
        )
        .accessibilityIdentifier("velSensGraph")
    }

    private func yPosition(_ gain: Float, height: CGFloat) -> CGFloat {
        let y = min(1, max(0, gain))
        return height - CGFloat(y) * (height - 4) - 2
    }
}

struct ADSRGraph: View {
    @Environment(\.theme) private var theme
    let attack: Float
    let decay: Float
    let sustain: Float
    let release: Float
    var delay: Float = 0
    var hold: Float = 0
    var attackCurve: Float = 0
    var decayCurve: Float = 0
    var releaseCurve: Float = 0
    var envelopeModel: EnvelopeModel = .legacy

    var body: some View {
        Canvas { context, size in
            let padX: CGFloat = 3
            let padY: CGFloat = 3
            let innerW = max(1, size.width - padX * 2)
            let innerH = max(1, size.height - padY * 2)

            let dTime = delay > 0.0005 ? max(0.05, sqrt(Double(delay))) : 0.0
            let aTime = max(0.05, sqrt(Double(max(0.001, attack))))
            let hTime = hold > 0.0005 ? max(0.05, sqrt(Double(hold))) : 0.0
            let decTime = max(0.05, sqrt(Double(max(0.001, decay))))
            let sTime = 0.30
            let rTime = max(0.06, sqrt(Double(max(0.001, release))))
            let total = dTime + aTime + hTime + decTime + sTime + rTime

            let x0 = padX
            let xDelay = x0 + CGFloat(dTime / total) * innerW
            let xAttack = xDelay + CGFloat(aTime / total) * innerW
            let xHold = xAttack + CGFloat(hTime / total) * innerW
            let xDecay = xHold + CGFloat(decTime / total) * innerW
            let xSustain = xDecay + CGFloat(sTime / total) * innerW
            let xRelease = padX + innerW
            let bottomY = padY + innerH

            @inline(__always)
            func yPos(_ level: Float) -> CGFloat {
                let clamped = max(0, min(1, level))
                return padY + innerH * CGFloat(1.0 - clamped)
            }

            // Vertical dashed phase dividers
            var dividers = Path()
            let dividerXs: [CGFloat] = [
                dTime > 0 ? xDelay : nil,
                xAttack,
                hTime > 0 ? xHold : nil,
                xDecay,
                xSustain
            ].compactMap { $0 }
            for dx in dividerXs {
                dividers.move(to: CGPoint(x: dx, y: padY))
                dividers.addLine(to: CGPoint(x: dx, y: bottomY))
            }
            context.stroke(
                dividers,
                with: .color(theme.border.opacity(0.45)),
                style: StrokeStyle(lineWidth: 0.75, dash: [2, 2])
            )

            var strokePath = Path()
            var fillPath = Path()
            let startPt = CGPoint(x: x0, y: bottomY)
            strokePath.move(to: startPt)
            fillPath.move(to: startPt)

            if dTime > 0 {
                let delayPt = CGPoint(x: xDelay, y: bottomY)
                strokePath.addLine(to: delayPt)
                fillPath.addLine(to: delayPt)
            }

            let segSteps = 16
            // Attack segment
            for i in 1...segSteps {
                let p = Float(i) / Float(segSteps)
                let level = Self.attackLevel(p: p, curve: attackCurve, model: envelopeModel)
                let pt = CGPoint(x: xDelay + CGFloat(p) * (xAttack - xDelay), y: yPos(level))
                strokePath.addLine(to: pt)
                fillPath.addLine(to: pt)
            }

            // Hold segment
            if hTime > 0 {
                let holdPt = CGPoint(x: xHold, y: yPos(1))
                strokePath.addLine(to: holdPt)
                fillPath.addLine(to: holdPt)
            }

            // Decay segment
            let sus = max(0, min(1, sustain))
            for i in 1...segSteps {
                let p = Float(i) / Float(segSteps)
                let fall = Self.decayFactor(p: p, curve: decayCurve, model: envelopeModel)
                let level = sus + (1.0 - sus) * fall
                let pt = CGPoint(x: xHold + CGFloat(p) * (xDecay - xHold), y: yPos(level))
                strokePath.addLine(to: pt)
                fillPath.addLine(to: pt)
            }

            // Sustain plateau
            let susEndPt = CGPoint(x: xSustain, y: yPos(sus))
            strokePath.addLine(to: susEndPt)
            fillPath.addLine(to: susEndPt)

            // Release segment
            for i in 1...segSteps {
                let p = Float(i) / Float(segSteps)
                let fall = Self.decayFactor(p: p, curve: releaseCurve, model: envelopeModel)
                let level = sus * fall
                let pt = CGPoint(x: xSustain + CGFloat(p) * (xRelease - xSustain), y: yPos(level))
                strokePath.addLine(to: pt)
                fillPath.addLine(to: pt)
            }

            fillPath.addLine(to: CGPoint(x: xRelease, y: bottomY))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [theme.aEnv.opacity(0.24), theme.aLFO.opacity(0.04)]),
                    startPoint: CGPoint(x: 0, y: padY),
                    endPoint: CGPoint(x: 0, y: bottomY)
                )
            )
            context.stroke(
                strokePath,
                with: .linearGradient(
                    Gradient(colors: [theme.aEnv, theme.aLFO]),
                    startPoint: CGPoint(x: x0, y: 0),
                    endPoint: CGPoint(x: xRelease, y: 0)
                ),
                style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round)
            )

            // Transition node dots
            var nodes: [CGPoint] = [startPt]
            if dTime > 0 { nodes.append(CGPoint(x: xDelay, y: bottomY)) }
            nodes.append(CGPoint(x: xAttack, y: yPos(1)))
            if hTime > 0 { nodes.append(CGPoint(x: xHold, y: yPos(1))) }
            nodes.append(CGPoint(x: xDecay, y: yPos(sus)))
            nodes.append(susEndPt)
            nodes.append(CGPoint(x: xRelease, y: bottomY))

            for pt in nodes {
                let dotRect = CGRect(x: pt.x - 2, y: pt.y - 2, width: 4, height: 4)
                context.fill(Path(ellipseIn: dotRect), with: .color(theme.card))
                context.stroke(Path(ellipseIn: dotRect), with: .color(theme.aEnv), lineWidth: 1.25)
            }
        }
    }

    private static func attackLevel(p: Float, curve: Float, model: EnvelopeModel) -> Float {
        let clamped = max(0, min(1, p))
        if model == .analog {
            let ratio: Float = 0.3
            let base = ratio / (1.0 + ratio)
            return min(1.0, (1.0 + ratio) * (1.0 - pow(base, clamped)))
        }
        if abs(curve) < 0.005 {
            let denom: Float = 1.0 - exp(-5.0)
            return (1.0 - exp(-5.0 * clamped)) / denom
        }
        let exponent = curve > 0 ? (1.0 + 3.0 * curve) : (1.0 / (1.0 - 3.0 * curve))
        return pow(clamped, exponent)
    }

    private static func decayFactor(p: Float, curve: Float, model: EnvelopeModel) -> Float {
        let clamped = max(0, min(1, p))
        if model == .analog {
            let r: Float = 0.015
            return max(0.0, (pow(r, clamped) - r) / (1.0 - r))
        }
        if abs(curve) < 0.005 {
            let tail: Float = exp(-5.0)
            return max(0.0, (exp(-5.0 * clamped) - tail) / (1.0 - tail))
        }
        let exponent = curve > 0 ? (1.0 + 3.0 * curve) : (1.0 / (1.0 - 3.0 * curve))
        return max(0.0, 1.0 - pow(clamped, exponent))
    }
}

#Preview {
    ADSRView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(Theme.baseline.bg)
}
