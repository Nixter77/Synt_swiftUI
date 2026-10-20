//
//  WaveformType.swift
//  Synt_swiftUI
//

import Foundation

enum WaveformType: String, CaseIterable, Codable {
    case sine = "Sine"
    case sawtooth = "Sawtooth"
    case square = "Square"
    case triangle = "Triangle"
    case noise = "Noise"
    /// Band-limited multi-frame table (Stage 3). Safe default: not used by factory presets.
    case wavetable = "Wavetable"

    var icon: String {
        switch self {
        case .sine: return "waveform"
        case .sawtooth: return "waveform.path.ecg"
        case .square: return "square.fill"
        case .triangle: return "triangle.fill"
        case .noise: return "sparkles"
        case .wavetable: return "square.stack.3d.up"
        }
    }
}
