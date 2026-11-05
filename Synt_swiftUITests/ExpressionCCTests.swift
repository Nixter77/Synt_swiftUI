//
//  ExpressionCCTests.swift
//  SYNT_65: CC7/CC11 gain, aftertouch curve, global poly aftertouch, CleanBus left alone.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct ExpressionCCTests {

    private func peakDifference(_ a: [Float], _ b: [Float]) -> Float {
        var peak: Float = 0
        let n = min(a.count, b.count)
        for i in 0..<n {
            peak = max(peak, abs(a[i] - b[i]))
        }
        return peak
    }

    private func quietPreset(flag: Bool) -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.respondToExpressionCC = flag
        preset.osc1Waveform = .sine
        preset.osc1Volume = 0.25
        preset.osc2Enabled = false
        preset.filterType = .lowPass
        preset.filterCutoff = 12000
        preset.filterResonance = 0
        preset.filterEnvelopeAmount = 0
        preset.filterDrive = 0
        preset.attack = 0.005
        preset.decay = 0.05
        preset.sustain = 1
        preset.release = 0.2
        preset.velocityToVolume = 0
        preset.masterVolume = 0.5
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.chorusMix = 0
        preset.distortionEnabled = false
        preset.distortionMix = 0
        preset.phaserEnabled = false
        preset.eqEnabled = false
        return preset
    }

    private func renderStereo(_ engine: AudioEngine, frames: Int) -> [Float] {
        var samples = [Float]()
        samples.reserveCapacity(frames * 2)
        for _ in 0..<frames {
            let (left, right) = engine.renderOneSample()
            samples.append(left)
            samples.append(right)
        }
        return samples
    }

    private func armedQuiet(flag: Bool) -> AudioEngine {
        let engine = AudioEngine()
        engine.preset = quietPreset(flag: flag)
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        return engine
    }

    private func preRMS(_ engine: AudioEngine, skip: Int, frames: Int) -> Float {
        for _ in 0..<skip { _ = engine.renderOneSample() }
        var sum = 0.0
        for _ in 0..<frames {
            _ = engine.renderOneSample()
            let left = engine.dynamicsPreCleanBusL
            let right = engine.dynamicsPreCleanBusR
            sum += Double(left * left + right * right)
        }
        return Float((sum / Double(frames * 2)).squareRoot())
    }

    @Test func controllerByteRoundTripsEveryMIDIValue() {
        for n in 0...127 {
            let value = Float(n) / 127
            #expect(AudioEngine.midiControllerByte(value) == UInt8(n))
        }
    }

    @Test func parserCommandsStayGlobalUnderMPE() {
        let volume = MIDIMessage.channelVolume(0.5, channel: 2)
        let expression = MIDIMessage.expression(0.25, channel: 3)
        #expect(AudioEngine.command(for: volume) == .setChannelVolume(0.5))
        #expect(AudioEngine.command(for: expression) == .setExpression(0.25))
        #expect(AudioEngine.command(for: expression, mpeEnabled: true, memberCount: 15) == .setExpression(0.25))
        #expect(AudioEngine.command(for: .controlChange(controller: 74, value: 10, channel: 0))
            == .controlChange(cc: 74, value: 10))
    }

    @Test func addressesAppendAfterPerVoiceCutoff() {
        #expect(SynthParameterAddress.perVoiceCutoffSources.rawValue == 188)
        #expect(SynthParameterAddress.respondToExpressionCC.rawValue == 189)
        #expect(SynthParameterAddress.aftertouchCurve.rawValue == 190)
        #expect(SynthParameterAddress.aftertouchCurve.min == -1)
        #expect(SynthParameterAddress.aftertouchCurve.max == 1)
        #expect(SynthParameterAddress.aftertouchDeadzone.rawValue == 191)
        #expect(SynthParameterAddress.aftertouchDeadzone.min == 0)
        #expect(abs(SynthParameterAddress.aftertouchDeadzone.max - 0.3) < 1e-6)
        #expect(SynthParameterAddress.allCases.last == .aftertouchDeadzone)

        var preset = SynthPreset.defaultPreset
        #expect(preset.respondToExpressionCC == false)
        #expect(preset.aftertouchCurve == 0)
        #expect(preset.aftertouchDeadzone == 0)
        preset.setParameterValue(1, for: .respondToExpressionCC)
        preset.setParameterValue(0.4, for: .aftertouchCurve)
        preset.setParameterValue(0.2, for: .aftertouchDeadzone)
        #expect(preset.respondToExpressionCC)
        #expect(preset.aftertouchCurve == 0.4)
        #expect(preset.aftertouchDeadzone == 0.2)
        #expect(preset.parameterValue(for: .respondToExpressionCC) == 1)
        preset.aftertouchCurve = 4
        preset.aftertouchDeadzone = 2
        let cleaned = preset.sanitized()
        #expect(cleaned.aftertouchCurve == 1)
        #expect(abs(cleaned.aftertouchDeadzone - 0.3) < 1e-6)
    }

    @Test func flagOffIgnoresExpressionEvenWhenTheSmootherIsNotUnity() {
        let preset = quietPreset(flag: false)
        func samples(stuck: Bool) -> [Float] {
            let engine = AudioEngine()
            engine.preset = preset
            engine.noteOn(midiNote: 60, velocity: 0.8)
            engine.processCommandsForTesting()
            if stuck {
                engine.expressionTarget = 0
                engine.expressionSmoothed = 0.15
                engine.channelVolumeTarget = 0
                engine.channelVolumeSmoothed = 0.4
            }
            return renderStereo(engine, frames: 1024)
        }
        let plain = samples(stuck: false)
        let stuck = samples(stuck: true)
        #expect(plain == stuck)

        let engine = AudioEngine()
        engine.handleCommand(.setExpression(0))
        engine.handleCommand(.setChannelVolume(0))
        #expect(engine.expressionTarget == 1)
        #expect(engine.channelVolumeTarget == 1)
    }

    @Test func gmCurveAtCC64IsAboutElevenPointNineDecibels() {
        let cc = Float(64) / 127
        let unity = armedQuiet(flag: true)
        let dipped = armedQuiet(flag: true)
        dipped.channelVolumeTarget = cc
        dipped.channelVolumeSmoothed = cc
        let both = armedQuiet(flag: true)
        both.channelVolumeTarget = cc
        both.channelVolumeSmoothed = cc
        both.expressionTarget = cc
        both.expressionSmoothed = cc

        let unityRMS = preRMS(unity, skip: 2205, frames: 4410)
        let volumeRMS = preRMS(dipped, skip: 2205, frames: 4410)
        let bothRMS = preRMS(both, skip: 2205, frames: 4410)
        #expect(unityRMS > 1e-4)
        let volumeDB = 20 * log10(volumeRMS / unityRMS)
        let expected = 40 * log10(cc)
        #expect(abs(volumeDB - expected) < 0.2, "volume \(volumeDB) dB, expected \(expected)")
        let bothDB = 20 * log10(bothRMS / unityRMS)
        let bothExpected = 80 * log10(cc)
        #expect(abs(bothDB - bothExpected) < 0.2, "product \(bothDB) dB, expected \(bothExpected)")
    }

    @Test func expressionSmoothingHasNoZipper() {
        let engine = armedQuiet(flag: true)
        let cc = Float(64) / 127
        engine.channelVolumeTarget = cc
        var previous: Float = 1
        var maxDelta: Float = 0
        let frames = 2205
        for _ in 0..<frames {
            _ = engine.renderOneSample()
            let gain = engine.channelVolumeSmoothed * engine.channelVolumeSmoothed
                * engine.expressionSmoothed * engine.expressionSmoothed
            maxDelta = max(maxDelta, abs(gain - previous))
            previous = gain
        }
        let settled = cc * cc
        let jump = 1 - settled
        #expect(maxDelta > 0)
        #expect(maxDelta < 0.02)
        #expect(maxDelta < jump * 0.05, "step \(maxDelta) vs unsmoothed \(jump)")
        #expect(abs(previous - settled) < 0.01)
    }

    @Test func clearAllMIDIResetAndPresetChangeReturnControllersToUnity() {
        let engine = AudioEngine()
        engine.channelVolumeTarget = 0.3
        engine.channelVolumeSmoothed = 0.3
        engine.expressionTarget = 0.3
        engine.expressionSmoothed = 0.3
        engine.handleCommand(.clearAll)
        #expect(engine.channelVolumeTarget == 1)
        #expect(engine.channelVolumeSmoothed == 1)
        #expect(engine.expressionTarget == 1)
        #expect(engine.expressionSmoothed == 1)

        engine.channelVolumeTarget = 0.2
        engine.channelVolumeSmoothed = 0.2
        engine.expressionTarget = 0.2
        engine.expressionSmoothed = 0.2
        engine.applyMIDIResetRT()
        #expect(engine.channelVolumeTarget == 1)
        #expect(engine.expressionSmoothed == 1)

        engine.channelVolumeTarget = 0.4
        engine.channelVolumeSmoothed = 0.4
        engine.expressionTarget = 0.4
        engine.expressionSmoothed = 0.4
        engine.preset = SynthPreset(name: "SYNT65 Other")
        engine.processCommandsForTesting()
        #expect(engine.channelVolumeTarget == 1)
        #expect(engine.channelVolumeSmoothed == 1)
        #expect(engine.expressionTarget == 1)
        #expect(engine.expressionSmoothed == 1)
    }

    @Test func ccLearnBeatsNativeVolume() {
        let engine = AudioEngine()
        var preset = engine.preset
        preset.respondToExpressionCC = true
        engine.preset = preset
        engine.processCommandsForTesting()
        engine.updateRTMappings([11: .cutoff])
        engine.setCCCaught(11)
        let before = engine.cachedFilterCutoff
        engine.handleCommand(.setExpression(0))
        #expect(engine.expressionTarget == 1)
        #expect(engine.expressionSmoothed == 1)
        #expect(abs(engine.cachedFilterCutoff - 20) < 0.05)
        #expect(before > 100)

        engine.updateRTMappings([:])
        engine.handleCommand(.setExpression(Float(64) / 127))
        #expect(abs(engine.expressionTarget - Float(64) / 127) < 1e-6)
    }

    @Test func aftertouchCurveAndDeadzone() {
        let engine = AudioEngine()
        #expect(engine.shapeAftertouch(0.4) == 0.4)
        #expect(engine.advanceAftertouch() == 0)

        engine.cachedAftertouchDeadzone = 0.2
        #expect(engine.shapeAftertouch(0.2) == 0)
        #expect(abs(engine.shapeAftertouch(0.6) - 0.5) < 1e-5)

        engine.cachedAftertouchDeadzone = 0
        engine.cachedAftertouchCurve = 1
        let lifted = engine.shapeAftertouch(0.5)
        #expect(lifted > 0.5)
        #expect(abs(lifted - pow(0.5, exp2(-3))) < 1e-5)
        engine.cachedAftertouchCurve = -1
        #expect(abs(engine.shapeAftertouch(0.5) - pow(0.5, 8)) < 1e-5)

        engine.cachedAftertouchCurve = 0
        engine.aftertouchTarget = 0.5
        engine.aftertouchSmoothed = 0.5
        #expect(engine.advanceAftertouch() == 0.5)
        engine.cachedAftertouchCurve = 1
        let bent = engine.advanceAftertouch()
        #expect(abs(bent - lifted) < 1e-5)
    }

    @Test func globalCutoffHearsPolyAftertouchOfThePolicyVoice() {
        func render(policy: GlobalVoiceSourcePolicy, poly: Float, channel: Float, deadzone: Float = 0) -> [Float] {
            let engine = AudioEngine()
            var preset = SynthPreset.defaultPreset
            preset.osc2Enabled = false
            preset.filterType = .lowPass
            preset.filterCutoff = 400
            preset.filterResonance = 0.1
            preset.filterEnvelopeAmount = 0
            preset.attack = 0.01
            preset.sustain = 1
            preset.globalVoiceSourcePolicy = policy
            preset.aftertouchDeadzone = deadzone
            preset.modMatrix = [PresetAuthoring.mod(.aftertouch, .cutoff, 0.8)]
            engine.preset = preset
            engine.noteOn(midiNote: 60, velocity: 0.9)
            engine.processCommandsForTesting()
            if poly > 0 {
                _ = engine.commandQueue.push(.setPolyAftertouch(midiNote: 60, pressure: poly))
                engine.processCommandsForTesting()
            }
            engine.aftertouchTarget = channel
            engine.aftertouchSmoothed = channel
            return renderStereo(engine, frames: 1200)
        }

        let dry = render(policy: .loudest, poly: 0, channel: 0)
        for policy in GlobalVoiceSourcePolicy.allCases {
            let poly = render(policy: policy, poly: 1, channel: 0)
            #expect(peakDifference(dry, poly) > 0.02, "poly missed \(policy)")
            let channel = render(policy: policy, poly: 0, channel: 1)
            #expect(peakDifference(dry, channel) > 0.02, "channel missed \(policy)")
        }
        let buried = render(policy: .loudest, poly: 0.15, channel: 0, deadzone: 0.3)
        #expect(peakDifference(dry, buried) == 0)

        let straight = render(policy: .loudest, poly: 0, channel: 0.45)
        let engine = AudioEngine()
        engine.preset = {
            var preset = SynthPreset.defaultPreset
            preset.osc2Enabled = false
            preset.filterType = .lowPass
            preset.filterCutoff = 400
            preset.filterResonance = 0.1
            preset.filterEnvelopeAmount = 0
            preset.attack = 0.01
            preset.sustain = 1
            preset.aftertouchCurve = 0
            preset.aftertouchDeadzone = 0
            preset.modMatrix = [PresetAuthoring.mod(.aftertouch, .cutoff, 0.8)]
            return preset
        }()
        engine.noteOn(midiNote: 60, velocity: 0.9)
        engine.processCommandsForTesting()
        engine.aftertouchTarget = 0.45
        engine.aftertouchSmoothed = 0.45
        #expect(renderStereo(engine, frames: 1200) == straight)

        let untouched = AudioEngine()
        _ = untouched.commandQueue.push(.setAftertouch(0.25))
        untouched.processCommandQueue()
        _ = untouched.commandQueue.push(.setPolyAftertouch(midiNote: 60, pressure: 1))
        untouched.processCommandQueue()
        #expect(untouched.aftertouchTarget == 0.25)
    }

    @Test func cleanBusThresholdStaysAndInitChordContrastSurvives() {
        #expect(AudioMath.cleanBusThreshold == 0.50)
        let engine = AudioEngine()
        let notes = [48, 52, 55, 60]
        let soft = DynamicsProbe.render(
            engine: engine,
            notes: notes.map { ($0, DynamicsProbe.midi(40)) }
        )
        let hard = DynamicsProbe.render(
            engine: engine,
            notes: notes.map { ($0, DynamicsProbe.midi(120)) }
        )
        #expect(!soft.nonFinite)
        #expect(!hard.nonFinite)
        let pre = DynamicsProbe.dbfs(hard.preRMS) - DynamicsProbe.dbfs(soft.preRMS)
        let post = DynamicsProbe.dbfs(hard.postRMS) - DynamicsProbe.dbfs(soft.postRMS)
        #expect(pre > 5, "pre contrast \(pre)")
        #expect(post / pre >= 0.7, "post/pre \(post / pre) pre \(pre) post \(post)")
    }
}
