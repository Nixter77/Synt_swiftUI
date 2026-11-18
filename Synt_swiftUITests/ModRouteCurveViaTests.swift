//
//  ModRouteCurveViaTests.swift
//  SYNT_64 D2: curve shape in the mod LUT, via scaling, timbre destinations,
//  and the guarded comb cutoff.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct ModRouteCurveViaTests {

    @Test func oldMatrixJsonStaysLinearWithNoShapeOrVia() throws {
        let json = #"{"name":"Old","modMatrix":[{"source":"Velocity","destination":"Amplitude","amount":0.4}]}"#
        let preset = try JSONDecoder().decode(SynthPreset.self, from: Data(json.utf8))
        #expect(preset.modMatrix[0].curve == .linear)
        #expect(preset.modMatrix[0].curveShape == 0)
        #expect(preset.modMatrix[0].viaSource == nil)
        #expect(preset.combUsesVoiceCutoff == false)
        #expect(preset.perVoiceCutoffSources == false)
        let again = try JSONDecoder().decode(SynthPreset.self, from: JSONEncoder().encode(preset))
        #expect(again.modMatrix[0].curveShape == 0)
        #expect(again.modMatrix[0].viaSource == nil)
    }

    @Test func flatLinearRowSkipsTheTableAndMatchesTheRawProduct() {
        let engine = AudioEngine()
        engine.rtModMatrix.publish([
            ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.3, curve: .linear, curveShape: 0)
        ])
        engine.rtModMatrix.pullRT()
        let (slots, count) = engine.rtModMatrix.snapshot()
        #expect(count == 1)
        #expect(slots[0].curveShape == 0)
        #expect(slots[0].viaSource == nil)
        let raw: Float = 0.4
        #expect(engine.modulatedAmount(slots[0], slot: 0, source: raw) == raw * 0.3)
    }

    @Test func powerShapeIsBakedAtPublishAndLookupHasNoExtraPow() {
        let shape: Float = 0.75
        let engine = AudioEngine()
        engine.rtModMatrix.publish([
            ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.5, curve: .linear, curveShape: shape)
        ])
        engine.rtModMatrix.pullRT()
        let (slots, _) = engine.rtModMatrix.snapshot()
        let source: Float = 0.5
        let looked = engine.rtModMatrix.lookup(bank: slots[0].tableBank, slot: 0, source: source)
        let expected = RTModMatrix.powerShape(source, shape: shape)
        #expect(abs(looked - expected) < 0.02)
        let shaped = engine.modulatedAmount(slots[0], slot: 0, source: source)
        #expect(abs(shaped - looked * 0.5) < 1e-5)
        #expect(abs(shaped - source * 0.5) > 0.01)

        #expect(RTModMatrix.powerShape(0.5, shape: 0) == 0.5)
        #expect(RTModMatrix.powerShape(-0.5, shape: 0) == -0.5)
        #expect(RTModMatrix.powerShape(1, shape: -1) == 1)
        #expect(RTModMatrix.powerShape(0, shape: 1) == 0)
    }

    @Test func viaMultipliesAmountAndANilViaDoesNot() {
        let engine = AudioEngine()
        engine.rtModMatrix.publish([
            ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.8, viaSource: .modWheel)
        ])
        engine.rtModMatrix.pullRT()
        let (slots, _) = engine.rtModMatrix.snapshot()
        #expect(slots[0].viaSource == .modWheel)
        let scaled = engine.rowAmount(
            slots[0], slot: 0, lfo: 0, lfo2: 0, env: 0, velocity: 1, modWheel: 0.25, keyTrack: 0
        )
        #expect(abs(scaled - 0.2) < 1e-5)

        engine.rtModMatrix.publish([
            ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.8)
        ])
        engine.rtModMatrix.pullRT()
        let (plain, _) = engine.rtModMatrix.snapshot()
        let bare = engine.rowAmount(
            plain[0], slot: 0, lfo: 0, lfo2: 0, env: 0, velocity: 1, modWheel: 0.25, keyTrack: 0
        )
        #expect(bare == 0.8)

        let quietVia = render(lfoAmp(0.8, via: .velocity), velocity: 0.15)
        let fullVia = render(lfoAmp(0.8, via: nil), velocity: 0.15)
        #expect(peakDifference(quietVia, fullVia) > 0.01)
    }

    @Test func explicitZeroShapeRendersTheSameSamplesAsAnOmittedShape() {
        let shaped = render(ampRow(0.45, curveShape: 0), velocity: 0.7)
        let omitted = render(ampRow(0.45), velocity: 0.7)
        #expect(shaped.count == omitted.count)
        for i in 0..<shaped.count {
            #expect(shaped[i] == omitted[i])
        }
        let curved = render(ampRow(0.45, curveShape: 0.8), velocity: 0.7)
        #expect(peakDifference(shaped, curved) > 0.001)
    }

    @Test func timbreSlotsStayInsideTheExistingSnapshot() {
        var seen = Set<Int>()
        for dest in ModDestination.allCases {
            let slot = LiveModulationSnapshot.slot(for: dest)
            #expect(slot >= 0 && slot < LiveModulationSnapshot.slotCount)
            #expect(seen.insert(slot).inserted)
        }
        #expect(LiveModulationSnapshot.slotCount == 32)
        #expect(LiveModulationSnapshot.slot(for: .drive) == 25)
        #expect(LiveModulationSnapshot.slot(for: .osc1Level) == 26)
        #expect(LiveModulationSnapshot.slot(for: .noiseLevel) == 29)
        #expect(LiveModulationSnapshot.slot(for: .filterEnvAmount) == 30)
        #expect(LiveModulationSnapshot.slot(for: .unisonDetune) == 31)
        #expect(SynthParameterAddress.combUsesVoiceCutoff.rawValue == 187)
        #expect(SynthParameterAddress.perVoiceCutoffSources.rawValue == 188)
        #expect(SynthParameterAddress.aftertouchDeadzone.rawValue == 191)
        #expect(SynthParameterAddress.busGlueEnabled.rawValue == 192)
        #expect(SynthParameterAddress.allCases.last == .busGlueEnabled)
    }

    @Test func velocityToDriveRaisesTheCentroid() {
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .sine
        preset.osc2Enabled = false
        preset.filterType = .lowPass
        preset.filterCutoff = 14000
        preset.filterResonance = 0.05
        preset.filterDrive = 0
        preset.attack = 0.005
        preset.decay = 0.2
        preset.sustain = 1
        preset.release = 0.15
        preset.modMatrix = [PresetAuthoring.mod(.velocity, .drive, 0.5)]

        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        var centroids: [Float] = []
        for midi in DynamicsProbe.midiVelocities {
            let take = DynamicsProbe.render(engine: engine, notes: [(60, DynamicsProbe.midi(midi))])
            #expect(!take.nonFinite)
            centroids.append(take.centroidHz)
        }
        let c32 = centroids[2]
        let c127 = centroids.last!
        #expect(c32 > 1)
        #expect(c127 / c32 >= 1.3, "VelBright \(c127 / c32) centroids \(centroids)")
        #expect(DynamicsProbe.monotonic(centroids, tolerance: 8), "centroids \(centroids)")
    }

    @Test func combFollowsTheVoiceCutoffOnlyWhenAsked() {
        let off = render(combPreset(flag: false), velocity: 1, count: 6000)
        let on = render(combPreset(flag: true), velocity: 1, count: 6000)
        #expect(peakDifference(off, on) > 0.01)

        // A lower comb frequency packs more teeth, so spectral centroid can rise
        // while the delay gets longer. Compare the samples: velocity reaches the
        // delay only when the flag is on. Volume tracking is off so loudness matches.
        var shaped = combPreset(flag: true)
        shaped.velocityToCutoff = 0.85
        shaped.velocityToVolume = 0
        let soft = render(shaped, velocity: DynamicsProbe.midi(32), count: 4000)
        let hard = render(shaped, velocity: DynamicsProbe.midi(127), count: 4000)
        let moved = peakDifference(soft, hard)
        #expect(moved > 0.01, "flag on peak \(moved)")

        var ignored = shaped
        ignored.combUsesVoiceCutoff = false
        let softOff = render(ignored, velocity: DynamicsProbe.midi(32), count: 4000)
        let hardOff = render(ignored, velocity: DynamicsProbe.midi(127), count: 4000)
        let stayed = peakDifference(softOff, hardOff)
        #expect(stayed < 1e-4, "flag off peak \(stayed)")
    }

    @Test func env2MovesCutoffPerVoiceOnlyBehindTheFlag() {
        let dead = render(env2Cutoff(flag: false), velocity: 0.9, count: 5000)
        let live = render(env2Cutoff(flag: true), velocity: 0.9, count: 5000)
        #expect(peakDifference(dead, live) > 0.01)
    }

    private func ampRow(_ amount: Float, curveShape: Float = 0) -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.modMatrix = [PresetAuthoring.mod(.velocity, .amp, amount, curveShape: curveShape)]
        return preset
    }

    private func lfoAmp(_ amount: Float, via: ModSource?) -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.lfoEnabled = true
        preset.lfoTarget = .none
        preset.lfoRate = 7
        preset.lfoDepth = 1
        preset.lfoWaveform = .sine
        preset.modMatrix = [PresetAuthoring.mod(.lfo1, .amp, amount, via: via)]
        return preset
    }

    private func combPreset(flag: Bool) -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.filterType = .comb
        preset.filterCutoff = 480
        preset.filterResonance = 0.55
        preset.filterEnvelopeAmount = 0.85
        preset.velocityToCutoff = 0
        preset.attack = 0.004
        preset.decay = 0.3
        preset.sustain = 0.8
        preset.release = 0.2
        preset.osc1Waveform = .sawtooth
        preset.osc2Enabled = false
        preset.combUsesVoiceCutoff = flag
        return preset
    }

    private func env2Cutoff(flag: Bool) -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.filterType = .lowPass
        preset.filterCutoff = 350
        preset.filterResonance = 0.2
        preset.filterEnvelopeAmount = 0
        preset.filterEnvUseDedicatedADSR = true
        preset.filterAttack = 0.01
        preset.filterDecay = 0.35
        preset.filterSustain = 0.85
        preset.filterRelease = 0.2
        preset.osc2Enabled = false
        preset.perVoiceCutoffSources = flag
        preset.modMatrix = [PresetAuthoring.mod(.env2, .cutoff, 0.55)]
        return preset
    }

    private func render(_ preset: SynthPreset, velocity: Float, count: Int = 2500) -> [Float] {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: velocity)
        engine.processCommandsForTesting()
        var samples = [Float](repeating: 0, count: count)
        for i in 0..<count {
            samples[i] = engine.renderOneSample().0
        }
        return samples
    }

    private func peakDifference(_ a: [Float], _ b: [Float]) -> Float {
        var peak: Float = 0
        let n = min(a.count, b.count)
        for i in 0..<n { peak = max(peak, abs(a[i] - b[i])) }
        return peak
    }
}
