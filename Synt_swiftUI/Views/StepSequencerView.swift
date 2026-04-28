//
//  StepSequencerView.swift
//  Synt_swiftUI
//
//  UI for the 16-step sequencer.
//

import SwiftUI

struct StepSequencerView: View {
    @ObservedObject var sequencer: StepSequencer
    @Binding var bpm: Float
    @Binding var isPlaying: Bool
    
    private let stepAccents: [Color] = [
        AppleTheme.accentDestructive, AppleTheme.accentOscillator, AppleTheme.accentModulation, AppleTheme.accentEnvelope,
        AppleTheme.accentLFO, AppleTheme.accentBlue, AppleTheme.accentFilter, AppleTheme.accentEffects,
        AppleTheme.accentDestructive, AppleTheme.accentOscillator, AppleTheme.accentModulation, AppleTheme.accentEnvelope,
        AppleTheme.accentLFO, AppleTheme.accentBlue, AppleTheme.accentFilter, AppleTheme.accentEffects
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                AppleSectionHeader(title: "STEP SEQUENCER", accent: AppleTheme.accentSequencer, icon: "squares.leading.rectangle")
                Spacer()
                Text("Root: \(noteNameForMIDI(sequencer.rootNote))")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(AppleTheme.textSecondary)
                Spacer()
                Button(action: { sequencer.clearPattern() }) {
                    Image(systemName: "trash").foregroundColor(AppleTheme.textTertiary)
                }.buttonStyle(.plain).help("Clear Pattern")
                Button(action: { sequencer.randomizePattern() }) {
                    Image(systemName: "dice").foregroundColor(AppleTheme.textTertiary)
                }.buttonStyle(.plain).help("Randomize Pattern")
            }
            
            HStack(spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    SeqStepButton(step: $sequencer.pattern.steps[index], index: index,
                        isCurrentStep: sequencer.currentStep == index && sequencer.isPlaying, color: stepAccents[index])
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
                    Text("SWING").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(AppleTheme.textSecondary)
                    SeqKnob(value: $sequencer.swing, range: 0...1).frame(width: 40, height: 40)
                    Text("\(Int(sequencer.swing * 100))%").font(.system(size: 10, design: .rounded)).foregroundColor(AppleTheme.textPrimary)
                }
                VStack(spacing: 2) {
                    Text("ROOT").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(AppleTheme.textSecondary)
                    HStack(spacing: 8) {
                        Button("-") { sequencer.rootNote = max(24, sequencer.rootNote - 1) }
                            .buttonStyle(.plain).foregroundColor(AppleTheme.textPrimary)
                        Text(noteNameForMIDI(sequencer.rootNote)).frame(width: 35).foregroundColor(AppleTheme.textPrimary).font(.system(size: 12, design: .rounded))
                        Button("+") { sequencer.rootNote = min(96, sequencer.rootNote + 1) }
                            .buttonStyle(.plain).foregroundColor(AppleTheme.textPrimary)
                    }
                }
                VStack(spacing: 2) {
                    Text("LENGTH").font(.system(size: 10, weight: .medium, design: .rounded)).foregroundColor(AppleTheme.textSecondary)
                    HStack(spacing: 8) {
                        Button("-") { sequencer.pattern.length = max(1, sequencer.pattern.length - 1) }
                            .buttonStyle(.plain).foregroundColor(AppleTheme.textPrimary)
                        Text("\(sequencer.pattern.length)").frame(width: 30).foregroundColor(AppleTheme.textPrimary)
                        Button("+") { sequencer.pattern.length = min(16, sequencer.pattern.length + 1) }
                            .buttonStyle(.plain).foregroundColor(AppleTheme.textPrimary)
                    }
                }
                Spacer()
            }
        }
        .padding()
        .appleCard(accent: AppleTheme.accentSequencer)
    }
    
    private func noteNameForMIDI(_ midi: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midi / 12) - 1
        return "\(noteNames[midi % 12])\(octave)"
    }
}

// MARK: - Sequencer Step Button

struct SeqStepButton: View {
    @Binding var step: SequencerStep
    let index: Int
    let isCurrentStep: Bool
    let color: Color
    
    var body: some View {
        Button(action: { step.isActive.toggle() }) {
            RoundedRectangle(cornerRadius: 6)
                .fill(step.isActive ? color.opacity(0.7) : AppleTheme.surfaceSecondary)
                .shadow(color: step.isActive ? color.opacity(0.25) : AppleTheme.shadowDark, radius: step.isActive ? 2 : 4, x: 1, y: 2)
                .shadow(color: AppleTheme.shadowLight, radius: 2, x: -1, y: -1)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCurrentStep ? AppleTheme.textPrimary : Color.white.opacity(0.4), lineWidth: isCurrentStep ? 2 : 0.5)
                )
                .overlay(
                    Group {
                        if index % 4 == 0 {
                            Circle().fill(AppleTheme.textTertiary.opacity(0.5)).frame(width: 4, height: 4).offset(y: -15)
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
    @Binding var step: SequencerStep
    let rootNote: Int
    let isEnabled: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            let finalNote = rootNote + step.noteOffset + (step.octave * 12)
            Text(noteNameForMIDI(finalNote))
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isEnabled ? AppleTheme.textPrimary : AppleTheme.textTertiary.opacity(0.5))
            HStack(spacing: 2) {
                Button(action: { step.noteOffset = min(24, step.noteOffset + 1) }) {
                    Image(systemName: "chevron.up").font(.system(size: 8))
                        .foregroundColor(isEnabled ? AppleTheme.textSecondary : AppleTheme.textTertiary.opacity(0.3))
                }.buttonStyle(.plain)
                Button(action: { step.noteOffset = max(-24, step.noteOffset - 1) }) {
                    Image(systemName: "chevron.down").font(.system(size: 8))
                        .foregroundColor(isEnabled ? AppleTheme.textSecondary : AppleTheme.textTertiary.opacity(0.3))
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
    @Binding var velocity: Float
    let isEnabled: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle().fill(AppleTheme.surfaceInset)
                Rectangle()
                    .fill(isEnabled ? AppleTheme.accentEnvelope.opacity(0.6) : AppleTheme.textTertiary.opacity(0.2))
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
    @Binding var value: Float
    let range: ClosedRange<Float>
    @State private var lastY: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let normalizedValue = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let rotation = -135 + Double(normalizedValue) * 270
            ZStack {
                Circle()
                    .fill(AppleTheme.surfaceSecondary)
                    .shadow(color: AppleTheme.shadowDark, radius: 3, x: 1, y: 2)
                    .shadow(color: AppleTheme.shadowLight, radius: 2, x: -1, y: -1)
                Circle()
                    .trim(from: 0.25, to: 0.25 + CGFloat(normalizedValue) * 0.75)
                    .stroke(AppleTheme.accentBlue, lineWidth: 3)
                    .rotationEffect(.degrees(-135))
                Rectangle()
                    .fill(AppleTheme.knobIndicator)
                    .frame(width: 2, height: size * 0.35)
                    .offset(y: -size * 0.15)
                    .rotationEffect(.degrees(rotation))
            }
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
    StepSequencerView(sequencer: StepSequencer(), bpm: .constant(120), isPlaying: .constant(false))
        .frame(width: 700, height: 200).background(AppleTheme.windowBackground)
}
