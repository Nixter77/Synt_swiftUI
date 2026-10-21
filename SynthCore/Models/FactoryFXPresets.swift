//
//  FactoryFXPresets.swift
//  Synt_swiftUI
//

import Foundation

public enum FactoryFXPresets {
    public static let all: [FXPreset] = distortion + eq + phaser + chorus + delay + reverb

    public static func presets(for kind: FXKind) -> [FXPreset] {
        all.filter { $0.kind == kind }
    }

    public static let distortion: [FXPreset] = [
        make(.distortion, "Warm Tape", values: ["drive": 0.28, "tone": 0.42, "mix": 0.35], ints: ["type": index(.tapeSaturation)]),
        make(.distortion, "Crunch", values: ["drive": 0.55, "tone": 0.6, "mix": 0.5], ints: ["type": index(.hardClip)]),
        make(.distortion, "Fuzz", values: ["drive": 0.82, "tone": 0.35, "mix": 0.7], ints: ["type": index(.wavefolder)]),
        make(.distortion, "Bitcrush Lo-Fi", values: ["drive": 0.45, "tone": 0.5, "mix": 0.55], ints: ["type": index(.bitcrusher)]),
    ]

    /// The old EQ picker curves, now ordinary effect presets.
    public static let eq: [FXPreset] = EQPreset.allCases.map { curve in
        let s = curve.settings
        return make(.eq, curve.rawValue, values: [
            "lowGain": s.lowGain, "lowFreq": s.lowFreq,
            "midGain": s.midGain, "midFreq": s.midFreq, "midQ": s.midQ,
            "highGain": s.highGain, "highFreq": s.highFreq,
        ])
    }

    public static let phaser: [FXPreset] = [
        make(.phaser, "Slow Sweep", values: ["rate": 0.12, "depth": 0.55, "feedback": 0.2, "center": 700, "spread": 0.3, "mix": 0.35], ints: ["mode": mode(.phaser4)]),
        make(.phaser, "Fast Leslie", values: ["rate": 2.4, "depth": 0.4, "feedback": 0.1, "center": 1200, "spread": 0.6, "mix": 0.3], ints: ["mode": mode(.phaser2)]),
        make(.phaser, "Deep 8", values: ["rate": 0.25, "depth": 0.8, "feedback": 0.45, "center": 600, "spread": 0.7, "mix": 0.45], ints: ["mode": mode(.phaser8)]),
        make(.phaser, "Soft Flange", values: ["rate": 0.18, "depth": 0.35, "feedback": 0.55, "center": 900, "spread": 0.4, "mix": 0.28], ints: ["mode": mode(.flanger)]),
    ]

    public static let chorus: [FXPreset] = [
        make(.chorus, "Light Ensemble", values: ["rate": 0.4, "depth": 0.25, "mix": 0.2]),
        make(.chorus, "Wide Juno", values: ["rate": 0.7, "depth": 0.55, "mix": 0.4]),
        make(.chorus, "Slow Wash", values: ["rate": 0.15, "depth": 0.7, "mix": 0.35]),
        make(.chorus, "Shimmer", values: ["rate": 1.6, "depth": 0.3, "mix": 0.22]),
    ]

    public static let delay: [FXPreset] = [
        make(.delay, "Slapback", values: ["time": 0.12, "feedback": 0.15, "mix": 0.28]),
        make(.delay, "Eighth Dotted 120", values: ["time": 0.375, "feedback": 0.35, "mix": 0.3]),
        make(.delay, "Ping Wide", values: ["time": 0.28, "feedback": 0.42, "mix": 0.34]),
        make(.delay, "Dub Tail", values: ["time": 0.55, "feedback": 0.72, "mix": 0.4]),
    ]

    public static let reverb: [FXPreset] = [
        make(.reverb, "Small Room", values: ["mix": 0.18, "room": 0.22]),
        make(.reverb, "Hall", values: ["mix": 0.32, "room": 0.62]),
        make(.reverb, "Plate", values: ["mix": 0.28, "room": 0.4]),
        make(.reverb, "Huge Space", values: ["mix": 0.5, "room": 0.92]),
    ]

    private static func make(
        _ kind: FXKind,
        _ name: String,
        values: [String: Float],
        ints: [String: Int] = [:]
    ) -> FXPreset {
        FXPreset(name: name, kind: kind, isFactory: true, values: values, ints: ints)
    }

    private static func index(_ type: DistortionType) -> Int {
        DistortionType.allCases.firstIndex(of: type) ?? 0
    }

    private static func mode(_ mode: PhaserMode) -> Int {
        PhaserMode.allCases.firstIndex(of: mode) ?? 0
    }
}
