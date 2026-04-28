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
        let packetListMutable = UnsafeMutablePointer(mutating: packetList)
        let numPackets = packetListMutable.pointee.numPackets
        
        // Safely get pointer to the first packet using MemoryLayout
        var currentPacketPtr = UnsafeMutableRawPointer(packetListMutable)
            .advanced(by: MemoryLayout<MIDIPacketList>.offset(of: \.packet)!)
            .assumingMemoryBound(to: MIDIPacket.self)
        
        for _ in 0..<numPackets {
            let length = Int(currentPacketPtr.pointee.length)
            
            // Access packet data safely
            var bytes = [UInt8]()
            withUnsafeBytes(of: currentPacketPtr.pointee.data) { ptr in
               for i in 0..<length {
                   bytes.append(ptr[i])
               }
            }
            
            parseMIDIBytes(bytes)
            
            currentPacketPtr = MIDIPacketNext(currentPacketPtr)
        }
    }
    
    private func parseMIDIBytes(_ bytes: [UInt8]) {
        guard !bytes.isEmpty else { return }
        
        // Simple state machine or parser needed really, but for now assuming standard 3-byte messages
        var i = 0
        while i < bytes.count {
            let status = bytes[i]
            let command = status & 0xF0
            // let channel = status & 0x0F
            
            if command == 0x90 { // Note On
                if i + 2 < bytes.count {
                    let note = bytes[i+1]
                    let velocity = bytes[i+2]
                    
                    if velocity > 0 {
                        audioEngine?.noteOn(midiNote: Int(note), velocity: Float(velocity) / 127.0)
                    } else {
                        audioEngine?.noteOff(midiNote: Int(note))
                    }
                    i += 3
                } else { break }
            } else if command == 0x80 { // Note Off
                if i + 2 < bytes.count {
                    let note = bytes[i+1]
                    // let velocity = bytes[i+2]
                    
                    audioEngine?.noteOff(midiNote: Int(note))
                    i += 3
                } else { break }
            } else {
                // Skip other messages for now or implement proper parsing
                i += 1
            }
        }
    }
}
