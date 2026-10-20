//
//  MIDIStatusView.swift
//  Synt_swiftUI
//
//  Header pill: MIDI source picker, connection dot (blinks on input), last note.
//

import SwiftUI

struct MIDIStatusView: View {
    @Environment(\.theme) private var theme
    @ObservedObject var midi: MIDIHandler
    @ObservedObject var activity: MIDIActivityModel

    private var isConnected: Bool { !midi.connectedDevices.isEmpty }

    private var label: String {
        if midi.setupError != nil { return "MIDI error" }
        if midi.selectedDevice == MIDIHandler.allDevices {
            switch midi.connectedDevices.count {
            case 0: return "MIDI: no device"
            case 1: return "MIDI: \(midi.connectedDevices[0])"
            default: return "MIDI: All (\(midi.connectedDevices.count))"
            }
        }
        return isConnected ? "MIDI: \(midi.selectedDevice)" : "MIDI: \(midi.selectedDevice) (offline)"
    }

    private var tint: Color { isConnected ? theme.positive : theme.textFaint }

    var body: some View {
        HStack(spacing: 6) {
            Menu {
                Button {
                    midi.selectDevice(MIDIHandler.allDevices)
                } label: {
                    item("All devices", selected: midi.selectedDevice == MIDIHandler.allDevices)
                }
                if midi.availableDevices.isEmpty {
                    Text("No MIDI sources")
                } else {
                    Divider()
                    ForEach(midi.availableDevices, id: \.self) { device in
                        Button {
                            midi.selectDevice(device)
                        } label: {
                            item(device, selected: midi.selectedDevice == device)
                        }
                    }
                }
                Divider()
                Button("Load Samson Graphite 49 Map") {
                    MIDICCLearnStore.shared.applySamsonGraphite49Template()
                }
                Button("Clear All MIDI CC Mappings") {
                    MIDICCLearnStore.shared.clearMappings()
                }
                Divider()
                Button("Rescan") { midi.rescan() }
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(activity.isActive ? theme.accent : tint)
                        .frame(width: 6, height: 6)
                    Text(label)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(tint)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 170, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(tint)
                }
                .padding(4)
                .background(tint.opacity(0.1))
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(midi.setupError ?? "MIDI input. Plugged-in devices connect automatically.")

            Text(activity.lastNote)
                .font(theme.monoFont(size: 10, weight: .regular))
                .foregroundColor(theme.textDim)
                .lineLimit(1)
                .frame(minWidth: 44, alignment: .leading)
                .help("Last MIDI note · velocity")
        }
        .accessibilityIdentifier("midiStatus")
    }

    @ViewBuilder
    private func item(_ title: String, selected: Bool) -> some View {
        if selected {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}
