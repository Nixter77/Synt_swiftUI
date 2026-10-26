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
        "Clean Sub": 0xcac88f8e067c059d,
        "Velvet Acid": 0xc1dbca9cb37466e0,
        "Round Reese": 0x3ca78e0283019ed5,
        "Wavetable Growl": 0x0015693cdf2c94dd,
        "Muted Funk": 0xbb31d1d9edb1a857,
        "Soft 808": 0x7142a425a126d030,
        "Silk Lead": 0x3b98e154342017f6,
        "Crystal Lead": 0x87994f74d856f6c4,
        "Warm Mono": 0xd3bbe39df5f13062,
        "Arp Cascade": 0x3c6c6257c405cb60,
        "Supersaw Soft": 0x8f94da60c37cf8f4,
        "PWM Whisper": 0x7cc3859b898c95e8,
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
        "Rubber Wobble": 0xa7be2deb64b25d13,
        "PWM Sub Pulse": 0x9d2b5c3b8d1249ee,
        "Snap Resonator": 0x9a5a47bd5739bf6f,
        "Vox Morph Lead": 0x16b29c3f0c44cb67,
        "Delayed Vibrato": 0x446171972f97e91f,
        "Fifth Sync Lead": 0x97a4f69a17eb5c26,
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
        "Acid Squelch": 0x5d6f0923fa768e95,
        "Hollow Pulse Bass": 0xe45642d1feadd919,
        "Fat Unison Bass": 0x528de4ba671d5935,
        "Finger Pluck Bass": 0xae8e0d34ea15b11d,
        "Wavefold Bass": 0x89017bd6e347a7a7,
        "Dub Wobble": 0xa077b554d494fcdc,
        "Chip Square Lead": 0x6aedd705300d2abb,
        "Glide Saw Lead": 0x8d7e82bfa9864c74,
        "Breathy Flute": 0xc8a0e626acce0cdb,
        "Overdrive Lead": 0x118166efe9f4153e,
        "Whistle Lead": 0x6a99c5c5d68484c9,
        "Nasal Band Lead": 0x5e8faedee316cfb3,
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
        "Brass Stab": 0xe6050f1729edd1a1,
        "Soft Horns": 0x9ebbdd10aba5ca2a,
        "Trumpet Lead": 0x28436fbf196191cf,
        "Synth Brass Pad": 0x34abc722158db133,
        "Low Tuba": 0x166e59a7675511b6,
        "Up Arp Pluck": 0x71b82ea29729d6b4,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0x09d92d6d50e3334d,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0xd6d6e9e0a04f2375,
        "Wind Gust": 0xa110a6c6ba8cce2d,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xf5f82f0104b2d945,
        "Vowel Ah Lead": 0x40156f60fd6fdd39,
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
