//
//  StepSequencerView.swift
//  Synt_swiftUI
//
//  UI for the 16-step sequencer.
//

import AppKit
import SynthCore
import SwiftUI
import UniformTypeIdentifiers

struct StepSequencerView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var sequencer: StepSequencer
    @ObservedObject var playhead: PlayheadModel
    @Binding var bpm: Float
    @Binding var isPlaying: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                AppleSectionHeader(title: "STEP SEQUENCER", accent: theme.aSeq, icon: "squares.leading.rectangle")
                Spacer()
                Text("Root: \(noteNameForMIDI(sequencer.rootNote))")
                    .themeCaption(theme, size: 12, weight: .regular).foregroundColor(theme.textDim)
                Spacer()
                Button(action: { sequencer.clearPattern() }) {
                    Image(systemName: "trash").foregroundColor(theme.textFaint)
                }.buttonStyle(.plain).help("Clear Pattern")
                Button(action: { sequencer.randomizePattern() }) {
                    Image(systemName: "dice").foregroundColor(theme.textFaint)
                }.buttonStyle(.plain).help("Randomize Pattern")
                Button(action: { exportMIDI() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 10))
                        Text("MIDI")
                            .font(theme.monoFont(size: 10, weight: .bold))
                    }
                    .foregroundColor(theme.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 4).fill(theme.panel))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.border, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                .help("Export 16-step pattern to Standard MIDI File (.mid)")
            }
            
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    SeqStepButton(step: $sequencer.pattern.steps[index], index: index,
                        isCurrentStep: playhead.step == index && sequencer.isPlaying)
                }
            }
            
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    SeqNoteCell(step: $sequencer.pattern.steps[index], rootNote: sequencer.rootNote,
                        isEnabled: sequencer.pattern.steps[index].isActive)
                }
            }
            
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    SeqVelocityBar(velocity: $sequencer.pattern.steps[index].velocity,
                        isEnabled: sequencer.pattern.steps[index].isActive)
                }
            }.frame(height: 40)

            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    SeqTieButton(step: $sequencer.pattern.steps[index])
                }
            }
            
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("SWING").themeCaption(theme, size: 10).foregroundColor(theme.textDim)
                    SeqKnob(value: $sequencer.swing, range: 0...1)
                }
                VStack(spacing: 2) {
                    Text("ROOT").themeCaption(theme, size: 10).foregroundColor(theme.textDim)
                    HStack(spacing: 8) {
                        Button("-") { sequencer.rootNote = max(24, sequencer.rootNote - 1) }
                            .buttonStyle(.plain).foregroundColor(theme.text)
                        Text(noteNameForMIDI(sequencer.rootNote)).frame(width: 35).foregroundColor(theme.text).font(theme.monoFont(size: 12))
                        Button("+") { sequencer.rootNote = min(96, sequencer.rootNote + 1) }
                            .buttonStyle(.plain).foregroundColor(theme.text)
                    }
                }
                VStack(spacing: 2) {
                    Text("LENGTH").themeCaption(theme, size: 10).foregroundColor(theme.textDim)
                    HStack(spacing: 8) {
                        Button("-") { sequencer.pattern.length = max(1, sequencer.pattern.length - 1) }
                            .buttonStyle(.plain).foregroundColor(theme.text)
                        Text("\(sequencer.pattern.length)").frame(width: 30).foregroundColor(theme.text)
                        Button("+") { sequencer.pattern.length = min(16, sequencer.pattern.length + 1) }
                            .buttonStyle(.plain).foregroundColor(theme.text)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .appleCard(accent: theme.aSeq)
    }
    
    private func noteNameForMIDI(_ midi: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midi / 12) - 1
        return "\(noteNames[midi % 12])\(octave)"
    }

    private func exportMIDI() {
        let midiData = MIDIFileBuilder.buildSMF(
            steps: sequencer.pattern.steps,
            rootNote: sequencer.rootNote,
            bpm: bpm,
            length: sequencer.pattern.length
        )
        #if os(macOS)
        let savePanel = NSSavePanel()
        if let midiType = UTType(filenameExtension: "mid") {
            savePanel.allowedContentTypes = [midiType]
        }
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "Sequencer_Pattern.mid"
        savePanel.begin { response in
            if response == .OK, let destination = savePanel.url {
                try? midiData.write(to: destination)
            }
        }
        #endif
    }
}

// MARK: - Sequencer Step Button

struct SeqStepButton: View {
    @Environment(\.theme) private var theme
    @Binding var step: SequencerStep
    let index: Int
    let isCurrentStep: Bool

    var body: some View {
        Button(action: { step.isActive.toggle() }) {
            RoundedRectangle(cornerRadius: 6)
                .fill(step.isActive ? theme.aSeq : theme.tile)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCurrentStep ? theme.accent : theme.border, lineWidth: isCurrentStep ? 2 : 1)
                )
                .overlay(alignment: .top) {
                    if index % 4 == 0 {
                        Circle().fill(theme.accent).frame(width: 4, height: 4).padding(.top, 3)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if step.ratchet > 1 {
                        Text("\(step.ratchet)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(step.isActive ? .black : theme.accent)
                            .padding([.bottom, .trailing], 2)
                    }
                }
        }
        .buttonStyle(.plain)
        .frame(width: 35, height: 35)
        .animation(.easeInOut(duration: 0.1), value: isCurrentStep)
        .contextMenu {
            Menu("Ratchet (\(step.ratchet)x)") {
                Button("1x (Normal)") { step.ratchet = 1 }
                Button("2x (Roll)") { step.ratchet = 2 }
                Button("3x (Triplet)") { step.ratchet = 3 }
                Button("4x (Quad)") { step.ratchet = 4 }
            }
            Menu("Probability (\(Int(step.probability * 100))%)") {
                Button("25%") { step.probability = 0.25 }
                Button("50%") { step.probability = 0.50 }
                Button("75%") { step.probability = 0.75 }
                Button("100%") { step.probability = 1.00 }
            }
        }
        .help("Click: Toggle Step | Right-Click: Ratchet & Probability")
    }
}

// MARK: - Sequencer Note Cell

struct SeqNoteCell: View {
    @Environment(\.theme) private var theme
    @Binding var step: SequencerStep
    let rootNote: Int
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            let finalNote = rootNote + step.noteOffset + (step.octave * 12)
            Text(noteNameForMIDI(finalNote))
                .font(theme.monoFont(size: 9, weight: .medium))
                .foregroundColor(isEnabled ? theme.text : theme.textFaint.opacity(0.5))
            HStack(spacing: 2) {
                Button(action: { step.noteOffset = min(24, step.noteOffset + 1) }) {
                    Image(systemName: "chevron.up").font(.system(size: 8))
                        .foregroundColor(isEnabled ? theme.textDim : theme.textFaint.opacity(0.3))
                }.buttonStyle(.plain)
                Button(action: { step.noteOffset = max(-24, step.noteOffset - 1) }) {
                    Image(systemName: "chevron.down").font(.system(size: 8))
                        .foregroundColor(isEnabled ? theme.textDim : theme.textFaint.opacity(0.3))
                }.buttonStyle(.plain)
            }
        }
        .frame(width: 35, height: 30)
    }
    
    private func noteNameForMIDI(_ midi: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let clampedMidi = max(0, min(127, midi))
        return "\(noteNames[clampedMidi % 12])\((clampedMidi / 12) - 1)"
    }
}

// MARK: - Sequencer Velocity Bar

struct SeqVelocityBar: View {
    @Environment(\.theme) private var theme
    @Binding var velocity: Float
    let isEnabled: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle().fill(theme.inset)
                Rectangle()
                    .fill(isEnabled ? theme.aSeq : theme.tile)
                    .frame(height: geometry.size.height * CGFloat(velocity))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        velocity = max(0.0, min(1.0, 1.0 - Float(value.location.y / geometry.size.height)))
                    }
            )
        }
        .frame(width: 35).cornerRadius(3)
    }
}

// MARK: - Sequencer Knob for Swing

struct SeqKnob: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    @State private var lastY: CGFloat = 0

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let fraction = knobArcFraction(value: value, range: range)
                KnobChrome(fraction: fraction, angle: -135 + Double(fraction) * 270, diameter: size, indicatorWidth: 2)
                    .shadow(color: theme.knobShadow.color, radius: theme.knobShadow.radius, x: 0, y: theme.knobShadow.y)
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                let delta = Float((lastY - gesture.location.y) / 100)
                                value = max(range.lowerBound, min(range.upperBound, value + delta * (range.upperBound - range.lowerBound)))
                                lastY = gesture.location.y
                            }
                            .onEnded { _ in lastY = 0 }
                    )
            }
            .frame(width: 40, height: 40)

            KnobValueField(
                value: $value,
                range: range,
                format: "%.0f%%",
                valueText: "\(Int((value * 100).rounded()))%",
                fontSize: 10,
                color: theme.text
            )
        }
    }
}

// MARK: - Sequencer Tie Button

struct SeqTieButton: View {
    @Environment(\.theme) private var theme
    @Binding var step: SequencerStep

    var body: some View {
        Button(action: { step.tie.toggle() }) {
            ZStack {
                RoundedRectangle(cornerRadius: 3)
                    .fill(step.tie ? theme.aSeq.opacity(0.85) : theme.tile)
                Image(systemName: "link")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(step.tie ? .black : theme.textFaint.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
        .frame(width: 35, height: 16)
        .contextMenu {
            Menu("Ratchet (\(step.ratchet)x)") {
                Button("1x (Normal)") { step.ratchet = 1 }
                Button("2x (Roll)") { step.ratchet = 2 }
                Button("3x (Triplet)") { step.ratchet = 3 }
                Button("4x (Quad)") { step.ratchet = 4 }
            }
            Menu("Probability (\(Int(step.probability * 100))%)") {
                Button("25%") { step.probability = 0.25 }
                Button("50%") { step.probability = 0.50 }
                Button("75%") { step.probability = 0.75 }
                Button("100%") { step.probability = 1.00 }
            }
            Menu("Step Gate (\(Int(step.gate * 100))%)") {
                Button("25% (Staccato)") { step.gate = 0.25 }
                Button("50% (Normal)") { step.gate = 0.50 }
                Button("80% (Full)") { step.gate = 0.80 }
                Button("100% (Legato)") { step.gate = 1.00 }
            }
            Menu("Step Octave (\(step.octave >= 0 ? "+\(step.octave)" : "\(step.octave)"))") {
                Button("-1 Octave") { step.octave = -1 }
                Button("0 Octave") { step.octave = 0 }
                Button("+1 Octave") { step.octave = 1 }
            }
        }
        .help("Click: Toggle Tie/Slide (🔗) | Right-Click: Step Gate, Octave, Ratchet & Probability")
    }
}

#Preview {
    let seq = StepSequencer()
    StepSequencerView(sequencer: seq, playhead: seq.playhead, bpm: .constant(120), isPlaying: .constant(false))
        .frame(width: 700, height: 200).background(Theme.baseline.bg)
}
