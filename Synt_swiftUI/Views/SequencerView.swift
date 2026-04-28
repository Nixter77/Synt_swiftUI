//
//  SequencerView.swift
//  Synt_swiftUI
//

import SwiftUI

struct SequencerView: View {
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                AppleSectionHeader(title: "ARPEGGIATOR / SEQUENCER", accent: AppleTheme.accentSequencer, icon: "metronome")
                Spacer()
                HStack(spacing: 4) {
                    Text("BPM").font(.system(size: 10, design: .rounded)).foregroundColor(AppleTheme.textSecondary)
                    Text("\(Int(preset.bpm))").font(.system(size: 11, weight: .bold)).frame(width: 30)
                    Stepper("", value: $preset.bpm, in: 20...300, step: 1).labelsHidden().scaleEffect(0.8)
                }
                .padding(4).background(AppleTheme.surfaceSecondary).cornerRadius(6)
                
                Picker("Rate", selection: $preset.arpRate) {
                    ForEach(TimeDivision.allCases, id: \.self) { rate in
                        Text(rate.rawValue).tag(rate)
                    }
                }
                .pickerStyle(.menu).frame(width: 60).background(AppleTheme.surfaceSecondary).cornerRadius(6).labelsHidden()

                Spacer()
                
                Picker("Mode", selection: $preset.arpMode) {
                    ForEach(ArpeggiatorMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.menu).frame(width: 80).background(AppleTheme.surfaceSecondary).cornerRadius(6).labelsHidden()
            }
            .padding(.horizontal, 8)
            
            HStack(spacing: 2) {
                ForEach(0..<16) { index in
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(preset.sequencerData[index].isActive ? AppleTheme.accentSequencer : AppleTheme.surfaceInset)
                            .frame(height: 20).cornerRadius(3)
                        Button(action: { preset.sequencerData[index].isActive.toggle() }) {
                            Circle()
                                .fill(preset.sequencerData[index].isActive ? AppleTheme.accentSequencer : AppleTheme.surfaceInset)
                                .frame(width: 8, height: 8)
                                .shadow(color: preset.sequencerData[index].isActive ? AppleTheme.accentSequencer.opacity(0.3) : .clear, radius: 2)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(4).appleInset(cornerRadius: 6)
        }
        .padding(8)
        .appleCard(accent: AppleTheme.accentSequencer)
    }
}
