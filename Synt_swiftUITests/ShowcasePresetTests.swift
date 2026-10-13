//
//  ShowcasePresetTests.swift
//  The 2026-10-13 showcase factory patches: load, render finite and audible,
//  use raw LFO rows, and touch every matrix destination across the set.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct ShowcasePresetTests {
    @Test func showcaseIsAppendedAfterLegacyLibrary() {
        let all = SynthPreset.factoryPresets
        #expect(SynthPreset.showcasePresets.count == 20)
        #expect(Array(all.suffix(20).map(\.name)) == SynthPreset.showcasePresets.map(\.name))
        #expect(SynthPreset.showcasePresets.allSatisfy { !$0.lfoRowsFollowDepth })
    }

    @Test func showcaseCoversEveryMatrixDestinationAndNewFeatures() {
        let ps = SynthPreset.showcasePresets
        let dests = Set(ps.flatMap { $0.modMatrix.map(\.destination) })
        #expect(dests == Set(ModDestination.allCases))
        #expect(ps.contains { $0.lfoTarget == .none && $0.modMatrix.contains { $0.source == .lfo1 } })
        #expect(ps.contains { $0.unisonVoices > 1 })
        #expect(ps.contains { $0.phaserEnabled && $0.phaserMode == .flanger })
        for p in ps { #expect(!p.modMatrix.isEmpty, "\(p.name) uses no matrix row") }
    }

    @Test func everyShowcasePresetRendersFiniteNonSilentAudio() {
        for preset in SynthPreset.showcasePresets {
            let engine = AudioEngine()
            engine.preset = preset
            engine.applyPresetForTesting()
            engine.noteOn(midiNote: 60, velocity: 0.8)
            engine.noteOn(midiNote: 64, velocity: 0.7)
            engine.processCommandsForTesting()
            var peak: Float = 0
            var finite = true
            for _ in 0..<44100 {
                let (l, r) = engine.renderOneSample()
                if !l.isFinite || !r.isFinite { finite = false }
                peak = max(peak, abs(l), abs(r))
            }
            #expect(finite, "\(preset.name) produced NaN/Inf")
            #expect(peak > 0.005, "\(preset.name) is silent (peak \(peak))")
            #expect(peak < 1.5, "\(preset.name) peak \(peak) too hot")
        }
    }
}
