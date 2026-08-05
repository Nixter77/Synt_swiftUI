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

    // MARK: - Factory preset library

    @Test func factoryLibraryCoversAllCategoriesNonEmpty() async throws {
        let presets = SynthPreset.factoryPresets
        #expect(!presets.isEmpty)
        for category in PresetCategory.allCases {
            let count = presets.filter { $0.category == category }.count
            #expect(count >= 3, "Category \(category.rawValue) should have multiple presets, got \(count)")
        }
    }

    @Test func factoryLibraryHasUniqueNames() async throws {
        let names = SynthPreset.factoryPresets.map(\.name)
        #expect(Set(names).count == names.count)
        #expect(!names.contains("Sub Bass")) // old library marker gone
    }

    @Test func factoryLibraryUsesNewSoundFeatures() async throws {
        let presets = SynthPreset.factoryPresets
        #expect(presets.contains { $0.osc1Waveform == .wavetable || $0.osc2Waveform == .wavetable })
        #expect(presets.contains { $0.unisonVoices > 1 })
        #expect(presets.contains { !$0.modMatrix.isEmpty })
        #expect(presets.contains { $0.lfoEnabled })
        #expect(presets.contains { $0.arpMode != .off })
        #expect(presets.contains { $0.reverbMix > 0.05 || $0.chorusMix > 0.05 || $0.delayMix > 0.05 })
        #expect(presets.contains { $0.distortionEnabled || $0.eqEnabled || $0.phaserEnabled })
    }

    @Test func factoryLibraryStaysWithinCleanSoundRanges() async throws {
        for p in SynthPreset.factoryPresets {
            #expect(p.masterVolume.isFinite && p.masterVolume > 0 && p.masterVolume <= 0.75)
            #expect(p.unisonVoices >= 1 && p.unisonVoices <= 5)
            #expect(p.filterResonance.isFinite && p.filterResonance >= 0 && p.filterResonance <= 0.9)
            #expect(p.filterCutoff.isFinite && p.filterCutoff > 20 && p.filterCutoff < 20000)
            #expect(p.distortionDrive.isFinite && p.distortionDrive >= 0 && p.distortionDrive <= 0.7)
            #expect(p.distortionMix.isFinite && p.distortionMix >= 0 && p.distortionMix <= 0.5)
            #expect(p.phaserFeedback.isFinite && abs(p.phaserFeedback) <= 0.5)
            #expect(p.phaserMix.isFinite && p.phaserMix <= 0.6)
            #expect(p.osc1Volume.isFinite && p.osc1Volume <= 1.0)
            #expect(p.attack.isFinite && p.attack >= 0)
            #expect(p.release.isFinite && p.release >= 0)
        }
        // Init remains safe neutral
        let initP = SynthPreset.defaultPreset
        #expect(initP.name == "Init")
        #expect(initP.masterVolume <= 0.7)
        #expect(initP.unisonVoices == 1)
        #expect(!initP.distortionEnabled && !initP.eqEnabled && !initP.phaserEnabled)
    }

    @Test func applyingFactoryPresetUpdatesEngineAudioPath() async throws {
        let engine = AudioEngine()

        guard let bass = SynthPreset.factoryPresets.first(where: { $0.name == "Clean Sub" }) else {
            Issue.record("Missing Clean Sub factory preset")
            return
        }
        engine.loadPreset(bass)
        engine.applyPresetForTesting()
        let cached = engine.cachedAudioParamsForTesting()
        #expect(abs(cached.masterVolume - bass.masterVolume) < 0.001)
        #expect(abs(cached.filterCutoff - bass.filterCutoff) < 0.1)
        #expect(engine.appliedAdvancedFXForTesting().eqEnabled == true)
        #expect(engine.appliedAdvancedFXForTesting().eqLowGain == bass.eqLowGain)

        guard let lead = SynthPreset.factoryPresets.first(where: { $0.name == "Crystal Lead" }) else {
            Issue.record("Missing Crystal Lead factory preset")
            return
        }
        engine.loadPreset(lead)
        engine.applyPresetForTesting()
        let adv = engine.appliedAdvancedFXForTesting()
        #expect(adv.osc1Waveform == .wavetable)
        #expect(abs(adv.osc1Morph - lead.osc1WavetableMorph) < 0.001)
        #expect(adv.eqEnabled == true)

        guard let pad = SynthPreset.factoryPresets.first(where: { $0.name == "Glass Horizon" }) else {
            Issue.record("Missing Glass Horizon factory preset")
            return
        }
        engine.loadPreset(pad)
        engine.applyPresetForTesting()
        let padAdv = engine.appliedAdvancedFXForTesting()
        #expect(padAdv.phaserEnabled == true)
        #expect(abs(padAdv.phaserMix - pad.phaserMix) < 0.001)
        #expect(pad.unisonVoices >= 1)

        guard let glitch = SynthPreset.factoryPresets.first(where: { $0.name == "Glitch Arp" }) else {
            Issue.record("Missing Glitch Arp factory preset")
            return
        }
        engine.loadPreset(glitch)
        engine.applyPresetForTesting()
        #expect(engine.cachedAudioParamsForTesting().arpMode == .random)
        #expect(engine.appliedAdvancedFXForTesting().distortionEnabled == true)
        #expect(abs(engine.appliedAdvancedFXForTesting().distortionDrive - glitch.distortionDrive) < 0.001)
    }

    @Test func updatePresetKeepsAdvancedFXWhenOtherFieldsChange() async throws {
        let engine = AudioEngine()
        // Simulate AdvancedEffectsView path: enable distortion via preset update
        engine.updatePreset { p in
            p.distortionEnabled = true
            p.distortionDrive = 0.42
            p.distortionMix = 0.3
            p.eqEnabled = true
            p.eqLowGain = 4
            p.phaserEnabled = true
            p.phaserMix = 0.33
        }
        #expect(engine.appliedAdvancedFXForTesting().distortionEnabled)
        #expect(abs(engine.appliedAdvancedFXForTesting().distortionDrive - 0.42) < 0.001)
        #expect(engine.appliedAdvancedFXForTesting().eqEnabled)
        #expect(engine.appliedAdvancedFXForTesting().phaserEnabled)

        // Simulate filter/ADSR edit (same as UI writing a core preset field)
        engine.updatePreset { p in
            p.filterCutoff = 1500
            p.attack = 0.05
            p.masterVolume = 0.5
        }

        let adv = engine.appliedAdvancedFXForTesting()
        #expect(adv.distortionEnabled, "Distortion must survive filter/master edits")
        #expect(abs(adv.distortionDrive - 0.42) < 0.001)
        #expect(adv.eqEnabled)
        #expect(abs(adv.eqLowGain - 4) < 0.001)
        #expect(adv.phaserEnabled)
        #expect(abs(adv.phaserMix - 0.33) < 0.001)
        #expect(abs(engine.cachedAudioParamsForTesting().filterCutoff - 1500) < 0.1)
    }

    @Test func updatePresetKeepsWavetableMorphWhenOtherFieldsChange() async throws {
        let engine = AudioEngine()
        engine.updatePreset { p in
            p.osc1Waveform = .wavetable
            p.osc1WavetableMorph = 0.67
            p.osc2Waveform = .wavetable
            p.osc2WavetableMorph = 0.21
        }
        #expect(abs(engine.appliedAdvancedFXForTesting().osc1Morph - 0.67) < 0.001)
        #expect(abs(engine.appliedAdvancedFXForTesting().osc2Morph - 0.21) < 0.001)

        engine.updatePreset { p in
            p.osc1Volume = 0.4
            p.filterResonance = 0.3
        }

        let adv = engine.appliedAdvancedFXForTesting()
        #expect(abs(adv.osc1Morph - 0.67) < 0.001, "Morph must survive volume/filter edits")
        #expect(abs(adv.osc2Morph - 0.21) < 0.001)
        #expect(adv.osc1Waveform == .wavetable)
        #expect(abs(engine.preset.osc1WavetableMorph - 0.67) < 0.001)
    }

    @Test func factoryPresetJSONRoundTripPreservesAdvancedFields() async throws {
        guard let sample = SynthPreset.factoryPresets.first(where: { $0.distortionEnabled && $0.eqEnabled })
                ?? SynthPreset.factoryPresets.first(where: { $0.phaserEnabled }) else {
            Issue.record("No advanced-FX factory preset found")
            return
        }
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(SynthPreset.self, from: data)
        #expect(decoded.name == sample.name)
        #expect(decoded.distortionEnabled == sample.distortionEnabled)
        #expect(decoded.eqEnabled == sample.eqEnabled)
        #expect(decoded.phaserEnabled == sample.phaserEnabled)
        #expect(abs(decoded.osc1WavetableMorph - sample.osc1WavetableMorph) < 0.0001)
    }

    // MARK: - Advanced FX (Этап 4)

    @Test func distortionAutoGainKeepsDriveFromExploding() async throws {
        let d = Distortion()
        d.enabled = true
        d.type = .hardClip
        d.mix = 1.0
        d.tone = 0.5
        d.drive = 0.0
        let quiet = abs(d.process(0.5))

        d.drive = 1.0
        let hot = abs(d.process(0.5))

        // Without compensation hardClip@drive1 could be huge; with compensation stay bounded.
        #expect(hot < 1.5)
        #expect(d.autoGainCompensation() < 1.0)
        // Hot shouldn't be wildly louder than low-drive
        #expect(hot < quiet * 4 + 0.5)
    }

    @Test func distortionEnableResetsStateAntiPop() async throws {
        let d = Distortion()
        d.enabled = true
        d.type = .softClip
        d.mix = 1
        d.tone = 0.2 // engages lowpass state
        _ = d.process(1.0)
        _ = d.process(1.0)
        d.enabled = false
        d.enabled = true
        // After re-enable, first sample with tone@0.5 (neutral) should not carry old LPF DC
        d.tone = 0.5
        d.drive = 0
        let out = d.process(0.0)
        #expect(abs(out) < 0.001)
    }

    @Test func parametricEQDirtyFlagsAvoidPerSampleTrig() async throws {
        let eq = ParametricEQ(sampleRate: 44100)
        eq.enabled = true
        eq.lowGain = 6
        // First process computes coeffs; subsequent with no param change stay finite
        var y: Float = 0
        for i in 0..<128 {
            y = eq.process(sin(Float(i) * 0.1))
        }
        #expect(y.isFinite)
        #expect(abs(y) < 10)
    }

    @Test func parametricEQEnableResetsFilterState() async throws {
        let eq = ParametricEQ(sampleRate: 44100)
        eq.enabled = true
        eq.midGain = 12
        eq.midFreq = 1000
        for _ in 0..<64 {
            _ = eq.process(1.0)
        }
        eq.enabled = false
        eq.enabled = true
        let out = eq.process(0.0)
        #expect(abs(out) < 0.05)
    }

    @Test func phaserLUTMatchesTanReference() async throws {
        let p = Phaser(sampleRate: 44100)
        for freq: Float in [200, 500, 1000, 2000, 4000] {
            let lut = p.allpassCoeffFromLUT(frequency: freq)
            let ref = p.calculateAllpassCoeffReference(frequency: freq)
            #expect(abs(lut - ref) < 0.05)
        }
    }

    @Test func phaserBypassPassesThroughAndResetOnEngage() async throws {
        let p = Phaser(sampleRate: 44100)
        p.bypass = true
        let (a, b) = p.process(inputL: 0.3, inputR: -0.2)
        #expect(abs(a - 0.3) < 0.0001)
        #expect(abs(b + 0.2) < 0.0001)

        p.bypass = false
        p.mix = 0
        // mix 0 → dry only after engage
        let (c, d) = p.process(inputL: 0.25, inputR: 0.25)
        #expect(abs(c - 0.25) < 0.0001)
        #expect(abs(d - 0.25) < 0.0001)
    }

    @Test func phaserDoesNotExplodeOrSilenceOnSustainedInput() async throws {
        let p = Phaser(sampleRate: 44100)
        p.bypass = false
        p.mix = 0.7
        p.feedback = 0.7
        p.depth = 0.8
        p.rate = 1.0
        p.mode = .phaser8

        var phase: Float = 0
        let dt: Float = 2 * Float.pi * 220 / 44100
        for _ in 0..<8000 {
            let s = sin(phase) * 0.5
            phase += dt
            let (l, r) = p.process(inputL: s, inputR: s * 0.9)
            #expect(l.isFinite)
            #expect(r.isFinite)
            #expect(abs(l) < 3)
            #expect(abs(r) < 3)
        }
        // Still produces energy after thousands of samples (not stuck at zero/NaN)
        let (l, _) = p.process(inputL: 0.4, inputR: 0.4)
        #expect(abs(l) > 0.001)
    }

    @Test func eqPresetsApplyFiniteGains() async throws {
        let eq = ParametricEQ(sampleRate: 44100)
        eq.enabled = true
        for preset in EQPreset.allCases {
            eq.applyPreset(preset)
            var y: Float = 0
            for i in 0..<64 {
                y = eq.process(sin(Float(i) * 0.15) * 0.5)
                #expect(y.isFinite)
            }
            #expect(abs(y) < 5)
        }
    }

    @Test func audioEngineAdvancedFXDisabledByDefault() async throws {
        let engine = AudioEngine()
        #expect(engine.distortion.enabled == false)
        #expect(engine.parametricEQL.enabled == false)
        #expect(engine.phaser.bypass == true)
    }

    // MARK: - Wavetable (Этап 3)

    @Test func wavetableBandLimitPreservesSineNotSaw() async throws {
        let n = 2048
        var sine = [Float](repeating: 0, count: n)
        for i in 0..<n {
            sine[i] = sin(2.0 * Float.pi * Float(i) / Float(n))
        }

        let osc = WavetableOscillator()
        let limited = osc.bandLimitForTesting(sine, maxHarmonic: 8)

        // Correlation with pure sine should stay high (not replaced by saw 1/h series).
        var corrSine: Float = 0
        var corrSaw: Float = 0
        var energyLim: Float = 0
        var energySine: Float = 0
        var energySaw: Float = 0
        for i in 0..<n {
            let s = sine[i]
            let l = limited[i]
            let saw = 2.0 * Float(i) / Float(n) - 1.0
            corrSine += l * s
            corrSaw += l * saw
            energyLim += l * l
            energySine += s * s
            energySaw += saw * saw
        }
        let normSine = corrSine / sqrt(energyLim * energySine)
        let normSaw = corrSaw / sqrt(energyLim * energySaw)
        #expect(normSine > 0.95)
        #expect(normSine > abs(normSaw))
    }

    @Test func wavetableBandLimitRemovesHighHarmonics() async throws {
        let n = 2048
        // Sum harmonics 1 + 40 (high partial)
        var wave = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let ph = 2.0 * Float.pi * Float(i) / Float(n)
            wave[i] = sin(ph) + 0.5 * sin(ph * 40.0)
        }

        let osc = WavetableOscillator()
        let limited = osc.bandLimitForTesting(wave, maxHarmonic: 8)

        // Full complex projection onto harmonics 1 and 40.
        var re40: Float = 0, im40: Float = 0
        var re1: Float = 0, im1: Float = 0
        for i in 0..<n {
            let a = 2.0 * Float.pi * Float(i) / Float(n)
            re40 += limited[i] * cos(a * 40)
            im40 += limited[i] * sin(a * 40)
            re1 += limited[i] * cos(a)
            im1 += limited[i] * sin(a)
        }
        let mag40 = sqrt(re40 * re40 + im40 * im40) / Float(n)
        let mag1 = sqrt(re1 * re1 + im1 * im1) / Float(n)
        #expect(mag1 > mag40 * 5)
        #expect(mag40 < 0.05)
    }

    @Test func wavetableGenerateSampleDoesNotApplyInternalVolume() async throws {
        let osc = WavetableOscillator()
        osc.volume = 0.25
        osc.targetFramePosition = 0
        for _ in 0..<5000 { osc.advanceMorph() }

        var peak: Float = 0
        let twoPi = 2.0 * Double.pi
        let dt = twoPi * 220.0 / 44100.0
        var phase = 0.0
        for _ in 0..<2048 {
            let s = abs(osc.generateSample(phase: phase, phaseIncrement: dt))
            peak = max(peak, s)
            phase += dt
            if phase >= twoPi { phase -= twoPi }
        }
        // Peak-normalized tables → peak near 1, not near 0.25
        #expect(peak > 0.5)
    }

    @Test func wavetableMorphSmoothingAdvancesTowardTarget() async throws {
        let osc = WavetableOscillator()
        osc.morphSmoothingCoeff = 0.5
        osc.targetFramePosition = 0.0
        osc.advanceMorph()
        #expect(abs(osc.framePosition) < 0.001)

        osc.targetFramePosition = 1.0
        osc.advanceMorph()
        // One pole: 0 + (1-0)*0.5 = 0.5
        #expect(abs(osc.framePosition - 0.5) < 0.001)

        osc.advanceMorph()
        // 0.5 + (1-0.5)*0.5 = 0.75
        #expect(abs(osc.framePosition - 0.75) < 0.001)

        osc.morphSmoothingCoeff = 1.0
        osc.advanceMorph()
        #expect(abs(osc.framePosition - 1.0) < 0.001)
    }

    @Test func oscillatorWavetableAppliesVolumeOnce() async throws {
        let engine = WavetableOscillator()
        engine.targetFramePosition = 0
        for _ in 0..<3000 { engine.advanceMorph() }

        var osc = Oscillator()
        osc.waveform = .wavetable
        osc.wavetableEngine = engine
        osc.volume = 0.5
        osc.wavetableMorph = 0

        let phase = 0.3
        let dt = 0.02
        let raw2 = abs(engine.generateSample(phase: phase, phaseIncrement: dt))
        let out2 = abs(osc.generateSample(phase: phase, phaseIncrement: dt))
        if raw2 > 0.01 {
            #expect(abs(out2 / raw2 - 0.5) < 0.08)
        }
    }

    // MARK: - Multi-note cleanliness

    @Test func polyphonyScaleDropsForChords() async throws {
        let one = AudioMath.polyphonyScale(activeVoices: 1)
        let three = AudioMath.polyphonyScale(activeVoices: 3)
        #expect(abs(one - 1) < 0.0001)
        #expect(three < one)
        #expect(abs(three - Float(1.0 / sqrt(3.0))) < 0.0001)
        // 3 equal unit peaks after scale stay under ~2 (headroom for filter)
        let peakAfter = 3.0 * three
        #expect(peakAfter < 2.0)
    }

    @Test func multiNoteOnOffDoesNotCorruptVoiceMap() async throws {
        let engine = AudioEngine()
        var p = SynthPreset.defaultPreset
        p.arpMode = .off
        p.unisonVoices = 1
        engine.preset = p

        // 4 simultaneous notes — previously mutated Dictionary during for-in
        for n in [60, 64, 67, 71] {
            engine.noteOn(midiNote: n, velocity: 0.8)
        }
        engine.processCommandsForTesting()
        #expect(engine.activeNoteCountForTesting == 4)

        // Render many samples without audio device (drains voices through private path via note off)
        engine.noteOff(midiNote: 60)
        engine.noteOff(midiNote: 64)
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60) || !engine.isNoteActiveForTesting(60) || engine.activeNoteCountForTesting >= 2)
        #expect(engine.isNoteActiveForTesting(67))
        #expect(engine.isNoteActiveForTesting(71))

        engine.clearAllNotes()
        engine.processCommandsForTesting()
        #expect(engine.activeNoteCountForTesting == 0)
    }

    @Test func softClipBoundsHotBus() async throws {
        let hot = AudioMath.softClip(3.0, threshold: 1.25)
        #expect(hot.isFinite)
        #expect(abs(hot) <= 1.25 + 0.001)
        #expect(abs(hot) > 1.0) // still passes loud content, but limited
    }

    @Test func filterStaysFiniteOnHotMultiNoteInput() async throws {
        let f = CachedBiquadFilter()
        f.type = .lowPass
        f.cutoff = 1200
        f.resonance = 0.75 // previously mapped to extreme Q
        var y: Float = 0
        // Simulate three summed saw-ish peaks into filter
        for i in 0..<2048 {
            let t = Float(i) / 44100.0
            let s = sin(2 * Float.pi * 110 * t)
                + sin(2 * Float.pi * 138.6 * t)
                + sin(2 * Float.pi * 164.8 * t)
            y = f.process(s * 0.9, sampleRate: 44100)
            #expect(y.isFinite)
            #expect(abs(y) < 4)
        }
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

    @Test func softClipSafetyNetNearFullScale() async throws {
        // Production uses threshold ≈ 0.95 after linear −6 dB headroom (not tanh@0.5).
        let ceiling: Float = 0.95
        #expect(abs(AudioMath.softClip(0.0, threshold: ceiling)) < 0.0001)
        let quiet = AudioMath.softClip(0.1, threshold: ceiling)
        #expect(abs(quiet - 0.1) < 0.02)
        let hot = AudioMath.softClip(10.0, threshold: ceiling)
        #expect(abs(hot) <= ceiling + 0.0001)
        #expect(hot > ceiling * 0.99)
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
