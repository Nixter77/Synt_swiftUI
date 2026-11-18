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
        "Clean Sub": 0xca3ef85ea919e88c,
        "Velvet Acid": 0xbf063d4a2b2c02ed,
        "Round Reese": 0xdf227c0e1f72971e,
        "Wavetable Growl": 0x5dfd8967e75bbd49,
        "Muted Funk": 0x8b2aec3edbaa3cf3,
        "Soft 808": 0x32ac5f3782159a07,
        "Silk Lead": 0x12f7b665f461cffd,
        "Crystal Lead": 0x326d6520425fde0d,
        "Warm Mono": 0x5c4271f6e3a3ed8f,
        "Arp Cascade": 0xeb924b94bd5da411,
        "Supersaw Soft": 0xc14ed588f417cfec,
        "PWM Whisper": 0xdbf87f65c53f2c08,
        "Cloud Bed": 0xd7f7f49c1c8bd6e5,
        "Glass Horizon": 0xe2ecb2497ba96f76,
        "Analog Drift": 0xa3f1436f8d7bdf33,
        "Noir Pad": 0x8e6804c708156e0b,
        "Air Choir": 0x293d31b87592347a,
        "Slow Motion": 0xacc0a256ec3fd2f8,
        "Soft EP": 0x94f906286ad44dc2,
        "Organ Soft": 0x16054dc3190f63f4,
        "Clav Tick": 0xd5d28b2b30a31cdf,
        "Bell Keys": 0xb75a834828b286f3,
        "Rhodes Warm": 0xeec4061386a19556,
        "Nylon Pluck": 0x933bd75db3baf90c,
        "Steel Spark": 0xd83afc2cd0551c3e,
        "Kalimba Soft": 0x57afd378e54c7aee,
        "WT Pluck": 0x1b9fa0c9f65a0972,
        "Muted Guitar": 0x9163d336c0613cee,
        "Section Soft": 0xd09f4f242170bd43,
        "Cello Warm": 0x722e460cb0863764,
        "High Ensemble": 0x8f70fcfedd8afe6f,
        "Tremolo Strings": 0xc2bd0bd2dea87b7,
        "WT Orchestra": 0xe74343be3e01dfff,
        "Shimmer Rise": 0x24e89427d75f4d64,
        "Noise Sweep": 0xf1b99ed99b23b14a,
        "Glitch Arp": 0xe1ce9a3f3b19bd87,
        "Deep Drone": 0xb1e372300d9cb7e6,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x1745522a588717fe,
        "PWM Sub Pulse": 0x50bc19c6c098d390,
        "Snap Resonator": 0x2274f223b78fdc92,
        "Vox Morph Lead": 0xf3b9841c5ef95b2b,
        "Delayed Vibrato": 0x750a47ecee26337c,
        "Fifth Sync Lead": 0xc2001f01c1070ba2,
        "Phase Cathedral": 0xadcd30c7e55c9830,
        "Breathing Glass": 0xe47362d4678b19e0,
        "Tidal Pad": 0x8508362323fd9ef6,
        "Phaser Rhodes": 0x4536dcb153e723e3,
        "Wurli Tremolo": 0x91ce129bb959fe4d,
        "Velvet Clav": 0xaf2c694c8be1aebe,
        "Pan Ping Pluck": 0xde6c7dbe953b68eb,
        "Flange Harp": 0x5ed76fe6227732ee,
        "Bit Pluck Arp": 0x92ef51341ce7b9a5,
        "Chamber Swell": 0x3533b6667a6c1cfc,
        "Phased Violins": 0x3e363bcd599163a9,
        "Siren Drift": 0x67e89795f7001da7,
        "Jet Flanger": 0xc61ebf257e47c377,
        "Random Bloom": 0x4666baffc165cfcf,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0xab4fec96c546e985,
        "Hollow Pulse Bass": 0xaaaf1c60aa79ddeb,
        "Fat Unison Bass": 0x9a3f16cb510bed34,
        "Finger Pluck Bass": 0x433c83e76db46055,
        "Wavefold Bass": 0xe9fe7416d436608a,
        "Dub Wobble": 0x86b7ddd7e390da5c,
        "Chip Square Lead": 0x603b8c64131df23f,
        "Glide Saw Lead": 0xa2365456c40cf2c5,
        "Breathy Flute": 0x3886ebdfe454798a,
        "Overdrive Lead": 0x450721cfb90327cb,
        "Whistle Lead": 0xfa97ab8d62a34b8d,
        "Nasal Band Lead": 0x64613566582479b3,
        "Soft Saw Pad": 0x1c29338de3f17e97,
        "Sine Glass Pad": 0xfa1d12dad004f109,
        "Dark Choir": 0x91422737c88a79bc,
        "Pulse Sweep Pad": 0x100a1224918227e8,
        "Night Swell": 0x4130b96a908d6311,
        "Toy Piano": 0x761e1ceb5f7fcd9c,
        "Digital EP": 0xfb46083f233a4a07,
        "Rotary Organ": 0x7a286e4465a21fe1,
        "Bright Harpsi": 0xc619affc2043433e,
        "Mellow Vibes": 0xd3c0ce788274f6,
        "Koto Pluck": 0x842112be33070bf7,
        "Marimba": 0xc8ae11aab6d1b951,
        "Harp Glimmer": 0x6f0fcb6210ab7a96,
        "Muted Synth Pluck": 0x66fcfd386689c7a7,
        "Echo Pluck": 0xb19699bf2a90eb4b,
        "Slow Violas": 0x75d14ee72c535eb,
        "Pizzicato": 0x6e3a083bd6c83ed7,
        "Solo Cello": 0x47cae88befa7f74a,
        "String Machine": 0x7e2943560e09adf7,
        "Brass Stab": 0x78051c97fafdd18b,
        "Soft Horns": 0x936c294aee12d8f2,
        "Trumpet Lead": 0x4250f8db1a09d51b,
        "Synth Brass Pad": 0x60418331c30ab2e9,
        "Low Tuba": 0x35c163fad8cdd78,
        "Up Arp Pluck": 0x1f3b5747e2bce7ed,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xb0255a697b6de53d,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x6565d4b161880386,
        "Wind Gust": 0xa0b7fff74db0cc61,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xa5e7629437479455,
        "Vowel Ah Lead": 0x376df7a2d0c90fd4,
        "MSEG Drift": 0xbdcce4b1e99fa17e,
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
