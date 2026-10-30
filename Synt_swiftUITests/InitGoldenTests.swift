//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten. Re-capture only on purpose.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0xcbd6bc7996064b1b,
        "Velvet Acid": 0x8a127772c218afdb,
        "Round Reese": 0xb09158a90ccaed36,
        "Wavetable Growl": 0xad6a961f0cec231f,
        "Muted Funk": 0xfc745cfd702226ab,
        "Soft 808": 0xb3d48224f933cf19,
        "Silk Lead": 0x58c95d992254ae55,
        "Crystal Lead": 0x13d9969ffd3749cb,
        "Warm Mono": 0x021944bdd19258fb,
        "Arp Cascade": 0x51efe8d8b3b67a8f,
        "Supersaw Soft": 0x2ab7f852a76fb1ab,
        "PWM Whisper": 0x20ae97d9ae65b036,
        "Cloud Bed": 0x9c111f97901acd42,
        "Glass Horizon": 0x7be7aeec8cf1288b,
        "Analog Drift": 0x2d3818ae71bd3411,
        "Noir Pad": 0xe09fb6bb3488af1d,
        "Air Choir": 0xb3468ee7397e304d,
        "Slow Motion": 0x21bf8e06574cbc46,
        "Soft EP": 0x841812ec94fdc9de,
        "Organ Soft": 0x4d59c50aad0f5dda,
        "Clav Tick": 0xa37a88e1059db9b9,
        "Bell Keys": 0x98d3d26f684b9db7,
        "Rhodes Warm": 0x2ab880986090875f,
        "Nylon Pluck": 0x3df12ab2c8a1ff4f,
        "Steel Spark": 0x662192d1e1a84654,
        "Kalimba Soft": 0xf04f0a4d0790ddb1,
        "WT Pluck": 0x151baabfe986d772,
        "Muted Guitar": 0x5481382de5c2c808,
        "Section Soft": 0xc8bf585eff4c4397,
        "Cello Warm": 0x77da90c8cb757ce5,
        "High Ensemble": 0x70c6c12eb519090c,
        "Tremolo Strings": 0x1d70fca546e55044,
        "WT Orchestra": 0xc6cf60e3953479e8,
        "Shimmer Rise": 0x461f06cbd3d36ec3,
        "Noise Sweep": 0x799e1b4594c7e627,
        "Glitch Arp": 0x4f20181bce5e9dae,
        "Deep Drone": 0x41c12aae37320a49,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0xcd02f8e0deb7a56d,
        "PWM Sub Pulse": 0x749fd753b45413b8,
        "Snap Resonator": 0x88aaccfc500149f1,
        "Vox Morph Lead": 0x5b1ea6ee36178de9,
        "Delayed Vibrato": 0x17bab02d56d60037,
        "Fifth Sync Lead": 0xb3364a1117b0cd20,
        "Phase Cathedral": 0x5263ffb436875c0a,
        "Breathing Glass": 0x73a9ba452263a79b,
        "Tidal Pad": 0x794cc6b8309d9b25,
        "Phaser Rhodes": 0x3e2ea1f20d9437b1,
        "Wurli Tremolo": 0x4a2e3647b159b6f3,
        "Velvet Clav": 0x1dff4bcca1af8bea,
        "Pan Ping Pluck": 0xb4ece16a1d35fe86,
        "Flange Harp": 0x65f5cbd21e685671,
        "Bit Pluck Arp": 0xeedfe34d1639f2ea,
        "Chamber Swell": 0x9cfd6cd7cc2f9960,
        "Phased Violins": 0xdd395ee069f63c5a,
        "Siren Drift": 0x6e4694f7d84bb11e,
        "Jet Flanger": 0x1f7bd904e253e8c7,
        "Random Bloom": 0xb7b8174312b7bb45,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x734608e87ba49753,
        "Hollow Pulse Bass": 0xa0f7661290a4d3b9,
        "Fat Unison Bass": 0xd2cdccec9bfa8389,
        "Finger Pluck Bass": 0xa8d86862d4fd4935,
        "Wavefold Bass": 0xc4d3beda61765ab7,
        "Dub Wobble": 0x1f2598345fda2b5e,
        "Chip Square Lead": 0x079a279212fdaf57,
        "Glide Saw Lead": 0x00511e907fa0a635,
        "Breathy Flute": 0x8a0f47964e591889,
        "Overdrive Lead": 0x4b3d10675746afa9,
        "Whistle Lead": 0xf8370acff2533951,
        "Nasal Band Lead": 0x5cf18e7d8cebf629,
        "Soft Saw Pad": 0x374e506024100bb0,
        "Sine Glass Pad": 0xf4ff5438a69f1b02,
        "Dark Choir": 0x34b5ee565a0f9631,
        "Pulse Sweep Pad": 0xbc66a9c72951919d,
        "Night Swell": 0x01014e4876c11115,
        "Toy Piano": 0xd4227af36e1237fa,
        "Digital EP": 0x8c73129bd6da4b54,
        "Rotary Organ": 0x8ea9d8f036dc2c01,
        "Bright Harpsi": 0x265b7a74e7164af0,
        "Mellow Vibes": 0x83861a1252995e6c,
        "Koto Pluck": 0x4f0e76efbc7f9cf0,
        "Marimba": 0x1a610d8785aa54c1,
        "Harp Glimmer": 0xd2de071c2bfeee70,
        "Muted Synth Pluck": 0x747a7720de6aefa4,
        "Echo Pluck": 0x29e35237f42ad74f,
        "Slow Violas": 0x812df06aaebd9022,
        "Pizzicato": 0x1da82783a0cf0a0c,
        "Solo Cello": 0x2c26d7c8f3e8e999,
        "String Machine": 0xc6e4758f0003a182,
        "Brass Stab": 0x08117e67d45ceac2,
        "Soft Horns": 0xd8573f671d265497,
        "Trumpet Lead": 0x865399a92aabed43,
        "Synth Brass Pad": 0xbb2c74175b1499d2,
        "Low Tuba": 0xf75e46f3406ffae2,
        "Up Arp Pluck": 0x71b82ea29729d6b4,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0x09d92d6d50e3334d,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0xd6d6e9e0a04f2375,
        "Wind Gust": 0xa110a6c6ba8cce2d,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xb4fff5c6383a026f,
        "Vowel Ah Lead": 0x0960de8f479f4050,
        "MSEG Drift": 0x38a9a548079d7e25,
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
    @MainActor static func renderHash(_ preset: SynthPreset) -> UInt64 {
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
