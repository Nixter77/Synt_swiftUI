//
//  ModMatrixTests.swift
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct ModMatrixTests {

    @Test func formatAmountShowsSignAndUnits() {
        #expect(ModDestination.pitch1.formatAmount(0.5) == "+0.50 oct")
        #expect(ModDestination.pitch2.formatAmount(-0.25).hasPrefix("-"))
        #expect(ModDestination.cutoff.formatAmount(0.5) == "+2.0 oct")
        #expect(ModDestination.amp.formatAmount(0.25) == "+25 %")
        #expect(ModDestination.resonance.formatAmount(-0.1).contains("%"))
        #expect(ModDestination.pan.formatAmount(0.3) == "R 30 %")
        #expect(ModDestination.pan.formatAmount(-0.3) == "L 30 %")
        #expect(ModDestination.lfoRate.formatAmount(0.24).contains("rate"))
        #expect(ModDestination.pwm1.formatAmount(0.25).contains("%"))
        #expect(ModDestination.mix.formatAmount(-0.5).hasPrefix("-"))
        #expect(ModDestination.lfoDepth.formatAmount(0.25) == "+25 %")
        #expect(PresetAuthoring.liveDestinations == Set(ModDestination.allCases))
    }

    @Test func everyDestinationChangesTheSignal() {
        for dest in ModDestination.allCases {
            let quiet = renderPair(destination: dest, amount: 0)
            let loud = renderPair(destination: dest, amount: 0.8)
            let rms = differenceRMS(quiet.mono, loud.mono)
            #expect(rms > 1e-4, "\(dest.rawValue) rms \(rms)")
        }
    }

    @Test func pitchCutoffAndPanMoveInTheExpectedDirection() {
        let still = renderPair(destination: .pitch1, amount: 0)
        let up = renderPair(destination: .pitch1, amount: 0.8)
        #expect(zeroRate(up.mono) > zeroRate(still.mono))

        let dark = renderPair(destination: .cutoff, amount: -0.8)
        let bright = renderPair(destination: .cutoff, amount: 0.8)
        #expect(centroid(bright.mono) > centroid(dark.mono))

        let left = renderPair(destination: .pan, amount: -0.8)
        let right = renderPair(destination: .pan, amount: 0.8)
        #expect(sideEnergy(left) < sideEnergy(right))
    }

    @Test func allPairsStayFiniteUnderTheCeiling() {
        for source in ModSource.allCases {
            for dest in ModDestination.allCases {
                let audio = renderPair(destination: dest, amount: 0.8, source: source, seconds: 0.12)
                var maxAbs: Float = 0
                for i in 0..<audio.mono.count {
                    let l = audio.mono[i]
                    let r = audio.right[i]
                    #expect(l.isFinite && r.isFinite, "\(source) \(dest)")
                    maxAbs = max(maxAbs, abs(l), abs(r))
                }
                #expect(maxAbs <= 1, "\(source.rawValue) \(dest.rawValue) peak \(maxAbs)")
            }
        }
    }

    @Test func lfoOffStillModulatesCutoffWithoutTheDirectTarget() {
        var withRow = SynthPreset.defaultPreset
        withRow.lfoEnabled = false
        withRow.lfoTarget = .none
        withRow.lfoDepth = 1
        withRow.lfoRate = 6
        withRow.modMatrix = [ModMatrixEntry(source: .lfo1, destination: .cutoff, amount: 0.8)]

        var plain = withRow
        plain.modMatrix = []

        var direct = withRow
        direct.lfoTarget = .filter
        direct.modMatrix = []

        let modulated = render(withRow)
        let silent = render(plain)
        let filterTarget = render(direct)
        #expect(differenceRMS(modulated.mono, silent.mono) > 1e-4)
        #expect(differenceRMS(filterTarget.mono, silent.mono) < 1e-6)
    }

    /// The render must not borrow `filterL.resonance` (main owns it), or a knob
    /// move landing mid-sample would be overwritten by a stale restore.
    @Test func resonanceRowNeverWritesTheSharedField() throws {
        let render = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Synt_swiftUI/Audio/AudioEngine+Render.swift")
        let text = try String(contentsOf: render, encoding: .utf8)
        #expect(!text.contains("filterL.resonance ="))

        var preset = SynthPreset.defaultPreset
        preset.filterCutoff = 900
        preset.filterResonance = 0.35
        preset.modMatrix = [ModMatrixEntry(source: .velocity, destination: .resonance, amount: 0.8)]
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 69, velocity: 0.8)
        engine.processCommandsForTesting()
        _ = engine.renderFramesForTesting(256)
        #expect(engine.filterL.resonance == 0.35)
        engine.filterL.resonance = 0.6          // what applyPreset does on main
        _ = engine.renderFramesForTesting(256)
        #expect(engine.filterL.resonance == 0.6)
    }

    @Test func initHashStaysTheGolden() {
        #expect(InitGoldenTests.renderHash(.defaultPreset) == 0xd1b3635203a4799e)
    }

    private func renderPair(
        destination: ModDestination,
        amount: Float,
        source: ModSource = .velocity,
        seconds: Double = 0.5
    ) -> (mono: [Float], right: [Float]) {
        var preset = SynthPreset.defaultPreset
        preset.modMatrix = [ModMatrixEntry(source: source, destination: destination, amount: amount)]
        if destination == .pwm1 || destination == .pwm2 {
            preset.osc1Waveform = .square
            preset.osc2Waveform = .square
            preset.osc1PulseWidth = 0.5
            preset.osc2PulseWidth = 0.5
        }
        if destination == .lfoRate || destination == .lfoDepth || source == .lfo1 {
            preset.lfoEnabled = true
            preset.lfoTarget = destination == .lfoRate || destination == .lfoDepth ? .pitch : .none
            // Depth starts below the ceiling so a positive row can still raise it.
            preset.lfoDepth = destination == .lfoDepth ? 0.2 : 1
            preset.lfoRate = 5
            preset.lfoWaveform = .sine
        }
        if destination == .cutoff || destination == .resonance {
            preset.filterCutoff = 900
            preset.filterResonance = 0.35
        }
        return render(preset, seconds: seconds)
    }

    private func render(_ preset: SynthPreset, seconds: Double = 0.5) -> (mono: [Float], right: [Float]) {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 69, velocity: 0.8)
        engine.processCommandsForTesting()
        let count = Int(44100 * seconds)
        var left = [Float](repeating: 0, count: count)
        var right = [Float](repeating: 0, count: count)
        for i in 0..<count {
            let sample = engine.renderOneSample()
            left[i] = sample.0
            right[i] = sample.1
        }
        return (left, right)
    }

    private func differenceRMS(_ a: [Float], _ b: [Float]) -> Double {
        let n = min(a.count, b.count)
        var acc = 0.0
        for i in 0..<n {
            let d = Double(a[i] - b[i])
            acc += d * d
        }
        return (acc / Double(max(n, 1))).squareRoot()
    }

    private func zeroRate(_ samples: [Float]) -> Double {
        var crossings = 0
        for i in 1..<samples.count where samples[i - 1] <= 0 && samples[i] > 0 {
            crossings += 1
        }
        return Double(crossings) / Double(samples.count) * 44100
    }

    private func centroid(_ samples: [Float]) -> Double {
        let n = min(1024, samples.count)
        var num = 0.0
        var den = 0.0
        for k in 1..<128 {
            var re = 0.0
            var im = 0.0
            let w = 2 * Double.pi * Double(k) / Double(n)
            for i in 0..<n {
                let s = Double(samples[i])
                re += s * cos(w * Double(i))
                im -= s * sin(w * Double(i))
            }
            let mag = (re * re + im * im).squareRoot()
            let freq = Double(k) * 44100 / Double(n)
            num += freq * mag
            den += mag
        }
        return den > 0 ? num / den : 0
    }

    private func sideEnergy(_ audio: (mono: [Float], right: [Float])) -> Double {
        var left = 0.0
        var right = 0.0
        for i in 0..<audio.mono.count {
            left += Double(audio.mono[i] * audio.mono[i])
            right += Double(audio.right[i] * audio.right[i])
        }
        let total = left + right
        return total > 0 ? (right - left) / total : 0
    }
}
