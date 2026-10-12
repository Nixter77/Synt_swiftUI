//
//  VUMeterView.swift
//  Synt_swiftUI
//

import SwiftUI

/// LED ladder in dB: 3 dB per segment, top segment = 0 dBFS (meter 1.0).
let ledDBPerSegment: Float = 3

/// Segments lit by `level` (fill) and the single peak-hold segment, if any.
func ledSegments(level: Float, peak: Float, count: Int) -> (filled: Int, peakIndex: Int?) {
    func index(_ v: Float) -> Int {
        guard v.isFinite, v > 0 else { return 0 }
        let db = 20 * log10(v)
        let fromBottom = Float(count) + db / ledDBPerSegment   // 0 dB → count
        return max(0, min(count, Int(fromBottom.rounded(.down))))
    }
    let filled = index(level)
    let p = index(peak)
    return (filled, p > filled ? p - 1 : nil)
}

struct VUMeterView: View {
    @Environment(\.theme) private var theme
    let level: Float
    let peakLevel: Float
    var label: String = "L"
    var orientation: Orientation = .vertical

    enum Orientation { case vertical, horizontal }

    private let segmentCount = 12

    var body: some View {
        if orientation == .vertical { verticalMeter } else { horizontalMeter }
    }

    private var segments: (filled: Int, peakIndex: Int?) {
        ledSegments(level: level, peak: peakLevel, count: segmentCount)
    }

    private func isLit(_ index: Int, _ seg: (filled: Int, peakIndex: Int?)) -> Bool {
        index < seg.filled || index == seg.peakIndex
    }

    private var verticalMeter: some View {
        let seg = segments
        return VStack(spacing: 1) {
            ForEach((0..<segmentCount).reversed(), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(ledColor(index: index, lit: isLit(index, seg)))
                    .frame(width: 12, height: 5)
            }
            Text(label)
                .font(theme.monoFont(size: 9, weight: .medium))
                .foregroundColor(theme.textFaint)
        }
    }

    private var horizontalMeter: some View {
        let seg = segments
        return HStack(spacing: 2) {
            Text(label)
                .font(theme.monoFont(size: 9, weight: .medium))
                .foregroundColor(theme.textFaint)
                .frame(width: 12)
            HStack(spacing: 1) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ledColor(index: index, lit: isLit(index, seg)))
                        .frame(width: 5, height: 12)
                }
            }
        }
    }

    private func ledColor(index: Int, lit: Bool) -> Color {
        let color: Color
        if index >= segmentCount - 2 {
            color = theme.meterHigh
        } else if index >= segmentCount - 5 {
            color = theme.meterMid
        } else {
            color = theme.meterLow
        }
        return lit ? color : theme.meterOff
    }
}

struct StereoVUMeterView: View {
    @Environment(\.theme) private var theme
    let leftLevel: Float
    let rightLevel: Float
    let leftPeak: Float
    let rightPeak: Float

    var body: some View {
        VStack(spacing: 6) {
            Text("OUTPUT")
                .themeCaption(theme, size: 10, weight: .bold)
                .foregroundColor(theme.positive)
            if theme.meterStyle == .needle {
                HStack(spacing: 4) {
                    NeedleVUMeterView(level: leftLevel, peak: leftPeak, label: "L")
                    NeedleVUMeterView(level: rightLevel, peak: rightPeak, label: "R")
                }
            } else {
                HStack(spacing: 4) {
                    VUMeterView(level: leftLevel, peakLevel: leftPeak, label: "L")
                    VUMeterView(level: rightLevel, peakLevel: rightPeak, label: "R")
                }
                HStack {
                    // 12 × 3 dB: the ladder spans −36…0 dB.
                    Text("-36"); Spacer(); Text("0")
                }
                .font(theme.monoFont(size: 7))
                .foregroundColor(theme.textFaint)
                .frame(width: 44)
            }
        }
        .padding(8)
        .appleInset(cornerRadius: 10)
    }
}

struct CompactVUMeterView: View {
    @Environment(\.theme) private var theme
    let level: Float
    let peakLevel: Float
    private let segmentCount = 12
    var body: some View {
        let seg = ledSegments(level: level, peak: peakLevel, count: segmentCount)
        return HStack(spacing: 1) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let lit = index < seg.filled || index == seg.peakIndex
                let color: Color = index >= segmentCount - 2
                    ? theme.meterHigh
                    : index >= segmentCount - 5 ? theme.meterMid : theme.meterLow
                RoundedRectangle(cornerRadius: 1)
                    .fill(lit ? color : theme.meterOff)
                    .frame(width: 3, height: 8)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StereoVUMeterView(leftLevel: 0.6, rightLevel: 0.75, leftPeak: 0.8, rightPeak: 0.95)
        CompactVUMeterView(level: 0.7, peakLevel: 0.9)
    }
    .padding().background(Theme.baseline.bg)
}
