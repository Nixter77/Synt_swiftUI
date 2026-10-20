//
//  MIDIHandler.swift
//  Synt_swiftUI
//
//  CoreMIDI input → AudioEngine.
//
//  Threads:
//  - main: device list, connect / disconnect, hot-plug (client notify block).
//  - CoreMIDI receive thread: decodes UMP words and pushes into
//    `AudioEngine.midiQueue` (lock-free SPSC; this thread is its only producer).
//    No locks, no allocation, no @Published writes on that thread.
//

import Foundation
import CoreMIDI
import os
import Synchronization

/// Display-only MIDI activity. Only `MIDIStatusView` observes it, so a note
/// never invalidates ContentView. Safe to post from the CoreMIDI thread:
/// updates are coalesced into at most one main-queue hop at a time.
final class MIDIActivityModel: ObservableObject, @unchecked Sendable {
    @Published private(set) var lastNote: String = "—"
    @Published private(set) var isActive = false

    /// bit 31 = has note, bits 8…15 = note, bits 0…7 = velocity.
    private let latest = Atomic<UInt32>(0)
    private let scheduled = Atomic<Bool>(false)
    private var blinkGeneration = 0

    /// Any thread.
    func post(note: UInt8, velocity: UInt8) {
        latest.store(0x8000_0000 | UInt32(note) << 8 | UInt32(velocity), ordering: .relaxed)
        schedule()
    }

    /// Any thread. Non-note traffic (bend, CC): blink only.
    func touch() {
        schedule()
    }

    private func schedule() {
        guard !scheduled.exchange(true, ordering: .acquiringAndReleasing) else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.scheduled.store(false, ordering: .releasing)
            let packed = self.latest.load(ordering: .relaxed)
            if packed & 0x8000_0000 != 0 {
                let note = Int((packed >> 8) & 0x7F)
                let velocity = Int(packed & 0x7F)
                let text = "\(Note.noteName(for: note)) · \(velocity)"
                if text != self.lastNote { self.lastNote = text }
            }
            if !self.isActive { self.isActive = true }
            self.blinkGeneration &+= 1
            let generation = self.blinkGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self, self.blinkGeneration == generation else { return }
                self.isActive = false
            }
        }
    }
}

final class MIDIHandler: ObservableObject {
    static let allDevices = "All"
    private static let log = Logger(subsystem: "Home.Synt-swiftUI", category: "MIDI")

    /// Source display names, in CoreMIDI order. Main thread.
    @Published private(set) var availableDevices: [String] = []
    /// `MIDIHandler.allDevices` or one name from `availableDevices`.
    @Published private(set) var selectedDevice: String = MIDIHandler.allDevices
    /// Sources currently connected to the input port.
    @Published private(set) var connectedDevices: [String] = []
    /// Non-nil when CoreMIDI could not be set up.
    @Published private(set) var setupError: String?

    let activity = MIDIActivityModel()
    /// Latest CC values waiting for the main-thread display update.
    let ccDisplay = CCCoalescer()

    /// Main thread.
    func drainCCDisplay() {
        let batch = ccDisplay.drain()
        guard !batch.isEmpty else { return }
        audioEngine?.applyCCBatchFromMIDI(batch)
    }
    /// Set once in `init`, before the input port exists; read on the CoreMIDI thread.
    let audioEngine: AudioEngine?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    /// Main thread only.
    private var connected: [MIDIEndpointRef: String] = [:]

    /// Byte-stream parser for `parseMIDIBytesForTesting` (legacy packet format).
    private var byteParser = MIDIByteParser()

    /// `coreMIDI: false` builds the parser/dispatch path only (no client, no port,
    /// no device scan). The default is off under the XCTest host.
    init(audioEngine: AudioEngine?, coreMIDI: Bool = !RuntimeEnvironment.isUnitTestHost) {
        self.audioEngine = audioEngine
        if coreMIDI { setupMIDI() }
    }

    deinit {
        // Disposing the port drops its connections, and disposing the client
        // drops the port, so `connected` (main-only state) isn't read here.
        if inputPort != 0 { MIDIPortDispose(inputPort) }
        if client != 0 { MIDIClientDispose(client) }
    }

    // MARK: - Setup

    private func setupMIDI() {
        var status = MIDIClientCreateWithBlock("Synt_swiftUI_Client" as CFString, &client) { [weak self] notification in
            // Delivered on the run loop that created the client (main).
            // One plug / unplug sends ObjectAdded/Removed *and* SetupChanged;
            // SetupChanged alone covers it, so one rescan per change.
            guard Self.shouldRescan(for: notification.pointee.messageID) else { return }
            if Thread.isMainThread {
                self?.rescan()
            } else {
                DispatchQueue.main.async { self?.rescan() }
            }
        }
        guard status == noErr else {
            reportSetupError("MIDIClientCreate failed (\(status))")
            return
        }

        // MIDI 1.0 protocol: CoreMIDI hands us UMP words (type 0x2 for channel voice).
        status = MIDIInputPortCreateWithProtocol(
            client, "Synt_swiftUI_Input" as CFString, ._1_0, &inputPort
        ) { [weak self] eventList, _ in
            self?.handleEventList(eventList)
        }
        guard status == noErr else {
            reportSetupError("MIDIInputPortCreate failed (\(status))")
            return
        }

        rescan()
    }

    /// Only `msgSetupChanged` triggers a rescan (it follows every add / remove).
    static func shouldRescan(for message: MIDINotificationMessageID) -> Bool {
        message == .msgSetupChanged
    }

    private func reportSetupError(_ message: String) {
        Self.log.error("\(message, privacy: .public)")
        if Thread.isMainThread {
            setupError = message
        } else {
            DispatchQueue.main.async { self.setupError = message }
        }
    }

    // MARK: - Devices (main thread)

    /// Re-reads the source list and (re)connects what the selection asks for.
    /// Called on launch, on hot-plug, and from the menu.
    func rescan() {
        guard inputPort != 0 else { return }
        let found = Self.currentSources()
        let names = Self.uniqueNames(found.map(\.name))
        let sources = zip(found.map(\.ref), names).map { (ref: $0.0, name: $0.1) }

        let wanted: [(ref: MIDIEndpointRef, name: String)] = selectedDevice == Self.allDevices
            ? sources
            : sources.filter { $0.name == selectedDevice }
        let wantedRefs = Set(wanted.map(\.ref))

        // Unplugged or deselected: disconnect, and make sure nothing keeps ringing.
        var lostAny = false
        for (ref, _) in connected where !wantedRefs.contains(ref) {
            MIDIPortDisconnectSource(inputPort, ref)
            connected[ref] = nil
            lostAny = true
        }
        if lostAny { releaseEverything() }

        for source in wanted where connected[source.ref] == nil {
            let status = MIDIPortConnectSource(inputPort, source.ref, nil)
            if status == noErr {
                connected[source.ref] = source.name
            } else {
                Self.log.error("Failed to connect \(source.name, privacy: .public) (\(status))")
            }
        }
        for source in wanted where connected[source.ref] != nil { connected[source.ref] = source.name }

        let connectedNames = sources.filter { connected[$0.ref] != nil }.map(\.name)
        if availableDevices != names { availableDevices = names }
        if connectedDevices != connectedNames { connectedDevices = connectedNames }
    }

    func selectDevice(_ name: String) {
        guard name != selectedDevice else { rescan(); return }
        selectedDevice = name
        // The old device can't send its note-offs / bend-center / pedal-up any more.
        for ref in connected.keys { MIDIPortDisconnectSource(inputPort, ref) }
        connected.removeAll()
        releaseEverything()
        rescan()
    }

    /// Main thread. Raises the engine's reset flag; the audio thread applies it
    /// after the MIDI ring, so late events from the lost device can't outlive it.
    func releaseEverything() {
        audioEngine?.requestMIDIReset()
    }

    private static func currentSources() -> [(ref: MIDIEndpointRef, name: String)] {
        var out: [(ref: MIDIEndpointRef, name: String)] = []
        for i in 0..<MIDIGetNumberOfSources() {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }
            out.append((src, displayName(for: src) ?? "MIDI Source \(i + 1)"))
        }
        return out
    }

    /// Two identical keyboards get "Name", "Name (2)".
    static func uniqueNames(_ names: [String]) -> [String] {
        var seen: [String: Int] = [:]
        return names.map { name in
            let n = (seen[name] ?? 0) + 1
            seen[name] = n
            return n == 1 ? name : "\(name) (\(n))"
        }
    }

    private static func displayName(for endpoint: MIDIEndpointRef) -> String? {
        for key in [kMIDIPropertyDisplayName, kMIDIPropertyName] {
            var value: Unmanaged<CFString>?
            if MIDIObjectGetStringProperty(endpoint, key, &value) == noErr,
               let s = value?.takeRetainedValue() as String?, !s.isEmpty {
                return s
            }
        }
        return nil
    }

    // MARK: - Receive (CoreMIDI thread)

    /// Byte offset of `words` inside a packet; constant, so computed once.
    private static let wordsOffset = MemoryLayout<MIDIEventPacket>.offset(of: \.words)!

    private func handleEventList(_ list: UnsafePointer<MIDIEventList>) {
        let wordsOffset = Self.wordsOffset
        for packet in list.unsafeSequence() {
            let count = Int(packet.pointee.wordCount)
            let words = UnsafeRawPointer(packet).advanced(by: wordsOffset)
                .assumingMemoryBound(to: UInt32.self)
            var i = 0
            while i < count {
                let word = words[i]
                dispatch(MIDIDecode.ump(word))
                i += MIDIDecode.umpWordCount(firstWord: word)
            }
        }
    }

    /// Feeds raw MIDI 1.0 bytes (running status, SysEx…) through the same path.
    func parseMIDIBytesForTesting(_ bytes: [UInt8]) {
        for b in bytes {
            if let message = byteParser.feed(b) { dispatch(message) }
        }
    }

    /// The real receive entry point, fed a caller-built `MIDIEventList`.
    func handleEventListForTesting(_ list: UnsafePointer<MIDIEventList>) {
        handleEventList(list)
    }

    /// Feeds UMP words exactly as the CoreMIDI callback does.
    func handleUMPWordsForTesting(_ words: [UInt32]) {
        var i = 0
        while i < words.count {
            dispatch(MIDIDecode.ump(words[i]))
            i += MIDIDecode.umpWordCount(firstWord: words[i])
        }
    }

    private func dispatch(_ message: MIDIMessage) {
        switch message {
        case let .noteOn(note, velocity, _):
            audioEngine?.midiNoteOn(midiNote: Int(note), velocity: velocity)
            activity.post(note: note, velocity: UInt8((velocity * 127).rounded()))
        case let .noteOff(note, _):
            audioEngine?.midiNoteOff(midiNote: Int(note))
        case let .pitchBend(value, _):
            audioEngine?.midiPitchBend(value)
            activity.touch()
        case let .modWheel(value, _):
            audioEngine?.midiModWheel(value)
            activity.touch()
        case let .sustain(down, _):
            audioEngine?.midiSustainPedal(down: down)
            activity.touch()
        case let .channelPressure(pressure, _):
            audioEngine?.midiAftertouch(pressure)
            activity.touch()
        case let .polyPressure(note, pressure, _):
            audioEngine?.midiPolyAftertouch(midiNote: Int(note), pressure: pressure)
            activity.touch()
        case .allNotesOff:
            audioEngine?.midiAllNotesOff()
        case .allSoundOff:
            audioEngine?.midiAllSoundOff()
        case let .programChange(program, _):
            // Rare (a button press), so one main hop is fine here.
            let n = Int(program)
            DispatchQueue.main.async { [weak self] in self?.applyProgramChange(n) }
        case let .controlChange(controller, value, _):
            activity.touch()
            if let engine = audioEngine {
                // DSP: audio thread only. Display (preset / Apple FX): one coalesced main hop.
                _ = engine.midiQueue.push(.controlChange(cc: controller, value: value))
                if ccDisplay.post(cc: controller, value: value) {
                    DispatchQueue.main.async { [weak self] in self?.drainCCDisplay() }
                }
            }
        case .ignored:
            break
        }
    }

    /// Main thread. Program N (0-based) loads factory preset N+1 in browse
    /// order (same number as the "NNN / 100" counter); N ≥ 100 is ignored.
    func applyProgramChange(_ program: Int) {
        guard let engine = audioEngine, let preset = PresetBrowser.preset(forProgram: program) else { return }
        engine.preset = preset
    }
}
