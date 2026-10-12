//
//  NeedleVUMeterView.swift
//  Retro OUTPUT meters. Both needles read the existing mono level.
//

import SwiftUI

/// VU scale in dB: −20…+3 VU across the arc. 0 VU is meter level 0.5
/// (the engine sends min(rms*2, 1), so 1.0 is +6 VU and pins the right stop).
let needleLeftStop = -50.0
let needleRightStop = 50.0
let needleMinVU = -20.0
let needleMaxVU = 3.0
/// Meter level that reads 0 VU.
let needleReferenceLevel: Float = 0.5
let needleZeroDB = angleForVU(0)
/// Scale marks, printed like a real VU face.
let needleTickVU: [Double] = [-20, -10, -7, -5, -3, -2, -1, 0, 1, 2, 3]

func angleForVU(_ vu: Double) -> Double {
    let t = (min(needleMaxVU, max(needleMinVU, vu)) - needleMinVU) / (needleMaxVU - needleMinVU)
    return needleLeftStop + t * (needleRightStop - needleLeftStop)
}

func needleVU(level: Float) -> Double {
    guard level.isFinite, level > 0 else { return -.infinity }
    return 20 * log10(Double(level) / Double(needleReferenceLevel))
}

func needleAngle(level: Float) -> Double {
    let vu = needleVU(level: level)
    guard vu.isFinite else { return needleLeftStop }
    return angleForVU(vu)
}

/// Above 0 VU. Reachable: level 0.5…1.0 is 0…+6 VU.
func needleIsInRedZone(level: Float) -> Bool {
    needleVU(level: level) > 0
}

/// Peak lamp: the sample peak is at the ceiling.
func needlePeakLampLit(peak: Float) -> Bool {
    peak.isFinite && peak >= 0.98
}

struct NeedleVUMeterView: View {
    var level: Float
    var peak: Float = 0
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

                ForEach(needleTickVU.indices, id: \.self) { i in
                    let vu = needleTickVU[i]
                    let angle = angleForVU(vu)
                    let major = vu == -20 || vu == -10 || vu == 0 || vu == 3
                    Rectangle()
                        .fill(vu > 0 ? Color(hex: "#C0392B") : Color.black)
                        .frame(width: 1, height: major ? 7 : 4)
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

                Circle()
                    .fill(needlePeakLampLit(peak: peak) ? Color(hex: "#C0392B") : Color.black.opacity(0.15))
                    .frame(width: 4, height: 4)
                    .offset(x: 14, y: 10)
            }
            .frame(width: 40, height: 32)
            .clipped()

            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .foregroundColor(Color.black.opacity(0.7))
        }
    }
}
