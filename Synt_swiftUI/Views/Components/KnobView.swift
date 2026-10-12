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

    @State private var isDragging = false

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

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.knobTop, theme.knobBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.9), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: knobSize - 2, height: knobSize - 2)

                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .frame(width: knobSize - 6, height: knobSize - 6)

                Rectangle()
                    .fill(isDragging ? theme.knobFill : theme.knobIndicator)
                    .frame(width: 3, height: knobSize / 3)
                    .offset(y: -knobSize / 6)
                    .rotationEffect(Angle(degrees: rotationAngle))
                    .shadow(color: isDragging ? theme.knobFill.opacity(0.4) : .clear, radius: 3)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let delta = Float(-gesture.translation.height) / 150.0
                        let range = self.range.upperBound - self.range.lowerBound
                        let newValue = value + delta * range
                        value = min(max(newValue, self.range.lowerBound), self.range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(theme.textDim)

            Text(String(format: format, value))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(theme.textFaint)
        }
    }

    private var rotationAngle: Double {
        let normalized = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return -135 + normalized * 270
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

    @State private var isDragging = false

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

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [theme.knobTop, theme.knobBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)

                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.95), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: knobSize - 3, height: knobSize - 3)

                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .frame(width: knobSize - 8, height: knobSize - 8)

                Rectangle()
                    .fill(isDragging ? theme.knobFill : theme.accent)
                    .frame(width: 4, height: knobSize / 2.5)
                    .offset(y: -knobSize / 5)
                    .rotationEffect(Angle(degrees: rotationAngle))
                    .shadow(color: isDragging ? theme.knobFill.opacity(0.5) : theme.accent.opacity(0.3), radius: 4)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let delta = Float(-gesture.translation.height) / 150.0
                        let range = self.range.upperBound - self.range.lowerBound
                        let newValue = value + delta * range
                        value = min(max(newValue, self.range.lowerBound), self.range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(theme.text)

            Text(String(format: format, value))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(theme.accent)
        }
    }

    private var rotationAngle: Double {
        let normalized = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return -135 + normalized * 270
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
            .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
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
