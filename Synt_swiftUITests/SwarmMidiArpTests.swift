//
//  SwarmMidiArpTests.swift
//  Synt_swiftUITests
//

import AppKit
import Foundation
import Testing
@testable import SynthCore
@testable import Synt_swiftUI

@MainActor
struct SwarmMidiArpTests {

    // MARK: - UMP Type 0x1 (System Common / Real-Time)

    @Test func umpType1SystemRealtimeDecoding() {
        #expect(MIDIDecode.ump(0x10F8_0000) == .clock)
        #expect(MIDIDecode.ump(0x15F8_0000) == .clock)
        #expect(MIDIDecode.ump(0x10FA_0000) == .songStart)
        #expect(MIDIDecode.ump(0x12FA_0000) == .songStart)
        #expect(MIDIDecode.ump(0x10FB_0000) == .songContinue)
        #expect(MIDIDecode.ump(0x10FC_0000) == .songStop)

        // Other Type 0x1 system messages and Type 0x0 utility remain ignored.
        #expect(MIDIDecode.ump(0x10F1_0000) == .ignored)
        #expect(MIDIDecode.ump(0x10F2_0000) == .ignored)
        #expect(MIDIDecode.ump(0x10FE_0000) == .ignored)
        #expect(MIDIDecode.ump(0x0000_0000) == .ignored)

        // Type 0x2 channel voice behavior remains intact.
        #expect(MIDIDecode.ump(0x2090_3C7F) == .noteOn(note: 60, velocity: 1, channel: 0))
    }

    @Test func umpType1TransportReachesEngineThroughMIDIHandler() {
        let engine = AudioEngine()
        var preset = engine.preset
        preset.syncSource = .midiClock
        engine.preset = preset
        engine.applyPresetForTesting()

        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.handleUMPWordsForTesting([0x10FA_0000, 0x10F8_0000])
        engine.processCommandsForTesting()
        #expect(engine.midiClockRunning)

        midi.handleUMPWordsForTesting([0x10FC_0000])
        engine.processCommandsForTesting()
        #expect(!engine.midiClockRunning)

        midi.handleUMPWordsForTesting([0x10FB_0000])
        engine.processCommandsForTesting()
        #expect(engine.midiClockRunning)
    }

    @Test func midiHandlerSelectDeviceSafeWithoutInputPort() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.selectDevice("Virtual Test Port")
        #expect(midi.selectedDevice == "Virtual Test Port")
        midi.selectDevice(MIDIHandler.allDevices)
        #expect(midi.selectedDevice == MIDIHandler.allDevices)
    }

    // MARK: - KeyboardHandler Cmd+keyUp stuck-note fix

    private func makeKeyEvent(
        type: NSEvent.EventType,
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags = [],
        windowNumber: Int = 0
    ) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: type,
                location: .zero,
                modifierFlags: modifiers,
                timestamp: 0,
                windowNumber: windowNumber,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: keyCode
            )
        )
    }

    @Test func keyboardHandlerReleasesNoteWhenCommandHeldOnKeyUp() throws {
        let engine = AudioEngine()
        let handler = KeyboardHandler()
        handler.audioEngine = engine

        // Press A (keyCode 0 -> MIDI note 60 at baseOctave 4)
        let keyDownA = try makeKeyEvent(type: .keyDown, keyCode: 0)
        #expect(handler.processKeyEvent(keyDownA) == nil)
        #expect(handler.physicalKeyToNote[0] == 60)
        #expect(handler.pressedKeys.contains(60))
        engine.processCommandsForTesting()
        #expect(engine.isNoteActiveForTesting(60))

        // Press Cmd+Z (keyCode 6) while holding A: passes through untouched, no octave change
        let cmdZDown = try makeKeyEvent(type: .keyDown, keyCode: 6, modifiers: .command)
        let cmdZResult = handler.processKeyEvent(cmdZDown)
        #expect(cmdZResult === cmdZDown)
        #expect(handler.baseOctave == 4)

        // Release A while Command is still held: must still release note 60 and consume keyUp
        let keyUpAWithCmd = try makeKeyEvent(type: .keyUp, keyCode: 0, modifiers: .command)
        #expect(handler.processKeyEvent(keyUpAWithCmd) == nil)
        #expect(handler.physicalKeyToNote[0] == nil)
        #expect(!handler.pressedKeys.contains(60))
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))
    }

    @Test func keyboardHandlerReleasesExactPressedNoteAcrossOctaveOrResponderChange() throws {
        let engine = AudioEngine()
        let handler = KeyboardHandler()
        handler.audioEngine = engine

        let keyDownA = try makeKeyEvent(type: .keyDown, keyCode: 0)
        #expect(handler.processKeyEvent(keyDownA) == nil)
        #expect(handler.physicalKeyToNote[0] == 60)

        // Even if baseOctave shifts directly or a text field becomes firstResponder before keyUp,
        // releasing keyCode 0 must release the original note 60.
        handler.baseOctave = 5
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        let field = NSTextField(frame: NSRect(x: 10, y: 10, width: 100, height: 24))
        window.contentView?.addSubview(field)
        window.makeFirstResponder(field)

        let keyUpAInTextField = try makeKeyEvent(type: .keyUp, keyCode: 0, windowNumber: window.windowNumber)
        #expect(handler.processKeyEvent(keyUpAInTextField) == nil)
        #expect(handler.physicalKeyToNote.isEmpty)
        #expect(!handler.pressedKeys.contains(60))
        engine.processCommandsForTesting()
        #expect(engine.isNoteReleasingForTesting(60))

        // Cmd+A down and up without prior un-commanded down must pass through untouched
        let cmdADown = try makeKeyEvent(type: .keyDown, keyCode: 0, modifiers: .command)
        #expect(handler.processKeyEvent(cmdADown) === cmdADown)
        let cmdAUp = try makeKeyEvent(type: .keyUp, keyCode: 0, modifiers: .command)
        #expect(handler.processKeyEvent(cmdAUp) === cmdAUp)
        #expect(handler.pressedKeys.isEmpty)
    }

    @Test func keyboardHandlerClearsPhysicalKeyMapOnReleaseAndStop() throws {
        let engine = AudioEngine()
        let handler = KeyboardHandler()
        handler.audioEngine = engine

        let keyDownA = try makeKeyEvent(type: .keyDown, keyCode: 0)
        #expect(handler.processKeyEvent(keyDownA) == nil)
        #expect(handler.physicalKeyToNote[0] == 60)

        handler.releaseAllNotes()
        #expect(handler.physicalKeyToNote.isEmpty)
        #expect(handler.pressedKeys.isEmpty)

        let keyDownS = try makeKeyEvent(type: .keyDown, keyCode: 1)
        #expect(handler.processKeyEvent(keyDownS) == nil)
        #expect(handler.physicalKeyToNote[1] == 62)

        handler.stopListening()
        #expect(handler.physicalKeyToNote.isEmpty)
    }

    // MARK: - ArpeggiatorEngine capacity safety

    @Test func arpeggiatorEngineCapacitySafetyAcrossThreeOctavesWith128Keys() {
        var arp = ArpeggiatorEngine()
        #expect(arp.sortedNotes.capacity >= 384)

        arp.mode = .up
        arp.octaves = 3

        var allKeys = MIDIKeySet()
        for note in 0..<128 {
            allKeys.insert(note)
        }
        arp.setHeldKeys(allKeys)

        // 128 + 116 + 104 = 348 valid MIDI notes across 3 octaves, strictly <= 384.
        #expect(arp.sortedNotes.count == 348)
        #expect(arp.sortedNotes.count <= 384)
        #expect(arp.sortedNotes.capacity >= 384)

        // Even with a large asPlayed list, sortedNotes must stay capped at <= 384 without reallocating.
        arp.mode = .asPlayed
        let repeatedOrder = Array(repeating: 10, count: 200)
        arp.setHeldKeys(allKeys, playedOrder: repeatedOrder)
        #expect(arp.sortedNotes.count == 384)
        #expect(arp.sortedNotes.capacity >= 384)
    }

    // MARK: - SyntArpAUViewController main-thread safety check

    @Test func syntArpViewControllerDispatchesUIAttachToMainInCreateAudioUnit() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("SyntArpAUv3/SyntArpAUViewController.swift")
        let source = try String(contentsOf: url, encoding: .utf8)
        let start = try #require(source.range(of: "func createAudioUnit("))
        let end = try #require(source.range(of: "return unit", range: start.upperBound..<source.endIndex))
        let body = String(source[start.upperBound..<end.lowerBound])
        #expect(body.contains("DispatchQueue.main.async"))
        #expect(!body.contains("preferredContentSize"))
        #expect(!body.contains("NSHostingView"))
    }
}
