//
//  OscilloscopeView.swift
//  Synt_swiftUI
//

import SwiftUI

struct OscilloscopeView: View {
    var data: [Float]
    var lineColor: Color = AppleTheme.accentBlue
    var lineWidth: CGFloat = 2.0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2.0
                let count = data.count
                let stepX = width / CGFloat(count - 1)
                if count > 0 {
                    let startY = midY - CGFloat(data[0]) * midY
                    path.move(to: CGPoint(x: 0, y: startY))
                    for i in 1..<count {
                        let x = CGFloat(i) * stepX
                        var val = CGFloat(data[i])
                        val = max(-1.0, min(1.0, val))
                        let y = midY - val * midY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(lineColor, lineWidth: lineWidth)
            .shadow(color: lineColor.opacity(0.4), radius: 3, x: 0, y: 0)
        }
        .background(AppleTheme.surfaceInset)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 1, y: 1)
        .shadow(color: Color.white.opacity(0.8), radius: 1, x: -1, y: -1)
    }
}

#Preview {
    OscilloscopeView(data: (0..<512).map { sin(Double($0) * 0.1).toFloat() })
        .frame(height: 100)
        .padding()
        .background(AppleTheme.windowBackground)
}

extension Double {
    func toFloat() -> Float {
        return Float(self)
    }
}
