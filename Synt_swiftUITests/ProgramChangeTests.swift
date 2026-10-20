//
//  ProgramChangeTests.swift
//  MIDI Program Change → factory preset (0-based, browse order).
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct ProgramChangeTests {
    @Test func parserDecodesProgramChange() {
        var p = MIDIByteParser()
        #expect(p.parse([0xC3, 41]) == [.programChange(program: 41, channel: 3)])
        // Running status: two program changes in a row.
        #expect(p.parse([0xC0, 1, 2]) == [.programChange(program: 1, channel: 0), .programChange(program: 2, channel: 0)])
        #expect(MIDIDecode.ump(0x20C0_2A00) == .programChange(program: 42, channel: 0))
    }

    @Test func applyProgramChangeLoadsThatPreset() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.applyProgramChange(41)
        #expect(engine.preset.name == PresetBrowser.list[41].name)
        #expect(PresetBrowser.counterLabel(for: engine.preset) == "042 / 100")
        midi.applyProgramChange(0)
        #expect(engine.preset.name == PresetBrowser.list[0].name)
    }

    @Test func programsBeyondTheLibraryAreIgnored() {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.applyProgramChange(5)
        let before = engine.preset.name
        midi.applyProgramChange(100)
        midi.applyProgramChange(127)
        #expect(engine.preset.name == before)
    }

    @Test func programChangeBytesReachTheEngineViaMain() async {
        let engine = AudioEngine()
        let midi = MIDIHandler(audioEngine: engine, coreMIDI: false)
        midi.parseMIDIBytesForTesting([0xC0, 7])
        // The handler hops to the main queue; a later main-actor hop runs after it.
        await MainActor.run {}
        #expect(engine.preset.name == PresetBrowser.list[7].name)
    }
}
