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
        "Clean Sub": 0x0208c70026bc7ad5,
        "Velvet Acid": 0xcbd741288142d0bf,
        "Round Reese": 0xd262542f9d5a1b88,
        "Wavetable Growl": 0x10aa4f0e0d7e464f,
        "Muted Funk": 0x004faecc6054c925,
        "Soft 808": 0xc6703cc74a0ab671,
        "Silk Lead": 0xcd79a7bde132c427,
        "Crystal Lead": 0xc3876bac11cfb1fc,
        "Warm Mono": 0x8bb22e057b2d139d,
        "Arp Cascade": 0x5cd40402b836a938,
        "Supersaw Soft": 0x929f511cd853e493,
        "PWM Whisper": 0x93a0d054710b00fd,
        "Cloud Bed": 0xdddcab47536c3dd8,
        "Glass Horizon": 0x2fb35ff3a0c8bf69,
        "Analog Drift": 0xb95851d594067401,
        "Noir Pad": 0x1e9384034d6e8668,
        "Air Choir": 0x9d1f2eeb227e558d,
        "Slow Motion": 0x5408adca18502925,
        "Soft EP": 0x1d716f57719e6fcf,
        "Organ Soft": 0xf57be8ef35e894a0,
        "Clav Tick": 0xe79bbec3f935b44c,
        "Bell Keys": 0xc3cdeb7c34bc0f17,
        "Rhodes Warm": 0xbdb8b489e50073a1,
        "Nylon Pluck": 0x3cdaff71e73edda9,
        "Steel Spark": 0xaa66db1a76050bb6,
        "Kalimba Soft": 0x96e8e744901651f9,
        "WT Pluck": 0xd57c93dd10842cd4,
        "Muted Guitar": 0xa451dc247c1dbb66,
        "Section Soft": 0x59a636458175b99f,
        "Cello Warm": 0xf3ada7734bb87159,
        "High Ensemble": 0xb1092974bd964cd5,
        "Tremolo Strings": 0xdd8c08b53d031e57,
        "WT Orchestra": 0x7f7d3a1396f4e9f6,
        "Shimmer Rise": 0x5f23cb6a8c03289f,
        "Noise Sweep": 0x35814c2d501b155c,
        "Glitch Arp": 0x9c1bda7f8c872325,
        "Deep Drone": 0xa886071c3d9a9b9d,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x563405bf9877a8a0,
        "PWM Sub Pulse": 0x7830347da4f3c591,
        "Snap Resonator": 0x662673525c2718bf,
        "Vox Morph Lead": 0x72c9d339be7e31a2,
        "Delayed Vibrato": 0x6f995b223fa8fc64,
        "Fifth Sync Lead": 0x5f7287e5bc8bc075,
        "Phase Cathedral": 0xf7fc1c63878b18c0,
        "Breathing Glass": 0xcb1fd8df82b37929,
        "Tidal Pad": 0xd810d39bd029f7bc,
        "Phaser Rhodes": 0x25d391327a37eb8f,
        "Wurli Tremolo": 0x1336a052d0fb1160,
        "Velvet Clav": 0xec284956036cbb90,
        "Pan Ping Pluck": 0x46aab3cc79ceaab5,
        "Flange Harp": 0xfa2c26add1b0c10b,
        "Bit Pluck Arp": 0x342970804eaccc19,
        "Chamber Swell": 0x52bf15a5d3e25942,
        "Phased Violins": 0xa450fddc09662384,
        "Siren Drift": 0x39282e6c3167f2e0,
        "Jet Flanger": 0x6b6e449b6733bd05,
        "Random Bloom": 0x7417a7b3d5b736fe,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x3314ab6d7c96624b,
        "Hollow Pulse Bass": 0x58081eefd80bc5a5,
        "Fat Unison Bass": 0x52817707230d67a8,
        "Finger Pluck Bass": 0x48aed5edc2352641,
        "Wavefold Bass": 0xcebab1b174efc8d1,
        "Dub Wobble": 0x6fac75651cb655f7,
        "Chip Square Lead": 0x717ce56dd8445e4f,
        "Glide Saw Lead": 0x4e9fbb76fd7e72ee,
        "Breathy Flute": 0x9d17e0dab3951fa9,
        "Overdrive Lead": 0x45c05492607f8dd3,
        "Whistle Lead": 0xece28282ad57f616,
        "Nasal Band Lead": 0xffd565e1327165b0,
        "Soft Saw Pad": 0x280609a75716f8c1,
        "Sine Glass Pad": 0xc2141011d325763d,
        "Dark Choir": 0xf2ea9a65efe1bc50,
        "Pulse Sweep Pad": 0x4281ab439d600c8a,
        "Night Swell": 0xc3a5d730efb17c17,
        "Toy Piano": 0x06de46fc963049ed,
        "Digital EP": 0xdba780d6b57eeae1,
        "Rotary Organ": 0x149986cc1a900953,
        "Bright Harpsi": 0x6440b1c02a92d589,
        "Mellow Vibes": 0x86422ab232164836,
        "Koto Pluck": 0x788904b12cea175c,
        "Marimba": 0x4f93ddd6ed36f2ae,
        "Harp Glimmer": 0x63c38ffffda0c98f,
        "Muted Synth Pluck": 0xbce921bfcd5dacad,
        "Echo Pluck": 0x4c51a6a39ebf17d2,
        "Slow Violas": 0x3ead29342fe9fcd8,
        "Pizzicato": 0x4ee001f9aec1c88e,
        "Solo Cello": 0x9a1f64f772d5a9f8,
        "String Machine": 0x7afa3e326e6bd850,
        "Brass Stab": 0x0fd3dc8ce2a8c057,
        "Soft Horns": 0x6a00b039638b4774,
        "Trumpet Lead": 0x06251759859b90a0,
        "Synth Brass Pad": 0xd19263800bc5ce3c,
        "Low Tuba": 0x3f3189d54d9c11c8,
        "Up Arp Pluck": 0xe5d900d3ec9ec734,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xb5726918c820a8e0,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x3733b0195bb87927,
        "Wind Gust": 0x498b783c8850c6a9,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0x1ec86dd22bda42c0,
        "Vowel Ah Lead": 0x3bfd08144fbf5896,
        "MSEG Drift": 0x90f0d2f9c90a6dbe,
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
