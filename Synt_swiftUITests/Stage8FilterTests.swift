//
//  Stage8FilterTests.swift
//  Filter 2 (off by default) and the feedback NaN reset.
//

import AudioToolbox
import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage8FilterTests {

    private func render(_ mutate: (inout SynthPreset) -> Void, samples: Int) -> [Float] {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        mutate(&preset)
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.handleNoteOn(midiNote: 48, velocity: 1)
        var out: [Float] = []
        out.reserveCapacity(samples)
        for _ in 0..<samples {
            out.append(engine.renderOneSample().0)
        }
        return out
    }

    private func highFrequencyEnergy(_ samples: [Float]) -> Float {
        var energy: Float = 0
        if samples.count < 2 { return 0 }
        for i in 1..<samples.count {
            let delta = samples[i] - samples[i - 1]
            energy += delta * delta
        }
        return energy
    }

    @Test func offMatchesTheDefaultRender() throws {
        let json = #"{"name":"Old","category":"Lead"}"#
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(json.utf8))
        #expect(decoded.filter2Routing == .off)
        #expect(decoded.filter2Type == .lowPass)
        #expect(decoded.filter2Cutoff == 2000)

        let plain = render({ _ in }, samples: 700)
        let explicitOff = render({ patch in
            patch.filter2Routing = .off
            patch.filter2Type = .highPass
            patch.filter2Cutoff = 40
            patch.filter2Resonance = 1
            patch.filter2Balance = 1
        }, samples: 700)
        #expect(plain == explicitOff)
        #expect(plain.contains { $0 != 0 })
    }

    @Test func serialAndParallelChangeTheSpectrum() {
        func patch(_ routing: DualFilterRouting, _ body: inout SynthPreset) {
            body.osc2Enabled = false
            body.osc1Waveform = .sawtooth
            body.filterType = .lowPass
            body.filterCutoff = 600
            body.filterResonance = 0.15
            body.filter2Routing = routing
            body.filter2Type = .highPass
            body.filter2Cutoff = 2800
            body.filter2Resonance = 0.25
            body.filter2Balance = 1
        }
        let off = render({ patch(.off, &$0) }, samples: 2500)
        let serial = render({ patch(.serial, &$0) }, samples: 2500)
        let parallel = render({ patch(.parallel, &$0) }, samples: 2500)
        let window = 400..<2200
        let offEnergy = highFrequencyEnergy(Array(off[window]))
        let serialEnergy = highFrequencyEnergy(Array(serial[window]))
        let parallelEnergy = highFrequencyEnergy(Array(parallel[window]))
        #expect(abs(serialEnergy - parallelEnergy) > 0.01)
        #expect(abs(serialEnergy - offEnergy) > 0.01)
        #expect(abs(parallelEnergy - offEnergy) > 0.01)
        #expect(!off.contains { !$0.isFinite })
        #expect(!serial.contains { !$0.isFinite })
        #expect(!parallel.contains { !$0.isFinite })
    }

    @Test func maxResonanceStaysFinite() {
        let samples = render({ patch in
            patch.osc1Waveform = .sawtooth
            patch.osc2Enabled = false
            patch.filterType = .ladder
            patch.filterCutoff = 900
            patch.filterResonance = 1
            patch.filter2Routing = .serial
            patch.filter2Type = .ladder
            patch.filter2Cutoff = 700
            patch.filter2Resonance = 1
            patch.filter2Balance = 1
        }, samples: 22_050)
        var peak: Float = 0
        var finite = true
        for sample in samples {
            if !sample.isFinite { finite = false }
            peak = max(peak, abs(sample))
        }
        #expect(finite)
        #expect(peak <= 1)
        #expect(peak > 0)
    }

    @Test func nonFiniteFeedbackResetsTheVoiceFilter() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.filterType = .ladder
        preset.filterFeedback = 1
        preset.filterCutoff = 1200
        engine.preset = preset
        engine.prepare(sampleRate: 44_100, maxFrames: 64)
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        let index = engine.voices.firstIndex(where: \.isActive)
        #expect(index != nil)
        guard let index else { return }
        engine.voices[index].filter.y1 = 3
        engine.voices[index].filter.y2 = -2
        engine.voices[index].filterFeedbackState = .nan
        let frame = engine.renderOneSample()
        #expect(frame.0.isFinite)
        #expect(frame.1.isFinite)
        #expect(engine.voices[index].filterFeedbackState == 0)
        #expect(engine.voices[index].filter.y1 == 0)
        #expect(engine.voices[index].filter.y2 == 0)
        #expect(engine.voices[index].filter.x1 == 0)
        #expect(engine.voices[index].filter.x2 == 0)
    }

    @Test func activeNoteCopyDoesNotRetainFilterBanks() {
        let note = ActiveNote()
        let classFields = Mirror(reflecting: note).children.compactMap { child -> String? in
            Mirror(reflecting: child.value).displayStyle == .class ? (child.label ?? "?") : nil
        }
        #expect(classFields.isEmpty)
        let engine = AudioEngine()
        #expect(Mirror(reflecting: engine.voiceDual[0]).displayStyle == .class)
        #expect(Mirror(reflecting: engine.voiceFormant[0]).displayStyle == .class)
        #expect(engine.voiceDual.count == AudioEngine.maxVoices)
        #expect(engine.voiceFormant.count == AudioEngine.maxVoices)
        #expect(engine.voiceDual[0] !== engine.voiceDual[1])
        #expect(engine.voiceFormant[0] !== engine.voiceFormant[1])
        var copy = engine.voices[0]
        copy.isActive = true
        engine.voices[0] = copy
        engine.voiceFormant[0].vowel = 2.5
        #expect(engine.voiceFormant[0].vowel == 2.5)
        #expect(engine.voiceDual[0] !== engine.voiceDual[1])
    }
}

@MainActor
struct Stage8FilterUITests {
    /// Group order is not a contract (SYNT_10 appended modFollower after filter2).
    /// Addresses and identifiers are: hosts save automation by address.
    @Test func filter2GroupIsPublishedWithStableAddresses() throws {
        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        let tree = try #require(unit.parameterTree)
        let group = try #require(tree.children.first { $0.identifier == "filter2" } as? AUParameterGroup)
        let expected: [(UInt64, String)] = [
            (135, "filter2Cutoff"), (136, "filter2Resonance"), (137, "filter2Type"),
            (138, "filter2Balance"), (139, "filter2Routing"),
        ]
        #expect(group.children.compactMap { ($0 as? AUParameter)?.address }.sorted() == expected.map(\.0))
        for (address, identifier) in expected {
            let parameter = try #require(tree.parameter(withAddress: address))
            #expect(parameter.identifier == identifier)
            #expect(SynthParameterAddress(rawValue: address)?.identifier == identifier)
        }
        let routing = try #require(tree.parameter(withAddress: SynthParameterAddress.filter2Routing.rawValue))
        #expect(routing.maxValue == 2)
        let cutoff = try #require(tree.parameter(withAddress: SynthParameterAddress.filter2Cutoff.rawValue))
        #expect(cutoff.minValue == 20)
        #expect(cutoff.flags.contains(.flag_DisplayLogarithmic))
        #expect(tree.allParameters.count == SynthParameterAddress.allCases.count - 2)
    }
}
