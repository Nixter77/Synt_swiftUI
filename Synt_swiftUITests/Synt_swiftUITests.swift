//
//  Synt_swiftUITests.swift
//  Synt_swiftUITests
//
//  Created by Nikolay Nikolayenko on 26/01/2026.
//

import Foundation
import Testing
@testable import Synt_swiftUI

/// Tiny mutex counter for concurrent queue regression tests.
private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    func increment() {
        lock.lock()
        _value += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }
}

struct Synt_swiftUITests {

    // MARK: - AudioCommandQueue

    @Test func audioCommandQueueMaintainsFIFOOrder() async throws {
        let queue = AudioCommandQueue(capacity: 4)

        #expect(queue.push(.noteOn(midiNote: 60, velocity: 0.5)))
        #expect(queue.push(.noteOff(midiNote: 60)))
        #expect(queue.count == 2)

        guard let first = queue.pop() else {
            Issue.record("Expected first command")
            return
        }
        if case let .noteOn(midiNote, velocity) = first {
            #expect(midiNote == 60)
            #expect(abs(velocity - 0.5) < 0.0001)
        } else {
            Issue.record("Expected noteOn as first command")
        }

        guard let second = queue.pop() else {
            Issue.record("Expected second command")
            return
        }
        if case let .noteOff(midiNote) = second {
            #expect(midiNote == 60)
        } else {
            Issue.record("Expected noteOff as second command")
        }

        #expect(queue.pop() == nil)
        #expect(queue.isEmpty)
    }

    @Test func audioCommandQueueReportsFullWithoutOverwritingUnreadNoteOns() async throws {
        let queue = AudioCommandQueue(capacity: 3)

        #expect(queue.push(.noteOn(midiNote: 60, velocity: 1.0)))
        #expect(queue.push(.noteOn(midiNote: 61, velocity: 1.0)))
        // Non-critical push must fail when full (capacity-1 usable slots)
        #expect(!queue.push(.noteOn(midiNote: 62, velocity: 1.0)))

        guard let first = queue.pop() else {
            Issue.record("Expected queued command after full push attempt")
            return
        }
        if case let .noteOn(midiNote, _) = first {
            #expect(midiNote == 60)
        } else {
            Issue.record("Expected first original noteOn to remain queued")
        }
    }

    @Test func audioCommandQueuePrioritizesNoteOffWhenFull() async throws {
        let queue = AudioCommandQueue(capacity: 3)

        #expect(queue.push(.noteOn(midiNote: 60, velocity: 1.0)))
        #expect(queue.push(.noteOn(midiNote: 61, velocity: 1.0)))
        #expect(!queue.push(.noteOn(midiNote: 62, velocity: 1.0)))

        // Critical noteOff must succeed via side-channel (producer never advances tail)
        #expect(queue.push(.noteOff(midiNote: 61)))
        #expect(queue.hasPendingNoteOffForTesting(61))

        var sawNoteOff = false
        queue.drain(limit: 16) { cmd in
            if case .noteOff(let n) = cmd, n == 61 {
                sawNoteOff = true
            }
        }
        #expect(sawNoteOff)
        #expect(!queue.hasPendingNoteOffForTesting(61))
    }

    @Test func audioCommandQueuePrioritizesClearAllWhenFull() async throws {
        let queue = AudioCommandQueue(capacity: 3)
        #expect(queue.push(.noteOn(midiNote: 10, velocity: 1.0)))
        #expect(queue.push(.noteOn(midiNote: 11, velocity: 1.0)))
        #expect(!queue.push(.noteOn(midiNote: 12, velocity: 1.0)))
        // Ring full — clearAll parks on side-channel (producer never stores tail)
        #expect(queue.push(.clearAll))
        #expect(queue.hasPendingClearAllForTesting)

        var sawClear = false
        queue.drain(limit: 16) { cmd in
            if case .clearAll = cmd {
                sawClear = true
            }
        }
        #expect(sawClear)
        #expect(!queue.hasPendingClearAllForTesting)
    }

    @Test func audioCommandQueueClearAllDiscardsPreClearRingNoteOns() async throws {
        // Skeptic: after side-channel clearAll, drain must not replay ring noteOns
        // (would recreate voices after panic clear in processCommandQueue).
        let queue = AudioCommandQueue(capacity: 4)
        #expect(queue.push(.noteOn(midiNote: 60, velocity: 1.0)))
        #expect(queue.push(.noteOn(midiNote: 61, velocity: 1.0)))
        #expect(queue.push(.noteOn(midiNote: 62, velocity: 1.0)))
        #expect(!queue.push(.noteOn(midiNote: 63, velocity: 1.0)))
        #expect(queue.push(.clearAll))
        #expect(queue.hasPendingClearAllForTesting)

        var emitted: [AudioCommand] = []
        queue.drain(limit: 32) { cmd in
            emitted.append(cmd)
        }

        #expect(emitted.count == 1)
        #expect(emitted.first == .clearAll)
        // No noteOn after (or before) clearAll when clear came from side-channel first
        let noteOnAfterClear = emitted.drop(while: { $0 != .clearAll }).dropFirst().contains {
            if case .noteOn = $0 { return true }
            return false
        }
        #expect(!noteOnAfterClear)
        #expect(queue.isEmpty)
        #expect(!queue.hasPendingClearAllForTesting)

        // Ring-path clearAll: commands before clear emit; commands after must be discarded
        let q2 = AudioCommandQueue(capacity: 8)
        #expect(q2.push(.noteOn(midiNote: 48, velocity: 1.0)))
        #expect(q2.push(.noteOn(midiNote: 50, velocity: 1.0)))
        #expect(q2.push(.clearAll))
        #expect(q2.push(.noteOn(midiNote: 52, velocity: 1.0)))
        #expect(q2.push(.noteOn(midiNote: 53, velocity: 1.0)))

        var emitted2: [AudioCommand] = []
        q2.drain(limit: 32) { cmd in
            emitted2.append(cmd)
        }

        #expect(emitted2.contains(.clearAll))
        // noteOn 52/53 were after clearAll in the ring — must not appear
        let afterClear = Array(emitted2.drop(while: { $0 != .clearAll }).dropFirst())
        #expect(afterClear.isEmpty)
        #expect(emitted2.filter {
            if case .noteOn(let n, _) = $0 { return n == 52 || n == 53 }
            return false
        }.isEmpty)

        // Engine integration: full ring noteOns + clearAll must leave no active notes
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .off
        engine.preset = preset

        // Use the engine's real command queue path
        let eq = engine.commandQueueForTesting
        // Flood then clear via public API
        for n in 0..<32 {
            engine.noteOn(midiNote: 40 + (n % 20), velocity: 0.8)
        }
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        #expect(engine.activeNoteCountForTesting == 0)
        // Drain any leftover should be empty
        var leftoverNoteOn = false
        eq.drain(limit: 128) { cmd in
            if case .noteOn = cmd { leftoverNoteOn = true }
        }
        #expect(!leftoverNoteOn)
    }

    @Test func audioCommandQueueConcurrentFullQueueNoteOffAndDrain() async throws {
        // Models UI producer filling the ring while audio consumer drains.
        // Critical noteOff must be accepted without the producer storing tail.
        let queue = AudioCommandQueue(capacity: 8)
        let iterations = 2_000
        let noteOffNote = 72

        let criticalPushOK = LockedCounter()
        let noteOffSeen = LockedCounter()

        let producer = Task.detached {
            for i in 0..<iterations {
                _ = queue.push(.noteOn(midiNote: i % 12 + 48, velocity: 0.5))
                if i % 7 == 0 {
                    if queue.push(.noteOff(midiNote: noteOffNote)) {
                        criticalPushOK.increment()
                    }
                }
            }
            if queue.push(.noteOff(midiNote: noteOffNote)) {
                criticalPushOK.increment()
            }
        }

        let consumer = Task.detached {
            for _ in 0..<(iterations * 2) {
                queue.drain(limit: 32) { cmd in
                    if case .noteOff(let n) = cmd, n == noteOffNote {
                        noteOffSeen.increment()
                    }
                }
                await Task.yield()
            }
        }

        await producer.value
        await consumer.value

        // Drain anything remaining after both tasks finish
        for _ in 0..<128 {
            queue.drain(limit: 64) { cmd in
                if case .noteOff(let n) = cmd, n == noteOffNote {
                    noteOffSeen.increment()
                }
            }
            if queue.isEmpty { break }
        }

        let pushed = criticalPushOK.value
        let seen = noteOffSeen.value
        // Critical pushes always return true; side-channel may coalesce same-note offs
        // into one bit, so seen can be < pushed but must be >= 1 and fully drained.
        #expect(pushed >= 1)
        #expect(seen >= 1)
        #expect(seen <= pushed)
        #expect(!queue.hasPendingNoteOffForTesting(noteOffNote))
        #expect(queue.isEmpty)

        // Deterministic interleaved full-queue path (fill → noteOff side-channel → drain)
        let q = AudioCommandQueue(capacity: 4)
        #expect(q.push(.noteOn(midiNote: 60, velocity: 1)))
        #expect(q.push(.noteOn(midiNote: 61, velocity: 1)))
        #expect(q.push(.noteOn(midiNote: 62, velocity: 1)))
        #expect(!q.push(.noteOn(midiNote: 63, velocity: 1)))
        #expect(q.push(.noteOff(midiNote: 60)))
        #expect(q.hasPendingNoteOffForTesting(60))

        var saw = false
        q.drain(limit: 1) { _ in }
        _ = q.push(.noteOn(midiNote: 64, velocity: 1))
        q.drain(limit: 16) { cmd in
            if case .noteOff(let n) = cmd, n == 60 { saw = true }
        }
        #expect(saw)
        #expect(!q.hasPendingNoteOffForTesting(60))
    }

    @Test func audioEngineApplyPresetDoesNotRequireMainThreadArpMutation() async throws {
        // applyPreset must only snapshot caches; audio path applies cachedArpMode.
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .upDown
        preset.bpm = 180
        engine.preset = preset
        engine.applyPresetForTesting()

        let cached = engine.cachedAudioParamsForTesting()
        #expect(cached.arpMode == .upDown)
        #expect(abs(cached.bpm - 180) < 0.001)

        // Note path still works after preset apply (command queue + drain)
        preset.arpMode = .off
        engine.preset = preset
        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))
    }

    // MARK: - VoiceManager

    @Test func voiceManagerCapsActiveVoicesAtPreallocatedLimit() async throws {
        let manager = VoiceManager()

        for midiNote in 0..<80 {
            manager.addVoices(
                midiNote: midiNote,
                velocity: 1.0,
                unisonVoices: 1,
                detuneAmount: 0.0,
                spreadAmount: 0.0,
                portamento: 0.0
            )
        }

        #expect(manager.activeCount == VoiceManager.maxVoices)
    }

    @Test func voiceManagerMarksReleasedVoicesWithoutAllocatingNewCollections() async throws {
        let manager = VoiceManager()
        manager.addVoices(
            midiNote: 60,
            velocity: 0.75,
            unisonVoices: 3,
            detuneAmount: 7.0,
            spreadAmount: 0.8,
            portamento: 0.0
        )

        manager.releaseVoices(midiNote: 60)

        var releasingCount = 0
        manager.forEachActiveVoice { voice in
            if voice.midiNote == 60 && voice.isReleasing {
                releasingCount += 1
            }
            return true
        }

        #expect(releasingCount == 3)
        #expect(manager.activeCount == 3)
    }

    @Test func voiceManagerHardKillsSameNoteOnRetrigger() async throws {
        let manager = VoiceManager()
        manager.addVoices(
            midiNote: 60,
            velocity: 1.0,
            unisonVoices: 2,
            detuneAmount: 5.0,
            spreadAmount: 0.5,
            portamento: 0.0
        )
        #expect(manager.activeCount == 2)

        // Re-trigger must not leave old + new voices (double-trigger bug)
        manager.addVoices(
            midiNote: 60,
            velocity: 1.0,
            unisonVoices: 2,
            detuneAmount: 5.0,
            spreadAmount: 0.5,
            portamento: 0.0
        )
        #expect(manager.activeCount == 2)

        var count = 0
        manager.forEachActiveVoice { voice in
            if voice.midiNote == 60 {
                count += 1
                #expect(!voice.isReleasing)
            }
            return true
        }
        #expect(count == 2)
    }

    // MARK: - AtomicMeteringState

    @Test func atomicMeteringStateWriteThenReadRoundTrip() async throws {
        let metering = AtomicMeteringState()
        metering.setOutputLevel(0.42)
        metering.setPeakLevel(0.87)

        #expect(abs(metering.getOutputLevel() - 0.42) < 0.0001)
        #expect(abs(metering.getPeakLevel() - 0.87) < 0.0001)

        let scope = (0..<512).map { Float($0) / 512.0 }
        metering.writeScopeBuffer(scope)
        let read = metering.readScopeBuffer()
        #expect(read.count == 512)
        #expect(abs(read[0] - 0.0) < 0.0001)
        #expect(abs(read[256] - 256.0 / 512.0) < 0.0001)
    }

    // MARK: - ArpeggiatorEngine (all modes against cached state)

    @Test func arpeggiatorUpModeCyclesAscending() async throws {
        var arp = ArpeggiatorEngine()
        arp.mode = .up
        arp.setHeldKeys([60, 64, 67])
        var seed: UInt32 = 1

        // Primed first tick plays lowest, then cycles up
        let n1 = arp.advanceTick(randomSource: &seed)
        let n2 = arp.advanceTick(randomSource: &seed)
        let n3 = arp.advanceTick(randomSource: &seed)
        let n4 = arp.advanceTick(randomSource: &seed)

        #expect(n1 == 60)
        #expect(n2 == 64)
        #expect(n3 == 67)
        #expect(n4 == 60)
    }

    @Test func arpeggiatorDownModeCyclesDescending() async throws {
        var arp = ArpeggiatorEngine()
        arp.mode = .down
        arp.setHeldKeys([60, 64, 67])
        var seed: UInt32 = 1

        let n1 = arp.advanceTick(randomSource: &seed)
        #expect(n1 == 67)

        let n2 = arp.advanceTick(randomSource: &seed)
        #expect(n2 == 64)

        let n3 = arp.advanceTick(randomSource: &seed)
        #expect(n3 == 60)

        let n4 = arp.advanceTick(randomSource: &seed)
        #expect(n4 == 67)
    }

    @Test func arpeggiatorUpDownModeBouncesWithoutSticking() async throws {
        var arp = ArpeggiatorEngine()
        arp.mode = .upDown
        arp.setHeldKeys([60, 64, 67])
        var seed: UInt32 = 1

        var sequence: [Int] = []
        for _ in 0..<8 {
            if let n = arp.advanceTick(randomSource: &seed) {
                sequence.append(n)
            }
        }

        // Primed: 60, then up to 64, 67, bounce 64, 60, 64, 67, 64
        #expect(sequence.count == 8)
        #expect(sequence[0] == 60)
        #expect(sequence[1] == 64)
        #expect(sequence[2] == 67)
        #expect(sequence[3] == 64)
        #expect(sequence[4] == 60)
        #expect(sequence.contains(60))
        #expect(sequence.contains(67))
    }

    @Test func arpeggiatorRandomModeStaysWithinHeldKeys() async throws {
        var arp = ArpeggiatorEngine()
        arp.mode = .random
        let keys: Set<Int> = [48, 52, 55, 59]
        arp.setHeldKeys(keys)
        var seed: UInt32 = 42

        for _ in 0..<32 {
            guard let n = arp.advanceTick(randomSource: &seed) else {
                Issue.record("Random mode should always return a note when keys held")
                return
            }
            #expect(keys.contains(n))
        }
    }

    @Test func arpeggiatorOffModeReturnsNil() async throws {
        var arp = ArpeggiatorEngine()
        arp.mode = .off
        arp.setHeldKeys([60, 64])
        var seed: UInt32 = 1
        #expect(arp.advanceTick(randomSource: &seed) == nil)
    }

    // MARK: - AudioEngine RT path (shipped type, no AVAudio start required)

    @Test func audioEngineSnapshotsPresetParamsForAudioPath() async throws {
        let engine = AudioEngine()
        var preset = SynthPreset.defaultPreset
        preset.bpm = 140
        preset.arpMode = .upDown
        preset.osc2Enabled = false
        preset.unisonVoices = 4
        preset.portamento = 0.25
        preset.filterCutoff = 1234
        preset.masterVolume = 0.33
        preset.modMatrix = [
            ModMatrixEntry(source: .lfo1, destination: .pitch1, amount: 0.5)
        ]
        engine.preset = preset
        engine.applyPresetForTesting()

        let cached = engine.cachedAudioParamsForTesting()
        #expect(abs(cached.bpm - 140) < 0.001)
        #expect(cached.arpMode == .upDown)
        #expect(cached.osc2Enabled == false)
        #expect(cached.unisonVoices == 4)
        #expect(abs(cached.portamento - 0.25) < 0.0001)
        #expect(abs(cached.filterCutoff - 1234) < 0.1)
        #expect(abs(cached.masterVolume - 0.33) < 0.0001)
        #expect(cached.modMatrixCount == 1)
    }

    @Test func audioEngineNoteOnOffViaCommandQueue() async throws {
        let engine = AudioEngine()
        // Ensure arp off so noteOn pushes .noteOn
        var preset = SynthPreset.defaultPreset
        preset.arpMode = .off
        engine.preset = preset

        engine.noteOn(midiNote: 60, velocity: 0.9)
        engine.noteOn(midiNote: 64, velocity: 0.8)
        #expect(engine.activeNoteCountForTesting == 0) // not yet drained

        engine.processCommandsForTesting()
        #expect(engine.activeNoteCountForTesting == 2)
        #expect(engine.isNoteActiveForTesting(60))
        #expect(engine.isNoteActiveForTesting(64))

        engine.noteOff(midiNote: 60)
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
        #expect(engine.isNoteActiveForTesting(64))

        engine.clearAllNotes()
        engine.processCommandsForTesting()
        #expect(engine.activeNoteCountForTesting == 0)
    }

    @Test func audioEngineMeteringStateIsWritableWithoutMainHop() async throws {
        let engine = AudioEngine()
        let metering = engine.meteringStateForTesting
        metering.setOutputLevel(0.55)
        metering.setPeakLevel(0.91)
        #expect(abs(metering.getOutputLevel() - 0.55) < 0.0001)
        #expect(abs(metering.getPeakLevel() - 0.91) < 0.0001)
    }

    // MARK: - Gain staging (Этап 1)

    @Test func polyphonyScaleIsPowerPreserving() async throws {
        #expect(abs(AudioMath.polyphonyScale(activeVoices: 0) - 1.0) < 0.0001)
        #expect(abs(AudioMath.polyphonyScale(activeVoices: 1) - 1.0) < 0.0001)
        #expect(abs(AudioMath.polyphonyScale(activeVoices: 4) - 0.5) < 0.0001)
        // 1/√7 ≈ 0.37796
        #expect(abs(AudioMath.polyphonyScale(activeVoices: 7) - Float(1.0 / sqrt(7.0))) < 0.0001)
        // denser chords must be quieter per-voice scale
        #expect(AudioMath.polyphonyScale(activeVoices: 16) < AudioMath.polyphonyScale(activeVoices: 4))
    }

    @Test func softClipGuaranteesMinusSixDbHeadroom() async throws {
        let ceiling: Float = 0.5 // −6 dB
        #expect(abs(AudioMath.softClip(0.0, threshold: ceiling)) < 0.0001)
        // Quiet signals stay nearly linear (tanh(x/t)*t ≈ x for small x)
        let quiet = AudioMath.softClip(0.1, threshold: ceiling)
        #expect(abs(quiet - 0.1) < 0.02)
        // Hard peaks asymptote to ±ceiling (Float may hit exactly 0.5 via tanh≈1)
        let hot = AudioMath.softClip(10.0, threshold: ceiling)
        #expect(abs(hot) <= ceiling + 0.0001)
        #expect(hot > ceiling * 0.99) // fully driven into the knee
        // Symmetric for negative
        #expect(abs(AudioMath.softClip(-10.0, threshold: ceiling) + hot) < 0.0001)
    }

    // MARK: - Existing DSP unit tests

    @Test func noteCalculatesFrequencyNameAndBlackKey() async throws {
        let a4 = Note(midiNote: 69)
        let cSharp4 = Note(midiNote: 61)

        #expect(abs(a4.frequency - 440.0) < 0.0001)
        #expect(a4.name == "A4")
        #expect(!a4.isBlack)
        #expect(cSharp4.name == "C#4")
        #expect(cSharp4.isBlack)
    }

    @Test func compressorLimiterClampsFirstTransient() async throws {
        let limiter = Compressor(sampleRate: 48_000)
        limiter.enabled = true
        limiter.limiterMode = true
        limiter.kneeWidth = 0.0
        limiter.setAttack(0.001)
        limiter.setRelease(0.080)

        let (left, right) = limiter.processStereo(inputL: 4.0, inputR: -4.0)

        #expect(abs(left) <= 1.0)
        #expect(abs(right) <= 1.0)
    }

    @Test func adsrDecayUsesExponentialCurve() async throws {
        var envelope = ADSREnvelope()
        envelope.attack = 0.01
        envelope.decay = 1.0
        envelope.sustain = 0.5
        envelope.release = 1.0

        var phase: EnvelopePhase = .decay
        var time = 0.0
        let sampleRate = 10.0

        let first = envelope.process(
            currentValue: 1.0,
            phase: &phase,
            time: &time,
            releaseStartValue: 0.0,
            isReleasing: false,
            sampleRate: sampleRate
        )

        let expected = Float(0.5 + (1.0 - 0.5) * exp(-5.0 / sampleRate))
        #expect(abs(first - expected) < 0.0001)
        #expect(first < 0.95)
        #expect(phase == .decay)
    }

    @Test func adsrReleaseUsesExponentialCurve() async throws {
        var envelope = ADSREnvelope()
        envelope.release = 1.0

        var phase: EnvelopePhase = .release
        var time = 0.0
        let sampleRate = 10.0

        let first = envelope.process(
            currentValue: 0.8,
            phase: &phase,
            time: &time,
            releaseStartValue: 0.8,
            isReleasing: true,
            sampleRate: sampleRate
        )

        let expected = Float(0.8 * exp(-5.0 / sampleRate))
        #expect(abs(first - expected) < 0.0001)
        #expect(first < 0.8)
        #expect(phase == .release)
    }

    @Test func oscillatorPolyBLEPGuardKeepsHighDtOutputFinite() async throws {
        var oscillator = Oscillator()
        oscillator.waveform = .square
        oscillator.volume = 1.0

        let sample = oscillator.generateSample(
            phase: 0.0,
            phaseIncrement: AudioMath.twoPi * 2.0,
            noiseValue: 0.0
        )

        #expect(sample.isFinite)
        #expect(sample >= -1.0 && sample <= 1.0)
    }
}
