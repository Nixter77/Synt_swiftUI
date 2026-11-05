//
//  FactoryGoldenTests.swift
//  Bit-exact render hashes for every factory preset (non-Init only).
//  History: recaptured in SYNT_30, SYNT_35/36/37, and SYNT_66 after the factory dynamics pass.
//
//  How to re-capture (factory only, never Init):
//    run Synt_swiftUITests -only-testing:Synt_swiftUITests/FactoryGoldenTests;
//    each mismatch prints "<name> changed: 0x<hash>" — paste the new values below.
//    Init lives in InitGoldenTests.swift and is never re-captured.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryGoldenTests {
    static let golden: [String: UInt64] = [
        "Clean Sub": 0xf5d8afb2ab0d68f1,
        "Velvet Acid": 0xfb49ec1d2635b610,
        "Round Reese": 0x9d217b0f85a34f7d,
        "Wavetable Growl": 0xd029131e797cc9ad,
        "Muted Funk": 0xdebde07f706da253,
        "Soft 808": 0xbad5f1602d595e64,
        "Silk Lead": 0xfbf1d2a6e63b0f23,
        "Crystal Lead": 0x85bbf6178d753fa8,
        "Warm Mono": 0x78ba7632353d9533,
        "Arp Cascade": 0xb3bdb27c0729695f,
        "Supersaw Soft": 0x44297862641f424c,
        "PWM Whisper": 0xe47645a5ba0dfa5b,
        "Cloud Bed": 0xb90d80e14724520d,
        "Glass Horizon": 0x6bee2fb23927fabf,
        "Analog Drift": 0x21cf54f8fcae8a24,
        "Noir Pad": 0x5c9fa3b3bf924c0c,
        "Air Choir": 0x39568d552e6bc174,
        "Slow Motion": 0x3b456dd8d74fb258,
        "Soft EP": 0x8ef52014902aae3e,
        "Organ Soft": 0xbed207dd22a6b59f,
        "Clav Tick": 0x6daec08ffdfc3dc3,
        "Bell Keys": 0xd58280a6c16eff30,
        "Rhodes Warm": 0x4854b956f567946d,
        "Nylon Pluck": 0x4ba2a85aea402609,
        "Steel Spark": 0x3efc25a3d04cce6d,
        "Kalimba Soft": 0xb587df8d2e85c4bc,
        "WT Pluck": 0xba4a202eca97083b,
        "Muted Guitar": 0xeb628e8c93dd4571,
        "Section Soft": 0x9459a3895f52fa,
        "Cello Warm": 0xdef273ce15bba7f0,
        "High Ensemble": 0xaf3d51e0032c0c02,
        "Tremolo Strings": 0xf29cee2d65bdfa45,
        "WT Orchestra": 0x8b7b62dde463ec11,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x7e5ba799ab4b0aca,
        "PWM Sub Pulse": 0x2c49ffc504d5ab4d,
        "Snap Resonator": 0xe60f5d0216a5fa11,
        "Vox Morph Lead": 0x1f1356698400ab1a,
        "Delayed Vibrato": 0x7e8efe628d3534a4,
        "Fifth Sync Lead": 0x9a0c7b06c9c305a4,
        "Phase Cathedral": 0x4fe24ddc7bf10a23,
        "Breathing Glass": 0x5d164f5000f87643,
        "Tidal Pad": 0xcfe53ff904fe5d71,
        "Phaser Rhodes": 0x4de6c810947a978b,
        "Wurli Tremolo": 0x9499e4b2865ea18e,
        "Velvet Clav": 0x198dfedb54a4ee5b,
        "Pan Ping Pluck": 0xd181ff42120919dd,
        "Flange Harp": 0xdd69633c782026f1,
        "Bit Pluck Arp": 0x5dd3bf48b0521611,
        "Chamber Swell": 0xa2c0b1f294b6f9ec,
        "Phased Violins": 0xcb50774ba1af6019,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x26f09116ef9353fe,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0xee3f1ee775d3c802,
        "Hollow Pulse Bass": 0xb37cb77cec2092,
        "Fat Unison Bass": 0x4b666f954de50e66,
        "Finger Pluck Bass": 0x9962f577f799163c,
        "Wavefold Bass": 0x81dd0a7ed9cd8bed,
        "Dub Wobble": 0xfc7a5e9f4c8ee0b6,
        "Chip Square Lead": 0x142b11825ad4de80,
        "Glide Saw Lead": 0x899c07f9d02f2ac5,
        "Breathy Flute": 0x6b5494dd9e64aad5,
        "Overdrive Lead": 0xcd737736b8ed734d,
        "Whistle Lead": 0x5db50cfeb5c5f5e3,
        "Nasal Band Lead": 0x4b48fb638df8716f,
        "Soft Saw Pad": 0x2b1150f774277691,
        "Sine Glass Pad": 0xe25fdb4cb3d9305f,
        "Dark Choir": 0xdad87947363511e1,
        "Pulse Sweep Pad": 0x5f1c7c83cc15b447,
        "Night Swell": 0x710576fb9a13f533,
        "Toy Piano": 0x221daa8635077cf1,
        "Digital EP": 0x93f4d7a489a258b4,
        "Rotary Organ": 0x91fe218ffd5b23ae,
        "Bright Harpsi": 0xdb7e539cc6247271,
        "Mellow Vibes": 0x932d01740ecd6f12,
        "Koto Pluck": 0x2f2000cb65f3d74f,
        "Marimba": 0x89ac48a9a81ca758,
        "Harp Glimmer": 0x28fc3946050851f0,
        "Muted Synth Pluck": 0x473c85b5ed31e6f5,
        "Echo Pluck": 0x43338e14fd41960f,
        "Slow Violas": 0x274e4cda3ad8083e,
        "Pizzicato": 0x482e38600e4d0b53,
        "Solo Cello": 0x5b21949982e212b5,
        "String Machine": 0xa0e2590bdbde24f7,
        "Brass Stab": 0x51514d747c3acebc,
        "Soft Horns": 0x209209edac2c159,
        "Trumpet Lead": 0xdc4444847c17485f,
        "Synth Brass Pad": 0x49b8a3986e57d2f5,
        "Low Tuba": 0xc4a2155b89efaf1e,
        "Up Arp Pluck": 0x1eba4acd799158fb,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0x495f4d8fbe0019c4,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x830cb28b1fd7c4f2,
        "Wind Gust": 0x6d1737d1f932dab6,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0x234695b8002d5ca0,
        "Vowel Ah Lead": 0x31474cea761e4c46,
        "MSEG Drift": 0x2e712decc132c46f,
    ]

    @Test func factoryPresetsRenderBitIdenticalToGolden() {
        let presets = SynthPreset.factoryPresets
        #expect(presets.count == Self.golden.count)
        #expect(Self.golden["Init"] == nil)
        for p in presets {
            let h = InitGoldenTests.renderHash(p)
            #expect(h == Self.golden[p.name], "\(p.name) changed: 0x\(String(h, radix: 16))")
        }
    }
}
