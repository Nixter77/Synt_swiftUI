//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten; SYNT_35 re-captured non-Init after velocity floors; SYNT_36 after loudness floors; SYNT_37 after category gesture; SYNT_44 after warm/drift floors; SYNT_45 after cutoff bands + comb; SYNT_46 after fxOrder fills + monoBass stagger. Re-capture only on purpose.
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
        "Velvet Acid": 0x1334ad4033c16eea,
        "Round Reese": 0xdbb0bc1a1f252a57,
        "Wavetable Growl": 0x73f62bf1221d1fb1,
        "Muted Funk": 0x4e16d3f326b30ec5,
        "Soft 808": 0x1e57572ea495bdb9,
        "Silk Lead": 0x1892cb8f9ab8b8a5,
        "Crystal Lead": 0x8d75c28fa1ab4b70,
        "Warm Mono": 0xb8e2ad856b2d1a2c,
        "Arp Cascade": 0x5854ac10147973c7,
        "Supersaw Soft": 0x764cc1cb70f97541,
        "PWM Whisper": 0xf7d3a23f83649293,
        "Cloud Bed": 0x10ec91fddf330fa9,
        "Glass Horizon": 0x6aa33609fde9f767,
        "Analog Drift": 0x47702bd30e084946,
        "Noir Pad": 0x37fd1b013c41141d,
        "Air Choir": 0xcf97d53143b91980,
        "Slow Motion": 0xbcb2c057c8117fd2,
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
        "Cello Warm": 0xc76dad1864e0fe5b,
        "High Ensemble": 0x01e3b0646e1e22ff,
        "Tremolo Strings": 0xb5955e090317936f,
        "WT Orchestra": 0x4371f57f00a28fa2,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x610734bf68492dab,
        "PWM Sub Pulse": 0x94224be28dd621ec,
        "Snap Resonator": 0x39609533ad70060b,
        "Vox Morph Lead": 0x92ca10a1e85ae3a9,
        "Delayed Vibrato": 0x6cd9aeb01e079a38,
        "Fifth Sync Lead": 0xbeba3bb1fa2d47a0,
        "Phase Cathedral": 0xf2f04c20279b6688,
        "Breathing Glass": 0x9fd606e4a9d9c011,
        "Tidal Pad": 0xfb1c6ee5a23b8acc,
        "Phaser Rhodes": 0x2f1824265370815e,
        "Wurli Tremolo": 0x7d91fa0b2b62bb81,
        "Velvet Clav": 0xdf5b3a5872d268b0,
        "Pan Ping Pluck": 0xb34d7d63053f5afb,
        "Flange Harp": 0x16e804e12cf34707,
        "Bit Pluck Arp": 0xb83ae8e0297c9337,
        "Chamber Swell": 0x24d5fa7156000f16,
        "Phased Violins": 0x96b5dca0c3fd8699,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x26f09116ef9353fe,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x43be78f411d8e07f,
        "Hollow Pulse Bass": 0x1d97bd9e153605ef,
        "Fat Unison Bass": 0x9be5651b7cc1af43,
        "Finger Pluck Bass": 0x1ffd084a7416cea9,
        "Wavefold Bass": 0x1851dc7645a79934,
        "Dub Wobble": 0xb84172ba3dab485a,
        "Chip Square Lead": 0x3caa95aa978d2f07,
        "Glide Saw Lead": 0x3d40fcb612453a22,
        "Breathy Flute": 0xb6aa7b1b5f43dadb,
        "Overdrive Lead": 0xc511b564c500c411,
        "Whistle Lead": 0x836adffcbb2f4389,
        "Nasal Band Lead": 0x99bd86a59598d506,
        "Soft Saw Pad": 0x54a9f5e40ed30152,
        "Sine Glass Pad": 0xa9a605a7b93126ed,
        "Dark Choir": 0xf26ad77c3df54641,
        "Pulse Sweep Pad": 0x13f363d5769dbac5,
        "Night Swell": 0x63de5a9e275ce6e7,
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
        "Solo Cello": 0x42c0f6ba6481cbac,
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
        "Serial Glass Bass": 0x824219f160f6175e,
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
