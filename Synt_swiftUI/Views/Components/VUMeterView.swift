//
//  VUMeterView.swift
//  Synt_swiftUI
//

import SwiftUI

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

    private var shownLevel: Float { max(level, peakLevel) }

    private var verticalMeter: some View {
        VStack(spacing: 1) {
            ForEach((0..<segmentCount).reversed(), id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(ledColor(index: index, lit: shownLevel >= Float(index + 1) / Float(segmentCount)))
                    .frame(width: 12, height: 5)
            }
            Text(label)
                .font(theme.monoFont(size: 9, weight: .medium))
                .foregroundColor(theme.textFaint)
        }
    }

    private var horizontalMeter: some View {
        HStack(spacing: 2) {
            Text(label)
                .font(theme.monoFont(size: 9, weight: .medium))
                .foregroundColor(theme.textFaint)
                .frame(width: 12)
            HStack(spacing: 1) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(ledColor(index: index, lit: shownLevel >= Float(index + 1) / Float(segmentCount)))
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
                    NeedleVUMeterView(level: leftLevel, label: "L")
                    NeedleVUMeterView(level: rightLevel, label: "R")
                }
            } else {
                HStack(spacing: 4) {
                    VUMeterView(level: leftLevel, peakLevel: leftPeak, label: "L")
                    VUMeterView(level: rightLevel, peakLevel: rightPeak, label: "R")
                }
                HStack {
                    Text("-∞"); Spacer(); Text("-12"); Spacer(); Text("-6"); Spacer(); Text("0")
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
        HStack(spacing: 1) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let lit = max(level, peakLevel) >= Float(index + 1) / Float(segmentCount)
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
