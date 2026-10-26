//
//  FactoryFXPresets.swift
//  Synt_swiftUI
//

import Foundation

public enum FactoryFXPresets {
    public static let all: [FXPreset] = distortion + eq + phaser + chorus + delay + reverb
        + rotary + frequencyShifter + transient + tranceGate + fxOrder

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

    public static let rotary: [FXPreset] = [
        make(.rotary, "Slow Leslie", values: rotaryValues(hornSlow: 0.55, hornFast: 4.2, drumSlow: 0.4, drumFast: 3.6, drive: 0.08, mix: 0.7, accel: 2.4), ints: ["fast": 0]),
        make(.rotary, "Fast Leslie", values: rotaryValues(hornSlow: 0.8, hornFast: 7.5, drumSlow: 0.6, drumFast: 6.2, drive: 0.16, mix: 0.82, accel: 4), ints: ["fast": 1]),
        make(.rotary, "Gospel Drive", values: rotaryValues(hornSlow: 0.7, hornFast: 6.4, drumSlow: 0.5, drumFast: 5.4, drive: 0.35, mix: 0.9, accel: 3), ints: ["fast": 1]),
        make(.rotary, "Cabinet Wide", values: rotaryValues(hornSlow: 0.45, hornFast: 5.2, drumSlow: 0.35, drumFast: 4.4, drive: 0.12, mix: 0.64, accel: 1.6), ints: ["fast": 0]),
    ]

    public static let frequencyShifter: [FXPreset] = [
        make(.frequencyShifter, "Mild Offset", values: ["shift": 8, "mix": 0.22, "feedback": 0.04]),
        make(.frequencyShifter, "Bode Shimmer", values: ["shift": 24, "mix": 0.35, "feedback": 0.12]),
        make(.frequencyShifter, "Down Shift", values: ["shift": -18, "mix": 0.3, "feedback": 0.06]),
        make(.frequencyShifter, "Laser Edge", values: ["shift": 60, "mix": 0.42, "feedback": 0.16]),
    ]

    public static let transient: [FXPreset] = [
        make(.transient, "Snap Attack", values: ["attack": 0.45, "sustain": -0.15, "output": 1, "mix": 0.7]),
        make(.transient, "Soft Finger", values: ["attack": -0.25, "sustain": 0.2, "output": 1, "mix": 0.55]),
        make(.transient, "Drum Crack", values: ["attack": 0.7, "sustain": -0.35, "output": 1.1, "mix": 0.8]),
        make(.transient, "Pad Glue", values: ["attack": -0.1, "sustain": 0.15, "output": 0.95, "mix": 0.4]),
    ]

    public static let tranceGate: [FXPreset] = [
        make(.tranceGate, "Straight 16", values: ["depth": 0.85, "smooth": 0.08], ints: ["pattern": 0xAAAA, "division": division(.sixteenth)]),
        make(.tranceGate, "Offbeat", values: ["depth": 0.75, "smooth": 0.12], ints: ["pattern": 0x5555, "division": division(.eighth)]),
        make(.tranceGate, "Sparse", values: ["depth": 0.9, "smooth": 0.2], ints: ["pattern": 0x8888, "division": division(.eighthD)]),
        make(.tranceGate, "Rolling", values: ["depth": 0.65, "smooth": 0.28], ints: ["pattern": 0xCCCC, "division": division(.sixteenth)]),
    ]

    public static let fxOrder: [FXPreset] = [
        make(.fxOrder, "Delay First", values: [:], ints: slotInts([.delay, .chorus, .eq, .distortion, .phaser, .reverb])),
        make(.fxOrder, "Dirt Last", values: [:], ints: slotInts([.eq, .phaser, .chorus, .delay, .reverb, .distortion])),
        make(.fxOrder, "Verb Early", values: [:], ints: slotInts([.reverb, .eq, .distortion, .phaser, .chorus, .delay])),
        make(.fxOrder, "Chorus Front", values: [:], ints: slotInts([.chorus, .delay, .reverb, .eq, .distortion, .phaser])),
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

    private static func division(_ division: TimeDivision) -> Int {
        TimeDivision.allCases.firstIndex(of: division) ?? 0
    }

    private static func slotInts(_ order: [FXSlotID]) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: order.enumerated().map { index, slot in
            ("slot\(index)", FXSlotID.allCases.firstIndex(of: slot) ?? 0)
        })
    }

    private static func rotaryValues(
        hornSlow: Float, hornFast: Float, drumSlow: Float, drumFast: Float,
        drive: Float, mix: Float, accel: Float
    ) -> [String: Float] {
        [
            "hornSlow": hornSlow, "hornFast": hornFast,
            "drumSlow": drumSlow, "drumFast": drumFast,
            "drive": drive, "mix": mix, "accel": accel,
        ]
    }
}
