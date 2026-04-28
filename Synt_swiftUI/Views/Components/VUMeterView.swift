//
//  VUMeterView.swift
//  Synt_swiftUI
//

import SwiftUI

struct VUMeterView: View {
    let level: Float
    let peakLevel: Float
    var label: String = "L"
    var orientation: Orientation = .vertical

    enum Orientation { case vertical, horizontal }

    private let segmentCount = 20
    private let yellowThreshold = 0.7
    private let redThreshold = 0.9

    var body: some View {
        if orientation == .vertical { verticalMeter } else { horizontalMeter }
    }

    private var verticalMeter: some View {
        VStack(spacing: 2) {
            Circle()
                .fill(peakLevel > Float(redThreshold) ? AppleTheme.accentDestructive : Color.clear)
                .frame(width: 8, height: 8)
                .shadow(color: peakLevel > Float(redThreshold) ? AppleTheme.accentDestructive.opacity(0.6) : .clear, radius: 4)
            VStack(spacing: 1) {
                ForEach((0..<segmentCount).reversed(), id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(segmentColor(for: index, isLit: level >= Float(index) / Float(segmentCount)))
                        .frame(width: 12, height: 4)
                        .opacity(level >= Float(index) / Float(segmentCount) ? 1.0 : 0.15)
                }
            }
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(AppleTheme.textTertiary)
        }
    }

    private var horizontalMeter: some View {
        HStack(spacing: 2) {
            Text(label).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(AppleTheme.textTertiary).frame(width: 12)
            HStack(spacing: 1) {
                ForEach(0..<segmentCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(segmentColor(for: index, isLit: level >= Float(index) / Float(segmentCount)))
                        .frame(width: 4, height: 12)
                        .opacity(level >= Float(index) / Float(segmentCount) ? 1.0 : 0.15)
                }
            }
            Circle()
                .fill(peakLevel > Float(redThreshold) ? AppleTheme.accentDestructive : Color.clear)
                .frame(width: 8, height: 8)
        }
    }

    private func segmentColor(for index: Int, isLit: Bool) -> Color {
        let pos = Double(index) / Double(segmentCount)
        if pos >= redThreshold { return isLit ? AppleTheme.accentDestructive : AppleTheme.accentDestructive.opacity(0.2) }
        else if pos >= yellowThreshold { return isLit ? AppleTheme.accentModulation : AppleTheme.accentModulation.opacity(0.2) }
        else { return isLit ? AppleTheme.accentPositive : AppleTheme.accentPositive.opacity(0.2) }
    }
}

struct StereoVUMeterView: View {
    let leftLevel: Float
    let rightLevel: Float
    let leftPeak: Float
    let rightPeak: Float

    var body: some View {
        VStack(spacing: 8) {
            Text("OUTPUT").font(.system(size: 10, weight: .bold, design: .rounded)).foregroundColor(AppleTheme.accentPositive)
            HStack(spacing: 4) {
                VUMeterView(level: leftLevel, peakLevel: leftPeak, label: "L")
                VUMeterView(level: rightLevel, peakLevel: rightPeak, label: "R")
            }
            HStack {
                Text("-∞"); Spacer(); Text("-12"); Spacer(); Text("-6"); Spacer(); Text("0")
            }
            .font(.system(size: 7, design: .monospaced)).foregroundColor(AppleTheme.textTertiary).frame(width: 40)
        }
        .padding(8)
        .appleInset(cornerRadius: 10)
    }
}

struct CompactVUMeterView: View {
    let level: Float
    let peakLevel: Float
    private let segmentCount = 16
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<segmentCount, id: \.self) { index in
                let t = Float(index) / Float(segmentCount)
                let isLit = level >= t
                let pos = Double(index) / Double(segmentCount)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(pos >= 0.9 ? AppleTheme.accentDestructive : pos >= 0.7 ? AppleTheme.accentModulation : AppleTheme.accentPositive)
                    .frame(width: 3, height: 8).opacity(isLit ? 1.0 : 0.1)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        StereoVUMeterView(leftLevel: 0.6, rightLevel: 0.75, leftPeak: 0.8, rightPeak: 0.95)
        CompactVUMeterView(level: 0.7, peakLevel: 0.9)
    }
    .padding().background(AppleTheme.windowBackground)
}
