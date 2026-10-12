//
//  KnobView.swift
//  Synt_swiftUI
//

import SwiftUI

/// 150 pt of vertical drag sweeps the full range, linearly from the grab point.
func knobDragValue(start: Float, translationY: CGFloat, range: ClosedRange<Float>) -> Float {
    let delta = Float(-translationY) / 150.0
    let span = range.upperBound - range.lowerBound
    return min(max(start + delta * span, range.lowerBound), range.upperBound)
}

struct KnobView: View {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"
    /// Replaces the formatted number when a destination has its own units.
    var valueText: String? = nil
    /// Matrix sources aimed at this parameter. A dot is drawn when the list is not empty.
    var modulated: [ModSource] = []

    var body: some View {
        KnobBody(
            value: $value,
            range: range,
            label: label,
            format: format,
            valueText: valueText,
            modulated: modulated,
            themeID: theme.id
        )
        .equatable()
    }
}

private struct KnobBody: View, Equatable {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    var valueText: String? = nil
    var modulated: [ModSource] = []
    let themeID: ThemeID

    private let knobSize: CGFloat = 50
    /// Value at drag start. Translation is cumulative, so it adds to this, not to `value`.
    @State private var dragStart: Float?

    static func == (lhs: KnobBody, rhs: KnobBody) -> Bool {
        lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.label == rhs.label
            && lhs.format == rhs.format
            && lhs.valueText == rhs.valueText
            && lhs.modulated == rhs.modulated
            && lhs.themeID == rhs.themeID
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                KnobDiscShadow(diameter: knobSize + 4, themeID: theme.id)
                .equatable()

                KnobChrome(
                    fraction: fraction,
                    angle: rotationAngle,
                    diameter: knobSize,
                    centeredFill: range.lowerBound < 0 && range.upperBound > 0
                )
                if !modulated.isEmpty {
                    Circle()
                        .fill(theme.aMod)
                        .frame(width: 5, height: 5)
                        .offset(y: knobSize * 0.38)
                        .help(modulated.map(\.rawValue).joined(separator: ", "))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = start }
                        value = knobDragValue(start: start, translationY: gesture.translation.height, range: range)
                    }
                    .onEnded { _ in dragStart = nil }
            )

            Text(label)
                .themeCaption(theme, size: 10)
                .foregroundColor(theme.textDim)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Text(valueText ?? String(format: format, value))
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
    var modulated: [ModSource] = []

    var body: some View {
        LargeKnobBody(
            value: $value,
            range: range,
            label: label,
            format: format,
            modulated: modulated,
            themeID: theme.id
        )
        .equatable()
    }
}

private struct LargeKnobBody: View, Equatable {
    @Environment(\.theme) private var theme
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    let format: String
    var modulated: [ModSource] = []
    let themeID: ThemeID

    private let knobSize: CGFloat = 70
    /// Value at drag start. Translation is cumulative, so it adds to this, not to `value`.
    @State private var dragStart: Float?

    static func == (lhs: LargeKnobBody, rhs: LargeKnobBody) -> Bool {
        lhs.value == rhs.value
            && lhs.range == rhs.range
            && lhs.label == rhs.label
            && lhs.format == rhs.format
            && lhs.modulated == rhs.modulated
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

                KnobChrome(
                    fraction: fraction,
                    angle: rotationAngle,
                    diameter: knobSize,
                    indicatorWidth: 4,
                    centeredFill: range.lowerBound < 0 && range.upperBound > 0
                )
                if !modulated.isEmpty {
                    Circle()
                        .fill(theme.aMod)
                        .frame(width: 5, height: 5)
                        .offset(y: knobSize * 0.38)
                        .help(modulated.map(\.rawValue).joined(separator: ", "))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let start = dragStart ?? value
                        if dragStart == nil { dragStart = start }
                        value = knobDragValue(start: start, translationY: gesture.translation.height, range: range)
                    }
                    .onEnded { _ in dragStart = nil }
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
    /// Bipolar ranges draw the value arc out from the center of the sweep.
    var centeredFill: Bool = false
    @Environment(\.theme) private var theme

    private var fillStart: CGFloat {
        let unit = max(0, min(1, fraction))
        guard centeredFill else { return 0 }
        return 0.75 * min(unit, 0.5)
    }

    private var fillEnd: CGFloat {
        let unit = max(0, min(1, fraction))
        guard centeredFill else { return 0.75 * unit }
        return 0.75 * max(unit, 0.5)
    }

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
                .trim(from: fillStart, to: fillEnd)
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
