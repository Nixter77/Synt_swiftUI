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
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x9204bf990f7d7c79,
        "PWM Sub Pulse": 0x7d3405924ee3fff3,
        "Snap Resonator": 0x7ed3dfc7b156a473,
        "Vox Morph Lead": 0xe96967fd7f4496b,
        "Delayed Vibrato": 0x2161d8bce741ed19,
        "Fifth Sync Lead": 0xaedcab1c80f8df75,
        "Phase Cathedral": 0x8f29c0a0b44327bb,
        "Breathing Glass": 0xd3b984a9f9a65e39,
        "Tidal Pad": 0x50ef3701753ce114,
        "Phaser Rhodes": 0xc5f6a04a8865d8ab,
        "Wurli Tremolo": 0x9e8014144dc8b7fc,
        "Velvet Clav": 0x5283dc546bc26cf6,
        "Pan Ping Pluck": 0x74154b1be024afea,
        "Flange Harp": 0x7f6df8b6019a4f88,
        "Bit Pluck Arp": 0xc860c0742370f5fe,
        "Chamber Swell": 0xca9fcd10de09f3e7,
        "Phased Violins": 0x97e49b07a61b9f60,
        "Siren Drift": 0x7e344b92e40099cf,
        "Jet Flanger": 0xa10e689b8597278f,
        "Random Bloom": 0x9c1bda7f8c872325,
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
