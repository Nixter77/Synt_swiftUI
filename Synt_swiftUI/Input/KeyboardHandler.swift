//
//  KeyboardHandler.swift
//  Synt_swiftUI
//

import AppKit
import SynthCore
import SwiftUI
import Combine

class KeyboardHandler: ObservableObject {
    /// Not @Published: AudioEngine.keyDisplay drives the lit keys.
    var pressedKeys: Set<Int> = []
    @Published var baseOctave: Int = 4

    weak var audioEngine: AudioEngine?

    private var eventMonitor: Any?
    private var resignObserver: Any?
    /// Hardware keyCode → MIDI note pressed on keyDown. keyUp often has empty `characters`
    /// on a Russian layout or in chords, and may arrive while `.command` is held or after
    /// `firstResponder` changes, which used to leave notes hanging.
    private(set) var physicalKeyToNote: [UInt16: Int] = [:]

    /// ANSI key codes → semitone offset from C. Independent of keyboard layout.
    static let keyCodeToNoteOffset: [UInt16: Int] = [
        0: 0,   // A  C
        13: 1,  // W  C#
        1: 2,   // S  D
        14: 3,  // E  D#
        2: 4,   // D  E
        3: 5,   // F  F
        17: 6,  // T  F#
        5: 7,   // G  G
        16: 8,  // Y  G#
        4: 9,   // H  A
        32: 10, // U  A#
        38: 11, // J  B
        40: 12, // K  C+
        31: 13, // O  C#+
        37: 14, // L  D+
        35: 15, // P  D#+
        41: 16, // ;  E+
    ]
    static let keyCodeOctaveDown: UInt16 = 6 // Z
    static let keyCodeOctaveUp: UInt16 = 7   // X

    /// A focused text field owns the key. Note keys must not play or be swallowed.
    static func ignoresTyping(firstResponder: NSResponder?) -> Bool {
        guard let responder = firstResponder else { return false }
        return responder is NSText || responder is NSTextField
    }

    init() {}

    deinit {
        stopListening()
    }

    func startListening() {
        #if os(macOS)
        stopListening()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self = self else { return event }
            return self.processKeyEvent(event)
        }

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.releaseAllNotes()
        }
        #endif
    }

    func stopListening() {
        #if os(macOS)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
        physicalKeyToNote.removeAll()
        #endif
    }

    #if os(macOS)
    @discardableResult
    func processKeyEvent(_ event: NSEvent) -> NSEvent? {
        let code = event.keyCode
        let isOurKey = Self.keyCodeToNoteOffset[code] != nil
            || code == Self.keyCodeOctaveDown
            || code == Self.keyCodeOctaveUp

        if event.type == .keyUp {
            if let midiNote = physicalKeyToNote.removeValue(forKey: code) {
                pressedKeys.remove(midiNote)
                audioEngine?.noteOff(midiNote: midiNote)
                return nil
            }
            if event.modifierFlags.contains(.command) || Self.ignoresTyping(firstResponder: event.window?.firstResponder) {
                return event
            }
            return isOurKey ? nil : event
        }

        guard event.type == .keyDown else { return event }

        if event.modifierFlags.contains(.command) || Self.ignoresTyping(firstResponder: event.window?.firstResponder) {
            return event
        }

        guard isOurKey else { return event }

        if event.isARepeat || physicalKeyToNote[code] != nil {
            return nil
        }

        if code == Self.keyCodeOctaveDown {
            octaveDown()
            return nil
        }
        if code == Self.keyCodeOctaveUp {
            octaveUp()
            return nil
        }

        if let offset = Self.keyCodeToNoteOffset[code] {
            let midiNote = (baseOctave + 1) * 12 + offset
            physicalKeyToNote[code] = midiNote
            pressedKeys.insert(midiNote)
            audioEngine?.noteOn(midiNote: midiNote)
        }
        return nil
    }
    #endif

    func octaveUp() {
        if baseOctave < 7 {
            releaseAllNotes()
            baseOctave += 1
        }
    }

    func octaveDown() {
        if baseOctave > 0 {
            releaseAllNotes()
            baseOctave -= 1
        }
    }

    func releaseAllNotes() {
        for midiNote in pressedKeys {
            audioEngine?.noteOff(midiNote: midiNote)
        }
        pressedKeys.removeAll()
        physicalKeyToNote.removeAll()
    }

    func noteOn(midiNote: Int) {
        if !pressedKeys.contains(midiNote) {
            pressedKeys.insert(midiNote)
            audioEngine?.noteOn(midiNote: midiNote)
        }
    }

    func noteOff(midiNote: Int) {
        pressedKeys.remove(midiNote)
        audioEngine?.noteOff(midiNote: midiNote)
    }
}
