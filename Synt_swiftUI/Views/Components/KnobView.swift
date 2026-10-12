//
//  KnobView.swift
//  Synt_swiftUI
//

import SwiftUI

struct KnobView: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"

    var body: some View {
        KnobBody(value: $value, range: range, label: label, format: format, themeID: theme.id)
            .equatable()
    }
}

private struct KnobBody: View, Equatable {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    let themeID: ThemeID

    private let knobSize: CGFloat = 50

    static func == (lhs: KnobBody, rhs: KnobBody) -> Bool {
        lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.label == rhs.label
            && lhs.format == rhs.format
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                KnobDiscShadow(diameter: knobSize + 4, themeID: theme.id)
                .equatable()

                KnobChrome(fraction: fraction, angle: rotationAngle, diameter: knobSize)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let delta = Float(-gesture.translation.height) / 150.0
                        let range = self.range.upperBound - self.range.lowerBound
                        let newValue = value + delta * range
                        value = min(max(newValue, self.range.lowerBound), self.range.upperBound)
                    }
                    .onEnded { _ in }
            )

            Text(label)
                .themeCaption(theme, size: 10)
                .foregroundColor(theme.textDim)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(String(format: format, value))
                .font(theme.monoFont(size: 9))
                .foregroundColor(theme.textFaint)
        }
    }

    private var fraction: CGFloat { knobArcFraction(value: value, range: range) }

    private var rotationAngle: Double {
        -135 + Double(fraction) * 270
    }
}

struct LargeKnobView: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"

    var body: some View {
        LargeKnobBody(value: $value, range: range, label: label, format: format, themeID: theme.id)
            .equatable()
    }
}

private struct LargeKnobBody: View, Equatable {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    let themeID: ThemeID

    private let knobSize: CGFloat = 70

    static func == (lhs: LargeKnobBody, rhs: LargeKnobBody) -> Bool {
        lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.label == rhs.label
            && lhs.format == rhs.format
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                KnobDiscShadow(diameter: knobSize + 6, themeID: theme.id)
                .equatable()

                ForEach(0..<11) { i in
                    let angle = -135 + Double(i) * 27
                    Rectangle()
                        .fill(theme.textFaint.opacity(0.5))
                        .frame(width: 1, height: 6)
                        .offset(y: -knobSize / 2 - 5)
                        .rotationEffect(Angle(degrees: angle))
                }

                KnobChrome(fraction: fraction, angle: rotationAngle, diameter: knobSize, indicatorWidth: 4)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let delta = Float(-gesture.translation.height) / 150.0
                        let range = self.range.upperBound - self.range.lowerBound
                        let newValue = value + delta * range
                        value = min(max(newValue, self.range.lowerBound), self.range.upperBound)
                    }
                    .onEnded { _ in }
            )

            Text(label)
                .themeCaption(theme, size: 12, weight: .semibold)
                .foregroundColor(theme.text)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(String(format: format, value))
                .font(theme.monoFont(size: 10))
                .foregroundColor(theme.accent)
        }
    }

    private var fraction: CGFloat { knobArcFraction(value: value, range: range) }

    private var rotationAngle: Double {
        -135 + Double(fraction) * 270
    }
}

struct KnobChrome: View {
    var fraction: CGFloat
    var angle: Double
    var diameter: CGFloat
    var indicatorWidth: CGFloat = 3
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [theme.knobTop, theme.knobBottom],
                        center: UnitPoint(x: 0.5, y: 0.38),
                        startRadius: 1,
                        endRadius: diameter * 0.62
                    )
                )
                .frame(width: diameter, height: diameter)

            Circle()
                .stroke(theme.knobRing, lineWidth: 1.5)
                .frame(width: diameter - 2, height: diameter - 2)

            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(theme.knobTrack, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: diameter - 6, height: diameter - 6)

            Circle()
                .trim(from: 0, to: 0.75 * max(0, min(1, fraction)))
                .stroke(theme.knobFill, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(135))
                .frame(width: diameter - 6, height: diameter - 6)

            Rectangle()
                .fill(theme.knobIndicator)
                .frame(width: indicatorWidth, height: diameter * 0.34)
                .offset(y: -diameter * 0.16)
                .rotationEffect(.degrees(angle))
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Static knob well. Parent redraws skip this when the diameter is unchanged.
private struct KnobDiscShadow: View, Equatable {
    @Environment(\.theme) private var theme
    let diameter: CGFloat
    let themeID: ThemeID

    static func == (lhs: KnobDiscShadow, rhs: KnobDiscShadow) -> Bool {
        lhs.diameter == rhs.diameter && lhs.themeID == rhs.themeID
    }

    var body: some View {
        Circle()
            .fill(theme.inset)
            .frame(width: diameter, height: diameter)
            .compositingGroup()
            .shadow(color: theme.knobShadow.color, radius: theme.knobShadow.radius, x: 0, y: theme.knobShadow.y)
            .drawingGroup()
    }
}

#Preview {
    HStack(spacing: 30) {
        KnobView(value: .constant(0.5), range: 0...1, label: "Volume")
        LargeKnobView(value: .constant(0.7), range: 0...1, label: "Cutoff")
    }
    .padding()
    .background(Theme.baseline.bg)
}
