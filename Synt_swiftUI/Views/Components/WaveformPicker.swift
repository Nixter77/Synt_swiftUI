//
//  WaveformPicker.swift
//  Synt_swiftUI
//

import SwiftUI

struct WaveformPicker: View {
    @Environment(\.theme) private var theme
    @Binding var selected: WaveformType
    var accent: Color? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WaveformType.allCases, id: \.self) { waveform in
                Button {
                    selected = waveform
                } label: {
                    WaveformIcon(
                        type: waveform,
                        isSelected: selected == waveform,
                        themeID: theme.id,
                        accent: accent ?? theme.aOsc
                    )
                        .equatable()
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WaveformIcon: View, Equatable {
    @Environment(\.theme) private var theme
    let type: WaveformType
    let isSelected: Bool
    let themeID: ThemeID
    let accent: Color

    static func == (lhs: WaveformIcon, rhs: WaveformIcon) -> Bool {
        lhs.type == rhs.type && lhs.isSelected == rhs.isSelected && lhs.themeID == rhs.themeID
            && lhs.accent == rhs.accent
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.rSmall)
                .fill(isSelected ? theme.tileSel : theme.tile)
                .frame(width: 38, height: 30)
                .shadow(
                    color: isSelected && theme.id == .baseline ? theme.cardShadow.color : .clear,
                    radius: isSelected && theme.id == .baseline ? 2 : 0,
                    x: 0,
                    y: 1
                )

            RoundedRectangle(cornerRadius: theme.rSmall)
                .stroke(isSelected ? accent : theme.border, lineWidth: 1)
                .frame(width: 38, height: 30)

            WaveformShape(type: type)
                .stroke(isSelected ? accent : theme.textFaint, lineWidth: 2)
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

        case .wavetable:
            // Stylized multi-frame morph: sine → richer partials
            path.move(to: CGPoint(x: 0, y: rect.midY))
            for x in stride(from: 0, through: rect.width, by: 1) {
                let t = x / rect.width
                let y = rect.midY
                    - sin(t * .pi * 2) * rect.height * 0.35
                    - sin(t * .pi * 4) * rect.height * 0.15
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

#Preview {
    WaveformPicker(selected: .constant(.sawtooth))
        .padding()
        .background(Theme.baseline.bg)
}
