//
//  OscillatorView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore
import UniformTypeIdentifiers

struct OscillatorView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    let oscillatorNumber: Int
    /// Optional: needed for wavetable morph (lives on AudioEngine, not preset).
    var audioEngine: AudioEngine? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AppleSectionHeader(title: "OSC \(oscillatorNumber)", accent: theme.aOsc, icon: "waveform")
                Spacer()
                if oscillatorNumber == 1 {
                    HStack(spacing: 3) {
                        Button {
                            preset.subOscOctave = preset.subOscOctave == -2 ? -1 : -2
                        } label: {
                            oscChipLabel(
                                preset.subOscOctave == -2 ? "-2 oct" : "-1 oct",
                                isActive: preset.subOscVolume > 0.001 && preset.subOscOctave == -2
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Sub-oscillator octave (-1 or -2)")

                        Menu {
                            Button("Sine") { preset.subOscWaveform = .sine }
                            Button("Triangle") { preset.subOscWaveform = .triangle }
                            Button("Square") { preset.subOscWaveform = .square }
                        } label: {
                            oscChipLabel(
                                preset.subOscWaveform == .sine ? "Sub Sin" : (preset.subOscWaveform == .triangle ? "Sub Tri" : "Sub Sqr"),
                                isActive: preset.subOscVolume > 0.001
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("Sub-oscillator waveform")

                        Menu {
                            ForEach(OscPhaseMode.allCases, id: \.self) { mode in
                                Button(mode.rawValue) { preset.oscPhaseMode = mode }
                            }
                        } label: {
                            oscChipLabel(
                                preset.oscPhaseMode.rawValue,
                                isActive: preset.oscPhaseMode != .reset
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .accessibilityIdentifier("oscPhaseMode")
                        .help("Oscillator phase: Reset, Free, or Random")
                    }
                }
                if oscillatorNumber == 2 {
                    HStack(spacing: 3) {
                        Button {
                            preset.osc2FixedFrequency.toggle()
                            if preset.osc2FixedFrequency {
                                preset.fmRatioEnabled = false
                            }
                        } label: {
                            oscChipLabel("HZ", isActive: preset.osc2FixedFrequency)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("osc2FixedFrequency")
                        .help("OSC 2 plays a fixed frequency (priority over FM ratio)")

                        Button {
                            preset.fmRatioEnabled.toggle()
                            if preset.fmRatioEnabled {
                                preset.osc2FixedFrequency = false
                            }
                        } label: {
                            oscChipLabel("RATIO", isActive: preset.fmRatioEnabled)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("fmRatio")
                        .help("FM ratio: coarse, fine, and which oscillator modulates the other (disabled when HZ is active)")

                        Button {
                            preset.oscSyncEnabled.toggle()
                        } label: {
                            oscChipLabel("SYNC", isActive: preset.oscSyncEnabled)
                        }
                        .buttonStyle(.plain)
                        .help("Hard Sync: OSC 1 forces OSC 2 phase reset")
                    }

                    ThemeToggle(isOn: $preset.osc2Enabled)
                }
            }

            if oscillatorNumber == 1 || preset.osc2Enabled {
                VStack(spacing: 8) {
                    HStack {
                        Text("Wave")
                            .themeCaption(theme, size: 11)
                            .foregroundColor(theme.textDim)
                            .lineLimit(1)
                        Spacer()
                    }
                    WaveformPicker(
                        selected: oscillatorNumber == 1 ? $preset.osc1Waveform : $preset.osc2Waveform,
                        accent: theme.aOsc
                    )
                    HStack(spacing: oscillatorNumber == 2 ? 6 : 10) {
                        KnobView(
                            value: oscillatorNumber == 1 ? $preset.osc1Volume : $preset.osc2Volume,
                            range: 0...1,
                            label: "Volume",
                            modulated: modSources(.mix, in: preset.modMatrix),
                            modulationAmount: modAmount(.mix, in: preset.modMatrix)
                        )
                        VStack(spacing: 4) {
                            Text("Octave")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .lineLimit(1)
                            HStack(spacing: 8) {
                                Button("-") {
                                    if oscillatorNumber == 1 { preset.osc1Octave = max(-2, preset.osc1Octave - 1) }
                                    else { preset.osc2Octave = max(-2, preset.osc2Octave - 1) }
                                }
                                .buttonStyle(.plain).foregroundColor(theme.text)
                                Text("\(oscillatorNumber == 1 ? preset.osc1Octave : preset.osc2Octave)")
                                    .font(theme.monoFont(size: 12))
                                    .foregroundColor(theme.text).frame(width: 30)
                                Button("+") {
                                    if oscillatorNumber == 1 { preset.osc1Octave = min(2, preset.osc1Octave + 1) }
                                    else { preset.osc2Octave = min(2, preset.osc2Octave + 1) }
                                }
                                .buttonStyle(.plain).foregroundColor(theme.text)
                            }
                        }
                        KnobView(
                            value: oscillatorNumber == 1 ? $preset.osc1Detune : $preset.osc2Detune,
                            range: -50...50,
                            label: "Detune",
                            format: "%.0f ct"
                        )
                        if oscillatorNumber == 1 {
                            KnobView(
                                value: $preset.subOscVolume,
                                range: 0...1,
                                label: "Sub",
                                format: "%.0f %%"
                            )
                        }
                        if oscillatorNumber == 2 {
                            KnobView(
                                value: $preset.fmAmount,
                                range: 0...1,
                                label: "FM",
                                format: "%.0f %%"
                            )
                            KnobView(
                                value: $preset.ringModAmount,
                                range: 0...1,
                                label: "Ring",
                                format: "%.0f %%"
                            )
                        }
                    }
                    if oscillatorNumber == 2 && preset.osc2FixedFrequency {
                        KnobView(value: $preset.osc2FrequencyHz, range: 20...4000, label: "Hz", format: "%.0f")
                    }
                    if oscillatorNumber == 2 && preset.fmRatioEnabled {
                        HStack(spacing: 6) {
                            KnobView(
                                value: Binding(
                                    get: { Float(preset.fmCoarse) },
                                    set: { preset.fmCoarse = Int(max(1, min(16, $0.rounded()))) }
                                ),
                                range: 1...16,
                                label: "Ratio",
                                format: "%.0f"
                            )
                            KnobView(
                                value: $preset.fmFine,
                                range: -1...1,
                                label: "Fine",
                                format: "%.2f"
                            )
                            Button {
                                preset.fmRoute = preset.fmRoute == .osc2ToOsc1 ? .osc1ToOsc2 : .osc2ToOsc1
                            } label: {
                                oscChipLabel(
                                    preset.fmRoute == .osc2ToOsc1 ? "2→1" : "1→2",
                                    isActive: true
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("fmRoute")
                            .help("OSC 2 modulates OSC 1, or OSC 1 modulates OSC 2")
                        }
                    }
                    if (oscillatorNumber == 1 && preset.osc1Waveform == .noise) ||
                       (oscillatorNumber == 2 && preset.osc2Waveform == .noise) {
                        HStack {
                            Text("Color")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            ThemeSegmented(
                                options: [
                                    (value: NoiseColor.white, title: "White"),
                                    (value: NoiseColor.pink, title: "Pink"),
                                    (value: NoiseColor.brown, title: "Brown")
                                ],
                                selection: $preset.noiseColor,
                                accent: theme.aOsc
                            )
                        }
                        .padding(.top, 4)
                    }
                    if (oscillatorNumber == 1 && preset.osc1Waveform == .square) ||
                       (oscillatorNumber == 2 && preset.osc2Waveform == .square) {
                        HStack {
                            Text("PWM")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            if !modSources(oscillatorNumber == 1 ? .pwm1 : .pwm2, in: preset.modMatrix).isEmpty {
                                Circle()
                                    .fill(theme.aMod)
                                    .frame(width: 5, height: 5)
                                    .help("Acts only on Pulse")
                            }
                            ThemeSlider(
                                value: oscillatorNumber == 1 ? $preset.osc1PulseWidth : $preset.osc2PulseWidth,
                                range: 0.05...0.95
                            )
                        }
                        .padding(.top, 4)
                    }
                    if isWavetableSelected, audioEngine != nil {
                        HStack(spacing: 4) {
                            ThemeSegmented(
                                options: [
                                    (value: 0, title: "Basic"),
                                    (value: 1, title: "Analog"),
                                    (value: 2, title: "Digital"),
                                    (value: 3, title: "PWM"),
                                    (value: 4, title: "Formant"),
                                    (value: 5, title: "User")
                                ],
                                selection: wavetableIndex,
                                accent: theme.aOsc
                            )
                            Button {
                                openUserWavetable()
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import…")
                                }
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(theme.textDim)
                                .padding(.horizontal, 5)
                                .frame(height: 22)
                                .background(theme.inset)
                                .clipShape(RoundedRectangle(cornerRadius: max(theme.rSmall - 1, 2)))
                            }
                            .buttonStyle(.plain)
                            .help("Import WAV/AIFF sample into wavetable")
                        }
                        .padding(.top, 4)

                        HStack {
                            Text("Morph")
                                .themeCaption(theme, size: 10)
                                .foregroundColor(theme.textDim)
                                .frame(width: 40, alignment: .trailing)
                            if !modSources(oscillatorNumber == 1 ? .wtMorph1 : .wtMorph2, in: preset.modMatrix).isEmpty {
                                Circle()
                                    .fill(theme.aMod)
                                    .frame(width: 5, height: 5)
                                    .help("Modulated by matrix")
                            }
                            ThemeSlider(value: wavetableMorph, range: 0...1)
                        }
                        .padding(.top, 4)

                        WavetableFramePreview(
                            frames: activeFrames,
                            morph: wavetableMorph,
                            accent: theme.aOsc
                        )
                        .frame(height: 30)
                        .padding(.top, 2)
                    }
                }
            }
        }
        .padding(8)
        .appleCard(accent: theme.aOsc)
    }

    private func oscChipLabel(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .themeCaption(theme, size: 8.5, weight: .bold)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isActive ? theme.aOsc : theme.inset)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isActive ? theme.aOsc : theme.border.opacity(0.75), lineWidth: 0.75)
            )
            .foregroundColor(isActive ? (theme.id == .studio ? theme.bg : .white) : theme.textDim)
    }

    private var isWavetableSelected: Bool {
        if oscillatorNumber == 1 {
            return preset.osc1Waveform == .wavetable
        }
        return preset.osc2Waveform == .wavetable
    }

    /// Morph is stored on `preset` so later `applyPreset` (filter/ADSR edits) cannot reset it.
    private var wavetableMorph: Binding<Float> {
        Binding(
            get: {
                oscillatorNumber == 1
                    ? preset.osc1WavetableMorph
                    : preset.osc2WavetableMorph
            },
            set: { value in
                let clamped = max(0, min(1, value))
                if let engine = audioEngine {
                    // Write through engine so didSet → applyPreset keeps oscillators in sync.
                    engine.updatePreset { p in
                        if oscillatorNumber == 1 {
                            p.osc1WavetableMorph = clamped
                        } else {
                            p.osc2WavetableMorph = clamped
                        }
                    }
                } else {
                    if oscillatorNumber == 1 {
                        preset.osc1WavetableMorph = clamped
                    } else {
                        preset.osc2WavetableMorph = clamped
                    }
                }
            }
        )
    }

    private var wavetableIndex: Binding<Int> {
        Binding(
            get: {
                oscillatorNumber == 1
                    ? preset.osc1WavetableIndex
                    : preset.osc2WavetableIndex
            },
            set: { value in
                let clamped = max(0, min(5, value))
                if clamped == 5 && WavetableOscillator.userWavetable == nil {
                    openUserWavetable()
                }
                if let engine = audioEngine {
                    engine.updatePreset { p in
                        if oscillatorNumber == 1 {
                            p.osc1WavetableIndex = clamped
                        } else {
                            p.osc2WavetableIndex = clamped
                        }
                    }
                } else {
                    if oscillatorNumber == 1 {
                        preset.osc1WavetableIndex = clamped
                    } else {
                        preset.osc2WavetableIndex = clamped
                    }
                }
            }
        )
    }

    private var activeFrames: [[Float]] {
        let idx = oscillatorNumber == 1 ? preset.osc1WavetableIndex : preset.osc2WavetableIndex
        if idx == 5 {
            return WavetableOscillator.userWavetable?.frames ?? WavetableOscillator.basicWavetables[0].frames
        }
        let safeIdx = max(0, min(WavetableOscillator.basicWavetables.count - 1, idx))
        return WavetableOscillator.basicWavetables[safeIdx].frames
    }

    private func openUserWavetable() {
        let panel = NSOpenPanel()
        panel.title = "Select Sample or Wavetable (.wav, .aif)"
        panel.allowedContentTypes = [
            UTType.audio,
            UTType.wav,
            UTType.aiff,
            UTType(filenameExtension: "aif") ?? .audio,
            UTType(filenameExtension: "aiff") ?? .audio
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try audioEngine?.loadUserWavetable(url: url, forOscillator: oscillatorNumber)
        } catch {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Couldn't load wavetable"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }
}

struct WavetableFramePreview: View {
    @Environment(\.theme) private var theme
    let frames: [[Float]]
    @Binding var morph: Float
    let accent: Color

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width)
            let frameCount = frames.count
            if frameCount > 0 {
                let framePos = max(0, min(Float(frameCount - 1), morph * Float(max(1, frameCount - 1))))
                let idx1 = max(0, min(frameCount - 1, Int(framePos)))

                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(theme.inset)

                    Canvas { context, size in
                        let cw = size.width
                        let ch = size.height
                        guard cw > 4, ch > 4 else { return }

                        let sliceCount = 6
                        let sliceW = max(1, cw - 16)
                        let baseMidY = ch * 0.62
                        let amp = ch * 0.28

                        // 6 background reference slices stacked with isometric depth/parallax
                        for layer in (0..<sliceCount).reversed() {
                            let layerNorm = Float(layer) / Float(max(1, sliceCount - 1))
                            let refIdx = frameCount > 1
                                ? min(frameCount - 1, Int(round(layerNorm * Float(frameCount - 1))))
                                : 0
                            let ref = frames[refIdx]
                            let n = ref.count
                            guard n > 1 else { continue }

                            let ox = 2.0 + CGFloat(layer + 1) * 2.0
                            let oy = -CGFloat(layer + 1) * 1.15
                            let step = max(1, n / max(1, Int(sliceW)))
                            var slicePath = Path()
                            var first = true
                            for i in stride(from: 0, to: n, by: step) {
                                let x = ox + (CGFloat(i) / CGFloat(n - 1)) * sliceW
                                let y = (baseMidY + oy) - CGFloat(ref[i]) * (amp * 0.85)
                                if first {
                                    slicePath.move(to: CGPoint(x: x, y: y))
                                    first = false
                                } else {
                                    slicePath.addLine(to: CGPoint(x: x, y: y))
                                }
                            }
                            context.stroke(
                                slicePath,
                                with: .color(accent.opacity(0.22)),
                                style: StrokeStyle(lineWidth: 0.85, lineCap: .round, lineJoin: .round)
                            )
                        }

                        // Foreground interpolated frame at `morph`
                        let idx2 = min(idx1 + 1, frameCount - 1)
                        let frac = framePos - Float(idx1)
                        let f1 = frames[idx1]
                        let f2 = frames[idx2]
                        let sampleCount = min(f1.count, f2.count)
                        guard sampleCount > 1 else { return }

                        let step = max(1, sampleCount / max(1, Int(sliceW)))
                        var fgPath = Path()
                        var fillPath = Path()
                        var first = true
                        var lastX: CGFloat = 2.0

                        for i in stride(from: 0, to: sampleCount, by: step) {
                            let val = f1[i] + (f2[i] - f1[i]) * frac
                            let x = 2.0 + (CGFloat(i) / CGFloat(sampleCount - 1)) * sliceW
                            let y = baseMidY - CGFloat(val) * amp
                            if first {
                                fgPath.move(to: CGPoint(x: x, y: y))
                                fillPath.move(to: CGPoint(x: x, y: ch))
                                fillPath.addLine(to: CGPoint(x: x, y: y))
                                first = false
                            } else {
                                fgPath.addLine(to: CGPoint(x: x, y: y))
                                fillPath.addLine(to: CGPoint(x: x, y: y))
                            }
                            lastX = x
                        }
                        fillPath.addLine(to: CGPoint(x: lastX, y: ch))
                        fillPath.closeSubpath()

                        context.fill(
                            fillPath,
                            with: .linearGradient(
                                Gradient(colors: [accent.opacity(0.28), accent.opacity(0.03)]),
                                startPoint: CGPoint(x: 0, y: 0),
                                endPoint: CGPoint(x: 0, y: ch)
                            )
                        )
                        context.stroke(
                            fgPath,
                            with: .color(accent),
                            style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round)
                        )
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                    Text("F \(idx1 + 1)/\(frameCount)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.textDim)
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(theme.border.opacity(0.6), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                PatchHistoryManager.shared.onDragStart()
                            }
                            let next = min(1, max(0, Float(gesture.location.x / w)))
                            morph = next
                        }
                        .onEnded { _ in
                            isDragging = false
                            PatchHistoryManager.shared.onDragEnd()
                        }
                )
            } else {
                RoundedRectangle(cornerRadius: 3)
                    .fill(theme.inset)
            }
        }
    }
}

#Preview {
    HStack {
        OscillatorView(preset: .constant(.defaultPreset), oscillatorNumber: 1)
        OscillatorView(preset: .constant(.defaultPreset), oscillatorNumber: 2)
    }
    .padding()
    .background(Theme.baseline.bg)
}
