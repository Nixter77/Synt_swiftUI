import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@Suite struct Stage11RotaryTests {
    @Test func rotaryOffKeepsTheInitHashAndOldPresetsStayOff() throws {
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old"}"#.utf8))
        #expect(decoded.rotaryEnabled == false)
        #expect(decoded.rotaryFast == false)
        #expect(decoded.rotaryMix == 1)
        #expect(SynthPreset.defaultPreset.rotaryEnabled == false)
        #expect(InitGoldenTests.renderHash(.defaultPreset) == 0xd1b3635203a4799e)
        #expect(FXSlotID.allCases.count == 6)
        #expect(SynthParameterAddress.rotaryEnabled.rawValue == 144)
        #expect(SynthParameterAddress.rotaryAccel.rawValue == 152)
    }

    @Test func rotaryOnStaysFiniteAndSeparatesTheSides() {
        var preset = SynthPreset.defaultPreset
        preset.rotaryEnabled = true
        preset.rotaryFast = true
        preset.rotaryMix = 1
        preset.rotaryDrive = 0.4
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.chorusMix = 0
        preset.dspReverbEnabled = false
        preset.attack = 0.01
        preset.release = 0.08
        preset.unisonVoices = 1
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 256)
        engine.preset = preset
        engine.handleNoteOn(midiNote: 60, velocity: 1)
        let rotaryID = ObjectIdentifier(engine.rotary)
        var diff: Float = 0
        var energy: Float = 0
        for i in 0..<3000 {
            if i == 1800 { engine.handleNoteOff(midiNote: 60) }
            let (l, r) = engine.renderOneSample()
            #expect(l.isFinite && r.isFinite)
            if l != 0 { #expect(abs(l) >= Float.leastNormalMagnitude) }
            if r != 0 { #expect(abs(r) >= Float.leastNormalMagnitude) }
            diff += abs(l - r)
            energy += abs(l) + abs(r)
        }
        #expect(energy > 1)
        #expect(diff > 0.5)
        #expect(ObjectIdentifier(engine.rotary) == rotaryID)
    }
}
