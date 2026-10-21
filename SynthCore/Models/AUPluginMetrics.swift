//
//  AUPluginMetrics.swift
//  SynthCore
//
//  The Audio Unit view is the control grid. Height stays within the layout test.
//

import CoreGraphics
import Foundation

public enum PluginLayout: String, Codable, CaseIterable, Sendable {
    case compact
    case extended
}

/// Plugin window scale. 100 is the authored size. Missing document state stays here.
public enum PluginZoom: Int, Codable, CaseIterable, Sendable {
    case p75 = 75
    case p100 = 100
    case p125 = 125
    case p150 = 150
    case p200 = 200

    public var factor: CGFloat { CGFloat(rawValue) / 100.0 }

    public static func nearest(_ raw: Int) -> PluginZoom {
        allCases.min { abs($0.rawValue - raw) < abs($1.rawValue - raw) } ?? .p100
    }
}

public struct PluginPanelFrame: Equatable, Sendable {
    public var id: String
    public var rect: CGRect

    public init(id: String, rect: CGRect) {
        self.id = id
        self.rect = rect
    }
}

/// Document chrome. Absent keys decode to compact / 100%.
public struct PluginChromeState: Codable, Equatable, Sendable {
    public var zoom: Int
    public var layout: String

    private enum CodingKeys: String, CodingKey {
        case zoom
        case layout
    }

    public init(zoom: PluginZoom, layout: PluginLayout) {
        self.zoom = zoom.rawValue
        self.layout = layout.rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        zoom = try container.decodeIfPresent(Int.self, forKey: .zoom) ?? PluginZoom.p100.rawValue
        layout = try container.decodeIfPresent(String.self, forKey: .layout) ?? PluginLayout.compact.rawValue
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(zoom, forKey: .zoom)
        try container.encode(layout, forKey: .layout)
    }
}

public enum AUPluginMetrics {
    public static let contentWidth: CGFloat = 1100
    public static let contentHeight: CGFloat = 520
    public static let compactWidth: CGFloat = 1100
    public static let compactHeight: CGFloat = 520
    public static let extendedWidth: CGFloat = 1440
    public static let extendedHeight: CGFloat = 760
    public static let panelSpacing: CGFloat = 10

    public static let panelIDs = ["osc1", "osc2", "adsr", "filter", "unison", "lfo", "matrix", "fx"]

    public static func preferredSize(layout: PluginLayout, zoom: PluginZoom) -> CGSize {
        let baseW = layout == .compact ? compactWidth : extendedWidth
        let baseH = layout == .compact ? compactHeight : extendedHeight
        return CGSize(
            width: (baseW * zoom.factor).rounded(),
            height: (baseH * zoom.factor).rounded()
        )
    }

    /// Four columns. Rects tile `width`×`height` and share no interior points.
    public static func frames(width: CGFloat, height: CGFloat, layout: PluginLayout) -> [PluginPanelFrame] {
        let widths = columnWidths(total: width, layout: layout)
        let columns: [[String]] = [
            ["osc1", "osc2"],
            ["adsr", "filter", "unison"],
            ["lfo", "matrix"],
            ["fx"],
        ]
        let rowWeights: [[CGFloat]] = [
            [0.48, 0.52],
            [0.34, 0.42, 0.24],
            [0.46, 0.54],
            [1],
        ]
        let spacing = panelSpacing
        var frames: [PluginPanelFrame] = []
        var x: CGFloat = 0
        for (column, ids) in columns.enumerated() {
            let gaps = spacing * CGFloat(max(0, ids.count - 1))
            let innerH = max(0, height - gaps)
            var y: CGFloat = 0
            var usedH: CGFloat = 0
            for (row, id) in ids.enumerated() {
                let h: CGFloat
                if row == ids.count - 1 {
                    h = max(0, innerH - usedH)
                } else {
                    h = floor(innerH * rowWeights[column][row])
                    usedH += h
                }
                frames.append(PluginPanelFrame(
                    id: id,
                    rect: CGRect(x: x, y: y, width: widths[column], height: h)
                ))
                y += h + spacing
            }
            x += widths[column] + spacing
        }
        return frames
    }

    public static func columnWidths(total: CGFloat, layout: PluginLayout) -> [CGFloat] {
        let spacing = panelSpacing
        let weights: [CGFloat] = layout == .extended
            ? [0.24, 0.30, 0.22, 0.24]
            : [0.26, 0.36, 0.20, 0.18]
        let inner = max(0, total - spacing * 3)
        var widths = [CGFloat](repeating: 0, count: 4)
        var used: CGFloat = 0
        for index in 0..<3 {
            let column = floor(inner * weights[index])
            widths[index] = column
            used += column
        }
        widths[3] = max(0, inner - used)
        return widths
    }
}
