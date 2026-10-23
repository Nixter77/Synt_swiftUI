//
//  Stage14Stage3Tests.swift
//  Synt_swiftUITests
//
//  Stage 3 tests for GROK_BUILD_TASKS_SYNT_14:
//  - Per-voice mod sources: MPE pitch bend, pressure, CC74 (timbre) in modulation matrix
//  - Pressure on note A modulates only voice A (voice B with zero pressure unaffected)
//  - New AU params from 164: MPE bend range (164), zone (165), member channel count (166)
//  - Accept MPE config via RPN 0 (bend range) and RPN 6 (MCM zone & member channel count)
//  - Golden hash bit-exactness: 0xd1b3635203a4799e
//

import XCTest
@testable import SynthCore

final class Stage14Stage3Tests: XCTestCase {

    // MARK: - 1. New AU Params from Address 164

    func testNewAUParameterAddressesFrom164() {
        XCTAssertEqual(SynthParameterAddress.mpeEnabled.rawValue, 163)
        XCTAssertEqual(SynthParameterAddress.mpePitchBendRange.rawValue, 164)
        XCTAssertEqual(SynthParameterAddress.mpeZone.rawValue, 165)
        XCTAssertEqual(SynthParameterAddress.mpeMemberChannelCount.rawValue, 166)

        // Verify min, max, display names
        XCTAssertEqual(SynthParameterAddress.mpePitchBendRange.min, 0.0)
        XCTAssertEqual(SynthParameterAddress.mpePitchBendRange.max, 96.0)
        XCTAssertEqual(SynthParameterAddress.mpePitchBendRange.identifier, "mpePitchBendRange")

        XCTAssertEqual(SynthParameterAddress.mpeZone.min, 0.0)
        XCTAssertEqual(SynthParameterAddress.mpeZone.max, 1.0)
        XCTAssertEqual(SynthParameterAddress.mpeZone.identifier, "mpeZone")

        XCTAssertEqual(SynthParameterAddress.mpeMemberChannelCount.min, 0.0)
        XCTAssertEqual(SynthParameterAddress.mpeMemberChannelCount.max, 15.0)
        XCTAssertEqual(SynthParameterAddress.mpeMemberChannelCount.identifier, "mpeMemberChannelCount")

        // Addresses 1-163 never moved (0 was never assigned; osc1Volume is 1)
        XCTAssertEqual(SynthParameterAddress.osc1Volume.rawValue, 1)
        XCTAssertEqual(SynthParameterAddress.mpeEnabled.rawValue, 163)
    }

    func testEngineParameterApplicationFrom164() {
        let engine = AudioEngine(coreOnly: true)

        // Address 164: bend range
        engine.adoptAddressedParameterOnMain(id: 164, value: 24.0)
        XCTAssertEqual(engine.preset.mpePitchBendRange, 24.0)
        engine.applyAddressedParameterRT(id: 164, value: 24.0)
        XCTAssertEqual(engine.cachedMpePitchBendRange, 24.0)
        XCTAssertEqual(engine.addressedParameterValue(.mpePitchBendRange), 24.0)

        // Address 165: zone (0 = lower, 1 = upper)
        engine.adoptAddressedParameterOnMain(id: 165, value: 1.0)
        XCTAssertEqual(engine.preset.mpeZone, .upper)
        engine.applyAddressedParameterRT(id: 165, value: 1.0)
        XCTAssertEqual(engine.cachedMpeZone, .upper)
        XCTAssertEqual(engine.addressedParameterValue(.mpeZone), 1.0)

        engine.adoptAddressedParameterOnMain(id: 165, value: 0.0)
        XCTAssertEqual(engine.preset.mpeZone, .lower)
        engine.applyAddressedParameterRT(id: 165, value: 0.0)
        XCTAssertEqual(engine.cachedMpeZone, .lower)
        XCTAssertEqual(engine.addressedParameterValue(.mpeZone), 0.0)

        // Address 166: member channel count
        engine.adoptAddressedParameterOnMain(id: 166, value: 7.0)
        XCTAssertEqual(engine.preset.mpeMemberChannelCount, 7)
        engine.applyAddressedParameterRT(id: 166, value: 7.0)
        XCTAssertEqual(engine.cachedMpeMemberChannelCount, 7)
        XCTAssertEqual(engine.addressedParameterValue(.mpeMemberChannelCount), 7.0)
    }

    // MARK: - 2. RPN 0 and RPN 6 Handling

    func testRPN0ChangesBendRange() {
        let engine = AudioEngine(coreOnly: true)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.cachedMpePitchBendRange = 48.0

        // Send RPN 0 sequence on Channel 1 (ch=0):
        // CC 101 = 0 (RPN MSB)
        // CC 100 = 0 (RPN LSB)
        // CC 6 = 24 (Data Entry MSB = 24 semitones)
        engine.handleCommand(.mpeControlChange(channel: 0, cc: 101, value: 0))
        engine.handleCommand(.mpeControlChange(channel: 0, cc: 100, value: 0))
        engine.handleCommand(.mpeControlChange(channel: 0, cc: 6, value: 24))

        XCTAssertEqual(engine.cachedMpePitchBendRange, 24.0, "RPN 0 must update MPE bend range to 24 semitones")
        engine.pollMPEConfigMailbox() // SYNT_15 R12-1: preset mirrored on main, not written from render
        XCTAssertEqual(engine.preset.mpePitchBendRange, 24.0)

        // Also test direct handleRPN call
        engine.handleRPN(channel: 0, rpn: 0, value: 12)
        XCTAssertEqual(engine.cachedMpePitchBendRange, 12.0)
    }

    func testRPN6SetsZoneAndMemberChannelCount() {
        let engine = AudioEngine(coreOnly: true)

        // 1. Send RPN 6 on Channel 1 (ch=0 -> Lower zone) with 10 member channels
        engine.handleCommand(.mpeControlChange(channel: 0, cc: 101, value: 0))
        engine.handleCommand(.mpeControlChange(channel: 0, cc: 100, value: 6))
        engine.handleCommand(.mpeControlChange(channel: 0, cc: 6, value: 10))

        XCTAssertEqual(engine.cachedMpeZone, .lower, "RPN 6 on Channel 1 must set lower zone")
        XCTAssertEqual(engine.cachedMpeMemberChannelCount, 10, "RPN 6 must set member channel count to 10")
        XCTAssertTrue(engine.cachedMpeEnabled, "RPN 6 with member channels > 0 must enable MPE")

        // 2. Send RPN 6 on Channel 16 (ch=15 -> Upper zone) with 5 member channels
        engine.handleCommand(.mpeControlChange(channel: 15, cc: 101, value: 0))
        engine.handleCommand(.mpeControlChange(channel: 15, cc: 100, value: 6))
        engine.handleCommand(.mpeControlChange(channel: 15, cc: 6, value: 5))

        XCTAssertEqual(engine.cachedMpeZone, .upper, "RPN 6 on Channel 16 must set upper zone")
        XCTAssertEqual(engine.cachedMpeMemberChannelCount, 5)
        XCTAssertTrue(engine.cachedMpeEnabled)

        // 3. Send RPN 6 with value 0 -> disables MPE
        engine.handleRPN(channel: 15, rpn: 6, value: 0)
        XCTAssertEqual(engine.cachedMpeMemberChannelCount, 0)
        XCTAssertFalse(engine.cachedMpeEnabled)
    }

    // MARK: - 3. Per-Voice Mod Sources in Mod Matrix: Pressure on Note A Modulates Only Voice A

    func testPressureOnNoteAModulatesOnlyVoiceA() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly

        // Configure mod matrix row: MPE Pressure -> Pitch OSC1 (Amount = 1.0)
        // With amount 1.0, pressure 1.0 adds full mod pitch
        let row = ModMatrixEntry(source: .mpePressure, destination: .pitch1, amount: 1.0)
        engine.preset.modMatrix = [row]
        engine.applyPreset()
        engine.cachedMpeEnabled = true

        // Note A on Member Channel 2, Note B on Member Channel 3
        engine.handleCommand(.mpeKeyDown(midiNote: 60, velocity: 0.8, channel: 2))
        engine.handleCommand(.mpeKeyDown(midiNote: 64, velocity: 0.8, channel: 3))

        // Find voice indices
        var voiceAIdx: Int?
        var voiceBIdx: Int?
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive {
                if engine.voices[i].midiNote == 60 && engine.voices[i].midiChannel == 2 {
                    voiceAIdx = i
                } else if engine.voices[i].midiNote == 64 && engine.voices[i].midiChannel == 3 {
                    voiceBIdx = i
                }
            }
        }

        guard let vA = voiceAIdx, let vB = voiceBIdx else {
            XCTFail("Failed to allocate both voices")
            return
        }

        // Initially both voices have 0 pressure
        XCTAssertEqual(engine.voices[vA].mpePressure, 0.0)
        XCTAssertEqual(engine.voices[vB].mpePressure, 0.0)

        // Send pressure 0.9 on Channel 2 ONLY (Note A)
        engine.handleCommand(.mpePressure(channel: 2, value: 0.9))

        XCTAssertEqual(engine.voices[vA].mpePressure, 0.9)
        XCTAssertEqual(engine.voices[vB].mpePressure, 0.0, "Voice B must remain with 0 pressure")

        // Render 100 samples to let the smoothing filter settle
        for _ in 0..<100 {
            _ = engine.renderOneSample()
        }

        // Voice A smoothed pressure should be close to 0.9, while Voice B smoothed pressure remains 0.0
        XCTAssertGreaterThan(engine.voices[vA].smoothedMpePressure, 0.8)
        XCTAssertEqual(engine.voices[vB].smoothedMpePressure, 0.0, accuracy: 1e-6)
    }

    func testTimbreCC74ModulatesOnlyTargetVoice() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44100, maxFrames: 256)
        engine.mpeEnabled = true
        engine.cachedMpeEnabled = true
        engine.preset.voiceMode = .poly

        // Configure mod matrix row: MPE Timbre -> Amplitude
        let row = ModMatrixEntry(source: .mpeTimbre, destination: .amp, amount: 0.5)
        engine.preset.modMatrix = [row]
        engine.applyPreset()
        engine.cachedMpeEnabled = true

        engine.handleCommand(.mpeKeyDown(midiNote: 50, velocity: 0.7, channel: 4))
        engine.handleCommand(.mpeKeyDown(midiNote: 55, velocity: 0.7, channel: 5))

        // Send timbre CC74 = 0.85 on Channel 4 ONLY
        engine.handleCommand(.mpeTimbre(channel: 4, value: 0.85))

        var voice4: Int?
        var voice5: Int?
        for i in 0..<AudioEngine.maxVoices {
            if engine.voices[i].isActive {
                if engine.voices[i].midiChannel == 4 { voice4 = i }
                if engine.voices[i].midiChannel == 5 { voice5 = i }
            }
        }

        guard let v4 = voice4, let v5 = voice5 else {
            XCTFail("Voices not allocated")
            return
        }

        XCTAssertEqual(engine.voices[v4].mpeTimbre, 0.85)
        XCTAssertEqual(engine.voices[v5].mpeTimbre, 0.0)

        for _ in 0..<100 { _ = engine.renderOneSample() }

        XCTAssertGreaterThan(engine.voices[v4].smoothedMpeTimbre, 0.8)
        XCTAssertEqual(engine.voices[v5].smoothedMpeTimbre, 0.0, accuracy: 1e-6)
    }

    // MARK: - 4. Golden Audio Harness Bit-Exactness

    func testGoldenHarnessPreserved() {
        let hash = InitGoldenTests.renderHash(.defaultPreset)
        XCTAssertEqual(hash, 0xd1b3635203a4799e, "Default sound must remain bit-identical to golden hash")
    }
}
