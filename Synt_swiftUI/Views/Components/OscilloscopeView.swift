//
//  OscilloscopeView.swift
//  Synt_swiftUI
//

import SwiftUI

struct OscilloscopeView: View {
    var metering: AtomicMeteringState
    var lineColor: Color = AppleTheme.accentBlue
    var lineWidth: CGFloat = 2.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(AppleTheme.surfaceInset)
                .compositingGroup()
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 1, y: 1)
                .shadow(color: Color.white.opacity(0.8), radius: 1, x: -1, y: -1)
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
                    context.addFilter(.shadow(color: lineColor.opacity(0.4), radius: 3, x: 0, y: 0))
                    context.stroke(
                        path,
                        with: .color(lineColor),
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
        .background(AppleTheme.windowBackground)
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
