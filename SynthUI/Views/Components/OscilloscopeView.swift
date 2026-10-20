//
//  OscilloscopeView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

struct OscilloscopeView: View {
    @Environment(\.theme) private var theme
    var metering: AtomicMeteringState
    var lineColor: Color? = nil
    var lineWidth: CGFloat = 2.0
    /// Engine stopped: freeze the last frame instead of redrawing at 30 Hz.
    var isRunning: Bool = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.rSmall)
                .fill(theme.scopeBg)

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isRunning)) { _ in
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
                    let strokeColor = lineColor ?? theme.scopeLine
                    context.stroke(
                        path,
                        with: .color(strokeColor),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: theme.rSmall))
            }

            RoundedRectangle(cornerRadius: theme.rSmall)
                .stroke(theme.border, lineWidth: 1)
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
