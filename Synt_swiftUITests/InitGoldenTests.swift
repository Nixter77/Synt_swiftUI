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
        "Cloud Bed": 0x6c2bf3b875d33a66,
        "Glass Horizon": 0x2fde77a2fccbf23e,
        "Analog Drift": 0x29d80146a32891be,
        "Noir Pad": 0x5e8299975379cdc2,
        "Air Choir": 0x15b00ed3b42560e0,
        "Slow Motion": 0x1985b16c2a91ad81,
        "Soft EP": 0x1f4bab883a31820c,
        "Organ Soft": 0x3bb544d2771957d3,
        "Clav Tick": 0x991aebb76fa811b0,
        "Bell Keys": 0x36c01637ba33c0b4,
        "Rhodes Warm": 0x027b642c97a5e11e,
        "Nylon Pluck": 0x386a3911ec94a80c,
        "Steel Spark": 0xd91cb66a84639475,
        "Kalimba Soft": 0xda9993e4bd128549,
        "WT Pluck": 0xac0da7182a1ade04,
        "Muted Guitar": 0xf9e2e483b745efb8,
        "Section Soft": 0x60f431ee08ac993c,
        "Cello Warm": 0x33e556b47cb03a31,
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
        "Breathing Glass": 0x9fa55cdf20aeee52,
        "Tidal Pad": 0x8a531c11ec936a78,
        "Phaser Rhodes": 0xa04ae9944d9f2385,
        "Wurli Tremolo": 0x6a38ac72ad08498e,
        "Velvet Clav": 0xa6e2dc6ddecd1bcf,
        "Pan Ping Pluck": 0x18191a2b3dec894c,
        "Flange Harp": 0x61e973b6846b2d18,
        "Bit Pluck Arp": 0xe2f9faebfdbfd4b7,
        "Chamber Swell": 0x656fcc624883cd21,
        "Phased Violins": 0x1fc740f42478ddb2,
        "Siren Drift": 0x131c09c58bdce34d,
        "Jet Flanger": 0xc1fcac75c9f6cb8f,
        "Random Bloom": 0x9fe4fd16fc4c4f43,
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
        "Soft Saw Pad": 0x0a3ac679409f0228,
        "Sine Glass Pad": 0xf5abe62db22ac3a6,
        "Dark Choir": 0x7e86735f118a8ce0,
        "Pulse Sweep Pad": 0x43d231fd8f911231,
        "Night Swell": 0xe62c8dee2ecbc460,
        "Toy Piano": 0x710180a1baa0234a,
        "Digital EP": 0x61af98fe014734d8,
        "Rotary Organ": 0x531b2c1378cf808a,
        "Bright Harpsi": 0xabf3c36ec7947bab,
        "Mellow Vibes": 0x410265afc9614d36,
        "Koto Pluck": 0xa35b0545c2755d0d,
        "Marimba": 0x2678331fc3a91898,
        "Harp Glimmer": 0xfcdcb47b4fff2676,
        "Muted Synth Pluck": 0xbbccb6c6467e4730,
        "Echo Pluck": 0xb72f9890ed1eb729,
        "Slow Violas": 0x82d322c1548a75bf,
        "Pizzicato": 0xaa6cfe960cc49f81,
        "Solo Cello": 0xdd4227a134e5ea2f,
        "String Machine": 0xe86c7b3fe14e721e,
        "Brass Stab": 0x08117e67d45ceac2,
        "Soft Horns": 0xd8573f671d265497,
        "Trumpet Lead": 0x865399a92aabed43,
        "Synth Brass Pad": 0xbb2c74175b1499d2,
        "Low Tuba": 0xf75e46f3406ffae2,
        "Up Arp Pluck": 0xe09b13bc35eee50b,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0x910249e3d4714ea4,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0xa274a81eac85b23c,
        "Wind Gust": 0xf9a9d58559d2d68e,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xb4fff5c6383a026f,
        "Vowel Ah Lead": 0x0960de8f479f4050,
        "MSEG Drift": 0x3726d92549b8ae0e,
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
