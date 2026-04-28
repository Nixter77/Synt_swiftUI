//
//  WaveformPicker.swift
//  Synt_swiftUI
//

import SwiftUI

struct WaveformPicker: View {
    @Binding var selected: WaveformType

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WaveformType.allCases, id: \.self) { waveform in
                Button {
                    selected = waveform
                } label: {
                    WaveformIcon(type: waveform, isSelected: selected == waveform)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WaveformIcon: View {
    let type: WaveformType
    let isSelected: Bool

    var body: some View {
        ZStack {
            // 3D raised pill
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? AppleTheme.accentOscillator.opacity(0.12) : AppleTheme.surfaceSecondary)
                .frame(width: 38, height: 30)
                .shadow(color: isSelected ? AppleTheme.accentOscillator.opacity(0.2) : AppleTheme.shadowDark, radius: isSelected ? 2 : 4, x: 1, y: 2)
                .shadow(color: AppleTheme.shadowLight, radius: isSelected ? 1 : 3, x: -1, y: -1)
            
            // Border
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? AppleTheme.accentOscillator.opacity(0.5) : Color.white.opacity(0.6), lineWidth: 1)
                .frame(width: 38, height: 30)

            WaveformShape(type: type)
                .stroke(isSelected ? AppleTheme.accentOscillator : AppleTheme.textTertiary, lineWidth: 2)
                .frame(width: 24, height: 16)
        }
    }
}

struct WaveformShape: Shape {
    let type: WaveformType

    func path(in rect: CGRect) -> Path {
        var path = Path()

        switch type {
        case .sine:
            path.move(to: CGPoint(x: 0, y: rect.midY))
            for x in stride(from: 0, through: rect.width, by: 1) {
                let normalizedX = x / rect.width
                let y = rect.midY - sin(normalizedX * .pi * 2) * rect.height / 2
                path.addLine(to: CGPoint(x: x, y: y))
            }

        case .sawtooth:
            path.move(to: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.minY))

        case .square:
            path.move(to: CGPoint(x: 0, y: rect.maxY))
            path.addLine(to: CGPoint(x: 0, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width / 2, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width / 2, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.minY))

        case .triangle:
            path.move(to: CGPoint(x: 0, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.width / 4, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.width * 3 / 4, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
            
        case .noise:
             path.move(to: CGPoint(x: 0, y: rect.midY))
             for x in stride(from: 0, through: rect.width, by: 2) {
                 let randomY = rect.midY + CGFloat.random(in: -rect.height/2...rect.height/2)
                 path.addLine(to: CGPoint(x: x, y: randomY))
             }
        }

        return path
    }
}

#Preview {
    WaveformPicker(selected: .constant(.sawtooth))
        .padding()
        .background(AppleTheme.windowBackground)
}
