//
//  VelocityDecibelCurveTests.swift
//  SYNT_62 D1.2, D1.4–D1.6: decibel velocity, release velocity, arp and legato flags.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct VelocityDecibelCurveTests {
    @Test func addressesStayAppendOnlyAfterMPE() {
        #expect(SynthParameterAddress.mpeMemberChannelCount.rawValue == 166)
        #expect(SynthParameterAddress.velocityRangeDb.rawValue == 167)
        #expect(SynthParameterAddress.velocityCurveShape.rawValue == 168)
        #expect(SynthParameterAddress.globalVoiceSourcePolicy.rawValue == 169)
        #expect(SynthParameterAddress.arpUsesInputVelocity.rawValue == 170)
        #expect(SynthParameterAddress.legatoUpdatesVelocity.rawValue == 171)
        #expect(SynthParameterAddress.velocityCurve.max == 3)
        #expect(SynthParameterAddress.velocityRangeDb.max == 60)
        #expect(SynthParameterAddress.velocityCurveShape.min == -1)
        #expect(SynthParameterAddress.velocityCurveShape.max == 1)
        #expect(velocityCurveFromFloat(3) == .decibel)
        #expect(velocityCurveFromFloat(4) == .linear)
        #expect(globalVoiceSourceFromFloat(0) == .loudest)
    }

    @Test func legacyCurvesIgnoreRangeAndShape() {
        for curve: VelocityCurve in [.linear, .exponential, .logarithmic] {
            for velocity: Float in [0, 0.2, 0.8, 1] {
                let plain = AudioEngine.legacyVelocityGain(velocity: velocity, curve: curve, toVolume: 1)
                let withRange = AudioEngine.legacyVelocityGain(
                    velocity: velocity, curve: curve, toVolume: 1, rangeDb: 40, curveShape: 1
                )
                #expect(plain.bitPattern == withRange.bitPattern)
            }
        }
    }

    @Test func decibelRangeZeroIsUnityAndFortyDbSpansTheEnds() {
        for velocity: Float in [0, 0.01, 0.5, 1] {
            let unity = AudioEngine.legacyVelocityGain(
                velocity: velocity, curve: .decibel, toVolume: 1, rangeDb: 0, curveShape: 0.7
            )
            #expect(abs(unity - 1) < 1e-5)
        }
        let quiet = AudioEngine.legacyVelocityGain(
            velocity: 0, curve: .decibel, toVolume: 1, rangeDb: 40, curveShape: 0
        )
        let loud = AudioEngine.legacyVelocityGain(
            velocity: 1, curve: .decibel, toVolume: 1, rangeDb: 40, curveShape: 0
        )
        #expect(abs(loud - 1) < 1e-5)
        #expect(abs(quiet - 0.01) < 1e-4)
        let span = 20 * log10(loud / quiet)
        #expect(abs(span - 40) <= 1)

        let midi1 = Float(1) / 127
        let soft = AudioEngine.legacyVelocityGain(
            velocity: midi1, curve: .decibel, toVolume: 1, rangeDb: 40, curveShape: 0
        )
        let midiSpan = 20 * log10(1 / soft)
        #expect(abs(midiSpan - 40 * (1 - midi1)) < 0.02)
        #expect(abs(midiSpan - 39.69) < 0.05)
    }

    @Test func decibelShapeIsMonotonicAndExpIsQuieterInTheMiddle() {
        let mid: Float = 0.5
        let lin = AudioEngine.decibelVelocityShape(mid, curveShape: 0)
        let expShape = AudioEngine.decibelVelocityShape(mid, curveShape: 1)
        let logShape = AudioEngine.decibelVelocityShape(mid, curveShape: -1)
        #expect(abs(lin - 0.5) < 1e-6)
        #expect(abs(expShape - pow(0.5, 8)) < 1e-5)
        #expect(logShape > lin)
        #expect(expShape < lin)

        let steps: [Float] = [0, 1, 16, 32, 48, 64, 80, 96, 112, 127].map { $0 / 127 }
        var previous: Float = -1
        for step in steps {
            let gain = AudioEngine.legacyVelocityGain(
                velocity: step, curve: .decibel, toVolume: 1, rangeDb: 40, curveShape: 0.4
            )
            #expect(gain + 1e-5 >= previous)
            previous = gain
        }
    }

    @Test func noteOnStoresDecibelGainAndTargetMatches() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.velocityCurve = .decibel
        preset.velocityRangeDb = 40
        preset.velocityCurveShape = 0
        preset.velocityToVolume = 1
        preset.arpMode = .off
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0)
        engine.processCommandsForTesting()
        let voice = engine.voices.first { $0.isActive }
        let expected = AudioEngine.legacyVelocityGain(
            velocity: 0, curve: .decibel, toVolume: 1, rangeDb: 40, curveShape: 0
        )
        #expect(abs((voice?.velGain ?? -1) - expected) < 1e-5)
        #expect(voice?.velGain == voice?.velGainTarget)
    }

    @Test func releaseVelocityReachesTheVoiceAndTheMatrix() {
        let engine = AudioEngine()
        engine.handleCommand(.keyDown(midiNote: 60, velocity: 0.8))
        for _ in 0..<200 { _ = engine.renderOneSample() }
        engine.handleCommand(.keyUp(midiNote: 60, releaseVelocity: 0.25))
        let voice = engine.voices.first { $0.isActive && $0.midiNote == 60 }
        #expect(abs((voice?.releaseVelocity ?? -1) - 0.25) < 1e-6)
        let src = engine.matrixSource(
            .releaseVelocity,
            lfo: 0, lfo2: 0, env: 0, velocity: 0, modWheel: 0, keyTrack: 0,
            releaseVelocity: voice?.releaseVelocity ?? 0
        )
        #expect(abs(src - 0.25) < 1e-6)
        _ = engine.renderOneSample()
        let after = engine.voices.first { $0.isActive && $0.midiNote == 60 }
        #expect(abs((after?.releaseVelocity ?? -1) - 0.25) < 1e-6)
    }

    @Test func arpFlagOffKeepsPointEightAndFlagOnUsesTheKey() {
        let engine = AudioEngine()
        engine.cachedArpMode = .up
        engine.handleCommand(.keyDown(midiNote: 60, velocity: 0.22))
        engine.handleArpTick(stepDuration: 1000)
        let legacy = engine.voices.first { $0.isActive && !$0.isReleasing }
        #expect(abs((legacy?.velocity ?? -1) - 0.8) < 1e-6)

        engine.cachedArpUsesInputVelocity = true
        engine.handleCommand(.keyDown(midiNote: 60, velocity: 0.35))
        engine.handleArpTick(stepDuration: 1000)
        let voiced = engine.voices.first { $0.isActive && !$0.isReleasing }
        #expect(abs((voiced?.velocity ?? -1) - 0.35) < 1e-6)
    }

    @Test func legatoFlagOffLeavesVelocityAndFlagOnGlidesGain() {
        let engine = AudioEngine()
        engine.cachedVoiceMode = .legato
        engine.cachedLegatoUpdatesVelocity = false
        engine.handleCommand(.noteOn(midiNote: 60, velocity: 0.4))
        engine.handleCommand(.noteOn(midiNote: 64, velocity: 0.9))
        let held = engine.voices.first { $0.isActive && !$0.isReleasing }
        #expect(abs((held?.velocity ?? -1) - 0.4) < 1e-6)
        #expect(held?.velGain == held?.velGainTarget)
        let before = held?.velGain ?? -1

        engine.cachedLegatoUpdatesVelocity = true
        engine.handleCommand(.noteOn(midiNote: 67, velocity: 0.2))
        let retuned = engine.voices.first { $0.isActive && !$0.isReleasing }
        #expect(abs((retuned?.velocity ?? -1) - 0.2) < 1e-6)
        #expect(abs((retuned?.velGain ?? -1) - before) < 1e-6)
        #expect(retuned?.velGain != retuned?.velGainTarget)

        _ = engine.renderOneSample()
        let moved = engine.voices.first { $0.isActive && !$0.isReleasing }
        let gain = moved?.velGain ?? -1
        let target = moved?.velGainTarget ?? -1
        #expect(gain < before)
        #expect(gain > target)
    }

    @Test func lastTriggeredSlotFollowsTheNewestNote() {
        let engine = AudioEngine()
        #expect(engine.cachedGlobalVoiceSourcePolicy == .loudest)
        engine.handleCommand(.noteOn(midiNote: 60, velocity: 0.4))
        engine.handleCommand(.noteOn(midiNote: 76, velocity: 0.9))
        let slot = engine.lastTriggeredSlot
        #expect(slot >= 0)
        #expect(engine.voices[slot].midiNote == 76)
        #expect(engine.voices[slot].isActive)
    }

    @Test func missingKeysDecodeAsInert() throws {
        let old = Data(#"{"name":"Old"}"#.utf8)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: old)
        #expect(decoded.velocityCurve == .linear)
        #expect(decoded.velocityRangeDb == 0)
        #expect(decoded.velocityCurveShape == 0)
        #expect(decoded.globalVoiceSourcePolicy == .loudest)
        #expect(decoded.arpUsesInputVelocity == false)
        #expect(decoded.legatoUpdatesVelocity == false)

        var preset = SynthPreset.defaultPreset
        preset.velocityCurve = .decibel
        preset.velocityRangeDb = 36
        preset.velocityCurveShape = 0.25
        preset.globalVoiceSourcePolicy = .highest
        preset.arpUsesInputVelocity = true
        preset.legatoUpdatesVelocity = true
        let back = try JSONDecoder().decode(SynthPreset.self, from: JSONEncoder().encode(preset))
        #expect(back.velocityCurve == .decibel)
        #expect(abs(back.velocityRangeDb - 36) < 1e-5)
        #expect(abs(back.velocityCurveShape - 0.25) < 1e-5)
        #expect(back.globalVoiceSourcePolicy == .highest)
        #expect(back.arpUsesInputVelocity)
        #expect(back.legatoUpdatesVelocity)
    }
}
