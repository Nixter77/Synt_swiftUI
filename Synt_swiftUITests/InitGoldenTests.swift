//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten; SYNT_35 re-captured non-Init after velocity floors; SYNT_36 after loudness floors; SYNT_37 after category gesture. Re-capture only on purpose.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0xfeae190612ede12c,
        "Velvet Acid": 0x5f87e67544aff827,
        "Round Reese": 0x7848569e8faa2fd7,
        "Wavetable Growl": 0x7804aca28f6684f5,
        "Muted Funk": 0x7756eab8abff4113,
        "Soft 808": 0x9021a879af787d2,
        "Silk Lead": 0x1892cb8f9ab8b8a5,
        "Crystal Lead": 0xe90356fce3460e5d,
        "Warm Mono": 0xb8e2ad856b2d1a2c,
        "Arp Cascade": 0xb80f7f0b2f64c65b,
        "Supersaw Soft": 0x35fe71d3270c54b,
        "PWM Whisper": 0xf7d3a23f83649293,
        "Cloud Bed": 0xc0c845beeb022c05,
        "Glass Horizon": 0xa75fb71c83584079,
        "Analog Drift": 0x60d9543a987f07ed,
        "Noir Pad": 0x37fd1b013c41141d,
        "Air Choir": 0xcf97d53143b91980,
        "Slow Motion": 0x063f0ac6acd7ca5b,
        "Soft EP": 0xe9c5d10781abda43,
        "Organ Soft": 0xcc618c6173e28a73,
        "Clav Tick": 0xfc00fa54ffa8a4ce,
        "Bell Keys": 0x268d12ec9d86d07d,
        "Rhodes Warm": 0x521b22f825a0738a,
        "Nylon Pluck": 0x267ea1c1fc435742,
        "Steel Spark": 0x50d80a80bd671e3a,
        "Kalimba Soft": 0x8d2700fdaf5c3283,
        "WT Pluck": 0xaa58ff07dd997fa5,
        "Muted Guitar": 0xf7b9fa22499d35e6,
        "Section Soft": 0x7e8f0ed8e74c0449,
        "Cello Warm": 0xdf716c17209b7a6f,
        "High Ensemble": 0x01e3b0646e1e22ff,
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
        "Snap Resonator": 0x86c0c63779f39c43,
        "Vox Morph Lead": 0x31974b4bf6f17a3d,
        "Delayed Vibrato": 0x433ec0f639afaf4f,
        "Fifth Sync Lead": 0xed3837c7437a8d68,
        "Phase Cathedral": 0x45f835616c06abd9,
        "Breathing Glass": 0x70426c223f9d717f,
        "Tidal Pad": 0xfb074699218903b1,
        "Phaser Rhodes": 0x2f1824265370815e,
        "Wurli Tremolo": 0x7d91fa0b2b62bb81,
        "Velvet Clav": 0xdf5b3a5872d268b0,
        "Pan Ping Pluck": 0xb34d7d63053f5afb,
        "Flange Harp": 0x25b7a6dbe65aab1c,
        "Bit Pluck Arp": 0xb83ae8e0297c9337,
        "Chamber Swell": 0x24d5fa7156000f16,
        "Phased Violins": 0x96b5dca0c3fd8699,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x733cf87bfc09782e,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x59b0039d869401d5,
        "Hollow Pulse Bass": 0x5e4f3c7073feef37,
        "Fat Unison Bass": 0x9ad5cef2b3d25067,
        "Finger Pluck Bass": 0x417dc067dcfc8c92,
        "Wavefold Bass": 0x737dc992f3ab78e1,
        "Dub Wobble": 0xc8d624867fa601a4,
        "Chip Square Lead": 0x30fd7cdc156cb389,
        "Glide Saw Lead": 0xd9ccc62a8e8d1231,
        "Breathy Flute": 0xb2cf81b7f9579280,
        "Overdrive Lead": 0xb0ffd49e4180d9a5,
        "Whistle Lead": 0x80014e8e8de60e8b,
        "Nasal Band Lead": 0xb80e97252cb201c5,
        "Soft Saw Pad": 0x50070f2df9699c1a,
        "Sine Glass Pad": 0x1800148fecf3d46e,
        "Dark Choir": 0xf26ad77c3df54641,
        "Pulse Sweep Pad": 0x4ccc423470373a91,
        "Night Swell": 0x64bd617b8d19a12c,
        "Toy Piano": 0x17614ec7d8659ccf,
        "Digital EP": 0xa6ed4be7961a0f94,
        "Rotary Organ": 0x5dccdc7afe09788f,
        "Bright Harpsi": 0xd4e5ee37608ed910,
        "Mellow Vibes": 0x0eeee71693aaaad1,
        "Koto Pluck": 0x69abbb986e4b183,
        "Marimba": 0x934ff498b0f5d13b,
        "Harp Glimmer": 0xbf5bb86078a9423a,
        "Muted Synth Pluck": 0xfa6578b64d49a19f,
        "Echo Pluck": 0xae052c575c5b6837,
        "Slow Violas": 0x982535609c4fcb54,
        "Pizzicato": 0x4baaef012ce3a943,
        "Solo Cello": 0xb248d341fb96300d,
        "String Machine": 0x90605eb4912eaf9b,
        "Brass Stab": 0xd17f909c97681e05,
        "Soft Horns": 0xebf4eb9c6411f80b,
        "Trumpet Lead": 0xc592e4ddfa8b0fcf,
        "Synth Brass Pad": 0x8d945de7d5430d8d,
        "Low Tuba": 0x6c70ed8e1d30394b,
        "Up Arp Pluck": 0x9be611bd1c043f67,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xca45d8d25ca6b28e,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x830cb28b1fd7c4f2,
        "Wind Gust": 0x6d1737d1f932dab6,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xd8f9fe691e870fd,
        "Vowel Ah Lead": 0x3cc486a5c98a3ba5,
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
