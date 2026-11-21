//
//  SwarmAudioCoreTests.swift
//  Synt_swiftUITests
//
//  Unit tests for audio-core swarm fixes:
//  - Thread-safe Audio Output Recorder & stop() cleanup
//  - Complete resetRenderStateForAllocation()
//  - AUv3 plain stereo delay tempo sync in adoptHostContext()
//  - Sequencer tie/slide microtuning & zero-portamento frequency updates
//  - True stereo scope ring buffer & phase correlation
//  - DSPFormantFilter prepare signature without dead scratch buffers
//  - ScalaParser empty description, non-finite rejection, 0.0 cents, malformed bounds
//  - MIDIFileBuilder swing timing & small-PPQN ratchet non-overlap
//  - PresetManager thread-safety & UserDefaults .sanitized() on load
//  - PatchHistoryManager drag suppression
//

import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
@Suite struct SwarmAudioCoreTests {

    // MARK: - Stereo Scope & Phase Correlation

    @Test func stereoScopeRingBufferAndPhaseCorrelation() {
        let n = 512
        let metering = AtomicMeteringState(bufferSize: n)
        #expect(!metering.hasStereoScopeData)
        #expect(metering.getPhaseCorrelation() == 1.0)

        let mono: [Float] = (0..<n).map { i in
            sin(2.0 * Float.pi * 4.0 * Float(i) / Float(n)) * 0.5
        }
        let inverted: [Float] = mono.map { -$0 }
        let quadRight: [Float] = (0..<n).map { i in
            cos(2.0 * Float.pi * 4.0 * Float(i) / Float(n)) * 0.5
        }
        let silence = [Float](repeating: 0.0, count: n)

        // +1.0 for identical mono channels
        mono.withUnsafeBufferPointer { bufL in
            mono.withUnsafeBufferPointer { bufR in
                metering.writeStereoScopeBuffer(left: bufL, right: bufR)
            }
        }
        #expect(metering.hasStereoScopeData)
        #expect(abs(metering.getPhaseCorrelation() - 1.0) < 1e-4)
        let readMono = metering.readStereoScopeBuffer()
        #expect(readMono.left == mono)
        #expect(readMono.right == mono)

        // -1.0 for inverted channels
        mono.withUnsafeBufferPointer { bufL in
            inverted.withUnsafeBufferPointer { bufR in
                metering.writeStereoScopeBuffer(left: bufL, right: bufR)
            }
        }
        #expect(abs(metering.getPhaseCorrelation() - (-1.0)) < 1e-4)
        let readInv = metering.readStereoScopeBuffer()
        #expect(readInv.left == mono)
        #expect(readInv.right == inverted)

        // 0.0 for orthogonal / uncorrelated channels
        mono.withUnsafeBufferPointer { bufL in
            quadRight.withUnsafeBufferPointer { bufR in
                metering.writeStereoScopeBuffer(left: bufL, right: bufR)
            }
        }
        #expect(abs(metering.getPhaseCorrelation()) < 1e-4)

        // 1.0 fallback on silence
        silence.withUnsafeBufferPointer { bufL in
            silence.withUnsafeBufferPointer { bufR in
                metering.writeStereoScopeBuffer(left: bufL, right: bufR)
            }
        }
        #expect(metering.getPhaseCorrelation() == 1.0)

        // 1.0 fallback on non-finite input
        var nonFinite = mono
        nonFinite[10] = .nan
        nonFinite.withUnsafeBufferPointer { bufL in
            mono.withUnsafeBufferPointer { bufR in
                metering.writeStereoScopeBuffer(left: bufL, right: bufR)
            }
        }
        #expect(metering.getPhaseCorrelation() == 1.0)
    }

    @Test func audioEnginePopulatesStereoAndMonoScopeBuffersDuringRender() {
        let engine = AudioEngine(coreOnly: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 512)

        var preset = SynthPreset.defaultPreset
        preset.pan = -1.0
        preset.unisonVoices = 1
        preset.chorusMix = 0
        preset.delayMix = 0
        preset.reverbMix = 0
        engine.preset = preset
        engine.applyPresetForTesting()

        engine.noteOn(midiNote: 60, velocity: 1.0)
        engine.processCommandsForTesting()

        for _ in 0..<512 {
            _ = engine.renderOneSample()
        }

        #expect(engine.meteringState.hasStereoScopeData)
        let stereo = engine.meteringState.readStereoScopeBuffer()
        let mono = engine.meteringState.readScopeBuffer()
        #expect(stereo.left.count == 512)
        #expect(stereo.right.count == 512)
        #expect(mono.count == 512)

        let energyL = stereo.left.reduce(Float(0)) { $0 + $1 * $1 }
        let energyR = stereo.right.reduce(Float(0)) { $0 + $1 * $1 }
        #expect(energyL > 0.01)
        #expect(energyL > energyR * 100.0)
    }

    // MARK: - Audio Output Recorder

    @Test func audioRecorderClearsURLAndStopsCleanlyOnEngineStop() {
        let engine = AudioEngine()
        let url1 = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwarmRec1_\(UUID().uuidString).wav")
        let url2 = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwarmRec2_\(UUID().uuidString).wav")
        defer {
            try? FileManager.default.removeItem(at: url1)
            try? FileManager.default.removeItem(at: url2)
        }

        #expect(engine.startRecording(to: url1))
        #expect(engine.isRecording)
        #expect(engine.stopRecording() == url1)
        #expect(!engine.isRecording)
        // Second call must return nil because recordingURL was cleared.
        #expect(engine.stopRecording() == nil)

        // Starting again and calling stop() cleanly closes recording without leaving tap active.
        #expect(engine.startRecording(to: url2))
        #expect(engine.isRecording)
        engine.stop()
        #expect(!engine.isRecording)
        #expect(engine.stopRecording() == nil)
    }

    // MARK: - resetRenderStateForAllocation & AUv3 Tempo Sync

    @Test func resetRenderStateForAllocationClearsPostAndStereoEffects() {
        let engine = AudioEngine(coreOnly: true, audioUnitHosted: true)
        engine.prepare(sampleRate: 44_100, maxFrames: 512)

        // Prime stereoTool Haas buffer, frequencyShifter feedback, characterTone, transientShaper, sceneHPF, compressor, and fades.
        for i in 0..<256 {
            let s = sin(Float(i) * 0.1) * 0.8
            _ = engine.stereoTool.process(
                left: s,
                right: -s,
                width: 1.5,
                midSide: 0.2,
                haasMs: 10.0,
                monoBassHz: 150.0,
                sampleRate: 44_100
            )
            _ = engine.frequencyShifter.process(
                inputL: s,
                inputR: -s,
                shiftHz: 120.0,
                mix: 1.0,
                feedback: 0.8,
                sampleRate: 44_100
            )
            _ = engine.characterToneL.process(s, mode: .warm, sampleRate: 44_100)
            _ = engine.characterToneR.process(-s, mode: .warm, sampleRate: 44_100)
            _ = engine.transientShaper.process(left: s, right: -s, attack: 0.5, sustain: 0.5, output: 1.0, mix: 1.0)
            _ = engine.sceneHPF.process(left: s, right: -s, hz: 120.0, sampleRate: 44_100)
        }
        engine.busGlueCompressor.configureBusGlueProfile()
        _ = engine.busGlueCompressor.processStereo(inputL: 0.9, inputR: 0.9)
        engine.sendFadeA = 0.75
        engine.sendFadeB = 0.65
        engine.lastRenderedSampleL = 0.42
        engine.lastRenderedSampleR = -0.42
        engine.envelopeFollowerRT = 0.5
        engine.envelopeFollowerValue = 0.5

        engine.resetRenderStateForAllocation()

        #expect(engine.sendFadeA == 0)
        #expect(engine.sendFadeB == 0)
        #expect(engine.lastRenderedSampleL == 0)
        #expect(engine.lastRenderedSampleR == 0)
        #expect(engine.envelopeFollowerRT == 0)
        #expect(engine.envelopeFollowerValue == 0)
        #expect(engine.busGlueCompressor.currentGainReduction == 0)

        let stereoAfter = engine.stereoTool.process(
            left: 0,
            right: 0,
            width: 1.5,
            midSide: 0.2,
            haasMs: 10.0,
            monoBassHz: 150.0,
            sampleRate: 44_100
        )
        #expect(stereoAfter.0 == 0 && stereoAfter.1 == 0)

        let shifterAfter = engine.frequencyShifter.process(
            inputL: 0,
            inputR: 0,
            shiftHz: 120.0,
            mix: 1.0,
            feedback: 0.8,
            sampleRate: 44_100
        )
        #expect(shifterAfter.left == 0 && shifterAfter.right == 0)

        let charAfterL = engine.characterToneL.process(0, mode: .warm, sampleRate: 44_100)
        let charAfterR = engine.characterToneR.process(0, mode: .warm, sampleRate: 44_100)
        #expect(charAfterL == 0 && charAfterR == 0)

        let hpfAfter = engine.sceneHPF.process(left: 0, right: 0, hz: 120.0, sampleRate: 44_100)
        #expect(hpfAfter.0 == 0 && hpfAfter.1 == 0)
    }

    @Test func auv3PlainStereoDelayTempoSyncUpdatesOnHostBPM() {
        let engine = AudioEngine(coreOnly: true, audioUnitHosted: true)
        #expect(engine.rendersAllDelayInDSP)

        var preset = SynthPreset.defaultPreset
        preset.delayPingPong = false
        preset.delayTempoSync = true
        preset.delaySyncDivision = .quarter
        engine.preset = preset
        engine.applyPresetForTesting()

        // Explicitly clear cachedDelayPingPong to verify rendersAllDelayInDSP alone suffices.
        engine.cachedDelayPingPong = false
        engine.adoptHostContext(tempo: 150.0, transportMoving: true)

        let expected = TimeDivision.quarter.duration(bpm: 150.0)
        #expect(abs(engine.pingPongDelay.delayTime - expected) < 1e-5)
    }

    // MARK: - Sequencer Tie Microtuning & Zero Portamento

    @Test func sequencerTieUsesScalaMicrotuningAndMovesImmediatelyAtZeroPortamento() {
        let engine = AudioEngine(coreOnly: true)
        var preset = SynthPreset.defaultPreset
        preset.bpm = 120.0
        preset.portamento = 0.0
        preset.unisonVoices = 1
        engine.preset = preset
        engine.applyPresetForTesting()

        var customTable = ScalaParser.standard12TETTable()
        let microtuned64 = 400.0
        customTable[64] = microtuned64
        engine.customTuningTable = customTable

        var pattern = [SequencerStep](repeating: SequencerStep(), count: 16)
        pattern[0] = SequencerStep(isActive: true, noteOffset: 0, tie: false, gate: 0.9)
        pattern[1] = SequencerStep(isActive: true, noteOffset: 4, tie: true, gate: 0.9)

        engine.sequencerTransport.publish(
            playing: true,
            swing: 0,
            bpm: 120.0,
            rootNote: 60,
            length: 2,
            generation: 1,
            gate: 0.9,
            patternSteps: pattern
        )

        // Step 0 triggers on first sample
        _ = engine.renderOneSample()
        #expect(engine.seqMirror.heldNote == 60)

        // Advance past step 0 boundary into step 1 (tied)
        let stepSamples = Int(engine.sampleRate * 60.0 / 120.0 / 4.0) + 2
        for _ in 0..<stepSamples {
            _ = engine.renderOneSample()
        }

        #expect(engine.seqMirror.heldNote == 64)
        let tiedVoice = engine.voices.first { $0.isActive && !$0.isReleasing && $0.midiNote == 64 }
        #expect(tiedVoice != nil)
        #expect(tiedVoice?.targetFrequency == microtuned64)
        #expect(tiedVoice?.currentFrequency == microtuned64)
        #expect(abs((tiedVoice?.currentFrequency ?? 0) - AudioMath.midiToFrequency(64)) > 50.0)
    }

    // MARK: - DSPFormantFilter

    @Test func formantFilterPrepareSignatureWorksWithoutScratchBuffers() {
        let filter = DSPFormantFilter(sampleRate: 44_100, maxFrames: 512)
        filter.prepare(sampleRate: 48_000, maxFrames: 256)
        let out = filter.process(0.4)
        #expect(out.isFinite)
        #expect(abs(out) > 0)
    }

    // MARK: - ScalaParser

    @Test func scalaParserAllowsEmptyDescriptionAndZeroCents() throws {
        let emptyDescScl = """
        ! Comment before empty description

        5
        9/8
        5/4
        3/2
        5/3
        2/1
        """
        let scale = try ScalaParser.parse(emptyDescScl)
        #expect(scale.description == "")
        #expect(scale.noteCount == 5)
        #expect(scale.ratios.count == 5)
        #expect(abs(scale.ratios[0] - 1.125) < 1e-9)

        let crlfEmptyDesc = "\r\n1\r\n0.0\r\n"
        let unisonScale = try ScalaParser.parse(crlfEmptyDesc)
        #expect(unisonScale.description == "")
        #expect(unisonScale.noteCount == 1)
        #expect(unisonScale.ratios == [1.0])
    }

    @Test func scalaParserRejectsNonFinitePitchesAndGuardsMalformedScaleBounds() {
        let nonFiniteInputs = [
            "Desc\n1\nnan",
            "Desc\n1\ninf",
            "Desc\n1\n-inf",
            "Desc\n1\n1e500",
            "Desc\n1\n1e500.0",
            "Desc\n1\ninf/1",
            "Desc\n1\n1/inf",
            "Desc\n1\n100000000.0"
        ]
        for input in nonFiniteInputs {
            #expect(throws: ScalaParseError.self) {
                _ = try ScalaParser.parse(input)
            }
        }

        // Comment-only or empty must still report .emptyFile
        #expect(throws: ScalaParseError.emptyFile) {
            _ = try ScalaParser.parse("! comment only\n")
        }

        // Malformed scale with fewer ratios than noteCount must not crash
        let malformed = ScalaScale(description: "Malformed", noteCount: 12, ratios: [1.5, 2.0])
        let table = ScalaParser.makeFrequencyTable(scale: malformed)
        #expect(table.count == 128)
        #expect(abs(table[69] - 440.0) < 0.01)
    }

    // MARK: - MIDIFileBuilder

    private func parseTrackNoteEvents(_ smf: Data) -> [(tick: UInt32, status: UInt8, note: UInt8)] {
        let bytes = [UInt8](smf)
        // Find "MTrk" header (starts at offset 14 for standard 14-byte MThd)
        var idx = 22
        var tick: UInt32 = 0
        var events: [(tick: UInt32, status: UInt8, note: UInt8)] = []

        func readVLQ() -> UInt32 {
            var value: UInt32 = 0
            while idx < bytes.count {
                let b = bytes[idx]
                idx += 1
                value = (value << 7) | UInt32(b & 0x7F)
                if b & 0x80 == 0 { break }
            }
            return value
        }

        while idx < bytes.count {
            tick += readVLQ()
            guard idx < bytes.count else { break }
            let status = bytes[idx]
            idx += 1
            if status == 0xFF {
                guard idx < bytes.count else { break }
                let metaType = bytes[idx]
                idx += 1
                let len = Int(readVLQ())
                idx += len
                if metaType == 0x2F { break }
            } else if status == 0x90 || status == 0x80 {
                guard idx + 1 < bytes.count else { break }
                let note = bytes[idx]
                idx += 2 // note + velocity
                events.append((tick: tick, status: status, note: note))
            }
        }
        return events
    }

    @Test func midiFileBuilderAppliesSwingAndPreventsRatchetOverlapAtSmallPPQN() {
        var swingSteps = [SequencerStep](repeating: SequencerStep(), count: 16)
        swingSteps[0] = SequencerStep(isActive: true, noteOffset: 0, gate: 0.5)
        swingSteps[1] = SequencerStep(isActive: true, noteOffset: 2, gate: 0.5)

        let swungData = MIDIFileBuilder.buildSMF(
            steps: swingSteps,
            rootNote: 60,
            bpm: 120.0,
            length: 2,
            ppqn: 480,
            swing: 0.5
        )
        let swungEvents = parseTrackNoteEvents(swungData)
        let noteOns = swungEvents.filter { $0.status == 0x90 }
        #expect(noteOns.count == 2)
        // Step 0 on grid (tick 0), Step 1 delayed by 0.5 * 0.5 * 120 = 30 ticks -> 150
        #expect(noteOns[0].tick == 0)
        #expect(noteOns[1].tick == 150)

        // Small PPQN ratchet non-overlap check: ppqn = 16 -> ticksPerStep = 4, ratchet = 4 -> subTicks = 1
        var ratchetSteps = [SequencerStep](repeating: SequencerStep(), count: 16)
        ratchetSteps[0] = SequencerStep(isActive: true, noteOffset: 0, gate: 1.0, ratchet: 4)
        ratchetSteps[1] = SequencerStep(isActive: true, noteOffset: 0, gate: 1.0, ratchet: 1)

        let ratchetData = MIDIFileBuilder.buildSMF(
            steps: ratchetSteps,
            rootNote: 60,
            bpm: 120.0,
            length: 2,
            ppqn: 16,
            swing: 0.0
        )
        let ratchetEvents = parseTrackNoteEvents(ratchetData)
        let rNoteOns = ratchetEvents.filter { $0.status == 0x90 && $0.note == 60 }
        let rNoteOffs = ratchetEvents.filter { $0.status == 0x80 && $0.note == 60 }
        #expect(rNoteOns.count == 5)
        #expect(rNoteOffs.count == 5)

        var activeNotes = 0
        for ev in ratchetEvents where ev.note == 60 {
            if ev.status == 0x80 {
                activeNotes -= 1
            } else if ev.status == 0x90 {
                activeNotes += 1
            }
            #expect(activeNotes >= 0 && activeNotes <= 1, "Same-note events must never overlap")
        }
        #expect(activeNotes == 0)
    }

    // MARK: - PatchHistoryManager Drag Suppression

    @Test func patchHistorySuppressesRecordChangeDuringDragAndRecordsSingleStepOnEnd() {
        let history = PatchHistoryManager(maxSteps: 64)
        let p0 = SynthPreset.defaultPreset
        var current = p0
        history.registerPresetProvider { current }

        history.onDragStart()
        for step in 1...10 {
            var next = current
            next.filterCutoff = Float(1000 + step * 100)
            history.recordChange(from: current, to: next)
            current = next
        }
        #expect(history.undoActions.isEmpty)

        history.onDragEnd()
        #expect(history.undoActions.count == 1)
        let undone = history.undo()
        #expect(undone?.preset == p0)

        // Same behavior via beginGesture / endGesture
        var p1 = p0
        p1.filterResonance = 0.65
        var p2 = p1
        p2.filterResonance = 0.85

        history.beginGesture(preset: p0)
        history.recordChange(from: p0, to: p1)
        #expect(history.undoActions.isEmpty)
        history.endGesture(currentPreset: p2)
        #expect(history.undoActions.count == 1)
        #expect(history.undo()?.preset == p0)
    }

    // MARK: - PresetManager Thread Safety & Sanitization

    @Test func presetManagerThreadSafetyAndSanitizedLoadFromDefaults() {
        let manager = PresetManager.shared
        let uniqueName = "SwarmTest_\(UUID().uuidString.prefix(8))"
        defer {
            manager.deleteUserPreset(name: uniqueName)
        }

        var hostile = SynthPreset(name: uniqueName, category: .bass)
        hostile.bpm = 9999
        hostile.filterCutoff = 99_999

        // Perform save & reload off the main thread synchronously
        DispatchQueue.global(qos: .userInitiated).sync {
            manager.saveUserPreset(hostile)
            manager.loadPresets()
            let found = manager.userPresets.first { $0.name == uniqueName }
            #expect(found != nil)
            #expect(found?.bpm == 300)
            #expect(found?.filterCutoff == 22_000)
            #expect(manager.nameExists(uniqueName))
        }
    }
}
