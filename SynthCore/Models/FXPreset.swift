//
//  FXPreset.swift
//  Synt_swiftUI
//
//  One effect's knobs, stored apart from the patch. The enable toggle is not included.
//

import Foundation

public enum FXKind: String, CaseIterable, Codable {
    case distortion, eq, phaser, chorus, delay, reverb
}

public struct FXPreset: Codable, Identifiable, Equatable {
    public var id: UUID
    public var name: String
    public var kind: FXKind
    public var isFactory: Bool
    public var schemaVersion: Int
    public var values: [String: Float]
    public var ints: [String: Int]

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, isFactory, schemaVersion, values, ints
    }

    public static let matchTolerance: Float = 1e-4

    public init(
        id: UUID = UUID(),
        name: String,
        kind: FXKind,
        isFactory: Bool,
        schemaVersion: Int = 1,
        values: [String: Float],
        ints: [String: Int] = [:]
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.isFactory = isFactory
        self.schemaVersion = schemaVersion
        self.values = Self.clamp(kind: kind, values: values)
        self.ints = Self.clampInts(kind: kind, ints: ints)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try c.decode(FXKind.self, forKey: .kind)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            name: try c.decode(String.self, forKey: .name),
            kind: kind,
            isFactory: try c.decodeIfPresent(Bool.self, forKey: .isFactory) ?? false,
            schemaVersion: try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1,
            values: try c.decodeIfPresent([String: Float].self, forKey: .values) ?? [:],
            ints: try c.decodeIfPresent([String: Int].self, forKey: .ints) ?? [:]
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(kind, forKey: .kind)
        try c.encode(isFactory, forKey: .isFactory)
        try c.encode(schemaVersion, forKey: .schemaVersion)
        try c.encode(values, forKey: .values)
        try c.encode(ints, forKey: .ints)
    }

    /// Writes this effect's fields and leaves the rest of the patch alone.
    public func apply(to preset: inout SynthPreset) {
        let values = Self.clamp(kind: kind, values: values)
        let ints = Self.clampInts(kind: kind, ints: ints)
        switch kind {
        case .distortion:
            if let type = DistortionType.allCases[safe: ints["type"] ?? 0] {
                preset.distortionType = type
            }
            preset.distortionDrive = values["drive"] ?? preset.distortionDrive
            preset.distortionTone = values["tone"] ?? preset.distortionTone
            preset.distortionMix = values["mix"] ?? preset.distortionMix
        case .eq:
            preset.eqLowGain = values["lowGain"] ?? preset.eqLowGain
            preset.eqLowFreq = values["lowFreq"] ?? preset.eqLowFreq
            preset.eqMidGain = values["midGain"] ?? preset.eqMidGain
            preset.eqMidFreq = values["midFreq"] ?? preset.eqMidFreq
            preset.eqMidQ = values["midQ"] ?? preset.eqMidQ
            preset.eqHighGain = values["highGain"] ?? preset.eqHighGain
            preset.eqHighFreq = values["highFreq"] ?? preset.eqHighFreq
            if let curve = EQPreset.allCases.first(where: { $0.rawValue == name }) {
                preset.eqPreset = curve
            }
        case .phaser:
            if let mode = PhaserMode.allCases[safe: ints["mode"] ?? 0] {
                preset.phaserMode = mode
            }
            preset.phaserRate = values["rate"] ?? preset.phaserRate
            preset.phaserDepth = values["depth"] ?? preset.phaserDepth
            preset.phaserFeedback = values["feedback"] ?? preset.phaserFeedback
            preset.phaserCenterFrequency = values["center"] ?? preset.phaserCenterFrequency
            preset.phaserStereoSpread = values["spread"] ?? preset.phaserStereoSpread
            preset.phaserMix = values["mix"] ?? preset.phaserMix
        case .chorus:
            preset.chorusRate = values["rate"] ?? preset.chorusRate
            preset.chorusDepth = values["depth"] ?? preset.chorusDepth
            preset.chorusMix = values["mix"] ?? preset.chorusMix
        case .delay:
            preset.delayTime = values["time"] ?? preset.delayTime
            preset.delayFeedback = values["feedback"] ?? preset.delayFeedback
            preset.delayMix = values["mix"] ?? preset.delayMix
        case .reverb:
            preset.reverbMix = values["mix"] ?? preset.reverbMix
            preset.reverbRoomSize = values["room"] ?? preset.reverbRoomSize
        }
    }

    public static func capture(kind: FXKind, from preset: SynthPreset) -> FXPreset {
        switch kind {
        case .distortion:
            return FXPreset(
                name: "",
                kind: kind,
                isFactory: false,
                values: [
                    "drive": preset.distortionDrive,
                    "tone": preset.distortionTone,
                    "mix": preset.distortionMix,
                ],
                ints: ["type": index(of: preset.distortionType, in: DistortionType.allCases)]
            )
        case .eq:
            return FXPreset(
                name: "",
                kind: kind,
                isFactory: false,
                values: [
                    "lowGain": preset.eqLowGain,
                    "lowFreq": preset.eqLowFreq,
                    "midGain": preset.eqMidGain,
                    "midFreq": preset.eqMidFreq,
                    "midQ": preset.eqMidQ,
                    "highGain": preset.eqHighGain,
                    "highFreq": preset.eqHighFreq,
                ]
            )
        case .phaser:
            return FXPreset(
                name: "",
                kind: kind,
                isFactory: false,
                values: [
                    "rate": preset.phaserRate,
                    "depth": preset.phaserDepth,
                    "feedback": preset.phaserFeedback,
                    "center": preset.phaserCenterFrequency,
                    "spread": preset.phaserStereoSpread,
                    "mix": preset.phaserMix,
                ],
                ints: ["mode": index(of: preset.phaserMode, in: PhaserMode.allCases)]
            )
        case .chorus:
            return FXPreset(
                name: "",
                kind: kind,
                isFactory: false,
                values: [
                    "rate": preset.chorusRate,
                    "depth": preset.chorusDepth,
                    "mix": preset.chorusMix,
                ]
            )
        case .delay:
            return FXPreset(
                name: "",
                kind: kind,
                isFactory: false,
                values: [
                    "time": preset.delayTime,
                    "feedback": preset.delayFeedback,
                    "mix": preset.delayMix,
                ]
            )
        case .reverb:
            return FXPreset(
                name: "",
                kind: kind,
                isFactory: false,
                values: [
                    "mix": preset.reverbMix,
                    "room": preset.reverbRoomSize,
                ]
            )
        }
    }

    public func matches(_ other: FXPreset) -> Bool {
        guard kind == other.kind, ints == other.ints else { return false }
        let keys = Set(values.keys).union(other.values.keys)
        for key in keys {
            let a = values[key] ?? 0
            let b = other.values[key] ?? 0
            if abs(a - b) > Self.matchTolerance { return false }
        }
        return true
    }

    private static func index<T: Equatable>(of value: T, in cases: [T]) -> Int {
        cases.firstIndex(of: value) ?? 0
    }

    public static func clamp(kind: FXKind, values: [String: Float]) -> [String: Float] {
        var out: [String: Float] = [:]
        for (key, raw) in values {
            let range = range(kind: kind, key: key)
            let finite = raw.isNaN ? range.lowerBound : raw
            out[key] = min(range.upperBound, max(range.lowerBound, finite))
        }
        return out
    }

    public static func clampInts(kind: FXKind, ints: [String: Int]) -> [String: Int] {
        var out: [String: Int] = [:]
        for (key, raw) in ints {
            switch (kind, key) {
            case (.distortion, "type"):
                out[key] = min(DistortionType.allCases.count - 1, max(0, raw))
            case (.phaser, "mode"):
                out[key] = min(PhaserMode.allCases.count - 1, max(0, raw))
            default:
                out[key] = raw
            }
        }
        return out
    }

    public static func range(kind: FXKind, key: String) -> ClosedRange<Float> {
        switch (kind, key) {
        case (.distortion, "drive"), (.distortion, "tone"), (.distortion, "mix"):
            return 0...1
        case (.eq, "lowGain"), (.eq, "midGain"), (.eq, "highGain"):
            return -12...12
        case (.eq, "lowFreq"):
            return 40...400
        case (.eq, "midFreq"):
            return 200...5000
        case (.eq, "midQ"):
            return 0.1...10
        case (.eq, "highFreq"):
            return 2000...16000
        case (.phaser, "rate"):
            return 0.05...5
        case (.phaser, "depth"), (.phaser, "spread"), (.phaser, "mix"):
            return 0...1
        case (.phaser, "feedback"):
            return -0.9...0.9
        case (.phaser, "center"):
            return 200...4000
        case (.chorus, "rate"):
            return 0.1...5
        case (.chorus, "depth"), (.chorus, "mix"):
            return 0...1
        case (.delay, "time"):
            return 0.01...1
        case (.delay, "feedback"):
            return 0...0.9
        case (.delay, "mix"), (.reverb, "mix"), (.reverb, "room"):
            return 0...1
        default:
            return -1000...1000
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
