//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset, captured at
//  d15765a (before the 2026-10-12 audit fixes). Any change to these is a
//  change to how a shipped patch sounds; re-capture only on purpose.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0x6899a388d7f69d29,
        "Velvet Acid": 0x15bd9c45fdf58622,
        "Round Reese": 0xdd6acf0cca377568,
        "Wavetable Growl": 0xd2036492c18d98a6,
        "Muted Funk": 0xaef1eef53fe7cffd,
        "Soft 808": 0x8dcdbcbd2bf16462,
        "Silk Lead": 0x47347a079721a87c,
        "Crystal Lead": 0x83deec42e6c6017,
        "Warm Mono": 0xa213d236fb809536,
        "Arp Cascade": 0x62ba0f55ed13dcaa,
        "Supersaw Soft": 0x32f28790d680448f,
        "PWM Whisper": 0x75267ea8a7487794,
        "Cloud Bed": 0x2b4c66906eb0a90f,
        "Glass Horizon": 0xde0c19408cf7d284,
        "Analog Drift": 0x21fee0eeea2a78db,
        "Noir Pad": 0x95e78a13a0ca3ae2,
        "Air Choir": 0xc9079475bd0f31e3,
        "Slow Motion": 0xd3c64646f10494e2,
        "Soft EP": 0xeb50cbb2925f18e4,
        "Organ Soft": 0xaf2b17027d65ca13,
        "Clav Tick": 0x4f0c0b41db6fadaa,
        "Bell Keys": 0xb65b3fb361012d2b,
        "Rhodes Warm": 0x476397fb66f5ec2a,
        "Nylon Pluck": 0x389cbea45d8cd733,
        "Steel Spark": 0xf97e8859e26e7db3,
        "Kalimba Soft": 0x3f5290dc3d6d64f,
        "WT Pluck": 0xca3235a76337ebe4,
        "Muted Guitar": 0xee93fada7ed591b9,
        "Section Soft": 0x51618792385bc634,
        "Cello Warm": 0x9b3fc4d8fe842a51,
        "High Ensemble": 0x8beb7b3b4872f5b6,
        "Tremolo Strings": 0xb1132464c68cd1f2,
        "WT Orchestra": 0x5f1a2bb0f0fb4688,
        "Shimmer Rise": 0x5e601ddf91a85cdc,
        "Noise Sweep": 0xa2d2ba5004da8e7b,
        "Glitch Arp": 0xb8136988069ba7,
        "Deep Drone": 0xa97c8cd29ded4aec,
        "Space Pluck FX": 0x9c1bda7f8c872325,
    ]

    @Test func initAndFactoryPresetsRenderBitIdenticalToGolden() {
        let presets = [SynthPreset.defaultPreset] + SynthPreset.factoryPresets
        #expect(presets.count == Self.golden.count)
        for p in presets {
            let h = Self.renderHash(p)
            #expect(h == Self.golden[p.name], "\(p.name) changed: 0x\(String(h, radix: 16))")
        }
    }

    /// Two notes, 8192 frames, note-off at 6000. FNV-1a over raw Float bits.
    static func renderHash(_ preset: SynthPreset) -> UInt64 {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.noteOn(midiNote: 64, velocity: 0.7)
        engine.processCommandsForTesting()
        var h: UInt64 = 0xcbf29ce484222325
        for i in 0..<8192 {
            if i == 6000 {
                engine.noteOff(midiNote: 60)
                engine.noteOff(midiNote: 64)
                engine.processCommandsForTesting()
            }
            let (l, r) = engine.renderOneSample()
            h = (h ^ UInt64(l.bitPattern)) &* 0x100000001b3
            h = (h ^ UInt64(r.bitPattern)) &* 0x100000001b3
        }
        return h
    }
}
