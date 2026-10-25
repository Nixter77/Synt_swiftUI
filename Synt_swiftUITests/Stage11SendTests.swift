//
//  Stage11SendTests.swift
//  Parallel send buses. Level 0 stays on the insert-chain hash.
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct Stage11SendTests {

    private func energy(_ preset: SynthPreset, samples: Int = 3000) -> Float {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.preset = preset
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        var sum: Float = 0
        for i in 0..<samples {
            if i == 1500 { engine.handleNoteOff(midiNote: 60) }
            let (l, r) = engine.renderOneSample()
            sum += abs(l) + abs(r)
        }
        return sum
    }

    @Test func sendZeroKeepsTheInitHashAndOldPresetsDecodeAtZero() throws {
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old"}"#.utf8))
        #expect(decoded.sendA == 0)
        #expect(decoded.sendB == 0)
        #expect(SynthPreset.defaultPreset.sendA == 0)
        #expect(SynthPreset.defaultPreset.sendB == 0)
        #expect(InitGoldenTests.renderHash(.defaultPreset) == 0xd1b3635203a4799e)
        #expect(FXSlotID.allCases.count == 6)
    }

    @Test func sendAboveZeroPutsEnergyOnTheBus() {
        var dry = SynthPreset.defaultPreset
        dry.reverbMix = 0
        dry.delayMix = 0
        dry.chorusMix = 0
        dry.dspReverbEnabled = false
        dry.attack = 0.01
        dry.release = 0.05
        dry.unisonVoices = 1
        var reverbSend = dry
        reverbSend.sendA = 0.85
        var delaySend = dry
        delaySend.sendB = 0.85
        delaySend.delayTime = 0.02
        delaySend.delayFeedback = 0.45

        let dryEnergy = energy(dry)
        let reverbEnergy = energy(reverbSend)
        let delayEnergy = energy(delaySend)
        #expect(dryEnergy > 1)
        #expect(abs(reverbEnergy - dryEnergy) > 0.5)
        #expect(abs(delayEnergy - dryEnergy) > 0.5)
    }

    @Test func sendRenderDoesNotAllocatePerSample() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        #expect(engine.sendReverb.isAllocated)
        var preset = SynthPreset.defaultPreset
        preset.sendA = 0.4
        preset.sendB = 0.4
        preset.reverbMix = 0
        preset.delayMix = 0
        engine.preset = preset
        engine.handleNoteOn(midiNote: 64, velocity: 1)
        let reverbID = ObjectIdentifier(engine.sendReverb)
        let delayID = ObjectIdentifier(engine.sendDelay)
        for _ in 0..<512 {
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
        }
        #expect(engine.sendReverb.isAllocated)
        #expect(ObjectIdentifier(engine.sendReverb) == reverbID)
        #expect(ObjectIdentifier(engine.sendDelay) == delayID)
    }
}
