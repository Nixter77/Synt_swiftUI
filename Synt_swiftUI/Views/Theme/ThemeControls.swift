//
//  ThemeControls.swift
//  Sliders, toggles, and segmented tracks drawn from theme tokens.
//

import SwiftUI

func knobArcFraction(value: Float, range: ClosedRange<Float>) -> CGFloat {
    let span = range.upperBound - range.lowerBound
    guard span > 0, value.isFinite else { return 0 }
    let unit = (value - range.lowerBound) / span
    if unit <= 0 { return 0 }
    if unit >= 1 { return 1 }
    return CGFloat(unit)
}

extension View {
    func themeCaption(_ theme: Theme, size: CGFloat = 10, weight: Font.Weight = .medium) -> some View {
        font(theme.captionFont(size: size, weight: weight))
            .tracking(theme.labelTracking)
            .textCase(theme.uppercaseLabels ? .uppercase : nil)
    }
}

struct ThemeSlider: View {
    @Binding var value: Float
    var range: ClosedRange<Float>
    var step: Float? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            let fraction = knobArcFraction(value: value, range: range)
            let thumb: CGFloat = 14
            let travel = max(width - thumb, 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.sliderTrack)
                    .frame(height: 4)
                Capsule()
                    .fill(theme.sliderFill)
                    .frame(width: max(4, travel * fraction + thumb / 2), height: 4)
                Circle()
                    .fill(theme.toggleKnob)
                    .frame(width: thumb, height: thumb)
                    .shadow(color: theme.knobShadow.color, radius: min(theme.knobShadow.radius, 3), x: 0, y: 1)
                    .offset(x: travel * fraction)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        apply(x: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: 20)
    }

    private func apply(x: CGFloat, width: CGFloat) {
        let t = min(1, max(0, x / width))
        var next = range.lowerBound + Float(t) * (range.upperBound - range.lowerBound)
        if let step, step > 0 {
            next = (next / step).rounded() * step
        }
        value = min(range.upperBound, max(range.lowerBound, next))
    }
}

struct ThemeToggle: View {
    @Binding var isOn: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Capsule()
                .fill(isOn ? theme.toggleOn : theme.toggleOff)
                .frame(width: 32, height: 18)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(theme.toggleKnob)
                        .padding(2)
                        .frame(width: 18, height: 18)
                }
        }
        .buttonStyle(.plain)
    }
}

struct ThemeSegmented<T: Hashable>: View {
    let options: [(value: T, title: String)]
    @Binding var selection: T
    var accent: Color
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .themeCaption(theme, size: 10)
                        .foregroundColor(textColor(selected))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(fill(selected))
                        .clipShape(RoundedRectangle(cornerRadius: max(theme.rSmall - 1, 2)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: theme.rSmall)
                .fill(theme.inset)
        )
    }

    private func fill(_ selected: Bool) -> some View {
        let color: Color = {
            guard selected else { return .clear }
            return theme.id == .baseline ? theme.card : accent
        }()
        return RoundedRectangle(cornerRadius: max(theme.rSmall - 1, 2))
            .fill(color)
            .shadow(
                color: selected && theme.id == .baseline ? theme.cardShadow.color : .clear,
                radius: selected && theme.id == .baseline ? 2 : 0,
                x: 0,
                y: 1
            )
    }

    private func textColor(_ selected: Bool) -> Color {
        guard selected else { return theme.textDim }
        return theme.id == .studio ? theme.bg : theme.text
    }
}
