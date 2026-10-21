//
//  Phase4ModulationTests.swift
//  Synt_swiftUITests
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

struct Phase4ModulationTests {

    @Test func lfoTempoSyncCalculatesExpectedFrequency() {
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120.0
        preset.lfoTempoSync = true
        preset.lfoSyncDivision = .quarter

        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()

        // 120 BPM quarter note = 0.5s -> 2.0 Hz
        #expect(abs(engine.lfo.rate - 2.0) < 1e-4)

        preset.lfoSyncDivision = .eighth
        engine.preset = preset
        engine.applyPresetForTesting()
        // 120 BPM eighth note = 0.25s -> 4.0 Hz
        #expect(abs(engine.lfo.rate - 4.0) < 1e-4)
    }

    @Test func delayTempoSyncCalculatesExpectedDelayTime() {
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120.0
        preset.delayTempoSync = true
        preset.delaySyncDivision = .eighth

        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()

        // 120 BPM eighth note = 0.25s
        #expect(abs(engine.delay.delayTime - 0.25) < 1e-4)
    }

    @Test func lfo2DirectFilterModulationAltersSignal() {
        var plain = SynthPreset.defaultPreset
        plain.filterCutoff = 1000
        plain.filterResonance = 0.5

        var modulated = plain
        modulated.lfo2Enabled = true
        modulated.lfo2Rate = 5.0
        modulated.lfo2Depth = 0.8
        modulated.lfo2Waveform = .sine
        modulated.lfo2Target = .filter

        let quiet = render(plain, seconds: 0.25)
        let loud = render(modulated, seconds: 0.25)
        let diff = differenceRMS(quiet, loud)
        #expect(diff > 1e-4, "LFO 2 filter modulation RMS difference: \(diff)")
    }

    @Test func lfo2MatrixRowAltersSignal() {
        var plain = SynthPreset.defaultPreset
        plain.filterCutoff = 1000
        plain.lfo2Enabled = true
        plain.lfo2Target = .none
        plain.lfo2Rate = 6.0
        plain.lfo2Depth = 1.0

        var withRow = plain
        withRow.modMatrix = [ModMatrixEntry(source: .lfo2, destination: .cutoff, amount: 0.7)]

        let quiet = render(plain, seconds: 0.25)
        let loud = render(withRow, seconds: 0.25)
        let diff = differenceRMS(quiet, loud)
        #expect(diff > 1e-4, "LFO 2 matrix cutoff RMS difference: \(diff)")
    }

    @Test func modWheelAndKeyTrackMatrixRowsAlterSignal() {
        var plain = SynthPreset.defaultPreset
        plain.filterCutoff = 1000

        var withWheel = plain
        withWheel.modMatrix = [ModMatrixEntry(source: .modWheel, destination: .cutoff, amount: 0.8)]

        var withKeyTrack = plain
        withKeyTrack.modMatrix = [ModMatrixEntry(source: .keyTrack, destination: .cutoff, amount: 0.8)]

        let ref = render(plain, seconds: 0.25)

        let wheelAudio = render(withWheel, seconds: 0.25) { engine in
            engine.modWheel(0.8)
        }
        let diffWheel = differenceRMS(ref, wheelAudio)
        #expect(diffWheel > 1e-4, "ModWheel matrix RMS difference: \(diffWheel)")

        let keyAudio = render(withKeyTrack, seconds: 0.25, midiNote: 84)
        let diffKey = differenceRMS(render(plain, seconds: 0.25, midiNote: 84), keyAudio)
        #expect(diffKey > 1e-4, "KeyTrack matrix RMS difference: \(diffKey)")
    }

    @Test func initPresetMaintainsGoldenAudioHash() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        #expect(hash == 0xd1b3635203a4799e, "Golden init hash must remain exactly bit-identical")
    }

    // MARK: - Helpers

    private func render(
        _ preset: SynthPreset,
        seconds: Double = 0.25,
        midiNote: Int = 69,
        configure: ((AudioEngine) -> Void)? = nil
    ) -> [Float] {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        configure?(engine)
        engine.noteOn(midiNote: midiNote, velocity: 0.8)
        engine.processCommandsForTesting()

        let count = Int(44100 * seconds)
        var buffer = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let (l, _) = engine.renderOneSample()
            buffer[i] = l
        }
        return buffer
    }

    private func differenceRMS(_ a: [Float], _ b: [Float]) -> Double {
        let n = min(a.count, b.count)
        guard n > 0 else { return 0 }
        var sum: Double = 0
        for i in 0..<n {
            let diff = Double(a[i] - b[i])
            sum += diff * diff
        }
        return (sum / Double(n)).squareRoot()
    }
}
