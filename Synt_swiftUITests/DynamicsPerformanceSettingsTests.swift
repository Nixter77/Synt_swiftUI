//
//  DynamicsPerformanceSettingsTests.swift
//  SYNT_67: touch curve, global CC7/CC11, live velocity atomics, fullState keys.
//

import CoreAudioKit
import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct DynamicsPerformanceSettingsTests {

    @Test func normalTouchIsBitExactIdentity() {
        let samples: [Float] = [0, 0.25, 0.8, 1, -0.2, 1.5]
        for sample in samples {
            let shaped = KeyboardTouch.normal.shape(sample)
            #expect(shaped.bitPattern == sample.bitPattern)
        }
        #expect(KeyboardTouch.light.shape(0.25) == 0.5)
        #expect(KeyboardTouch.heavy.shape(0.25) == 0.0625)
        #expect(KeyboardTouch.light.shape(0.25) > 0.25)
        #expect(KeyboardTouch.heavy.shape(0.25) < 0.25)
        for touch in KeyboardTouch.allCases {
            #expect(touch.shape(0) == 0)
            #expect(touch.shape(1) == 1)
        }
    }

    @Test func explicitNormalMatchesTheDefaultRender() {
        #expect(renderChord(setNormal: false) == renderChord(setNormal: true))
    }

    @Test func lightIsLouderThanNormalAndHeavyIsQuieter() {
        let light = sustainedLevel(touch: .light)
        let normal = sustainedLevel(touch: .normal)
        let heavy = sustainedLevel(touch: .heavy)
        #expect(light > normal)
        #expect(normal > heavy)
        #expect(light > 1e-4)
    }

    @Test func globalExpressionOffLeavesTheFlagOffBranchAlone() {
        let plain = renderWithStuckExpression(assignGlobalOff: false)
        let assigned = renderWithStuckExpression(assignGlobalOff: true)
        #expect(plain == assigned)

        let engine = AudioEngine()
        #expect(engine.globalExpressionCC == false)
        #expect(engine.cachedGlobalExpressionCC == false)
        engine.handleCommand(.setChannelVolume(0))
        engine.handleCommand(.setExpression(0))
        #expect(engine.channelVolumeTarget == 1)
        #expect(engine.expressionTarget == 1)
    }

    @Test func globalExpressionOnFollowsCC64() {
        let cc = Float(64) / 127
        let unity = armedQuiet(global: false)
        let dipped = armedQuiet(global: true)
        dipped.handleCommand(.setChannelVolume(cc))
        #expect(abs(dipped.channelVolumeTarget - cc) < 1e-6)
        let unityRMS = preRMS(unity)
        let dippedRMS = preRMS(dipped)
        #expect(unityRMS > 1e-4)
        let db = 20 * log10(dippedRMS / unityRMS)
        let expected = 40 * log10(cc)
        #expect(abs(db - expected) < 0.2, "global CC64 \(db) dB, expected \(expected)")
    }

    @Test func playedAndRawVelocitiesLandOnTheAtomics() {
        let engine = AudioEngine()
        engine.keyboardTouch = .light
        engine.noteOn(midiNote: 60, velocity: 0.25)
        engine.processCommandsForTesting()
        let meters = engine.meteringStateForTesting
        #expect(meters.getInputVelocity() == 0.25)
        #expect(meters.getPlayedVelocity() == 0.5)

        engine.keyboardTouch = .heavy
        engine.noteOn(midiNote: 64, velocity: 0.25)
        engine.processCommandsForTesting()
        #expect(meters.getInputVelocity() == 0.25)
        #expect(meters.getPlayedVelocity() == 0.0625)

        engine.noteOff(midiNote: 60, releaseVelocity: 0.2)
        engine.processCommandsForTesting()
        #expect(meters.getReleaseVelocity() == 0.2)

        engine.aftertouch(0.7)
        engine.processCommandsForTesting()
        #expect(meters.getAftertouch() == 0.7)
        engine.polyAftertouch(midiNote: 64, pressure: 0.3)
        engine.processCommandsForTesting()
        #expect(meters.getAftertouch() == 0.3)

        var arp = quietPreset()
        arp.arpMode = .up
        let arped = AudioEngine()
        arped.preset = arp
        arped.noteOn(midiNote: 67, velocity: 0.36)
        arped.processCommandsForTesting()
        #expect(arped.meteringStateForTesting.getInputVelocity() == 0.36)
    }

    @Test func engineEditsDoNotWriteUserDefaults() {
        let touchKey = PerformanceSettings.touchDefaultsKey
        let exprKey = PerformanceSettings.expressionDefaultsKey
        let touchBefore = storedInteger(touchKey)
        let exprBefore = UserDefaults.standard.object(forKey: exprKey) as? Bool
        let engine = AudioEngine()
        engine.keyboardTouch = .light
        engine.globalExpressionCC = true
        #expect(storedInteger(touchKey) == touchBefore)
        #expect(UserDefaults.standard.object(forKey: exprKey) as? Bool == exprBefore)
    }

    @Test func missingTouchDefaultIsNormalNotLight() {
        let touchKey = PerformanceSettings.touchDefaultsKey
        let exprKey = PerformanceSettings.expressionDefaultsKey
        let touchBefore = UserDefaults.standard.object(forKey: touchKey)
        let exprBefore = UserDefaults.standard.object(forKey: exprKey)
        defer {
            restore(touchKey, touchBefore)
            restore(exprKey, exprBefore)
        }
        UserDefaults.standard.removeObject(forKey: touchKey)
        UserDefaults.standard.removeObject(forKey: exprKey)
        #expect(PerformanceSettings.storedTouch() == .normal)
        #expect(PerformanceSettings.storedExpression() == false)
        UserDefaults.standard.set(KeyboardTouch.light.rawValue, forKey: touchKey)
        #expect(PerformanceSettings.storedTouch() == .light)
        UserDefaults.standard.set(99, forKey: touchKey)
        #expect(PerformanceSettings.storedTouch() == .normal)
        UserDefaults.standard.set(true, forKey: exprKey)
        #expect(PerformanceSettings.storedExpression() == true)
    }

    @Test func performanceKeysRoundTripAndMissingKeysStay() throws {
        let touchKey = PerformanceSettings.touchDefaultsKey
        let exprKey = PerformanceSettings.expressionDefaultsKey
        let touchBefore = UserDefaults.standard.object(forKey: touchKey)
        let exprBefore = UserDefaults.standard.object(forKey: exprKey)
        defer {
            restore(touchKey, touchBefore)
            restore(exprKey, exprBefore)
        }

        let description = AudioComponentDescription(
            componentType: kAudioUnitType_MusicDevice,
            componentSubType: 0x5379_6E74,
            componentManufacturer: 0x4E69_7872,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        let unit = try SyntAudioUnit(componentDescription: description)
        #expect(unit.keyboardTouch == .normal)
        #expect(!unit.globalExpressionCC)
        #expect(SyntAudioUnit.stateVersion == 1)
        #expect(SynthParameterAddress.allCases.last == .aftertouchDeadzone)
        #expect(SynthParameterAddress.aftertouchDeadzone.rawValue == 191)

        unit.keyboardTouch = .heavy
        unit.globalExpressionCC = true
        let saved = try #require(unit.fullState)
        #expect(saved[PerformanceSettings.touchStateKey] as? Int == KeyboardTouch.heavy.rawValue)
        #expect(saved[PerformanceSettings.expressionStateKey] as? Bool == true)

        let other = try SyntAudioUnit(componentDescription: description)
        let touchStored = storedInteger(touchKey)
        other.fullState = saved
        #expect(storedInteger(touchKey) == touchStored, "the test host must not persist touch")
        #expect(other.keyboardTouch == .heavy)
        #expect(other.globalExpressionCC)
        #expect(other.engine.cachedGlobalExpressionCC)

        other.keyboardTouch = .light
        other.globalExpressionCC = false
        var stripped = saved
        stripped.removeValue(forKey: PerformanceSettings.touchStateKey)
        stripped.removeValue(forKey: PerformanceSettings.expressionStateKey)
        other.fullState = stripped
        #expect(other.keyboardTouch == .light)
        #expect(!other.globalExpressionCC)
    }

    private func quietPreset() -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .sine
        preset.osc1Volume = 0.4
        preset.osc2Enabled = false
        preset.filterType = .lowPass
        preset.filterCutoff = 12000
        preset.filterResonance = 0
        preset.filterEnvelopeAmount = 0
        preset.filterDrive = 0
        preset.attack = 0.005
        preset.decay = 0.05
        preset.sustain = 1
        preset.release = 0.3
        preset.velocityCurve = .linear
        preset.velocityToVolume = 1
        preset.velocityRangeDb = 0
        preset.masterVolume = 0.5
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.chorusMix = 0
        preset.distortionEnabled = false
        preset.distortionMix = 0
        preset.phaserEnabled = false
        preset.eqEnabled = false
        preset.respondToExpressionCC = false
        return preset
    }

    private func renderChord(setNormal: Bool) -> [Float] {
        let engine = AudioEngine()
        if setNormal { engine.keyboardTouch = .normal }
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        engine.noteOn(midiNote: 64, velocity: 0.7)
        engine.processCommandsForTesting()
        var samples = [Float]()
        samples.reserveCapacity(2048)
        for _ in 0..<1024 {
            let (left, right) = engine.renderOneSample()
            samples.append(left)
            samples.append(right)
        }
        return samples
    }

    private func sustainedLevel(touch: KeyboardTouch) -> Float {
        let engine = AudioEngine()
        engine.keyboardTouch = touch
        engine.preset = quietPreset()
        engine.noteOn(midiNote: 60, velocity: 0.25)
        engine.processCommandsForTesting()
        return preRMS(engine)
    }

    private func armedQuiet(global: Bool) -> AudioEngine {
        let engine = AudioEngine()
        engine.globalExpressionCC = global
        engine.preset = quietPreset()
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        return engine
    }

    private func renderWithStuckExpression(assignGlobalOff: Bool) -> [Float] {
        let engine = AudioEngine()
        engine.preset = quietPreset()
        if assignGlobalOff { engine.globalExpressionCC = false }
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        engine.expressionTarget = 0
        engine.expressionSmoothed = 0.15
        engine.channelVolumeTarget = 0
        engine.channelVolumeSmoothed = 0.4
        var samples = [Float]()
        samples.reserveCapacity(512)
        for _ in 0..<256 {
            let (left, right) = engine.renderOneSample()
            samples.append(left)
            samples.append(right)
        }
        return samples
    }

    private func preRMS(_ engine: AudioEngine) -> Float {
        for _ in 0..<2205 { _ = engine.renderOneSample() }
        var sum = 0.0
        for _ in 0..<4410 {
            _ = engine.renderOneSample()
            let left = engine.dynamicsPreCleanBusL
            let right = engine.dynamicsPreCleanBusR
            sum += Double(left * left + right * right)
        }
        return Float((sum / Double(4410 * 2)).squareRoot())
    }

    private func storedInteger(_ key: String) -> Int? {
        guard UserDefaults.standard.object(forKey: key) != nil else { return nil }
        return UserDefaults.standard.integer(forKey: key)
    }

    private func restore(_ key: String, _ previous: Any?) {
        if let previous {
            UserDefaults.standard.set(previous, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
