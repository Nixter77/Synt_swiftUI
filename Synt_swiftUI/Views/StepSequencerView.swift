//
//  StepSequencerView.swift
//  Synt_swiftUI
//
//  UI for the 16-step sequencer.
//

import SwiftUI

struct StepSequencerView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var sequencer: StepSequencer
    @ObservedObject var playhead: PlayheadModel
    @Binding var bpm: Float
    @Binding var isPlaying: Bool
    
    private var stepAccents: [Color] {
        [
            theme.destructive, theme.aOsc, theme.aMod, theme.aEnv,
            theme.aLFO, theme.accent, theme.aFilter, theme.aFx,
            theme.destructive, theme.aOsc, theme.aMod, theme.aEnv,
            theme.aLFO, theme.accent, theme.aFilter, theme.aFx
        ]
    }
    
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
            }
            
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    SeqStepButton(step: $sequencer.pattern.steps[index], index: index,
                        isCurrentStep: playhead.step == index && sequencer.isPlaying, color: stepAccents[index])
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
            
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("SWING").themeCaption(theme, size: 10).foregroundColor(theme.textDim)
                    SeqKnob(value: $sequencer.swing, range: 0...1).frame(width: 40, height: 40)
                    Text("\(Int(sequencer.swing * 100))%").font(theme.monoFont(size: 10)).foregroundColor(theme.text)
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
}

// MARK: - Sequencer Step Button

struct SeqStepButton: View {
    @Environment(\.theme) private var theme
    @Binding var step: SequencerStep
    let index: Int
    let isCurrentStep: Bool
    let color: Color
    
    var body: some View {
        Button(action: { step.isActive.toggle() }) {
            RoundedRectangle(cornerRadius: 6)
                .fill(step.isActive ? color.opacity(0.7) : theme.panel)
                .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCurrentStep ? theme.text : Color.white.opacity(0.4), lineWidth: isCurrentStep ? 2 : 0.5)
                )
                .overlay(
                    Group {
                        if index % 4 == 0 {
                            Circle().fill(theme.textFaint.opacity(0.5)).frame(width: 4, height: 4).offset(y: -15)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .frame(width: 35, height: 35)
        .animation(.easeInOut(duration: 0.1), value: isCurrentStep)
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
                .font(.system(size: 9, weight: .medium, design: .monospaced))
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
                    .fill(isEnabled ? theme.aEnv.opacity(0.6) : theme.textFaint.opacity(0.2))
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
    }
}

#Preview {
    let seq = StepSequencer()
    return StepSequencerView(sequencer: seq, playhead: seq.playhead, bpm: .constant(120), isPlaying: .constant(false))
        .frame(width: 700, height: 200).background(Theme.baseline.bg)
}
