//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten; SYNT_35 re-captured non-Init after velocity floors; SYNT_36 after loudness floors; SYNT_37 after category gesture; SYNT_44 after warm/drift floors; SYNT_45 after cutoff bands + comb; SYNT_46 after fxOrder fills + monoBass stagger; SYNT_48 after Haas stagger + MidSide uptake. Re-capture only on purpose.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0xfdd1d4c400f6b6ab,
        "Velvet Acid": 0x1334ad4033c16eea,
        "Round Reese": 0xa1bd453efe0cf606,
        "Wavetable Growl": 0x73f62bf1221d1fb1,
        "Muted Funk": 0x4e16d3f326b30ec5,
        "Soft 808": 0x3d925f2a04185af7,
        "Silk Lead": 0x5c59d70bc8dcc13c,
        "Crystal Lead": 0x5f899d951ca29779,
        "Warm Mono": 0xbfe1d0a612da426f,
        "Arp Cascade": 0xa68620b93efdbf9e,
        "Supersaw Soft": 0x764cc1cb70f97541,
        "PWM Whisper": 0xc11dd531e7c354be,
        "Cloud Bed": 0xc562abd20ad545f5,
        "Glass Horizon": 0x6aa33609fde9f767,
        "Analog Drift": 0x34171ee48ce5f3eb,
        "Noir Pad": 0x37fd1b013c41141d,
        "Air Choir": 0xf8bdbc416c20c207,
        "Slow Motion": 0x19081db952d0f9d6,
        "Soft EP": 0x97584891d66cf3f2,
        "Organ Soft": 0xcc618c6173e28a73,
        "Clav Tick": 0xe231b97a82fd5c66,
        "Bell Keys": 0x268d12ec9d86d07d,
        "Rhodes Warm": 0x02533bef9b4dae7e,
        "Nylon Pluck": 0x267ea1c1fc435742,
        "Steel Spark": 0x50d80a80bd671e3a,
        "Kalimba Soft": 0x8d2700fdaf5c3283,
        "WT Pluck": 0xaa58ff07dd997fa5,
        "Muted Guitar": 0xf7b9fa22499d35e6,
        "Section Soft": 0xc98480982fce4040,
        "Cello Warm": 0xc76dad1864e0fe5b,
        "High Ensemble": 0x58420f0d40aff5a8,
        "Tremolo Strings": 0xb5955e090317936f,
        "WT Orchestra": 0xde5e285ef6b944ff,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0xdbf4968bc850760f,
        "PWM Sub Pulse": 0xa83e9df9c125dae2,
        "Snap Resonator": 0x859930f0ad8e55a4,
        "Vox Morph Lead": 0x3c3e438f3c21dfc5,
        "Delayed Vibrato": 0xdd423d9d293f6bba,
        "Fifth Sync Lead": 0x30c9426b8ef0af42,
        "Phase Cathedral": 0x432231a9370de8d2,
        "Breathing Glass": 0x0dad23fa49fe36d4,
        "Tidal Pad": 0x4e8d3cf8825e895b,
        "Phaser Rhodes": 0x2f1824265370815e,
        "Wurli Tremolo": 0xb5a899aa6865778c,
        "Velvet Clav": 0xdf5b3a5872d268b0,
        "Pan Ping Pluck": 0xb34d7d63053f5afb,
        "Flange Harp": 0x16e804e12cf34707,
        "Bit Pluck Arp": 0xb83ae8e0297c9337,
        "Chamber Swell": 0xf6bab21d29ed7c5a,
        "Phased Violins": 0x22c9ce249302e724,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x26f09116ef9353fe,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x5aa7943325f6605d,
        "Hollow Pulse Bass": 0x49ed63b968e308c2,
        "Fat Unison Bass": 0xebdafb0c5edcecd7,
        "Finger Pluck Bass": 0x1ffd084a7416cea9,
        "Wavefold Bass": 0xa0009750881fbaf7,
        "Dub Wobble": 0xb84172ba3dab485a,
        "Chip Square Lead": 0x2f88a8218f7c50e6,
        "Glide Saw Lead": 0x33e8e369ea59ab11,
        "Breathy Flute": 0x78d6ee5204bfe37a,
        "Overdrive Lead": 0x7c1e4a4b84e8c7a5,
        "Whistle Lead": 0x2ba834663899d18f,
        "Nasal Band Lead": 0x99bd86a59598d506,
        "Soft Saw Pad": 0x54a9f5e40ed30152,
        "Sine Glass Pad": 0x224009a0d00d0b1d,
        "Dark Choir": 0xa46d627a6e81cb68,
        "Pulse Sweep Pad": 0x3fbf9b6a6671561b,
        "Night Swell": 0x48002631c397d71e,
        "Toy Piano": 0x99d9419b98ae8491,
        "Digital EP": 0xa6ed4be7961a0f94,
        "Rotary Organ": 0xb4dc1ef2c4f0d655,
        "Bright Harpsi": 0xd4e5ee37608ed910,
        "Mellow Vibes": 0xf1a5313a8bd872e6,
        "Koto Pluck": 0x69abbb986e4b183,
        "Marimba": 0x934ff498b0f5d13b,
        "Harp Glimmer": 0xbf5bb86078a9423a,
        "Muted Synth Pluck": 0xfa6578b64d49a19f,
        "Echo Pluck": 0xae052c575c5b6837,
        "Slow Violas": 0x992c7d45c292ac60,
        "Pizzicato": 0x0a4b8692270d7124,
        "Solo Cello": 0x42c0f6ba6481cbac,
        "String Machine": 0xa23af17d7c3f45ea,
        "Brass Stab": 0xa95438fd1b2a82db,
        "Soft Horns": 0xebf4eb9c6411f80b,
        "Trumpet Lead": 0x79f6ff8e2a279bd3,
        "Synth Brass Pad": 0x86807cbdd53f7cfc,
        "Low Tuba": 0x6c70ed8e1d30394b,
        "Up Arp Pluck": 0x9be611bd1c043f67,
        "Down Arp Bells": 0x9c1bda7f8c872325,
        "Random Sparkle": 0xca45d8d25ca6b28e,
        "UpDown Bass Arp": 0x9c1bda7f8c872325,
        "Laser Zap": 0x830cb28b1fd7c4f2,
        "Wind Gust": 0x6d1737d1f932dab6,
        // Stage 8 demos, captured when the three patches were added.
        "Serial Glass Bass": 0x95527df58d58565f,
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
