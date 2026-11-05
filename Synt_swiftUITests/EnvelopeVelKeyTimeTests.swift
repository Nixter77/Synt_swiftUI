//
//  EnvelopeVelKeyTimeTests.swift
//  SYNT_63 D3.5–D3.9: velocity and key time, retrigger, unison tails, addresses.
//

import Foundation
@testable import SynthCore
import Testing

@MainActor
struct EnvelopeVelKeyTimeTests {
    private func engine(with preset: SynthPreset) -> AudioEngine {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        return engine
    }

    private func basePreset() -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .off
        preset.unisonVoices = 1
        preset.attack = 0.08
        preset.decay = 0.4
        preset.sustain = 1
        preset.release = 0.3
        preset.envelopeModel = .legacy
        return preset
    }

    private func attackSamples(_ engine: AudioEngine, note: Int) -> Int {
        for i in 1...30_000 {
            _ = engine.renderOneSample()
            guard let voice = engine.voices.first(where: { $0.isActive && $0.midiNote == note && !$0.isReleasing }) else {
                return i
            }
            if voice.envelopePhase != .attack && voice.envelopePhase != .delay {
                return i
            }
        }
        return 30_000
    }

    private func activeCount(_ engine: AudioEngine, note: Int, releasing: Bool? = nil) -> Int {
        engine.voices.reduce(0) { count, voice in
            guard voice.isActive, voice.midiNote == note else { return count }
            if let releasing, voice.isReleasing != releasing { return count }
            return count + 1
        }
    }

    @Test func zeroAmountsStayExactlyOne() {
        let scale = AudioEngine.envelopeTimeScale(velAmount: 0, velocity: 0.2, keyTrack: 0, note: 84)
        #expect(scale.bitPattern == Float(1).bitPattern)
    }

    @Test func velocity127AttacksAboutEightTimesFasterThan32() {
        let loud = AudioEngine.envelopeTimeScale(velAmount: 1, velocity: 1, keyTrack: 0, note: 60)
        let soft = AudioEngine.envelopeTimeScale(velAmount: 1, velocity: 32.0 / 127.0, keyTrack: 0, note: 60)
        let ratio = soft / loud
        #expect(abs(loud - 0.25) < 1e-6)
        #expect(abs(ratio - 8) < 0.1)

        var loudPreset = basePreset()
        loudPreset.velToAttack = 1
        let loudEngine = engine(with: loudPreset)
        loudEngine.noteOn(midiNote: 60, velocity: 1)
        loudEngine.processCommandsForTesting()
        let loudSamples = attackSamples(loudEngine, note: 60)

        let softEngine = engine(with: loudPreset)
        softEngine.noteOn(midiNote: 60, velocity: 32.0 / 127.0)
        softEngine.processCommandsForTesting()
        let softSamples = attackSamples(softEngine, note: 60)
        #expect(abs(Double(softSamples) / Double(loudSamples) - Double(ratio)) / Double(ratio) <= 0.05)
    }

    @Test func keyTrackHalvesAttackOneOctaveUp() {
        let low = AudioEngine.envelopeTimeScale(velAmount: 0, velocity: 0.8, keyTrack: 1, note: 60)
        let high = AudioEngine.envelopeTimeScale(velAmount: 0, velocity: 0.8, keyTrack: 1, note: 72)
        #expect(low.bitPattern == Float(1).bitPattern)
        #expect(high.bitPattern == Float(0.5).bitPattern)

        var preset = basePreset()
        preset.envKeyTrack = 1
        let lowEngine = engine(with: preset)
        lowEngine.noteOn(midiNote: 60, velocity: 0.8)
        lowEngine.processCommandsForTesting()
        let highEngine = engine(with: preset)
        highEngine.noteOn(midiNote: 72, velocity: 0.8)
        highEngine.processCommandsForTesting()
        let lowSamples = attackSamples(lowEngine, note: 60)
        let highSamples = attackSamples(highEngine, note: 72)
        #expect(abs(Double(lowSamples) / Double(highSamples) - 2) <= 0.05)
    }

    @Test func releaseVelocityScalesTheReleaseOnNoteOff() {
        var preset = basePreset()
        preset.releaseVelToRelease = 1
        let engine = engine(with: preset)
        engine.noteOn(midiNote: 60, velocity: 0.8)
        engine.processCommandsForTesting()
        for _ in 0..<30 { _ = engine.renderOneSample() }
        engine.noteOff(midiNote: 60, releaseVelocity: 1)
        engine.processCommandsForTesting()
        let voice = engine.voices.first { $0.isActive && $0.midiNote == 60 }
        let expected = AudioEngine.envelopeTimeScale(velAmount: 1, velocity: 1, keyTrack: 0, note: 60)
        #expect(abs((voice?.releaseScale ?? -1) - expected) < 1e-5)
        #expect(abs(expected - 0.25) < 1e-5)
        #expect(voice?.isReleasing == true)
    }

    @Test func matrixAttackRouteDoublesTheStage() {
        var plain = basePreset()
        plain.attack = 0.05
        let plainEngine = engine(with: plain)
        plainEngine.noteOn(midiNote: 60, velocity: 1)
        plainEngine.processCommandsForTesting()
        let plainSamples = attackSamples(plainEngine, note: 60)

        var routed = plain
        routed.modMatrix = [ModMatrixEntry(source: .velocity, destination: .ampAttack, amount: 1)]
        let routedEngine = engine(with: routed)
        routedEngine.noteOn(midiNote: 60, velocity: 1)
        routedEngine.processCommandsForTesting()
        #expect(routedEngine.cachedEnvTimeMod)
        let routedSamples = attackSamples(routedEngine, note: 60)
        #expect(abs(Double(routedSamples) / Double(plainSamples) - 2) <= 0.05)

        var silent = plain
        silent.modMatrix = [ModMatrixEntry(source: .velocity, destination: .ampAttack, amount: 0)]
        let silentEngine = engine(with: silent)
        silentEngine.noteOn(midiNote: 60, velocity: 1)
        silentEngine.processCommandsForTesting()
        let silentSamples = attackSamples(silentEngine, note: 60)
        #expect(abs(silentSamples - plainSamples) <= 1)
    }

    @Test func retriggerModesRestartOrKeepTheSameNote() {
        func prepare(_ mode: AmpRetriggerMode) -> AudioEngine {
            var preset = basePreset()
            preset.attack = 0.05
            preset.ampRetriggerMode = mode
            let engine = engine(with: preset)
            engine.noteOn(midiNote: 60, velocity: 0.4)
            engine.processCommandsForTesting()
            for _ in 0..<400 { _ = engine.renderOneSample() }
            return engine
        }

        let current = prepare(.fromCurrent)
        let before = current.voices.first { $0.isActive && $0.midiNote == 60 && !$0.isReleasing }
        #expect((before?.envelopeValue ?? 0) > 0.05)
        current.noteOn(midiNote: 60, velocity: 0.9)
        current.processCommandsForTesting()
        #expect(activeCount(current, note: 60, releasing: true) >= 1)
        #expect(activeCount(current, note: 60, releasing: false) == 1)
        let restarted = current.voices.first { $0.isActive && $0.midiNote == 60 && !$0.isReleasing }
        #expect(restarted?.envelopePhase == .attack)
        #expect(restarted?.envelopeValue == 0)

        let fromZero = prepare(.fromZero)
        let risen = fromZero.voices.first { $0.isActive && $0.midiNote == 60 }
        #expect((risen?.envelopeValue ?? 0) > 0.05)
        fromZero.noteOn(midiNote: 60, velocity: 0.95)
        fromZero.processCommandsForTesting()
        #expect(activeCount(fromZero, note: 60) == 1)
        #expect(activeCount(fromZero, note: 60, releasing: true) == 0)
        let zeroed = fromZero.voices.first { $0.isActive && $0.midiNote == 60 }
        #expect(zeroed?.envelopeValue == 0)
        #expect(zeroed?.envelopePhase == .attack)
        #expect(abs((zeroed?.velocity ?? 0) - 0.95) < 1e-6)

        let legato = prepare(.legatoNoRetrigger)
        let held = legato.voices.first { $0.isActive && $0.midiNote == 60 }
        let keptValue = held?.envelopeValue ?? -1
        let keptPhase = held?.envelopePhase
        legato.noteOn(midiNote: 60, velocity: 0.2)
        legato.processCommandsForTesting()
        let still = legato.voices.first { $0.isActive && $0.midiNote == 60 }
        #expect(activeCount(legato, note: 60) == 1)
        #expect(still?.envelopeValue.bitPattern == keptValue.bitPattern)
        #expect(still?.envelopePhase == keptPhase)
        #expect(abs((still?.velocity ?? 0) - 0.2) < 1e-6)
    }

    @Test func unisonTailFlagKeepsPartialsUntilASecondNoteIsHeld() {
        var preset = basePreset()
        preset.unisonVoices = 4
        preset.keepUnisonThroughTails = false
        let collapsed = engine(with: preset)
        collapsed.noteOn(midiNote: 60, velocity: 0.8)
        collapsed.processCommandsForTesting()
        #expect(activeCount(collapsed, note: 60) == 4)
        collapsed.noteOff(midiNote: 60)
        collapsed.processCommandsForTesting()
        collapsed.noteOn(midiNote: 64, velocity: 0.8)
        collapsed.processCommandsForTesting()
        #expect(activeCount(collapsed, note: 64, releasing: false) == 1)

        preset.keepUnisonThroughTails = true
        let kept = engine(with: preset)
        kept.noteOn(midiNote: 60, velocity: 0.8)
        kept.processCommandsForTesting()
        kept.noteOff(midiNote: 60)
        kept.processCommandsForTesting()
        kept.noteOn(midiNote: 64, velocity: 0.8)
        kept.processCommandsForTesting()
        #expect(activeCount(kept, note: 64, releasing: false) == 4)
        #expect(activeCount(kept, note: 60, releasing: true) == 4)

        let chord = engine(with: preset)
        chord.noteOn(midiNote: 60, velocity: 0.8)
        chord.processCommandsForTesting()
        chord.noteOn(midiNote: 64, velocity: 0.8)
        chord.processCommandsForTesting()
        #expect(activeCount(chord, note: 64, releasing: false) == 1)
        #expect(activeCount(chord, note: 60, releasing: false) == 1)
    }

    @Test func oldPresetJsonStaysInert() throws {
        let preset = try JSONDecoder().decode(SynthPreset.self, from: Data(#"{"name":"Old"}"#.utf8))
        #expect(preset.envelopeModel == .legacy)
        #expect(preset.filterAttackCurve == 0)
        #expect(preset.filterDecayCurve == 0)
        #expect(preset.filterReleaseCurve == 0)
        #expect(preset.ampDelay == 0)
        #expect(preset.ampHold == 0)
        #expect(preset.filterEnvDelay == 0)
        #expect(preset.filterEnvHold == 0)
        #expect(preset.velToAttack == 0)
        #expect(preset.velToDecay == 0)
        #expect(preset.releaseVelToRelease == 0)
        #expect(preset.envKeyTrack == 0)
        #expect(preset.ampRetriggerMode == .fromCurrent)
        #expect(preset.keepUnisonThroughTails == false)
        #expect(preset.shortAttackEnabled == false)
        #expect(ModDestination.allCases.contains(.ampAttack))
        #expect(ModDestination.allCases.contains(.filterRelease))
        #expect(LiveModulationSnapshot.slot(for: .ampAttack) == 19)
        #expect(LiveModulationSnapshot.slot(for: .filterRelease) == 24)
        #expect(LiveModulationSnapshot.slotCount == 32)
    }

    @Test func addressesAppendAfterLegatoAndRoundTrip() {
        #expect(SynthParameterAddress.legatoUpdatesVelocity.rawValue == 171)
        #expect(SynthParameterAddress.filterAttackCurve.rawValue == 172)
        #expect(SynthParameterAddress.filterDecayCurve.rawValue == 173)
        #expect(SynthParameterAddress.filterReleaseCurve.rawValue == 174)
        #expect(SynthParameterAddress.envelopeModel.rawValue == 175)
        #expect(SynthParameterAddress.ampDelay.rawValue == 176)
        #expect(SynthParameterAddress.ampHold.rawValue == 177)
        #expect(SynthParameterAddress.filterEnvDelay.rawValue == 178)
        #expect(SynthParameterAddress.filterEnvHold.rawValue == 179)
        #expect(SynthParameterAddress.velToAttack.rawValue == 180)
        #expect(SynthParameterAddress.velToDecay.rawValue == 181)
        #expect(SynthParameterAddress.releaseVelToRelease.rawValue == 182)
        #expect(SynthParameterAddress.envKeyTrack.rawValue == 183)
        #expect(SynthParameterAddress.ampRetriggerMode.rawValue == 184)
        #expect(SynthParameterAddress.keepUnisonThroughTails.rawValue == 185)
        #expect(SynthParameterAddress.shortAttackEnabled.rawValue == 186)
        #expect(SynthParameterAddress.combUsesVoiceCutoff.rawValue == 187)
        #expect(SynthParameterAddress.perVoiceCutoffSources.rawValue == 188)
        #expect(SynthParameterAddress.respondToExpressionCC.rawValue == 189)
        #expect(SynthParameterAddress.aftertouchCurve.rawValue == 190)
        #expect(SynthParameterAddress.aftertouchDeadzone.rawValue == 191)
        #expect(SynthParameterAddress.allCases.last == .aftertouchDeadzone)
        #expect(SynthParameterAddress.ampDelay.max == 4)
        #expect(SynthParameterAddress.filterAttackCurve.min == -1)
        #expect(SynthParameterAddress.velToAttack.max == 1)
        #expect(envelopeModelFromFloat(1) == .analog)
        #expect(envelopeModelFromFloat(2) == .digital)
        #expect(ampRetriggerFromFloat(2) == .legatoNoRetrigger)

        var preset = SynthPreset.defaultPreset
        preset.setParameterValue(2, for: .envelopeModel)
        preset.setParameterValue(-0.4, for: .filterDecayCurve)
        preset.setParameterValue(3.5, for: .ampHold)
        preset.setParameterValue(1, for: .velToAttack)
        preset.setParameterValue(1, for: .ampRetriggerMode)
        preset.setParameterValue(1, for: .keepUnisonThroughTails)
        preset.setParameterValue(1, for: .shortAttackEnabled)
        #expect(preset.envelopeModel == .digital)
        #expect(preset.filterDecayCurve == -0.4)
        #expect(preset.ampHold == 3.5)
        #expect(preset.velToAttack == 1)
        #expect(preset.ampRetriggerMode == .fromZero)
        #expect(preset.keepUnisonThroughTails)
        #expect(preset.shortAttackEnabled)
        #expect(preset.parameterValue(for: .envelopeModel) == 2)

        var wild = preset
        wild.ampDelay = 9
        wild.velToAttack = 4
        let cleaned = wild.sanitized()
        #expect(cleaned.ampDelay == 4)
        #expect(cleaned.velToAttack == 1)
        #expect(cleaned.envelopeModel == .digital)
    }
}
