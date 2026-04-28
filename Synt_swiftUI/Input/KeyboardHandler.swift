//
//  KeyboardHandler.swift
//  Synt_swiftUI
//

import SwiftUI
import Combine

class KeyboardHandler: ObservableObject {
    @Published var pressedKeys: Set<Int> = []
    @Published var baseOctave: Int = 4

    weak var audioEngine: AudioEngine?

    private var eventMonitor: Any?
    private var physicalKeysDown: Set<String> = []  // Track physical keys to prevent repeats

    private let keyToNoteOffset: [String: Int] = [
        "a": 0,   // C
        "w": 1,   // C#
        "s": 2,   // D
        "e": 3,   // D#
        "d": 4,   // E
        "f": 5,   // F
        "t": 6,   // F#
        "g": 7,   // G
        "y": 8,   // G#
        "h": 9,   // A
        "u": 10,  // A#
        "j": 11,  // B
        "k": 12,  // C (next octave)
        "o": 13,  // C#
        "l": 14,  // D
        "p": 15,  // D#
        ";": 16,  // E
    ]

    init() {}

    deinit {
        stopListening()
    }

    func startListening() {
        #if os(macOS)
        stopListening()

        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }

            let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

            // Check if this is a key we handle - if so, consume it (return nil)
            let isOurKey = self.keyToNoteOffset[key] != nil || key == "z" || key == "x"

            self.handleKeyEvent(event)

            // Return nil to consume the event and prevent system sound
            return isOurKey ? nil : event
        }
        #endif
    }

    func stopListening() {
        #if os(macOS)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        physicalKeysDown.removeAll()
        #endif
    }

    #if os(macOS)
    private func handleKeyEvent(_ event: NSEvent) {
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""

        if event.type == .keyDown {
            // Skip if this is a repeat event OR if we already have this key tracked
            if event.isARepeat || physicalKeysDown.contains(key) {
                return
            }

            // Handle octave change
            if key == "z" {
                octaveDown()
                return
            } else if key == "x" {
                octaveUp()
                return
            }

            // Handle note keys
            if let offset = keyToNoteOffset[key] {
                physicalKeysDown.insert(key)
                let midiNote = (baseOctave + 1) * 12 + offset
                pressedKeys.insert(midiNote)
                audioEngine?.noteOn(midiNote: midiNote)
            }
        } else if event.type == .keyUp {
            physicalKeysDown.remove(key)

            if let offset = keyToNoteOffset[key] {
                let midiNote = (baseOctave + 1) * 12 + offset
                pressedKeys.remove(midiNote)
                audioEngine?.noteOff(midiNote: midiNote)
            }
        }
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
        physicalKeysDown.removeAll()
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
