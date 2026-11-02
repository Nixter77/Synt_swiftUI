//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten; SYNT_35 re-captured non-Init after velocity floors; SYNT_36 after loudness floors; SYNT_37 after category gesture; SYNT_44 after warm/drift floors; SYNT_45 after cutoff bands + comb; SYNT_46 after fxOrder fills + monoBass stagger; SYNT_48 after Haas stagger + MidSide uptake; SYNT_50 after filterEnv category lift + Soft upper cap; SYNT_51 after dspReverbEnabled gate (reverbMix > 0); SYNT_55 after Pad LFO-rate stagger. Re-capture only on purpose.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0x24586193cc4d8240,
        "Velvet Acid": 0x1334ad4033c16eea,
        "Round Reese": 0xeeb65d8da0b0ba4b,
        "Wavetable Growl": 0xafba4108e7608e97,
        "Muted Funk": 0x16be30bcefb35d9f,
        "Soft 808": 0xf952e143c7835c4,
        "Silk Lead": 0xb06426c3e219604a,
        "Crystal Lead": 0x7a7de04c676a1cd3,
        "Warm Mono": 0xe2753a6053c4adb6,
        "Arp Cascade": 0x7570cde8b9b13f26,
        "Supersaw Soft": 0x56a199a6452f0c5e,
        "PWM Whisper": 0xc11dd531e7c354be,
        "Cloud Bed": 0x2ab8a6fe7a209427,
        "Glass Horizon": 0x2e793409c68fe085,
        "Analog Drift": 0xe19f0a5884526397,
        "Noir Pad": 0x65c9dc9e7f653ecb,
        "Air Choir": 0x92ae04a8a706ee86,
        "Slow Motion": 0xa176909fff483b98,
        "Soft EP": 0x809e0f434684804,
        "Organ Soft": 0x23f7d48e94815991,
        "Clav Tick": 0xb22e30f2b3c4a77d,
        "Bell Keys": 0xabf3ccc1b50d17c1,
        "Rhodes Warm": 0x615af225f7df924c,
        "Nylon Pluck": 0x9d2b8ad7b8effaf3,
        "Steel Spark": 0x2cc03ac0a4d95965,
        "Kalimba Soft": 0xdaea4c81e2b10aed,
        "WT Pluck": 0x9a71b4515f7ba26a,
        "Muted Guitar": 0x2dfd687300eb6d3c,
        "Section Soft": 0x5a43a38594c42219,
        "Cello Warm": 0xfc79b1c53b7d96ac,
        "High Ensemble": 0x58420f0d40aff5a8,
        "Tremolo Strings": 0xf29f9ac142d1aeb6,
        "WT Orchestra": 0xde5e285ef6b944ff,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0xd4aaeed1ec7b4bd0,
        "PWM Sub Pulse": 0x2ea81a8ea86087f1,
        "Snap Resonator": 0xc156f481cfc1df77,
        "Vox Morph Lead": 0xe8ce8d4774e31161,
        "Delayed Vibrato": 0x7834bbe1b4cee79b,
        "Fifth Sync Lead": 0xf1cb6d92fee42095,
        "Phase Cathedral": 0xe487aeb17ee21ed7,
        "Breathing Glass": 0x604eb82e8599f41d,
        "Tidal Pad": 0xc7fbcec5d8f37e04,
        "Phaser Rhodes": 0x62f9515f23ddc86d,
        "Wurli Tremolo": 0x8e7aa0488e41f264,
        "Velvet Clav": 0x5b6169630339aee1,
        "Pan Ping Pluck": 0x11760c07b282d78e,
        "Flange Harp": 0x976dfd5728fd3367,
        "Bit Pluck Arp": 0xbc440a791b0d40ad,
        "Chamber Swell": 0xf6bab21d29ed7c5a,
        "Phased Violins": 0x22c9ce249302e724,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x26f09116ef9353fe,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0xe7094f780a6b9b8c,
        "Hollow Pulse Bass": 0x1d3b36f4bb935f3d,
        "Fat Unison Bass": 0x5e15997cc72f07ac,
        "Finger Pluck Bass": 0x3443504ef7c4c03e,
        "Wavefold Bass": 0xa0009750881fbaf7,
        "Dub Wobble": 0x482b5b3e287a4837,
        "Chip Square Lead": 0x90e8177760a56af4,
        "Glide Saw Lead": 0x4299531865fe3cb,
        "Breathy Flute": 0x12ec2d66cbb2bbfa,
        "Overdrive Lead": 0xbbe6f98e2bca0fb9,
        "Whistle Lead": 0xa25db299ae714a1e,
        "Nasal Band Lead": 0x9069a3de4d63e9ec,
        "Soft Saw Pad": 0xcafbb3985c717b0f,
        "Sine Glass Pad": 0x18a01ff696948d5,
        "Dark Choir": 0x93245f5b5f2ea603,
        "Pulse Sweep Pad": 0x442258a34c32363a,
        "Night Swell": 0x707b8e258fc7b661,
        "Toy Piano": 0x8aaa355b49f78615,
        "Digital EP": 0x6d930a17688af5d6,
        "Rotary Organ": 0x3cad753b424e8c97,
        "Bright Harpsi": 0x15fd57d5ab0f788,
        "Mellow Vibes": 0x35296fac68866ee8,
        "Koto Pluck": 0xad1da107bdf8bf7f,
        "Marimba": 0x2d752d4cba8ea8fc,
        "Harp Glimmer": 0xceb4d6993dcbcec5,
        "Muted Synth Pluck": 0x496916a99359d129,
        "Echo Pluck": 0xea11cd7e3da3b721,
        "Slow Violas": 0x992c7d45c292ac60,
        "Pizzicato": 0x3ca95ba07834c1a0,
        "Solo Cello": 0x42c0f6ba6481cbac,
        "String Machine": 0xa23af17d7c3f45ea,
        "Brass Stab": 0x15704baee205b9fc,
        "Soft Horns": 0xbdbd669184725efb,
        "Trumpet Lead": 0x9d257ccb45263abf,
        "Synth Brass Pad": 0x7debf7babccab18b,
        "Low Tuba": 0xd2c20bc8f585fa0b,
        "Up Arp Pluck": 0x5602f9afded18c1,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xffd7bf19bc2c4141,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x830cb28b1fd7c4f2,
        "Wind Gust": 0x6d1737d1f932dab6,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0xb3932976c1419edb,
        "Vowel Ah Lead": 0xef885decd262e86d,
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
