#!/usr/bin/env swift
//
//  midi_test_keys.swift — play test notes into the synth without a keyboard.
//
//  Run while the app is open:   swift Tools/midi_test_keys.swift
//  Creates a virtual MIDI source "Synth Test Keys". The app picks it up by
//  itself (hot-plug), then hears a C-major arpeggio, a chord with a bend,
//  and a final All Notes Off (CC123).
//

import CoreMIDI
import Foundation

var client = MIDIClientRef()
var source = MIDIEndpointRef()
guard MIDIClientCreateWithBlock("SynthTestKeys" as CFString, &client, nil) == noErr,
      MIDISourceCreateWithProtocol(client, "Synth Test Keys" as CFString, ._1_0, &source) == noErr else {
    print("Could not create a virtual MIDI source"); exit(1)
}

func send(_ status: UInt8, _ d1: UInt8, _ d2: UInt8) {
    var list = MIDIEventList()
    let packet = MIDIEventListInit(&list, ._1_0)
    var word = UInt32(0x2) << 28 | UInt32(status) << 16 | UInt32(d1) << 8 | UInt32(d2)
    _ = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, 0, 1, &word)
    MIDIReceivedEventList(source, &list)
}
func wait(_ s: Double) { RunLoop.current.run(until: Date().addingTimeInterval(s)) }

print("Virtual source 'Synth Test Keys' is up; waiting for the app to connect…")
wait(1.5)

for (note, velocity) in [(60, 40), (64, 70), (67, 100), (72, 127)] as [(UInt8, UInt8)] {
    print("note on  \(note) vel \(velocity)")
    send(0x90, note, velocity); wait(0.35)
    send(0x80, note, 0); wait(0.1)
}

print("chord + pitch bend up and back")
for n in [60, 64, 67] as [UInt8] { send(0x90, n, 90) }
for v in stride(from: 8192, through: 16383, by: 512) { send(0xE0, UInt8(v & 0x7F), UInt8(v >> 7)); wait(0.02) }
for v in stride(from: 16383, through: 8192, by: -512) { send(0xE0, UInt8(v & 0x7F), UInt8(v >> 7)); wait(0.02) }
send(0xE0, 0x00, 0x40)
wait(0.5)
print("CC123 all notes off")
send(0xB0, 123, 0)
wait(0.5)
MIDIEndpointDispose(source)
MIDIClientDispose(client)
print("done")
