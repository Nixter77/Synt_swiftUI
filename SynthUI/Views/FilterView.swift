//
//  FilterView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

struct FilterView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    /// Default off so the panel keeps the Filter 1 height. LayoutTests measure that state.
    @State private var showsFilter2 = false

    private static let filter2Routes: [(value: DualFilterRouting, title: String)] = [
        (.off, "Off"),
        (.serial, "Serial"),
        (.parallel, "Parallel"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                AppleSectionHeader(title: "FILTER", accent: theme.aFilter, icon: "line.3.horizontal.decrease")
                Button {
                    showsFilter2.toggle()
                } label: {
                    HStack(spacing: 3) {
                        if preset.filter2Routing != .off {
                            Circle()
                                .fill(showsFilter2 ? .black : theme.aFilter)
                                .frame(width: 4, height: 4)
                        }
                        Text(showsFilter2 ? "F1" : "F2")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(showsFilter2 ? theme.aFilter : Color.clear)
                    .foregroundColor(showsFilter2 ? .black : theme.textDim)
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFilter.opacity(0.6), lineWidth: 1))
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("filter2Tab")
                .help("Filter 2")
                Spacer()
                Menu {
                    Menu("Velocity -> Env (\(Int((preset.velocityToEnvAmount * 100).rounded()))%)") {
                        Button("Off (0%)") { preset.velocityToEnvAmount = 0.0 }
                        Button("25%") { preset.velocityToEnvAmount = 0.25 }
                        Button("50%") { preset.velocityToEnvAmount = 0.50 }
                        Button("75%") { preset.velocityToEnvAmount = 0.75 }
                        Button("100% (Full)") { preset.velocityToEnvAmount = 1.00 }
                        Divider()
                        Button("-50% (Inverted)") { preset.velocityToEnvAmount = -0.50 }
                        Button("-100% (Inverted Full)") { preset.velocityToEnvAmount = -1.00 }
                    }
                } label: {
                    if abs(preset.velocityToEnvAmount) > 0.01 {
                        Text("V→E \(Int((preset.velocityToEnvAmount * 100).rounded()))%")
                            .font(theme.monoFont(size: 9, weight: .bold))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 4).fill(theme.accent.opacity(0.18)))
                    } else {
                        Image(systemName: "slider.horizontal.2.square")
                            .font(.system(size: 11))
                            .foregroundColor(theme.textDim)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Velocity to Envelope Amount Routing")
            }

            if showsFilter2 {
                ThemeSegmented(
                    options: Self.filter2Routes,
                    selection: $preset.filter2Routing,
                    accent: theme.aFilter
                )
                ThemeSegmented(
                    options: FilterType.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: $preset.filter2Type,
                    accent: theme.aFilter
                )
                FilterResponseGraph(
                    filterType: preset.filter2Type,
                    cutoff: $preset.filter2Cutoff,
                    resonance: $preset.filter2Resonance,
                    drive: 0,
                    vowel: preset.filterVowel,
                    filter2Routing: preset.filter2Routing,
                    filter2Type: preset.filterType,
                    filter2Cutoff: preset.filterCutoff,
                    filter2Resonance: preset.filterResonance,
                    isCutoffModulated: false
                )
                .frame(height: 34)
                HStack(spacing: 5) {
                    LargeKnobView(
                        value: $preset.filter2Cutoff,
                        range: 20...20000,
                        label: "Cutoff",
                        format: "%.0f Hz"
                    )
                    KnobView(value: $preset.filter2Resonance, range: 0...1, label: "Resonance")
                    KnobView(value: $preset.filter2Balance, range: 0...1, label: "Balance")
                    if preset.filter2Type == .formant {
                        KnobView(
                            value: $preset.filterVowel,
                            range: 0...4,
                            label: "Vowel",
                            modulated: modSources(.vowel, in: preset.modMatrix),
                            modulationAmount: modAmount(.vowel, in: preset.modMatrix)
                        )
                    }
                    Spacer(minLength: 0)
                }
            } else {
                ThemeSegmented(
                    options: FilterType.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: $preset.filterType,
                    accent: theme.aFilter
                )

                FilterResponseGraph(
                    filterType: preset.filterType,
                    cutoff: $preset.filterCutoff,
                    resonance: $preset.filterResonance,
                    drive: preset.filterDrive,
                    vowel: preset.filterVowel,
                    filter2Routing: preset.filter2Routing,
                    filter2Type: preset.filter2Type,
                    filter2Cutoff: preset.filter2Cutoff,
                    filter2Resonance: preset.filter2Resonance,
                    isCutoffModulated: !modSources(.cutoff, in: preset.modMatrix).isEmpty
                )
                .frame(height: 34)

                HStack(alignment: .center, spacing: 6) {
                    LargeKnobView(
                        value: $preset.filterCutoff,
                        range: 20...20000,
                        label: "Cutoff",
                        format: "%.0f Hz",
                        modulated: modSources(.cutoff, in: preset.modMatrix),
                        modulationAmount: modAmount(.cutoff, in: preset.modMatrix)
                    )
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            KnobView(
                                value: $preset.filterResonance,
                                range: 0...1,
                                label: "Resonance",
                                modulated: modSources(.resonance, in: preset.modMatrix),
                                modulationAmount: modAmount(.resonance, in: preset.modMatrix)
                            )
                            KnobView(value: $preset.filterEnvelopeAmount, range: -1...1, label: "Env")
                            KnobView(value: $preset.filterFeedback, range: -1...1, label: "Feedback")
                        }
                        HStack(spacing: 6) {
                            miniSlider("Vel", $preset.velocityToCutoff, 0...1)
                            miniSlider("Key Trk", $preset.filterKeyTracking, 0...1)
                            miniSlider("Drive", $preset.filterDrive, 0...1)
                        }
                    }
                }
                if preset.filterType == .formant {
                    HStack(spacing: 6) {
                        KnobView(
                            value: $preset.filterVowel,
                            range: 0...4,
                            label: "Vowel",
                            modulated: modSources(.vowel, in: preset.modMatrix),
                            modulationAmount: modAmount(.vowel, in: preset.modMatrix)
                        )
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(6)
        .appleCard(accent: theme.aFilter)
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

struct FilterResponseGraph: View {
    @Environment(\.theme) private var theme
    @Environment(\.liveModulation) private var liveModulation

    let filterType: FilterType
    @Binding var cutoff: Float
    @Binding var resonance: Float
    var drive: Float = 0
    var vowel: Float = 0
    var filter2Routing: DualFilterRouting = .off
    var filter2Type: FilterType = .lowPass
    var filter2Cutoff: Float = 2000
    var filter2Resonance: Float = 0.2
    var isCutoffModulated: Bool = false

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let h = max(1, geo.size.height)

            Group {
                if isCutoffModulated {
                    TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { _ in
                        canvasView(cutoffMod: liveModulation?.value(for: .cutoff) ?? 0)
                    }
                } else {
                    canvasView(cutoffMod: liveModulation?.value(for: .cutoff) ?? 0)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: theme.rSmall)
                    .fill(theme.scopeBg)
            )
            .clipShape(RoundedRectangle(cornerRadius: theme.rSmall))
            .overlay(
                RoundedRectangle(cornerRadius: theme.rSmall)
                    .stroke(theme.border, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            PatchHistoryManager.shared.onDragStart()
                        }
                        let nx = min(1.0, max(0.0, Double(gesture.location.x / w)))
                        let ny = min(1.0, max(0.0, Double(gesture.location.y / h)))
                        cutoff = Float(20.0 * pow(1000.0, nx))
                        resonance = Float(1.0 - ny)
                    }
                    .onEnded { _ in
                        isDragging = false
                        PatchHistoryManager.shared.onDragEnd()
                    }
            )
        }
    }

    private func canvasView(cutoffMod: Float) -> some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            guard w > 2, h > 2 else { return }

            drawGrid(context: &context, width: w, height: h)

            let steps = filterType == .comb || (filter2Routing != .off && filter2Type == .comb) ? 144 : 96
            var primaryPath = Path()
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: 0, y: h))

            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let freq = Float(20.0 * pow(1000.0, t))
                let mag = Self.magnitude(
                    type: filterType,
                    frequency: freq,
                    cutoff: cutoff,
                    resonance: resonance,
                    drive: drive,
                    vowel: vowel
                )
                let y = Self.yForMagnitude(mag, height: h)
                let x = CGFloat(t) * w
                let pt = CGPoint(x: x, y: y)
                if i == 0 { primaryPath.move(to: pt) } else { primaryPath.addLine(to: pt) }
                fillPath.addLine(to: pt)
            }
            fillPath.addLine(to: CGPoint(x: w, y: h))
            fillPath.closeSubpath()

            context.fill(
                fillPath,
                with: .linearGradient(
                    Gradient(colors: [theme.aFilter.opacity(0.26), theme.aFilter.opacity(0.03)]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h)
                )
            )

            if filter2Routing != .off {
                var secondaryPath = Path()
                for i in 0...steps {
                    let t = Double(i) / Double(steps)
                    let freq = Float(20.0 * pow(1000.0, t))
                    let mag2 = Self.magnitude(
                        type: filter2Type,
                        frequency: freq,
                        cutoff: filter2Cutoff,
                        resonance: filter2Resonance,
                        drive: 0,
                        vowel: vowel
                    )
                    let pt = CGPoint(x: CGFloat(t) * w, y: Self.yForMagnitude(mag2, height: h))
                    if i == 0 { secondaryPath.move(to: pt) } else { secondaryPath.addLine(to: pt) }
                }
                context.stroke(
                    secondaryPath,
                    with: .color(theme.accent2.opacity(0.75)),
                    style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round, dash: [4, 2.5])
                )
            }

            context.stroke(
                primaryPath,
                with: .color(theme.aFilter),
                style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
            )

            let baseX = Self.xForFrequency(cutoff, width: w)
            let baseY = CGFloat(1.0 - max(0, min(1, resonance))) * (h - 6) + 3

            if abs(cutoffMod) > 0.001 {
                let modCutoff = max(20, min(20000, cutoff * pow(2, cutoffMod * 4)))
                let modX = Self.xForFrequency(modCutoff, width: w)
                let bandX = min(baseX, modX)
                let bandW = abs(modX - baseX)
                if bandW > 0.5 {
                    context.fill(
                        Path(CGRect(x: bandX, y: 0, width: bandW, height: h)),
                        with: .color(theme.aMod.opacity(0.14))
                    )
                }
                var modLine = Path()
                modLine.move(to: CGPoint(x: modX, y: 1))
                modLine.addLine(to: CGPoint(x: modX, y: h - 1))
                context.stroke(modLine, with: .color(theme.aMod.opacity(0.85)), lineWidth: 1.0)

                let modMag = Self.magnitude(
                    type: filterType,
                    frequency: modCutoff,
                    cutoff: modCutoff,
                    resonance: resonance,
                    drive: drive,
                    vowel: vowel
                )
                let modY = Self.yForMagnitude(modMag, height: h)
                context.fill(
                    Path(ellipseIn: CGRect(x: modX - 2.5, y: modY - 2.5, width: 5, height: 5)),
                    with: .color(theme.aMod)
                )
            }

            let dotRect = CGRect(x: baseX - 2.5, y: baseY - 2.5, width: 5, height: 5)
            context.fill(Path(ellipseIn: dotRect), with: .color(theme.card))
            context.stroke(Path(ellipseIn: dotRect), with: .color(theme.aFilter), lineWidth: 1.5)
        }
    }

    private func drawGrid(context: inout GraphicsContext, width w: CGFloat, height h: CGFloat) {
        var grid = Path()
        for freq in [100.0, 1000.0, 10000.0] as [Float] {
            let x = Self.xForFrequency(freq, width: w)
            grid.move(to: CGPoint(x: x, y: 0))
            grid.addLine(to: CGPoint(x: x, y: h))
        }
        let zeroDbY = Self.yForDb(0, height: h)
        grid.move(to: CGPoint(x: 0, y: zeroDbY))
        grid.addLine(to: CGPoint(x: w, y: zeroDbY))
        context.stroke(grid, with: .color(theme.border.opacity(0.32)), lineWidth: 0.5)
    }

    private static func xForFrequency(_ freq: Float, width: CGFloat) -> CGFloat {
        let clamped = max(20.0, min(20000.0, Double(freq)))
        let norm = log10(clamped / 20.0) / 3.0
        return CGFloat(norm) * width
    }

    private static func yForDb(_ db: Float, height: CGFloat) -> CGFloat {
        let minDb: Float = -32.0
        let maxDb: Float = 20.0
        let norm = max(0.0, min(1.0, (db - minDb) / (maxDb - minDb)))
        return height - CGFloat(norm) * (height - 4) - 2
    }

    private static func yForMagnitude(_ mag: Float, height: CGFloat) -> CGFloat {
        let safeMag = max(1.0e-4, mag.isFinite ? mag : 1.0e-4)
        let db = 20.0 * log10(safeMag)
        return yForDb(db, height: height)
    }

    private static func magnitude(
        type: FilterType,
        frequency: Float,
        cutoff: Float,
        resonance: Float,
        drive: Float,
        vowel: Float
    ) -> Float {
        let fs: Float = 44100.0
        let safeFreq = max(20.0, min(fs * 0.48, frequency))
        let w = 2.0 * Float.pi * (safeFreq / fs)

        switch type {
        case .lowPass, .highPass, .bandPass, .notch:
            let coeffs = CachedBiquadFilter.coefficients(
                type: type,
                cutoff: max(20.0, min(fs * 0.48, cutoff)),
                resonance: resonance,
                sampleRate: fs
            )
            return biquadMagnitude(coeffs: coeffs, omega: w)

        case .ladder:
            let fc = max(20.0, min(fs * 0.45, cutoff))
            let g = tan(min(Float.pi * fc / fs, 1.5))
            let ratio = tan(w * 0.5) / max(1.0e-5, g)
            // Complex 1-pole TPT H1 = 1 / (1 + j * ratio)
            let invDen = 1.0 / (1.0 + ratio * ratio)
            let h1r = invDen
            let h1i = -ratio * invDen
            // Raise to 4th power: H1^4
            let h2r = h1r * h1r - h1i * h1i
            let h2i = 2.0 * h1r * h1i
            let h4r = h2r * h2r - h2i * h2i
            let h4i = 2.0 * h2r * h2i

            let res = max(0.0, min(1.0, resonance))
            let k = min(3.8, res * 3.8)
            let dr = 1.0 + k * h4r
            let di = k * h4i
            let d2 = max(1.0e-8, dr * dr + di * di)
            let rawMag = sqrt((h4r * h4r + h4i * h4i) / d2)
            let comp = 1.0 + k * 0.28 + max(0.0, min(1.0, drive)) * 0.35
            return rawMag * comp

        case .formant:
            let v = max(0.0, min(4.0, vowel))
            let baseIdx = min(3, Int(v))
            let frac = v - Float(baseIdx)
            let t0 = DSPFormantFilter.vowelTable[baseIdx]
            let t1 = DSPFormantFilter.vowelTable[baseIdx + 1]
            let freqs: [Float] = [
                (1 - frac) * t0.f1 + frac * t1.f1,
                (1 - frac) * t0.f2 + frac * t1.f2,
                (1 - frac) * t0.f3 + frac * t1.f3,
                (1 - frac) * t0.f4 + frac * t1.f4,
                (1 - frac) * t0.f5 + frac * t1.f5,
            ]
            let gains: [Float] = [
                (1 - frac) * t0.g1 + frac * t1.g1,
                (1 - frac) * t0.g2 + frac * t1.g2,
                (1 - frac) * t0.g3 + frac * t1.g3,
                (1 - frac) * t0.g4 + frac * t1.g4,
                (1 - frac) * t0.g5 + frac * t1.g5,
            ]
            let effectiveQ = max(0.5, min(40.0, 6.0 * (1.0 + max(0, min(1, resonance)) * 3.0)))
            let cw = cos(w)
            let sw = sin(w)
            let c2w = cos(2.0 * w)
            let s2w = sin(2.0 * w)
            var sumR: Float = 0
            var sumI: Float = 0

            for idx in 0..<5 {
                let bandFreq = max(20.0, min(fs * 0.48, freqs[idx]))
                let omega0 = 2.0 * Float.pi * (bandFreq / fs)
                let q = effectiveQ * (1.0 + 0.1 * Float(idx))
                let alpha = sin(omega0) / (2.0 * max(0.2, q))
                let invA0 = 1.0 / (1.0 + alpha)
                let b0 = alpha * invA0
                let b2 = -alpha * invA0
                let a1 = (-2.0 * cos(omega0)) * invA0
                let a2 = (1.0 - alpha) * invA0

                let nr = b0 + b2 * c2w
                let ni = -b2 * s2w
                let dr = 1.0 + a1 * cw + a2 * c2w
                let di = -(a1 * sw + a2 * s2w)
                let denom = max(1.0e-10, dr * dr + di * di)
                sumR += gains[idx] * (nr * dr + ni * di) / denom
                sumI += gains[idx] * (ni * dr - nr * di) / denom
            }
            return sqrt(sumR * sumR + sumI * sumI)

        case .comb:
            let fc = max(20.0, min(fs * 0.48, cutoff))
            let g = max(-0.98, min(0.98, resonance * 0.98))
            let phase = 2.0 * Float.pi * safeFreq / fc
            let denom = max(0.015, 1.0 + g * g - 2.0 * g * cos(phase))
            return min(8.0, 1.0 / sqrt(denom))
        }
    }

    private static func biquadMagnitude(coeffs: BiquadCoeffs, omega: Float) -> Float {
        let cw = cos(omega)
        let sw = sin(omega)
        let c2w = cos(2.0 * omega)
        let s2w = sin(2.0 * omega)
        let nr = coeffs.b0 + coeffs.b1 * cw + coeffs.b2 * c2w
        let ni = -(coeffs.b1 * sw + coeffs.b2 * s2w)
        let dr = 1.0 + coeffs.a1 * cw + coeffs.a2 * c2w
        let di = -(coeffs.a1 * sw + coeffs.a2 * s2w)
        let denom = max(1.0e-10, dr * dr + di * di)
        return sqrt((nr * nr + ni * ni) / denom)
    }
}

#Preview {
    FilterView(preset: .constant(.defaultPreset))
        .frame(width: 300).padding()
        .background(Theme.baseline.bg)
}
