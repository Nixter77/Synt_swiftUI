//
//  FactoryPresetCoverageTests.swift
//  Scans the shipped factory, expansion, and MPE banks. Fails until SYNT_30
//  coverage minimums hold. Init is not a musical preset.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct FactoryPresetCoverageTests {
    private static let macroSources: Set<ModSource> = [
        .macro1, .macro2, .macro3, .macro4, .macro5, .macro6, .macro7, .macro8
    ]

    /// FX / ambient patches may exceed the everyday send caps.
    private static let fxShowcaseRelax: Set<String> = []

    @Test func coverageMinimumsHoldOnShippedBanks() {
        let factory = SynthPreset.factoryPresets
        let expansion = SynthPreset.expansionPresets
        let mpe = SynthPreset.mpeFactoryPresets
        let all = factory + expansion + mpe

        #expect((100...120).contains(factory.count), "factory \(factory.count)")
        #expect((45...55).contains(expansion.count), "expansion \(expansion.count)")
        #expect(!factory.contains { $0.name == "Init" })
        #expect(!expansion.contains { $0.name == "Init" })
        #expect(!mpe.contains { $0.name == "Init" })
        #expect(SynthPreset.defaultPreset.name == "Init")

        let factoryNames = factory.map(\.name)
        let expansionNames = expansion.map(\.name)
        #expect(Set(factoryNames).count == factoryNames.count)
        #expect(Set(expansionNames).count == expansionNames.count)
        #expect(Set(factoryNames).isDisjoint(with: expansionNames))
        #expect(all.allSatisfy { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

        let categories = Set(PresetCategory.allCases)
        #expect(all.allSatisfy { categories.contains($0.category) })
        for category in PresetCategory.allCases {
            #expect(factory.contains { $0.category == category }, "factory missing \(category.rawValue)")
        }

        #expect(all.filter { $0.filter2Routing == .serial }.count >= 3, "filter2 serial")
        #expect(all.filter { $0.filter2Routing == .parallel }.count >= 2, "filter2 parallel")
        #expect(all.filter(Self.formantVowel).count >= 4, "formant + vowel")
        #expect(all.filter(Self.mseg1InMatrix).count >= 4, "mseg1")
        #expect(all.filter(Self.mseg2InMatrix).count >= 2, "mseg2")
        #expect(all.filter(Self.env2OrDedicated).count >= 6, "env2")
        #expect(all.filter(Self.wavetableMorphed).count >= 12, "wavetable")
        #expect(all.filter(Self.dualOrHybridWavetable).count >= 3, "dual/hybrid wt")
        #expect(all.filter { $0.fmAmount > 0 || $0.oscSyncEnabled }.count >= 4, "fm/sync")
        #expect(all.filter { $0.fxOrder != FXSlotID.defaultOrder }.count >= 3, "fx order")
        #expect(all.filter(Self.motionFX).count >= 3, "rotary/shifter/transient")
        #expect(all.filter(Self.macroDrivesMatrix).count >= 4, "macros")
        #expect(all.filter(Self.arpOrSequencerPro).count >= 4, "arp/seq")
        #expect(all.filter(\.mpeEnabled).count >= 2, "mpe")
        #expect(all.filter(\.stereoEnabled).count >= 2, "stereo")
        #expect(all.filter { $0.character != .off }.count >= 2, "character")
        #expect(all.filter { $0.noiseColor != .white }.count >= 2, "noise color")

        let pads = all.filter { $0.category == .pad || $0.category == .strings }
        let monos = all.filter {
            ($0.voiceMode == .mono || $0.voiceMode == .legato)
                && ($0.category == .bass || $0.category == .lead)
        }
        #expect(monos.count >= 3, "mono bass/lead demos")
        let padMax = pads.map(\.masterVolume).max() ?? 1
        let monoMin = monos.map(\.masterVolume).min() ?? 0
        #expect(padMax < monoMin, "pads \(padMax) should stay under monos \(monoMin)")

        for preset in all {
            #expect(preset.masterVolume <= 0.75, "\(preset.name) master")
            #expect((1...4).contains(preset.unisonVoices), "\(preset.name) unison \(preset.unisonVoices)")
            if preset.category == .pad || preset.category == .strings {
                #expect(preset.unisonVoices <= 2, "\(preset.name) unison")
            }
            let relaxed = preset.category == .fx || Self.fxShowcaseRelax.contains(preset.name)
            #expect(preset.reverbMix <= (relaxed ? 0.45 : 0.35), "\(preset.name) reverb")
            #expect(preset.delayMix <= (relaxed ? 0.30 : 0.22), "\(preset.name) delay")
            #expect(preset.chorusMix <= (relaxed ? 0.30 : 0.22), "\(preset.name) chorus")
        }
    }

    @Test func everyMusicalPresetRendersFiniteAndNonSilent() {
        let all = SynthPreset.factoryPresets + SynthPreset.expansionPresets + SynthPreset.mpeFactoryPresets
        for preset in all {
            var patch = preset
            patch.arpMode = .off
            let engine = AudioEngine()
            engine.preset = patch
            engine.applyPresetForTesting()
            engine.clearAllNotes()
            engine.processCommandsForTesting()
            engine.noteOn(midiNote: 60, velocity: 0.85)
            engine.processCommandsForTesting()
            let metrics = engine.renderFramesMetricsForTesting(44_100)
            #expect(metrics.nanCount == 0, "\(preset.name) NaN/Inf")
            #expect(metrics.peak > 0.005, "\(preset.name) silent peak \(metrics.peak)")
        }
    }

    private static func formantVowel(_ preset: SynthPreset) -> Bool {
        let formant = preset.filterType == .formant
            || (preset.filter2Routing != .off && preset.filter2Type == .formant)
        let vowel = preset.filterVowel != 0
            || preset.modMatrix.contains { $0.destination == .vowel && $0.amount != 0 }
        return formant && vowel
    }

    private static func mseg1InMatrix(_ preset: SynthPreset) -> Bool {
        !preset.mseg.points.isEmpty && preset.modMatrix.contains { $0.source == .mseg && $0.amount != 0 }
    }

    private static func mseg2InMatrix(_ preset: SynthPreset) -> Bool {
        !preset.mseg2.points.isEmpty && preset.modMatrix.contains { $0.source == .mseg2 && $0.amount != 0 }
    }

    private static func env2OrDedicated(_ preset: SynthPreset) -> Bool {
        preset.filterEnvUseDedicatedADSR
            || preset.modMatrix.contains { $0.source == .env2 && $0.amount != 0 }
    }

    private static func wavetableMorphed(_ preset: SynthPreset) -> Bool {
        func arm(_ wave: WaveformType, morph: Float, index: Int, on: Bool) -> Bool {
            on && wave == .wavetable && (morph != 0 || index != 0)
        }
        return arm(preset.osc1Waveform, morph: preset.osc1WavetableMorph, index: preset.osc1WavetableIndex, on: true)
            || arm(preset.osc2Waveform, morph: preset.osc2WavetableMorph, index: preset.osc2WavetableIndex, on: preset.osc2Enabled)
    }

    private static func dualOrHybridWavetable(_ preset: SynthPreset) -> Bool {
        let wt1 = preset.osc1Waveform == .wavetable
        let wt2 = preset.osc2Enabled && preset.osc2Waveform == .wavetable
        let classic2 = preset.osc2Enabled && preset.osc2Waveform != .wavetable
        let classic1 = preset.osc1Waveform != .wavetable
        return (wt1 && wt2) || (wt1 && classic2) || (classic1 && wt2)
    }

    private static func motionFX(_ preset: SynthPreset) -> Bool {
        preset.rotaryEnabled || preset.frequencyShifterEnabled || preset.transientEnabled
    }

    private static func macroDrivesMatrix(_ preset: SynthPreset) -> Bool {
        preset.modMatrix.contains { macroSources.contains($0.source) && $0.amount != 0 }
    }

    private static func arpOrSequencerPro(_ preset: SynthPreset) -> Bool {
        if preset.arpMode != .off { return true }
        return preset.sequencerData.contains { step in
            step.isActive && (step.tie || step.ratchet > 1 || step.probability < 0.999)
        }
    }
}
