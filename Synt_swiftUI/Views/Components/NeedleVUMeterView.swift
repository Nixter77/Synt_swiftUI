//
//  NeedleVUMeterView.swift
//  Retro OUTPUT meters. Both needles read the existing mono level.
//

import SwiftUI

/// Rest is the left stop. Level 1 is 0 dB. Anything louder enters the red zone.
let needleLeftStop = -50.0
let needleZeroDB = 32.0
let needleRightStop = 50.0

func needleAngle(level: Float) -> Double {
    guard level.isFinite else { return needleLeftStop }
    let clamped = Double(max(0, level))
    if clamped <= 1 {
        return needleLeftStop + clamped * (needleZeroDB - needleLeftStop)
    }
    let over = min(clamped - 1, 0.5) / 0.5
    return needleZeroDB + over * (needleRightStop - needleZeroDB)
}

func needleIsInRedZone(level: Float) -> Bool {
    guard level.isFinite, level > 1 else { return false }
    return needleAngle(level: level) > needleZeroDB
}

struct NeedleVUMeterView: View {
    var level: Float
    var label: String

    private let face = Color(hex: "#F4E3B0")

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(face)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.black.opacity(0.35), lineWidth: 1)
                    )

                ForEach(0..<11, id: \.self) { tick in
                    let angle = needleLeftStop + Double(tick) * (needleRightStop - needleLeftStop) / 10
                    Rectangle()
                        .fill(angle > needleZeroDB ? Color(hex: "#C0392B") : Color.black)
                        .frame(width: 1, height: tick % 2 == 0 ? 7 : 4)
                        .offset(y: -12)
                        .rotationEffect(.degrees(angle))
                }

                Rectangle()
                    .fill(Color.black)
                    .frame(width: 1.5, height: 16)
                    .offset(y: -7)
                    .rotationEffect(.degrees(needleAngle(level: level)))
                    .animation(.linear(duration: 0.05), value: level)

                Circle()
                    .fill(Color.black)
                    .frame(width: 4, height: 4)
            }
            .frame(width: 40, height: 32)
            .clipped()

            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.black.opacity(0.7))
        }
    }
}
