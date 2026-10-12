//
//  OscilloscopeView.swift
//  Synt_swiftUI
//

import SwiftUI

struct OscilloscopeView: View {
    @Environment(\.theme) private var theme
    var metering: AtomicMeteringState
    var lineColor: Color? = nil
    var lineWidth: CGFloat = 2.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.inset)
                .compositingGroup()
                .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
                .drawingGroup()

            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in
                Canvas { context, size in
                    let data = metering.readScopeBuffer()
                    let count = data.count
                    guard count > 1 else { return }
                    let midY = size.height / 2.0
                    let stepX = size.width / CGFloat(count - 1)
                    var path = Path()
                    let start = min(1.0, max(-1.0, CGFloat(data[0])))
                    path.move(to: CGPoint(x: 0, y: midY - start * midY))
                    for i in 1..<count {
                        let sample = min(1.0, max(-1.0, CGFloat(data[i])))
                        path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: midY - sample * midY))
                    }
                    let strokeColor = lineColor ?? theme.accent
                    // Glow without a per-frame blur filter: a wide faint pass, then the line.
                    context.stroke(
                        path,
                        with: .color(strokeColor.opacity(0.22)),
                        style: StrokeStyle(lineWidth: lineWidth + 4, lineCap: .round, lineJoin: .round)
                    )
                    context.stroke(
                        path,
                        with: .color(strokeColor),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        }
    }
}

#Preview {
    OscilloscopePreview()
        .frame(height: 100)
        .padding()
        .background(Theme.baseline.bg)
}

private struct OscilloscopePreview: View {
    let metering = AtomicMeteringState()

    var body: some View {
        OscilloscopeView(metering: metering)
            .onAppear {
                let samples = (0..<512).map { sin(Double($0) * 0.1).toFloat() }
                metering.writeScopeBuffer(samples)
            }
    }
}

extension Double {
    func toFloat() -> Float {
        return Float(self)
    }
}
