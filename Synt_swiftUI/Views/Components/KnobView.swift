//
//  KnobView.swift
//  Synt_swiftUI
//

import SwiftUI

struct KnobView: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"

    @State private var isDragging = false

    private let knobSize: CGFloat = 50

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 3D base shadow
                Circle()
                    .fill(AppleTheme.surfaceInset)
                    .frame(width: knobSize + 4, height: knobSize + 4)
                    .shadow(color: AppleTheme.shadowDark, radius: 4, x: 2, y: 3)
                    .shadow(color: AppleTheme.shadowLight, radius: 3, x: -2, y: -2)
                
                // Knob body with 3D gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppleTheme.knobTop, AppleTheme.knobBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)

                // Highlight rim (3D depth)
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
                
                // Inner shadow ring
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .frame(width: knobSize - 6, height: knobSize - 6)

                // Indicator line
                Rectangle()
                    .fill(isDragging ? AppleTheme.knobIndicatorActive : AppleTheme.knobIndicator)
                    .frame(width: 3, height: knobSize / 3)
                    .offset(y: -knobSize / 6)
                    .rotationEffect(Angle(degrees: rotationAngle))
                    .shadow(color: isDragging ? AppleTheme.knobIndicatorActive.opacity(0.4) : .clear, radius: 3)
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
                .foregroundColor(AppleTheme.textSecondary)

            Text(String(format: format, value))
                .font(.system(size: 9, weight: .regular, design: .monospaced))
                .foregroundColor(AppleTheme.textTertiary)
        }
    }

    private var rotationAngle: Double {
        let normalized = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return -135 + normalized * 270
    }
}

struct LargeKnobView: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String
    var format: String = "%.2f"

    @State private var isDragging = false

    private let knobSize: CGFloat = 70

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // 3D base shadow
                Circle()
                    .fill(AppleTheme.surfaceInset)
                    .frame(width: knobSize + 6, height: knobSize + 6)
                    .shadow(color: AppleTheme.shadowDark, radius: 6, x: 3, y: 4)
                    .shadow(color: AppleTheme.shadowLight, radius: 4, x: -3, y: -3)
                
                // Scale tick marks
                ForEach(0..<11) { i in
                    let angle = -135 + Double(i) * 27
                    Rectangle()
                        .fill(AppleTheme.textTertiary.opacity(0.5))
                        .frame(width: 1, height: 6)
                        .offset(y: -knobSize / 2 - 5)
                        .rotationEffect(Angle(degrees: angle))
                }
                
                // Knob body with 3D gradient
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppleTheme.knobTop, AppleTheme.knobBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)

                // Highlight rim
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
                
                // Inner shadow
                Circle()
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    .frame(width: knobSize - 8, height: knobSize - 8)

                // Indicator
                Rectangle()
                    .fill(isDragging ? AppleTheme.knobIndicatorActive : AppleTheme.accentBlue)
                    .frame(width: 4, height: knobSize / 2.5)
                    .offset(y: -knobSize / 5)
                    .rotationEffect(Angle(degrees: rotationAngle))
                    .shadow(color: isDragging ? AppleTheme.knobIndicatorActive.opacity(0.5) : AppleTheme.accentBlue.opacity(0.3), radius: 4)
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
                .foregroundColor(AppleTheme.textPrimary)

            Text(String(format: format, value))
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundColor(AppleTheme.accentBlue)
        }
    }

    private var rotationAngle: Double {
        let normalized = Double(value - range.lowerBound) / Double(range.upperBound - range.lowerBound)
        return -135 + normalized * 270
    }
}

#Preview {
    HStack(spacing: 30) {
        KnobView(value: .constant(0.5), range: 0...1, label: "Volume")
        LargeKnobView(value: .constant(0.7), range: 0...1, label: "Cutoff")
    }
    .padding()
    .background(AppleTheme.windowBackground)
}
