//
//  MIDIHandler.swift
//  Synt_swiftUI
//
//  Handles CoreMIDI inputs and routing to AudioEngine
//

import Foundation
import CoreMIDI

class MIDIHandler: ObservableObject {
    @Published var availableDevices: [String] = []
    @Published var selectedDevice: String = "All"
    
    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var sources: [String: MIDIEndpointRef] = [:]
    weak var audioEngine: AudioEngine?
    
    init() {
        setupMIDI()
    }

    deinit {
        for (_, src) in sources {
            MIDIPortDisconnectSource(inputPort, src)
        }
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }
        if client != 0 {
            MIDIClientDispose(client)
        }
    }
    
    private func setupMIDI() {
        var status = MIDIClientCreate("Synt_swiftUI_Client" as CFString, nil, nil, &client)
        if status != noErr {
            print("Error creating MIDI client: \(status)")
            return
        }
        
        status = MIDIInputPortCreateWithBlock(client, "Synt_swiftUI_Input" as CFString, &inputPort) { [weak self] packetList, _ in
            self?.handleMIDIPacketList(packetList)
        }
        
        if status != noErr {
            print("Error creating MIDI input port: \(status)")
            return
        }
        
        refreshDevices()
        
        // Auto-select first if available
        if let first = availableDevices.first {
            selectDevice(first)
        }
    }
    
    func refreshDevices() {
        sources.removeAll()
        var deviceNames: [String] = []
        let sourceCount = MIDIGetNumberOfSources()
        
        for i in 0..<sourceCount {
            let src = MIDIGetSource(i)
            if let name = getDeviceName(for: src) {
                sources[name] = src
                deviceNames.append(name)
            }
        }
        
        DispatchQueue.main.async {
            self.availableDevices = deviceNames
        }
    }
    
    func selectDevice(_ name: String) {
        // Disconnect all currently connected
        // For simplicity, we disconnect everything then connect the selected one
        // Ideally we track connected ones.
        for (_, src) in sources {
             MIDIPortDisconnectSource(inputPort, src)
        }
        
        // The old device can't send its bend-center / pedal-up any more.
        // Main thread → UI ring (the MIDI ring has one producer: CoreMIDI).
        audioEngine?.pitchBend(0)
        audioEngine?.sustainPedal(down: false)

        if let src = sources[name] {
            let status = MIDIPortConnectSource(inputPort, src, nil)
            if status == noErr {
                print("Connected to MIDI device: \(name)")
                DispatchQueue.main.async {
                    self.selectedDevice = name
                }
            } else {
                print("Failed to connect to \(name): \(status)")
            }
        }
    }
    
    private func getDeviceName(for endpoint: MIDIEndpointRef) -> String? {
        var name: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyName, &name)
        if status == noErr, let name = name?.takeRetainedValue() {
            return name as String
        }
        return nil
    }
    
    private func handleMIDIPacketList(_ packetList: UnsafePointer<MIDIPacketList>) {
        let numPackets = packetList.pointee.numPackets
        var packet = UnsafeRawPointer(packetList)
            .advanced(by: MemoryLayout<MIDIPacketList>.offset(of: \.packet)!)
            .assumingMemoryBound(to: MIDIPacket.self)
        let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!

        for _ in 0..<numPackets {
            // Read `length` bytes in place. The `data` tuple is only 256 long, but a
            // SysEx packet can be longer, so never go through the tuple; no [UInt8] either.
            let length = Int(packet.pointee.length)
            let bytes = UnsafeRawPointer(packet).advanced(by: dataOffset)
                .assumingMemoryBound(to: UInt8.self)
            for k in 0..<length {
                feed(bytes[k])
            }
            packet = UnsafePointer(MIDIPacketNext(packet))
        }
    }

    func parseMIDIBytesForTesting(_ bytes: [UInt8]) {
        for b in bytes { feed(b) }
    }

    // MARK: - Byte parser (CoreMIDI thread only)

    /// Channel-voice status kept for running status. 0 = none.
    private var runningStatus: UInt8 = 0
    private var inSysEx = false
    private var data0: UInt8 = 0
    private var dataCount = 0

    private func feed(_ b: UInt8) {
        if b >= 0xF8 { return }                     // realtime: ignore, keep running status
        if b == 0xF0 { inSysEx = true; runningStatus = 0; dataCount = 0; return }
        if b == 0xF7 { inSysEx = false; return }
        if b & 0x80 != 0 {
            inSysEx = false
            dataCount = 0
            // System common (F1–F6) cancels running status; its data is dropped.
            runningStatus = b < 0xF0 ? b : 0
            return
        }
        if inSysEx || runningStatus == 0 { return }

        let command = runningStatus & 0xF0
        let needed = (command == 0xC0 || command == 0xD0) ? 1 : 2
        if dataCount == 0 && needed == 2 {
            data0 = b
            dataCount = 1
            return
        }
        let d1 = needed == 2 ? data0 : b
        let d2 = needed == 2 ? b : 0
        dataCount = 0
        dispatch(command: command, d1: d1, d2: d2)
    }

    private func dispatch(command: UInt8, d1: UInt8, d2: UInt8) {
        switch command {
        case 0x90:
            if d2 > 0 {
                audioEngine?.midiNoteOn(midiNote: Int(d1), velocity: Float(d2) / 127.0)
            } else {
                audioEngine?.midiNoteOff(midiNote: Int(d1))
            }
        case 0x80:
            audioEngine?.midiNoteOff(midiNote: Int(d1))
        case 0xE0:
            let value = (Int(d2) << 7) | Int(d1)
            let normalized: Float = value >= 8192
                ? Float(value - 8192) / 8191
                : Float(value - 8192) / 8192
            audioEngine?.midiPitchBend(normalized)
        case 0xB0:
            if d1 == 1 {
                audioEngine?.midiModWheel(Float(d2) / 127)
            } else if d1 == 64 {
                audioEngine?.midiSustainPedal(down: d2 >= 64)
            }
        default:
            break
        }
    }
}
