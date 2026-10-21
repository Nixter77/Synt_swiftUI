//
//  MacroXYPad.swift
//  Writes Macro 1 and Macro 2. The pad does not touch the render thread.
//

import SwiftUI

/// X runs left to right across −1…1. Y grows downward, so the top of the pad is +1.
func macroXYValues(x: Double, y: Double, width: Double, height: Double) -> (macro1: Float, macro2: Float) {
    let w = max(width, 1)
    let h = max(height, 1)
    let nx = min(max(x / w, 0), 1)
    let ny = min(max(y / h, 0), 1)
    return (Float(nx) * 2 - 1, Float(1 - ny) * 2 - 1)
}

struct MacroXYPad: View {
    @Environment(\.theme) private var theme
    @Binding var macro1: Float
    @Binding var macro2: Float

    var body: some View {
        Color.clear
            .frame(height: 52)
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let x = CGFloat((macro1 + 1) * 0.5) * width
                    let y = CGFloat((1 - (macro2 + 1) * 0.5)) * height
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(theme.inset)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(theme.border, lineWidth: 0.5)
                            )
                        Text("M1")
                            .themeCaption(theme, size: 8)
                            .foregroundColor(theme.textFaint)
                            .padding(4)
                        Text("M2")
                            .themeCaption(theme, size: 8)
                            .foregroundColor(theme.textFaint)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, 4)
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 10, height: 10)
                            .position(x: min(max(x, 5), width - 5), y: min(max(y, 5), height - 5))
                    }
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0).onChanged { value in
                            let mapped = macroXYValues(
                                x: Double(value.location.x),
                                y: Double(value.location.y),
                                width: Double(width),
                                height: Double(height)
                            )
                            macro1 = mapped.macro1
                            macro2 = mapped.macro2
                        }
                    )
                }
            }
            .accessibilityIdentifier("macroXYPad")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Macro XY")
    }
}
