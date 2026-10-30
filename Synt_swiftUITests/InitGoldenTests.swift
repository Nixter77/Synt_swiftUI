//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten; SYNT_35 re-captured non-Init after velocity floors. Re-capture only on purpose.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0x6d500487ec1cdef5,
        "Velvet Acid": 0x5f87e67544aff827,
        "Round Reese": 0x7848569e8faa2fd7,
        "Wavetable Growl": 0x7804aca28f6684f5,
        "Muted Funk": 0xaf1ed5e1627375d7,
        "Soft 808": 0x57696e22662f8b67,
        "Silk Lead": 0x03fcc5420bb703d6,
        "Crystal Lead": 0x8eaca00807a6f6bb,
        "Warm Mono": 0x677edf0861a04287,
        "Arp Cascade": 0xc4aaf6ecd4e3c29d,
        "Supersaw Soft": 0x764833af976ddeb3,
        "PWM Whisper": 0x9e5d50235d368181,
        "Cloud Bed": 0xc0c845beeb022c05,
        "Glass Horizon": 0xa75fb71c83584079,
        "Analog Drift": 0x7925efe8b2bbe93f,
        "Noir Pad": 0x37fd1b013c41141d,
        "Air Choir": 0xcf97d53143b91980,
        "Slow Motion": 0x3e0d43540eb8abe9,
        "Soft EP": 0xe9c5d10781abda43,
        "Organ Soft": 0x8b352da4656ffce4,
        "Clav Tick": 0x1346a21913c79f33,
        "Bell Keys": 0x1bb5006300a4dff3,
        "Rhodes Warm": 0xf4b9b0210bef9fc9,
        "Nylon Pluck": 0xcf710df4b39fe77e,
        "Steel Spark": 0xb346a9b1c44b140b,
        "Kalimba Soft": 0xdc424597af5726dd,
        "WT Pluck": 0x764b7146441ab63c,
        "Muted Guitar": 0xaa6f6e39b83ae5bb,
        "Section Soft": 0x7e8f0ed8e74c0449,
        "Cello Warm": 0xd0f18fc6add9fb98,
        "High Ensemble": 0x79da49cdc9b0a886,
        "Tremolo Strings": 0xb5955e090317936f,
        "WT Orchestra": 0x4371f57f00a28fa2,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x6d3a2ecd29a68a57,
        "PWM Sub Pulse": 0x3ce68a887c668d2a,
        "Snap Resonator": 0x04b0f386ccc1dff3,
        "Vox Morph Lead": 0x2e9a4a3bef11d9f1,
        "Delayed Vibrato": 0x4a1789f1c0e782e1,
        "Fifth Sync Lead": 0xce5285f19e6c7827,
        "Phase Cathedral": 0x45f835616c06abd9,
        "Breathing Glass": 0x70426c223f9d717f,
        "Tidal Pad": 0xfb074699218903b1,
        "Phaser Rhodes": 0x2f1824265370815e,
        "Wurli Tremolo": 0x7d91fa0b2b62bb81,
        "Velvet Clav": 0x57a5cd1154fc4533,
        "Pan Ping Pluck": 0xb34d7d63053f5afb,
        "Flange Harp": 0x708db071a9bc7021,
        "Bit Pluck Arp": 0x6e87bc6b6399d43b,
        "Chamber Swell": 0x24d5fa7156000f16,
        "Phased Violins": 0x96b5dca0c3fd8699,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x733cf87bfc09782e,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x734608e87ba49753,
        "Hollow Pulse Bass": 0x5e4f3c7073feef37,
        "Fat Unison Bass": 0x9ad5cef2b3d25067,
        "Finger Pluck Bass": 0x417dc067dcfc8c92,
        "Wavefold Bass": 0x6a6fcebd99facec5,
        "Dub Wobble": 0xc8d624867fa601a4,
        "Chip Square Lead": 0x249c581df22356cb,
        "Glide Saw Lead": 0xf71c7e7d45922683,
        "Breathy Flute": 0xf5bbb997674025cc,
        "Overdrive Lead": 0x1e0ba25bc90acccb,
        "Whistle Lead": 0x80014e8e8de60e8b,
        "Nasal Band Lead": 0xe0dfce9c080103b1,
        "Soft Saw Pad": 0x50070f2df9699c1a,
        "Sine Glass Pad": 0x1800148fecf3d46e,
        "Dark Choir": 0x8acf731ea09deec2,
        "Pulse Sweep Pad": 0x4ccc423470373a91,
        "Night Swell": 0x64bd617b8d19a12c,
        "Toy Piano": 0xbb601357cb2d0e66,
        "Digital EP": 0x551aee29a816f616,
        "Rotary Organ": 0x8d3ad72578a45426,
        "Bright Harpsi": 0x7e4157dc08829ef1,
        "Mellow Vibes": 0x0eeee71693aaaad1,
        "Koto Pluck": 0xbe9711e856a02063,
        "Marimba": 0x5c3ddb050a4358f4,
        "Harp Glimmer": 0x52916298047d0cc8,
        "Muted Synth Pluck": 0x4d6dc863004d7cef,
        "Echo Pluck": 0x3fc4bb288ddfe44b,
        "Slow Violas": 0x982535609c4fcb54,
        "Pizzicato": 0x4baaef012ce3a943,
        "Solo Cello": 0x201cd0e342a42f0,
        "String Machine": 0x90605eb4912eaf9b,
        "Brass Stab": 0x146ccee4d56d05f0,
        "Soft Horns": 0xebf4eb9c6411f80b,
        "Trumpet Lead": 0x501527844ae5472f,
        "Synth Brass Pad": 0x5140f6491c3e00fc,
        "Low Tuba": 0x6c70ed8e1d30394b,
        "Up Arp Pluck": 0xaba56378263d64bd,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xca45d8d25ca6b28e,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x830cb28b1fd7c4f2,
        "Wind Gust": 0xc5d52142d8265655,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xd4203c6b27a9f147,
        "Vowel Ah Lead": 0xc0a2d5bd1daeaf57,
        "MSEG Drift": 0x2e712decc132c46f,
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
