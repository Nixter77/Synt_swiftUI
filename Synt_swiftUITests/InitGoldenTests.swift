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
        "Velvet Acid": 0x57a948ec3fe132ed,
        "Round Reese": 0x09241c251b72a589,
        "Wavetable Growl": 0xd1fc5dca691a7ded,
        "Muted Funk": 0xfc745cfd702226ab,
        "Soft 808": 0x2115e8d8e559c1bc,
        "Silk Lead": 0x7f3ddc7f122cccaa,
        "Crystal Lead": 0x13d9969ffd3749cb,
        "Warm Mono": 0xb8a75d9ddb4a27c6,
        "Arp Cascade": 0x51efe8d8b3b67a8f,
        "Supersaw Soft": 0xd4f64c33043a86eb,
        "PWM Whisper": 0x008a0806c66b9e8d,
        "Cloud Bed": 0xad2e046885aa057c,
        "Glass Horizon": 0x9c4fd1fd5b2420d5,
        "Analog Drift": 0x32850dd7a6e55972,
        "Noir Pad": 0x5e8299975379cdc2,
        "Air Choir": 0x15b00ed3b42560e0,
        "Slow Motion": 0x1985b16c2a91ad81,
        "Soft EP": 0xeedca1c5908a23f2,
        "Organ Soft": 0xb783fbbba84ea661,
        "Clav Tick": 0x991aebb76fa811b0,
        "Bell Keys": 0x36c01637ba33c0b4,
        "Rhodes Warm": 0xf00fc5d7edc46f02,
        "Nylon Pluck": 0x386a3911ec94a80c,
        "Steel Spark": 0xd91cb66a84639475,
        "Kalimba Soft": 0x75bc485ba1a5f076,
        "WT Pluck": 0xac0da7182a1ade04,
        "Muted Guitar": 0xf9e2e483b745efb8,
        "Section Soft": 0xcfab0a54711d110e,
        "Cello Warm": 0xad62d33e97541715,
        "High Ensemble": 0x534fcc86946937ba,
        "Tremolo Strings": 0xb58260142b48be4f,
        "WT Orchestra": 0xfbb40e24494abe72,
        "Shimmer Rise": 0x1f1332b7d851b8db,
        "Noise Sweep": 0x9b37d15c26472d8b,
        "Glitch Arp": 0x59e7e811dcdbc924,
        "Deep Drone": 0xee91751a1e769a26,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0xcd02f8e0deb7a56d,
        "PWM Sub Pulse": 0x749fd753b45413b8,
        "Snap Resonator": 0x88aaccfc500149f1,
        "Vox Morph Lead": 0x5b1ea6ee36178de9,
        "Delayed Vibrato": 0x17bab02d56d60037,
        "Fifth Sync Lead": 0xb3364a1117b0cd20,
        "Phase Cathedral": 0xf3692c4c06d6834b,
        "Breathing Glass": 0x33a43bbd768573f2,
        "Tidal Pad": 0x8a531c11ec936a78,
        "Phaser Rhodes": 0xa04ae9944d9f2385,
        "Wurli Tremolo": 0x6a38ac72ad08498e,
        "Velvet Clav": 0x914ed9fb0cd4c6fa,
        "Pan Ping Pluck": 0x18191a2b3dec894c,
        "Flange Harp": 0x61e973b6846b2d18,
        "Bit Pluck Arp": 0xe2f9faebfdbfd4b7,
        "Chamber Swell": 0x656fcc624883cd21,
        "Phased Violins": 0x1fc740f42478ddb2,
        "Siren Drift": 0x6367bde81d0acde1,
        "Jet Flanger": 0xc1fcac75c9f6cb8f,
        "Random Bloom": 0x9fe4fd16fc4c4f43,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x734608e87ba49753,
        "Hollow Pulse Bass": 0xa0f7661290a4d3b9,
        "Fat Unison Bass": 0xd2cdccec9bfa8389,
        "Finger Pluck Bass": 0xa8d86862d4fd4935,
        "Wavefold Bass": 0xc4d3beda61765ab7,
        "Dub Wobble": 0x4cb9510482f9b0e3,
        "Chip Square Lead": 0x079a279212fdaf57,
        "Glide Saw Lead": 0x00511e907fa0a635,
        "Breathy Flute": 0x8a0f47964e591889,
        "Overdrive Lead": 0x595149a6c872a9e3,
        "Whistle Lead": 0xf8370acff2533951,
        "Nasal Band Lead": 0x5cf18e7d8cebf629,
        "Soft Saw Pad": 0x0ed09077d86166f7,
        "Sine Glass Pad": 0x8732b3dae798345a,
        "Dark Choir": 0x7e86735f118a8ce0,
        "Pulse Sweep Pad": 0x43d231fd8f911231,
        "Night Swell": 0xe62c8dee2ecbc460,
        "Toy Piano": 0x710180a1baa0234a,
        "Digital EP": 0x61af98fe014734d8,
        "Rotary Organ": 0x531b2c1378cf808a,
        "Bright Harpsi": 0xabf3c36ec7947bab,
        "Mellow Vibes": 0xa1ffac20b90e605b,
        "Koto Pluck": 0xa35b0545c2755d0d,
        "Marimba": 0x2678331fc3a91898,
        "Harp Glimmer": 0xfcdcb47b4fff2676,
        "Muted Synth Pluck": 0x0de6d061e6f8a6cd,
        "Echo Pluck": 0xb72f9890ed1eb729,
        "Slow Violas": 0x82d322c1548a75bf,
        "Pizzicato": 0xaa6cfe960cc49f81,
        "Solo Cello": 0xdd4227a134e5ea2f,
        "String Machine": 0xe86c7b3fe14e721e,
        "Brass Stab": 0x969b4a96bbff2995,
        "Soft Horns": 0xd77f2e24b0d6c900,
        "Trumpet Lead": 0x2739c3dba9c8a71b,
        "Synth Brass Pad": 0xbb2c74175b1499d2,
        "Low Tuba": 0xf75e46f3406ffae2,
        "Up Arp Pluck": 0xe09b13bc35eee50b,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xa8c58ad18b58c94b,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0xa274a81eac85b23c,
        "Wind Gust": 0xf9a9d58559d2d68e,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xb4fff5c6383a026f,
        "Vowel Ah Lead": 0x0960de8f479f4050,
        "MSEG Drift": 0xa9a2f38f18dca8f7,
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
