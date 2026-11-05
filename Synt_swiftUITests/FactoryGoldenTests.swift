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
        "Clean Sub": 0x8b8319179b73a54b,
        "Velvet Acid": 0xaf3cb5d2382560ca,
        "Round Reese": 0x34f13b7e7ac31682,
        "Wavetable Growl": 0x19941f80f137ef7,
        "Muted Funk": 0x9ff5c9cbb4a30dd2,
        "Soft 808": 0x465130ef7e6c7aea,
        "Silk Lead": 0x9ad8d017beaaef5f,
        "Crystal Lead": 0xf913478febc176d2,
        "Warm Mono": 0xc682f7b3a9eabf42,
        "Arp Cascade": 0x35a4ed521e07698f,
        "Supersaw Soft": 0x5565ab70e75f80f4,
        "PWM Whisper": 0xfe11be8207ba1cb2,
        "Cloud Bed": 0x49f255bbe29aefaa,
        "Glass Horizon": 0xdda4aba11e204c79,
        "Analog Drift": 0x5b01c091ebf48951,
        "Noir Pad": 0x2067844e8422c0a3,
        "Air Choir": 0xa442fd923f7e6409,
        "Slow Motion": 0x8e542877f77af99b,
        "Soft EP": 0xd62834162bb72182,
        "Organ Soft": 0x4fd9149b124ac04,
        "Clav Tick": 0x861df337125ce971,
        "Bell Keys": 0x300465eb8bc867b8,
        "Rhodes Warm": 0xdced63522dfa451a,
        "Nylon Pluck": 0xf26ee31d3424687b,
        "Steel Spark": 0x450115cb180f5c8d,
        "Kalimba Soft": 0xaed4249d5d97bc80,
        "WT Pluck": 0x65ded2b555c1d76e,
        "Muted Guitar": 0xc1d99db408759377,
        "Section Soft": 0x96d31635068eadb1,
        "Cello Warm": 0x524d4b6816b0504a,
        "High Ensemble": 0x49d31c71b7997fee,
        "Tremolo Strings": 0xda09b294d25ada6c,
        "WT Orchestra": 0xc3b6edfab6bdb20c,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x6ea5d1bb686a84d9,
        "PWM Sub Pulse": 0xcf8f423d44e70fd6,
        "Snap Resonator": 0x13d207792b431f4d,
        "Vox Morph Lead": 0xfb9fd6e4c228280e,
        "Delayed Vibrato": 0x7607ac6fc6e47563,
        "Fifth Sync Lead": 0xb3ca0f1c097f57c5,
        "Phase Cathedral": 0x2a297b84d4dd85f2,
        "Breathing Glass": 0x8f013bd024a7def6,
        "Tidal Pad": 0x92e5206700364791,
        "Phaser Rhodes": 0xfbcd35da139d3565,
        "Wurli Tremolo": 0x698a4b107709c71c,
        "Velvet Clav": 0xb4e9e51562fc42fb,
        "Pan Ping Pluck": 0xede67fdbc7553692,
        "Flange Harp": 0x73c001bf1bc712a9,
        "Bit Pluck Arp": 0xe3cc013befc10a83,
        "Chamber Swell": 0x527335185654dd00,
        "Phased Violins": 0x7c1f6411e974c1e1,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x26f09116ef9353fe,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0xf0ff77ecfa6dc38f,
        "Hollow Pulse Bass": 0xc60844e9a09eef2e,
        "Fat Unison Bass": 0x528d0692ae05d51f,
        "Finger Pluck Bass": 0xcc100426af7d5587,
        "Wavefold Bass": 0x843992aaa680b99a,
        "Dub Wobble": 0x378de7118eb13122,
        "Chip Square Lead": 0x4db287e82da82b3d,
        "Glide Saw Lead": 0x10e52ad4cc1d2efa,
        "Breathy Flute": 0x1187e9b355dbfc79,
        "Overdrive Lead": 0xae20a7ef9a8eaa9d,
        "Whistle Lead": 0x8ab5cfd144c339e0,
        "Nasal Band Lead": 0x60b09093b755b8be,
        "Soft Saw Pad": 0x5367b84891e41f07,
        "Sine Glass Pad": 0xd4792d3c52855cbb,
        "Dark Choir": 0xfff848a4cebdc202,
        "Pulse Sweep Pad": 0xc0eac537a55458e1,
        "Night Swell": 0x976a031250aa838a,
        "Toy Piano": 0x6129fa93d4cf86d9,
        "Digital EP": 0x1feb597d6e44dff7,
        "Rotary Organ": 0x9f9a3f3a81960c85,
        "Bright Harpsi": 0x2694f866a7b970b7,
        "Mellow Vibes": 0xe3cd66ca4022e8a2,
        "Koto Pluck": 0x2ed0f70e18a56e7d,
        "Marimba": 0x873b7cee3044e1b5,
        "Harp Glimmer": 0xd4a06dd90677db98,
        "Muted Synth Pluck": 0x60c08064b1699c89,
        "Echo Pluck": 0x97291a263dc320af,
        "Slow Violas": 0xf78b64a6a268a1ac,
        "Pizzicato": 0x10de6983ae61e707,
        "Solo Cello": 0xeb72294348e3a1c7,
        "String Machine": 0xb8aec6ad2693344d,
        "Brass Stab": 0x92d268b1d650a9fe,
        "Soft Horns": 0x2e1afe3257df56f4,
        "Trumpet Lead": 0xc5c3ec2a8713ed5,
        "Synth Brass Pad": 0x7ea575866f969601,
        "Low Tuba": 0xed934259da7592a0,
        "Up Arp Pluck": 0x4b77c75f4da34599,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xf24dccaf33db72c0,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x830cb28b1fd7c4f2,
        "Wind Gust": 0x6d1737d1f932dab6,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0x9f9f5506ea14f9aa,
        "Vowel Ah Lead": 0xe50ac90ac2644809,
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
