//
//  InitGoldenTests.swift
//  Bit-exact render hashes for Init and every factory preset.
//  Init stays 0xd1b3635203a4799e. Factory hashes were recaptured in SYNT_30
//  after those preset bodies were rewritten; SYNT_35 re-captured non-Init after velocity floors; SYNT_36 after loudness floors; SYNT_37 after category gesture; SYNT_44 after warm/drift floors; SYNT_45 after cutoff bands + comb; SYNT_46 after fxOrder fills + monoBass stagger; SYNT_48 after Haas stagger + MidSide uptake; SYNT_50 after filterEnv category lift + Soft upper cap; SYNT_51 after dspReverbEnabled gate (reverbMix > 0); SYNT_55 after Pad LFO-rate stagger; SYNT_56 after Strings LFO-rate stagger; SYNT_57 after Keys/Pluck master stagger; SYNT_58 after Bass/Lead master stagger; SYNT_59 after Keys/Pluck motion-depth stagger; SYNT_60 after Bass/Lead motion-depth stagger. Re-capture only on purpose.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct InitGoldenTests {
    static let golden: [String: UInt64] = [
        "Init": 0xd1b3635203a4799e,
        "Clean Sub": 0xf2a600aa5bd934d5,
        "Velvet Acid": 0x1334ad4033c16eea,
        "Round Reese": 0x4331ba2251e100fd,
        "Wavetable Growl": 0x181ec62e6d2cb41,
        "Muted Funk": 0xfcfb826afb890d64,
        "Soft 808": 0x6f994db0edc3df53,
        "Silk Lead": 0x465036870a4852f9,
        "Crystal Lead": 0xa3b86494a765be33,
        "Warm Mono": 0x749588a066ec2619,
        "Arp Cascade": 0x29c1b503e888631d,
        "Supersaw Soft": 0x9965ed5f9da69760,
        "PWM Whisper": 0x7b919a9e269a9dcd,
        "Cloud Bed": 0x2ab8a6fe7a209427,
        "Glass Horizon": 0x2e793409c68fe085,
        "Analog Drift": 0xe19f0a5884526397,
        "Noir Pad": 0x65c9dc9e7f653ecb,
        "Air Choir": 0x92ae04a8a706ee86,
        "Slow Motion": 0xa176909fff483b98,
        "Soft EP": 0x91734dbffe5655e5,
        "Organ Soft": 0xb77bec514a07984d,
        "Clav Tick": 0xa6e2515df0b56886,
        "Bell Keys": 0x3f9c2570ae265b82,
        "Rhodes Warm": 0xa70cfc10fcdab0c2,
        "Nylon Pluck": 0xaac1e46d7fec515f,
        "Steel Spark": 0xd2d5cdb136d0fb4f,
        "Kalimba Soft": 0xcb068ca096727530,
        "WT Pluck": 0x6d01eca31fcfbbf0,
        "Muted Guitar": 0x1aabee09548c1159,
        "Section Soft": 0x61e5bd334d0fa2d1,
        "Cello Warm": 0xf16c23bb0bf04ff8,
        "High Ensemble": 0xbf5ce588058bb7ba,
        "Tremolo Strings": 0x688c000bfcb673ed,
        "WT Orchestra": 0xef125cd485c0f565,
        "Shimmer Rise": 0x64027a1f845d1fd6,
        "Noise Sweep": 0x6ce017fae185f547,
        "Glitch Arp": 0xb95cbf3010f044b5,
        "Deep Drone": 0xb4797193ef54f7aa,
        "Space Pluck FX": 0x9c1bda7f8c872325,
        // Showcase library (2026-10-13), captured at first add.
        "Rubber Wobble": 0x7a386b2f8bd5a139,
        "PWM Sub Pulse": 0xf1c414746eced75e,
        "Snap Resonator": 0xe3e9e9c51a5d794c,
        "Vox Morph Lead": 0x751f60b7a0644c8c,
        "Delayed Vibrato": 0xe9ebaaab60c9dfb4,
        "Fifth Sync Lead": 0x4bf7afb0f2d26931,
        "Phase Cathedral": 0xe487aeb17ee21ed7,
        "Breathing Glass": 0x604eb82e8599f41d,
        "Tidal Pad": 0xc7fbcec5d8f37e04,
        "Phaser Rhodes": 0xd350bb735b99ea79,
        "Wurli Tremolo": 0x6ce17d736c09d2f5,
        "Velvet Clav": 0x75d170818680a620,
        "Pan Ping Pluck": 0x28871ae2b4c232d6,
        "Flange Harp": 0x58cac0baa5bd656f,
        "Bit Pluck Arp": 0x8eaa8340143182b9,
        "Chamber Swell": 0x1c51ee1e21d4184a,
        "Phased Violins": 0xe794caeb1b5201a7,
        "Siren Drift": 0xbfec0d2c633db391,
        "Jet Flanger": 0x26f09116ef9353fe,
        "Random Bloom": 0xc973e7d0ed361444,
        // Library to 100 (2026-10-18), captured at first add.
        "Acid Squelch": 0x2266cd51c622c699,
        "Hollow Pulse Bass": 0xe82fbf32c32c1f8f,
        "Fat Unison Bass": 0x7eb07562da345763,
        "Finger Pluck Bass": 0x9e51022afc99c900,
        "Wavefold Bass": 0x4338c034cecb5999,
        "Dub Wobble": 0x482b5b3e287a4837,
        "Chip Square Lead": 0x18932865d76f1a5f,
        "Glide Saw Lead": 0xbc8fc8a7234240b4,
        "Breathy Flute": 0x58065167b73a6439,
        "Overdrive Lead": 0xe13c217e8f5154f1,
        "Whistle Lead": 0xec4fd6a0d20c95cc,
        "Nasal Band Lead": 0xe5ead7717d908fac,
        "Soft Saw Pad": 0xcafbb3985c717b0f,
        "Sine Glass Pad": 0x18a01ff696948d5,
        "Dark Choir": 0x93245f5b5f2ea603,
        "Pulse Sweep Pad": 0x442258a34c32363a,
        "Night Swell": 0x707b8e258fc7b661,
        "Toy Piano": 0xe7859701929939e7,
        "Digital EP": 0x19f631c21f485cc7,
        "Rotary Organ": 0xedc23b3ff240c2b0,
        "Bright Harpsi": 0x780a626a6c2b8c76,
        "Mellow Vibes": 0x2ed1604d32b891d0,
        "Koto Pluck": 0x82822e9b979e57fd,
        "Marimba": 0x53b29c456cdc4dfe,
        "Harp Glimmer": 0xc3c8b252d4e51271,
        "Muted Synth Pluck": 0x5925d1091fa8871c,
        "Echo Pluck": 0x4775d4b70d5b48c3,
        "Slow Violas": 0x45cc095af2c50,
        "Pizzicato": 0x91b51f627af86634,
        "Solo Cello": 0xf4e335dc5bfff6db,
        "String Machine": 0x977a0de14bb15bbb,
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
        "Serial Glass Bass": 0x456b1dbe5414deb,
        "Vowel Ah Lead": 0xeda1c0a7f22a3f9b,
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
