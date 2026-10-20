//
//  ModMatrixView.swift
//  Synt_swiftUI
//

import SwiftUI
import SynthCore

func modSources(_ destination: ModDestination, in entries: [ModMatrixEntry]) -> [ModSource] {
    var seen: [ModSource] = []
    for entry in entries where entry.destination == destination {
        if !seen.contains(entry.source) { seen.append(entry.source) }
    }
    return seen
}

/// Rows past this height scroll. Keeps the grid inside its ~470 pt budget.
let modMatrixScrollMaxHeight: CGFloat = 260

struct ModMatrixView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    private var atCapacity: Bool { preset.modMatrix.count >= RTModMatrix.capacity }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                AppleSectionHeader(title: "MOD MATRIX", accent: theme.aMod, icon: "arrow.triangle.branch")
                Spacer()
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(theme.textDim)
                    .help("Each row scales a source onto one destination. Cutoff and resonance follow the loudest note, because the filter is shared.")
                Button(action: addEntry) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(atCapacity ? theme.textFaint : theme.aMod)
                }
                .buttonStyle(.plain)
                .disabled(atCapacity)
                .help(atCapacity ? "16 rows is the limit." : "Add Velocity → Amp at +30%")
            }

            entryList
        }
        .padding(8)
        .appleCard(accent: theme.aMod)
    }

    private var entryList: some View {
        let list = VStack(spacing: 4) {
            ForEach($preset.modMatrix) { $entry in
                matrixRow($entry)
            }
            if preset.modMatrix.isEmpty {
                Text("No patches")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(theme.textFaint)
                    .padding(.vertical, 4)
            }
        }
        return Group {
            if preset.modMatrix.count > 2 {
                ScrollView { list }
                    .frame(maxHeight: modMatrixScrollMaxHeight)
            } else {
                list
            }
        }
    }

    private func matrixRow(_ entry: Binding<ModMatrixEntry>) -> some View {
        let row = entry.wrappedValue
        let warn = row.source == .lfo1 && !preset.lfoEnabled && preset.lfoTarget != .none
        // Two lines: the pickers get the full column width (min 140 pt), the
        // knob and icons sit below, so the menus never collapse to arrows.
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Picker("Source", selection: entry.source) {
                    ForEach(ModSource.allCases, id: \.self) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()

                Image(systemName: "arrow.right")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textFaint)

                Picker("Destination", selection: entry.destination) {
                    Section("Oscillator") {
                        ForEach([ModDestination.pitch1, .pitch2, .pwm1, .pwm2, .wtMorph1, .wtMorph2, .mix], id: \.self) { dest in
                            Text(dest.menuTitle).tag(dest)
                        }
                    }
                    Section("Filter") {
                        ForEach([ModDestination.cutoff, .resonance], id: \.self) { dest in
                            Text(dest.menuTitle).tag(dest)
                        }
                    }
                    Section("Amp") {
                        ForEach([ModDestination.amp, .pan], id: \.self) { dest in
                            Text(dest.menuTitle).tag(dest)
                        }
                    }
                    Section("LFO") {
                        ForEach([ModDestination.lfoRate, .lfoDepth], id: \.self) { dest in
                            Text(dest.menuTitle).tag(dest)
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            HStack(spacing: 6) {
                KnobView(
                    value: entry.amount,
                    range: -1...1,
                    label: "Amt",
                    valueText: row.destination.formatAmount(row.amount)
                )

                if warn {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(theme.destructive)
                        .help("LFO is off and still has a direct target. This row runs the LFO on its own.")
                }

                Button(action: { removeEntry(row.id) }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(theme.destructive)
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
            }
        }
        .padding(6)
        .background(theme.panel)
        .cornerRadius(6)
        .help(rowHelp(row))
    }

    private func rowHelp(_ row: ModMatrixEntry) -> String {
        let polarity: String
        switch row.source {
        case .env1: polarity = "Env 1 is 0…1."
        case .lfo1: polarity = preset.lfoEnabled ? "LFO 1 is bipolar." : "LFO 1 is off, so it runs only for the matrix."
        case .velocity: polarity = "Velocity is 0…1."
        case .lfo2: polarity = preset.lfo2Enabled ? "LFO 2 is bipolar." : "LFO 2 is off, so it runs only for the matrix."
        case .modWheel: polarity = "Mod Wheel is 0…1."
        case .keyTrack: polarity = "Key Track is relative to middle C."
        case .env2: polarity = "Env 2 (Filter) is 0…1."
        case .aftertouch: polarity = "Aftertouch is 0…1."
        case .macro1, .macro2, .macro3, .macro4: polarity = "\(row.source.rawValue) is performance macro."
        case .modEnv: polarity = "Mod Env is 0…1."
        case .pitchBend: polarity = "Pitch Bend is bipolar."
        case .random: polarity = "Random is bipolar per voice."
        case .sampleAndHold: polarity = "Sample & Hold is stepped random."
        }
        let action: String
        switch row.destination {
        case .cutoff:
            action = "\(row.source.rawValue) moves Cutoff by \(row.destination.formatAmount(row.amount)). The filter is shared, so the loudest note leads."
        case .pwm1, .pwm2:
            action = "\(row.source.rawValue) moves pulse width. It acts only on Pulse."
        case .lfoRate:
            action = "\(row.source.rawValue) scales LFO rate by \(row.destination.formatAmount(row.amount))."
        default:
            action = "\(row.source.rawValue) → \(row.destination.menuTitle) \(row.destination.formatAmount(row.amount))."
        }
        return "\(action) \(polarity)"
    }

    private func addEntry() {
        guard preset.modMatrix.count < RTModMatrix.capacity else { return }
        preset.modMatrix.append(ModMatrixEntry(source: .velocity, destination: .amp, amount: 0.30))
    }

    private func removeEntry(_ id: UUID) {
        preset.modMatrix.removeAll { $0.id == id }
    }
}
