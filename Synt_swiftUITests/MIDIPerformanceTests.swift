//
//  MIDIPerformanceTests.swift
//  Pitch bend, mod wheel, and sustain. Init stays put until a message arrives.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct MIDIPerformanceTests {

    @Test func fullBendUpRaisesA4ByTwoSemitones() {
        let plain = fundamentalHz(bend: nil)
        let bent = fundamentalHz(bend: 1)
        let expected = plain * pow(2, 2.0 / 12.0)
        let error = abs(bent - expected) / expected
        #expect(error < 0.005, "bent \(bent) Hz, expected \(expected) Hz, plain \(plain) Hz")
    }

    @Test func sustainHoldsTheNoteUntilThePedalLifts() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.attack = 0.001
        preset.decay = 0.01
        preset.sustain = 1
        preset.release = 0.4
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1)
        engine.sustainPedal(down: true)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        #expect(!engine.isNoteReleasingForTesting(60))

        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        #expect(!engine.isNoteReleasingForTesting(60))

        engine.sustainPedal(down: false)
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
    }

    @Test func modWheelAddsToPresetLFODepth() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.lfoEnabled = true
        preset.lfoDepth = 0.4
        engine.preset = preset
        engine.applyPresetForTesting()
        _ = engine.renderOneSample()
        #expect(abs(engine.lfo.depth - 0.4) < 0.0001)

        // CC1 = 0 (a resting wheel) must not kill the patch's vibrato.
        engine.modWheel(0)
        engine.processCommandsForTesting()
        _ = engine.renderOneSample()
        #expect(abs(engine.lfo.depth - 0.4) < 0.0001)

        engine.modWheel(1)
        engine.processCommandsForTesting()
        _ = engine.renderOneSample()
        #expect(abs(engine.lfo.depth - 1.0) < 0.0001)
    }

    @Test func midiBytesReachBendWheelAndPedal() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0xE0, 0x7F, 0x7F])
        midi.parseMIDIBytesForTesting([0xB0, 1, 64])
        midi.parseMIDIBytesForTesting([0xB0, 64, 127])
        engine.processCommandsForTesting()
        #expect(abs(engine.pitchBendTarget - 1) < 0.0001)
        #expect(abs(engine.modWheel - Float(64) / 127) < 0.0001)
        #expect(engine.sustainPedalDown)
    }

    @Test func midiUsesItsOwnRingNotTheUIRing() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 60, 100])
        #expect(engine.commandQueueForTesting.isEmpty)
        #expect(!engine.midiQueue.isEmpty)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        midi.parseMIDIBytesForTesting([0x80, 60, 0])
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
    }

    @Test func midiKeyFollowsArpModeOnTheAudioThread() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .up
        engine.preset = preset
        engine.applyPresetForTesting()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0x90, 64, 100])
        engine.processCommandsForTesting()
        #expect(engine.heldKeysForArp.contains(64))
        #expect(!engine.isNoteActiveForTesting(64))

        // Arp switched off while the key is down: the key-up still clears the arp.
        preset.arpMode = .off
        engine.preset = preset
        engine.applyPresetForTesting()
        midi.parseMIDIBytesForTesting([0x80, 64, 0])
        engine.processCommandsForTesting()
        #expect(!engine.heldKeysForArp.contains(64))
    }

    @Test func sustainDoesNotHoldArpGates() {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .up
        preset.bpm = 240
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.sustainPedal(down: true)
        engine.noteOn(midiNote: 60)
        engine.noteOn(midiNote: 64)
        engine.processCommandsForTesting()
        // 240 BPM 16ths = 2756 samples per tick; run a few ticks.
        _ = engine.renderFramesForTesting(2756 * 4 + 10)
        let held = engine.voiceReleaseFlagsForTesting().filter { !$0.isReleasing }
        #expect(held.count <= 1, "pedal piled up arp gates: \(held.count) held voices")
    }

    @Test func presetChangeResetsBendAndPedal() {
        let engine = AudioEngine()
        engine.pitchBend(1)
        engine.sustainPedal(down: true)
        engine.processCommandsForTesting()
        #expect(engine.sustainPedalDown)
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        #expect(engine.pitchBendTarget == 0)
        #expect(engine.pitchBendSmoothed == 0)
        #expect(!engine.sustainPedalDown)
    }

    @Test func runningStatusAndSysExDoNotDropNotes() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        // SysEx, then Note On with running status for 3 notes, a clock byte mid-stream,
        // then running-status velocity-0 offs.
        midi.parseMIDIBytesForTesting([0xF0, 0x7E, 0x01, 0x02, 0xF7,
                                       0x90, 60, 100, 64, 100, 0xF8, 67, 100])
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
        #expect(engine.isNoteActiveForTesting(64))
        #expect(engine.isNoteActiveForTesting(67))
        midi.parseMIDIBytesForTesting([60, 0, 64, 0, 67, 0])
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
        #expect(engine.isNoteReleasingForTesting(64))
        #expect(engine.isNoteReleasingForTesting(67))
    }

    @Test func presetSwitchResetsDSPOnTheRenderThreadOnly() {
        let engine = AudioEngine()
        engine.processCommandsForTesting()
        #expect(engine.commandQueueForTesting.isEmpty)
        var next = SynthPreset.defaultPreset
        next.id = UUID()
        next.name = "Other"
        next.filterCutoff = 1234
        engine.preset = next
        // Main thread only queued the work; smoothers are untouched until the render drains.
        #expect(!engine.commandQueueForTesting.isEmpty)
        #expect(engine.smoothedFilterCutoff != 1234)
        engine.processCommandsForTesting()
        #expect(engine.smoothedFilterCutoff == 1234)
        #expect(engine.commandQueueForTesting.isEmpty)
    }

    /// Real golden: Init must match the pre-MIDI capture, not just itself.
    @Test func initWithoutMIDIMatchesTheGolden() {
        #expect(InitGoldenTests.renderHash(.defaultPreset) == InitGoldenTests.golden["Init"])
    }

    @Test func oldJSONKeepsPitchBendRangeAtTwoSemitones() throws {
        let json = #"{"name":"Old Patch"}"#.data(using: .utf8)!
        let preset = try JSONDecoder().decode(SynthPreset.self, from: json)
        #expect(preset.pitchBendRange == 2)
        #expect(SynthPreset.defaultPreset.pitchBendRange == 2)
    }

    /// Held wheel must match the old per-sample exp2, and the glide must not stair-step.
    @Test func heldBendMatchesExp2AndADetunedSineWithin1e6() {
        let bendAmount: Float = 1
        let range: Float = 2
        let cents = bendAmount * range * 100

        let bent = AudioEngine()
        bent.preset = drySinePreset(bendRange: range)
        bent.pitchBend(bendAmount)
        bent.processCommandsForTesting()

        let tuned = AudioEngine()
        tuned.preset = drySinePreset(detuneCents: cents, bendRange: range)

        let settle = 4_000
        _ = bent.renderFramesForTesting(settle)
        _ = tuned.renderFramesForTesting(settle)
        #expect(bent.pitchBendSmoothed == bendAmount)

        let expected = exp2(Double(bent.pitchBendSmoothed) * Double(bent.cachedPitchBendRange) / 12)
        #expect(abs(bent.cachedPitchBendMultiplier - expected) <= 1e-6)

        bent.noteOn(midiNote: 69, velocity: 1)
        tuned.noteOn(midiNote: 69, velocity: 1)
        bent.processCommandsForTesting()
        tuned.processCommandsForTesting()

        var maxDiff: Float = 0
        var maxMulDiff = 0.0
        var peak: Float = 0
        for _ in 0..<2_048 {
            let (bl, br) = bent.renderOneSample()
            let (tl, tr) = tuned.renderOneSample()
            maxDiff = max(maxDiff, abs(bl - tl), abs(br - tr))
            peak = max(peak, abs(bl), abs(br))
            let diff = abs(bent.cachedPitchBendMultiplier - expected)
            if diff > maxMulDiff { maxMulDiff = diff }
        }
        #expect(maxMulDiff <= 1e-6, "cached bend \(bent.cachedPitchBendMultiplier) vs exp2 \(expected)")
        #expect(maxDiff <= 1e-6, "held bend vs \(cents) cent detune, max sample diff \(maxDiff)")
        #expect(peak > 0.01)
    }

    @Test func movingBendTracksExp2WithoutSteps() {
        let engine = AudioEngine()
        engine.preset = drySinePreset(bendRange: 2)
        engine.noteOn(midiNote: 69, velocity: 1)
        engine.pitchBend(-0.65)
        engine.processCommandsForTesting()

        var refSmoothed: Float = 0
        var previous = engine.pitchBendSmoothed
        var maxMulDiff = 0.0
        var maxFlatWhileMoving = 0
        var flat = 0
        var nan = 0
        var peak: Float = 0
        var settled = false
        let coeff = Float(1 - exp(-1.0 / (0.005 * engine.sampleRate)))

        for _ in 0..<8_000 {
            let (left, right) = engine.renderOneSample()
            if !left.isFinite || !right.isFinite { nan += 1 }
            peak = max(peak, abs(left), abs(right))

            let target = engine.pitchBendTarget
            if !(target == 0 && refSmoothed == 0) {
                refSmoothed += (target - refSmoothed) * coeff
                if abs(target - refSmoothed) < 0.00002 { refSmoothed = target }
            }
            let expectedMul = refSmoothed == 0
                ? 1.0
                : exp2(Double(refSmoothed) * Double(engine.cachedPitchBendRange) / 12)
            let mulDiff = abs(engine.cachedPitchBendMultiplier - expectedMul)
            if mulDiff > maxMulDiff { maxMulDiff = mulDiff }

            let now = engine.pitchBendSmoothed
            if now == target {
                settled = true
            } else if now == previous {
                flat += 1
                if flat > maxFlatWhileMoving { maxFlatWhileMoving = flat }
            } else {
                flat = 0
            }
            previous = now
            if settled { break }
        }

        #expect(maxMulDiff <= 1e-6, "glide multiplier drifted from per-sample exp2 by \(maxMulDiff)")
        #expect(maxFlatWhileMoving <= 1, "bend held for \(maxFlatWhileMoving) samples during the glide")
        #expect(settled)
        #expect(abs(engine.pitchBendSmoothed - engine.pitchBendTarget) <= 0.00002)
        #expect(nan == 0)
        #expect(peak > 0.01)
    }

    @Test func bendCacheFollowsARangeChange() {
        let engine = AudioEngine()
        var preset = drySinePreset(bendRange: 2)
        engine.preset = preset
        engine.pitchBend(0.5)
        engine.processCommandsForTesting()
        _ = engine.renderFramesForTesting(4_000)
        #expect(engine.pitchBendSmoothed == 0.5)

        preset.pitchBendRange = 12
        engine.preset = preset
        _ = engine.renderOneSample()
        let expected = exp2(Double(engine.pitchBendSmoothed) * Double(engine.cachedPitchBendRange) / 12)
        #expect(engine.cachedPitchBendRange == 12)
        #expect(abs(engine.cachedPitchBendMultiplier - expected) <= 1e-6)
        #expect(abs(engine.cachedPitchBendMultiplier - exp2(0.5 * 2.0 / 12.0)) > 1e-4)
    }

    private func drySinePreset(detuneCents: Float = 0, bendRange: Float = 2) -> SynthPreset {
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .sine
        preset.osc1Volume = 0.8
        preset.osc1Detune = detuneCents
        preset.osc2Enabled = false
        preset.subOscVolume = 0
        preset.attack = 0.001
        preset.decay = 0.01
        preset.sustain = 1
        preset.filterCutoff = 18_000
        preset.filterResonance = 0
        preset.filterEnvelopeAmount = 0
        preset.chorusMix = 0
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.distortionEnabled = false
        preset.eqEnabled = false
        preset.phaserEnabled = false
        preset.masterVolume = 0.7
        preset.pitchBendRange = bendRange
        preset.unisonVoices = 1
        preset.portamento = 0
        preset.lfoEnabled = false
        preset.lfo2Enabled = false
        preset.analogDrift = 0
        return preset
    }

    private func fundamentalHz(bend: Float?) -> Double {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.osc1Waveform = .sine
        preset.osc1Volume = 0.8
        preset.osc2Enabled = false
        preset.attack = 0.001
        preset.decay = 0.01
        preset.sustain = 1
        preset.filterCutoff = 18_000
        preset.filterResonance = 0
        preset.chorusMix = 0
        preset.reverbMix = 0
        preset.delayMix = 0
        preset.masterVolume = 0.7
        preset.pitchBendRange = 2
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 69, velocity: 1)
        if let bend {
            engine.pitchBend(bend)
        }
        engine.processCommandsForTesting()

        _ = engine.renderFramesForTesting(Int(44_100 * 0.25))

        var crossings = 0
        var previous: Float = 0
        for _ in 0..<44_100 {
            let (left, right) = engine.renderOneSample()
            let sample = (left + right) * 0.5
            if previous <= 0, sample > 0 { crossings += 1 }
            previous = sample
        }
        return Double(crossings)
    }

    // MARK: - Key highlight: MIDI thread writes bits, main polls (no per-note hop)

    @MainActor
    @Test func midiKeysLightThroughThePollNotAMainHop() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        DispatchQueue.global().sync {
            midi.parseMIDIBytesForTesting([0x90, 60, 100, 0x90, 100, 90])
        }
        // Nothing was scheduled onto main: the published set is untouched.
        #expect(engine.keyDisplay.keys.isEmpty)
        engine.refreshKeyDisplay()
        #expect(engine.keyDisplay.keys == [60, 100])

        engine.noteOn(midiNote: 48)                       // UI key merges in
        #expect(engine.keyDisplay.keys == [48, 60, 100])

        DispatchQueue.global().sync {
            midi.parseMIDIBytesForTesting([0x80, 60, 0, 0xB0, 123, 0])
        }
        engine.refreshKeyDisplay()
        #expect(engine.keyDisplay.keys == [48])

        midi.parseMIDIBytesForTesting([0x90, 61, 100])
        engine.clearAllNotes()                            // panic clears both sources
        engine.refreshKeyDisplay()
        #expect(engine.keyDisplay.keys.isEmpty)
    }

    @Test func atomicKeyBitsRoundTrip() {
        let set = AtomicKeyBits()
        for n in [0, 63, 64, 127, -1, 128] { set.insert(n) }
        let bits = set.bits
        #expect(AtomicKeyBits.notes(lo: bits.lo, hi: bits.hi) == [0, 63, 64, 127])
        set.remove(63)
        set.remove(127)
        let after = set.bits
        #expect(AtomicKeyBits.notes(lo: after.lo, hi: after.hi) == [0, 64])
        set.removeAll()
        #expect(set.bits.lo == 0 && set.bits.hi == 0)
    }
}
