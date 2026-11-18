//
//  FXChainView.swift
//  Synt_swiftUI
//
//  Reorderable rack containing all 6 FX slots: Distortion, EQ, Phaser, Chorus, Delay, Reverb.
//  Maintains total height within grid budget (all slots start collapsed when bypass/mix=0).
//

import SwiftUI
import UniformTypeIdentifiers
import SynthCore

struct FXChainView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset
    var audioEngine: AudioEngine? = nil

    @State private var draggedSlot: FXSlotID?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 8) {
                ForEach(preset.fxOrder, id: \.self) { slot in
                    slotCard(for: slot)
                        .onDrag {
                            draggedSlot = slot
                            return NSItemProvider(object: slot.rawValue as NSString)
                        }
                        .onDrop(of: [.text, .plainText], delegate: FXSlotDropDelegate(
                            item: slot,
                            order: Binding(
                                get: { preset.fxOrder },
                                set: { updateOrder($0) }
                            ),
                            draggedItem: $draggedSlot
                        ))
                }

                HStack(spacing: 6) {
                    Text("MASTER & MOD FX")
                        .themeCaption(theme, size: 9, weight: .semibold)
                        .foregroundColor(theme.textFaint)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    RoundedRectangle(cornerRadius: 1)
                        .fill(theme.border.opacity(0.6))
                        .frame(height: 1)
                }
                .padding(.top, 2)
                .padding(.horizontal, 2)

                characterAndGlueCard
                frequencyShifterCard
                sendsCard
                stereoCard
                rotaryCard
                transientCard
                tranceCard
                sceneHPFCard
                smoothCard
            }
        }
    }

    private func updateOrder(_ newOrder: [FXSlotID]) {
        let clean = SynthPreset.sanitizeFXOrder(newOrder)
        if let audioEngine {
            audioEngine.setFXOrder(clean)
        } else {
            preset.fxOrder = clean
        }
    }

    private func moveSlot(_ slot: FXSlotID, delta: Int) {
        var order = preset.fxOrder
        guard let index = order.firstIndex(of: slot) else { return }
        let target = index + delta
        guard target >= 0, target < order.count else { return }
        order.swapAt(index, target)
        updateOrder(order)
    }

    @ViewBuilder
    private func slotCard(for slot: FXSlotID) -> some View {
        let index = preset.fxOrder.firstIndex(of: slot) ?? 0
        let canMoveUp = index > 0
        let canMoveDown = index < preset.fxOrder.count - 1

        let onUp: (() -> Void)? = canMoveUp ? { moveSlot(slot, delta: -1) } : nil
        let onDown: (() -> Void)? = canMoveDown ? { moveSlot(slot, delta: 1) } : nil

        switch slot {
        case .distortion:
            distortionCard(onMoveUp: onUp, onMoveDown: onDown)
        case .eq:
            eqCard(onMoveUp: onUp, onMoveDown: onDown)
        case .phaser:
            phaserCard(onMoveUp: onUp, onMoveDown: onDown)
        case .chorus:
            chorusCard(onMoveUp: onUp, onMoveDown: onDown)
        case .delay:
            delayCard(onMoveUp: onUp, onMoveDown: onDown)
        case .reverb:
            reverbCard(onMoveUp: onUp, onMoveDown: onDown)
        }
    }

    private var presetBinding: Binding<SynthPreset> { $preset }

    private var characterAndGlueCard: some View {
        FXSlotCard(
            title: "Character & Glue",
            accent: theme.aFx,
            storageName: "characterGlue",
            startsExpanded: preset.character != .off || preset.busGlueEnabled,
            statusBadge: characterBadge
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                ThemeSegmented(
                    options: CharacterMode.allCases.map { (value: $0, title: $0.rawValue) },
                    selection: $preset.character,
                    accent: theme.aFx
                )
                HStack {
                    Text("Bus Glue")
                        .themeCaption(theme, size: 10)
                        .foregroundColor(theme.textDim)
                    Spacer()
                    ThemeToggle(isOn: $preset.busGlueEnabled)
                        .accessibilityIdentifier("busGlueToggle")
                }
            }
        }
    }

    private var frequencyShifterCard: some View {
        FXSlotCard(
            title: "Freq Shifter",
            enabled: $preset.frequencyShifterEnabled,
            accent: theme.aFx,
            storageName: "freqShifter",
            startsExpanded: preset.frequencyShifterEnabled,
            statusBadge: preset.frequencyShifterEnabled
                ? "\(Int(preset.frequencyShifterShiftHz.rounded()))Hz \(Int((preset.frequencyShifterMix * 100).rounded()))%"
                : nil,
            menu: { FXPresetMenu(kind: .frequencyShifter, preset: $preset) }
        ) {
            HStack(spacing: 8) {
                KnobView(value: $preset.frequencyShifterShiftHz, range: -1000...1000, label: "Shift", format: "%.0f Hz")
                KnobView(value: $preset.frequencyShifterFeedback, range: -0.95...0.95, label: "Fdbk")
                KnobView(value: $preset.frequencyShifterMix, range: 0...1, label: "Mix")
            }
        }
    }

    private var sceneHPFCard: some View {
        FXSlotCard(
            title: "Scene HPF",
            enabled: $preset.sceneHPFEnabled,
            accent: theme.aFx,
            storageName: "sceneHPF",
            startsExpanded: preset.sceneHPFEnabled,
            statusBadge: preset.sceneHPFEnabled ? "\(Int(preset.sceneHPFFrequency.rounded())) Hz" : nil
        ) {
            EmptyView()
        } content: {
            KnobView(value: $preset.sceneHPFFrequency, range: 20...2000, label: "Freq", format: "%.0f")
        }
    }

    private var sendsCard: some View {
        FXSlotCard(
            title: "Sends",
            accent: theme.aFx,
            storageName: "sends",
            startsExpanded: preset.sendA > 0.001 || preset.sendB > 0.001,
            statusBadge: (preset.sendA > 0.001 || preset.sendB > 0.001)
                ? "A \(Int((preset.sendA * 100).rounded()))% · B \(Int((preset.sendB * 100).rounded()))%"
                : nil
        ) {
            EmptyView()
        } content: {
            HStack(spacing: 6) {
                KnobView(value: $preset.sendA, range: 0...1, label: "Send A", format: "%.2f")
                KnobView(value: $preset.sendB, range: 0...1, label: "Send B", format: "%.2f")
            }
        }
    }

    private var rotaryCard: some View {
        FXSlotCard(
            title: "Rotary",
            enabled: $preset.rotaryEnabled,
            accent: theme.aFx,
            storageName: "rotary",
            startsExpanded: preset.rotaryEnabled,
            statusBadge: preset.rotaryEnabled
                ? "\(preset.rotaryFast ? "Fast" : "Slow") \(Int((preset.rotaryMix * 100).rounded()))%"
                : nil
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Fast", isOn: $preset.rotaryFast)
                .font(.system(size: 11, weight: .semibold))
                .toggleStyle(.switch)
                HStack(spacing: 6) {
                    KnobView(value: $preset.rotaryHornSlow, range: 0.2...3, label: "Horn Slow", format: "%.2f")
                    KnobView(value: $preset.rotaryHornFast, range: 1...12, label: "Horn Fast", format: "%.2f")
                    KnobView(value: $preset.rotaryDrumSlow, range: 0.15...2.5, label: "Drum Slow", format: "%.2f")
                    KnobView(value: $preset.rotaryDrumFast, range: 1...10, label: "Drum Fast", format: "%.2f")
                }
                HStack(spacing: 6) {
                    KnobView(value: $preset.rotaryDrive, range: 0...1, label: "Drive", format: "%.2f")
                    KnobView(value: $preset.rotaryMix, range: 0...1, label: "Mix", format: "%.2f")
                    KnobView(value: $preset.rotaryAccel, range: 0.2...20, label: "Accel", format: "%.1f")
                }
            }
        }
    }

    private var transientCard: some View {
        FXSlotCard(
            title: "Transient",
            enabled: $preset.transientEnabled,
            accent: theme.aFx,
            storageName: "transient",
            startsExpanded: preset.transientEnabled,
            statusBadge: preset.transientEnabled
                ? String(format: "A%+.1f S%+.1f", preset.transientAttack, preset.transientSustain)
                : nil
        ) {
            EmptyView()
        } content: {
            HStack(spacing: 6) {
                KnobView(value: $preset.transientAttack, range: -1...1, label: "Attack", format: "%+.2f")
                KnobView(value: $preset.transientSustain, range: -1...1, label: "Sustain", format: "%+.2f")
                KnobView(value: $preset.transientOutput, range: 0...2, label: "Output", format: "%.2f")
                KnobView(value: $preset.transientMix, range: 0...1, label: "Mix", format: "%.2f")
            }
        }
    }

    private var stereoCard: some View {
        FXSlotCard(
            title: "Stereo",
            enabled: $preset.stereoEnabled,
            accent: theme.aFx,
            storageName: "stereo",
            startsExpanded: preset.stereoEnabled,
            statusBadge: preset.stereoEnabled ? "Width \(Int((preset.stereoWidth * 100).rounded()))%" : nil
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    KnobView(value: $preset.stereoWidth, range: 0...2, label: "Width", format: "%.2f")
                    KnobView(value: $preset.stereoMidSide, range: -1...1, label: "Mid/Side", format: "%.2f")
                }
                HStack(spacing: 6) {
                    KnobView(value: $preset.stereoHaasMs, range: 0...30, label: "Haas", format: "%.1f")
                    KnobView(value: $preset.stereoMonoBassHz, range: 0...400, label: "Mono Bass", format: "%.0f")
                }
            }
        }
    }

    private var tranceCard: some View {
        FXSlotCard(
            title: "Trance Gate",
            enabled: $preset.tranceGateEnabled,
            accent: theme.aFx,
            storageName: "trance",
            startsExpanded: preset.tranceGateEnabled,
            statusBadge: preset.tranceGateEnabled
                ? "\(preset.tranceGateDivision.rawValue) \(Int((preset.tranceGateDepth * 100).rounded()))%"
                : nil
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 2) {
                    ForEach(0..<16, id: \.self) { step in
                        let on = preset.tranceGatePattern & (UInt16(1) << UInt16(step)) != 0
                        Button {
                            preset.tranceGatePattern ^= UInt16(1) << UInt16(step)
                        } label: {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(on ? theme.aFx : theme.inset)
                                .frame(width: 10, height: 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("tranceStep\(step)")
                    }
                }
                HStack(spacing: 6) {
                    KnobView(value: $preset.tranceGateDepth, range: 0...1, label: "Depth")
                    KnobView(value: $preset.tranceGateSmooth, range: 0...1, label: "Smooth")
                }
                Picker("Rate", selection: $preset.tranceGateDivision) {
                    ForEach(TimeDivision.allCases, id: \.self) { division in
                        Text(division.rawValue).tag(division)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
        }
    }

    private var smoothCard: some View {
        FXSlotCard(
            title: "Smooth Random",
            accent: theme.aMod,
            storageName: "smoothRandom",
            startsExpanded: false
        ) {
            EmptyView()
        } content: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    KnobView(value: $preset.perlinRate, range: 0.05...20, label: "Rate", format: "%.2f")
                    Button {
                        preset.perlinTempoSync.toggle()
                    } label: {
                        Text(preset.perlinTempoSync ? "SYNC" : "FREE")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(preset.perlinTempoSync ? theme.bg : theme.textDim)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(RoundedRectangle(cornerRadius: 3).fill(preset.perlinTempoSync ? theme.aMod : theme.inset))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("perlinSync")
                }
                if preset.perlinTempoSync {
                    Picker("Division", selection: $preset.perlinSyncDivision) {
                        ForEach(TimeDivision.allCases, id: \.self) { division in
                            Text(division.rawValue).tag(division)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
    }

    // MARK: - Distortion Slot

    private func distortionCard(onMoveUp: (() -> Void)?, onMoveDown: (() -> Void)?) -> some View {
        FXSlotCard(
            title: "Distortion",
            enabled: distortionEnabled,
            accent: theme.aFx,
            storageName: "distortion",
            startsExpanded: preset.distortionEnabled,
            statusBadge: distortionBadge,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            menu: { FXPresetMenu(kind: .distortion, preset: presetBinding) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("Type", selection: distortionType) {
                        ForEach(DistortionType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 11, design: .rounded))

                    Spacer()

                    Button {
                        preset.distortionOversampling.toggle()
                    } label: {
                        Text("2X HQ")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(preset.distortionOversampling ? theme.aFx : Color.clear)
                            .foregroundColor(preset.distortionOversampling ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: 8) {
                    KnobView(value: distortionDrive, range: 0...1, label: "Drive")
                    KnobView(value: distortionTone, range: 0...1, label: "Tone")
                    KnobView(value: distortionMix, range: 0...1, label: "Mix", target: .distortionMix)
                }
            }
        }
    }

    // MARK: - EQ Slot

    private func eqCard(onMoveUp: (() -> Void)?, onMoveDown: (() -> Void)?) -> some View {
        FXSlotCard(
            title: "EQ",
            enabled: eqEnabled,
            accent: theme.aFx,
            storageName: "eq",
            startsExpanded: preset.eqEnabled,
            statusBadge: eqBadge,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            menu: { FXPresetMenu(kind: .eq, preset: presetBinding) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    KnobView(value: eqLowGain, range: -12...12, label: "Low", format: "%.0fdB")
                    KnobView(value: eqMidGain, range: -12...12, label: "Mid", format: "%.0fdB")
                    KnobView(value: eqHighGain, range: -12...12, label: "High", format: "%.0fdB")
                }
                HStack(spacing: 8) {
                    KnobView(value: eqLowFreq, range: 40...400, label: "Lo F", format: "%.0fHz")
                    KnobView(value: eqMidFreq, range: 200...5000, label: "Mid F", format: "%.0fHz")
                    KnobView(value: eqHighFreq, range: 2000...16000, label: "Hi F", format: "%.0fHz")
                }
            }
        }
    }

    // MARK: - Phaser Slot

    private func phaserCard(onMoveUp: (() -> Void)?, onMoveDown: (() -> Void)?) -> some View {
        FXSlotCard(
            title: "Phaser",
            enabled: phaserEnabled,
            accent: theme.aFx,
            storageName: "phaser",
            startsExpanded: preset.phaserEnabled,
            statusBadge: phaserBadge,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            menu: { FXPresetMenu(kind: .phaser, preset: presetBinding) }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Mode", selection: phaserMode) {
                    ForEach(PhaserMode.allCases, id: \.self) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .font(.system(size: 11, design: .rounded))

                HStack(spacing: 8) {
                    KnobView(value: phaserRate, range: 0.05...5, label: "Rate", format: "%.2fHz")
                    KnobView(value: phaserDepth, range: 0...1, label: "Depth")
                    KnobView(value: phaserMix, range: 0...1, label: "Mix", target: .phaserMix)
                }
                HStack(spacing: 8) {
                    KnobView(value: phaserFeedback, range: -0.9...0.9, label: "Fdbk")
                    KnobView(value: phaserCenter, range: 200...4000, label: "Center", format: "%.0fHz")
                    KnobView(value: phaserSpread, range: 0...1, label: "Spread")
                }
            }
        }
    }

    // MARK: - Chorus Slot

    private func chorusCard(onMoveUp: (() -> Void)?, onMoveDown: (() -> Void)?) -> some View {
        FXSlotCard(
            title: "Chorus",
            accent: theme.aFx,
            storageName: "chorus",
            startsExpanded: preset.chorusMix > 0.001,
            statusBadge: chorusBadge,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            menu: {
                HStack(spacing: 4) {
                    Button {
                        if preset.chorusMode == .ensemble {
                            preset.chorusMode = .standard
                        } else {
                            preset.chorusMode = .ensemble
                            preset.chorusFlanger = false
                        }
                    } label: {
                        Text("ENS")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(preset.chorusMode == .ensemble ? theme.aFx : Color.clear)
                            .foregroundColor(preset.chorusMode == .ensemble ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chorusEnsemble")

                    Button {
                        let flanging = preset.chorusFlanger || preset.chorusMode == .flanger
                        if flanging {
                            preset.chorusFlanger = false
                            if preset.chorusMode == .flanger { preset.chorusMode = .standard }
                        } else {
                            preset.chorusFlanger = true
                            preset.chorusMode = .flanger
                        }
                    } label: {
                        Text("FLNG")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background((preset.chorusFlanger || preset.chorusMode == .flanger) ? theme.aFx : Color.clear)
                            .foregroundColor((preset.chorusFlanger || preset.chorusMode == .flanger) ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chorusFlanger")

                    Button {
                        preset.chorusStereo.toggle()
                    } label: {
                        Text("WIDE")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(preset.chorusStereo ? theme.aFx : Color.clear)
                            .foregroundColor(preset.chorusStereo ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)

                    FXPresetMenu(kind: .chorus, preset: $preset)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    KnobView(value: $preset.chorusRate, range: 0.1...5.0, label: "Rate", format: "%.1fHz")
                    KnobView(value: $preset.chorusDepth, range: 0...1, label: "Depth")
                    KnobView(value: $preset.chorusMix, range: 0...1, label: "Mix", target: .chorusMix)
                }
                if preset.chorusFlanger {
                    HStack(spacing: 8) {
                        KnobView(value: $preset.chorusFeedback, range: -0.95...0.95, label: "Fdbk")
                        Button {
                            preset.chorusFlangerSync.toggle()
                        } label: {
                            Text(preset.chorusFlangerSync ? "SYNC" : "FREE")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(preset.chorusFlangerSync ? .black : theme.textDim)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 3).fill(preset.chorusFlangerSync ? theme.aFx : theme.inset))
                        }
                        .buttonStyle(.plain)
                    }
                    if preset.chorusFlangerSync {
                        Picker("Division", selection: $preset.chorusFlangerDivision) {
                            ForEach(TimeDivision.allCases, id: \.self) { division in
                                Text(division.rawValue).tag(division)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: - Delay Slot

    private func delayCard(onMoveUp: (() -> Void)?, onMoveDown: (() -> Void)?) -> some View {
        FXSlotCard(
            title: "Delay",
            accent: theme.aFx,
            storageName: "delay",
            startsExpanded: preset.delayMix > 0.001,
            statusBadge: delayBadge,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            menu: {
                HStack(spacing: 4) {
                    Button {
                        preset.delayTempoSync.toggle()
                    } label: {
                        Text("SYNC")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(preset.delayTempoSync ? theme.aFx : Color.clear)
                            .foregroundColor(preset.delayTempoSync ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)

                    Button {
                        preset.delayPingPong.toggle()
                    } label: {
                        Text("PONG")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(preset.delayPingPong ? theme.aFx : Color.clear)
                            .foregroundColor(preset.delayPingPong ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)

                    FXPresetMenu(kind: .delay, preset: $preset)
                }
            }
        ) {
            HStack(spacing: 8) {
                if preset.delayTempoSync {
                    VStack(spacing: 2) {
                        Menu {
                            ForEach(TimeDivision.allCases, id: \.self) { div in
                                Button(div.rawValue) { preset.delaySyncDivision = div }
                            }
                        } label: {
                            Text(preset.delaySyncDivision.rawValue)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(theme.aFx)
                                .frame(width: 50, height: 26)
                                .background(theme.card)
                                .cornerRadius(4)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(theme.aFx.opacity(0.5), lineWidth: 1))
                        }
                        .menuStyle(.borderlessButton)
                        Text("Sync")
                            .themeCaption(theme, size: 9)
                            .foregroundColor(theme.textDim)
                    }
                    .frame(width: 50, height: 50)
                } else {
                    KnobView(value: $preset.delayTime, range: 0.01...1.0, label: "Time", format: "%.2fs")
                }
                KnobView(value: $preset.delayFeedback, range: 0...0.9, label: "Feedback")
                KnobView(value: $preset.delayMix, range: 0...1, label: "Mix", target: .delayMix)
            }
        }
    }

    // MARK: - Reverb Slot

    private func reverbCard(onMoveUp: (() -> Void)?, onMoveDown: (() -> Void)?) -> some View {
        FXSlotCard(
            title: "Reverb",
            accent: theme.aFx,
            storageName: "reverb",
            startsExpanded: preset.reverbMix > 0.001,
            statusBadge: reverbBadge,
            onMoveUp: onMoveUp,
            onMoveDown: onMoveDown,
            menu: {
                HStack(spacing: 4) {
                    Button {
                        preset.dspReverbEnabled.toggle()
                    } label: {
                        Text("DSP")
                            .font(.system(size: 8, weight: .bold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(preset.dspReverbEnabled ? theme.aFx : Color.clear)
                            .foregroundColor(preset.dspReverbEnabled ? .black : theme.textDim)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.aFx.opacity(0.6), lineWidth: 1))
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("dspReverb")
                    FXPresetMenu(kind: .reverb, preset: $preset)
                }
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    KnobView(value: $preset.reverbMix, range: 0...1, label: "Mix", target: .reverbMix)
                    KnobView(value: $preset.reverbRoomSize, range: 0...1, label: "Room")
                    KnobView(value: $preset.reverbShimmer, range: 0...1, label: "Shimmer", format: "%.0f%%")
                }
                if preset.dspReverbEnabled {
                    KnobView(value: $preset.reverbDamping, range: 0...1, label: "Damp")
                }
            }
        }
    }

    // MARK: - Collapsed Status Badges

    private var characterBadge: String? {
        guard preset.character != .off || preset.busGlueEnabled else { return nil }
        var parts: [String] = []
        if preset.character != .off { parts.append(preset.character.rawValue) }
        if preset.busGlueEnabled { parts.append("Glue") }
        return parts.joined(separator: " + ")
    }

    private var distortionBadge: String? {
        guard preset.distortionEnabled else { return nil }
        let mixPct = Int((preset.distortionMix * 100).rounded())
        return "\(preset.distortionType.rawValue) \(mixPct)%"
    }

    private var eqBadge: String? {
        guard preset.eqEnabled else { return nil }
        let l = Int(preset.eqLowGain.rounded())
        let m = Int(preset.eqMidGain.rounded())
        let h = Int(preset.eqHighGain.rounded())
        if l == 0 && m == 0 && h == 0 { return "Flat" }
        return String(format: "%+d/%+d/%+d dB", l, m, h)
    }

    private var phaserBadge: String? {
        guard preset.phaserEnabled else { return nil }
        let mixPct = Int((preset.phaserMix * 100).rounded())
        return "\(preset.phaserMode.rawValue) \(mixPct)%"
    }

    private var chorusBadge: String? {
        guard preset.chorusMix > 0.001 else { return nil }
        let mode: String
        if preset.chorusMode == .ensemble {
            mode = "Ens"
        } else if preset.chorusFlanger || preset.chorusMode == .flanger {
            mode = "Flng"
        } else if preset.chorusStereo {
            mode = "Wide"
        } else {
            mode = "Chr"
        }
        return "\(mode) \(Int((preset.chorusMix * 100).rounded()))%"
    }

    private var delayBadge: String? {
        guard preset.delayMix > 0.001 else { return nil }
        let mode: String
        if preset.delayPingPong {
            mode = "Pong"
        } else if preset.delayTempoSync {
            mode = preset.delaySyncDivision.rawValue
        } else {
            mode = "\(Int((preset.delayTime * 1000).rounded()))ms"
        }
        return "\(mode) \(Int((preset.delayMix * 100).rounded()))%"
    }

    private var reverbBadge: String? {
        guard preset.reverbMix > 0.001 else { return nil }
        let mode = preset.dspReverbEnabled ? "DSP" : "Verb"
        return "\(mode) \(Int((preset.reverbMix * 100).rounded()))%"
    }

    // MARK: - Helper Bindings

    private func binding<T>(
        get: @escaping (SynthPreset) -> T,
        set: @escaping (inout SynthPreset, T) -> Void
    ) -> Binding<T> {
        Binding(
            get: { get(preset) },
            set: { newValue in
                var next = preset
                set(&next, newValue)
                preset = next
            }
        )
    }

    private var distortionEnabled: Binding<Bool> {
        binding(get: { $0.distortionEnabled }, set: { $0.distortionEnabled = $1 })
    }
    private var distortionType: Binding<DistortionType> {
        binding(get: { $0.distortionType }, set: { $0.distortionType = $1 })
    }
    private var distortionDrive: Binding<Float> {
        binding(get: { $0.distortionDrive }, set: { $0.distortionDrive = $1 })
    }
    private var distortionTone: Binding<Float> {
        binding(get: { $0.distortionTone }, set: { $0.distortionTone = $1 })
    }
    private var distortionMix: Binding<Float> {
        binding(get: { $0.distortionMix }, set: { $0.distortionMix = $1 })
    }
    private var eqEnabled: Binding<Bool> {
        binding(get: { $0.eqEnabled }, set: { $0.eqEnabled = $1 })
    }
    private var eqLowGain: Binding<Float> {
        binding(get: { $0.eqLowGain }, set: { $0.eqLowGain = $1 })
    }
    private var eqMidGain: Binding<Float> {
        binding(get: { $0.eqMidGain }, set: { $0.eqMidGain = $1 })
    }
    private var eqHighGain: Binding<Float> {
        binding(get: { $0.eqHighGain }, set: { $0.eqHighGain = $1 })
    }
    private var eqLowFreq: Binding<Float> {
        binding(get: { $0.eqLowFreq }, set: { $0.eqLowFreq = $1 })
    }
    private var eqMidFreq: Binding<Float> {
        binding(get: { $0.eqMidFreq }, set: { $0.eqMidFreq = $1 })
    }
    private var eqHighFreq: Binding<Float> {
        binding(get: { $0.eqHighFreq }, set: { $0.eqHighFreq = $1 })
    }
    private var phaserEnabled: Binding<Bool> {
        binding(get: { $0.phaserEnabled }, set: { $0.phaserEnabled = $1 })
    }
    private var phaserMode: Binding<PhaserMode> {
        binding(get: { $0.phaserMode }, set: { $0.phaserMode = $1 })
    }
    private var phaserRate: Binding<Float> {
        binding(get: { $0.phaserRate }, set: { $0.phaserRate = $1 })
    }
    private var phaserDepth: Binding<Float> {
        binding(get: { $0.phaserDepth }, set: { $0.phaserDepth = $1 })
    }
    private var phaserMix: Binding<Float> {
        binding(get: { $0.phaserMix }, set: { $0.phaserMix = $1 })
    }
    private var phaserFeedback: Binding<Float> {
        binding(get: { $0.phaserFeedback }, set: { $0.phaserFeedback = $1 })
    }
    private var phaserCenter: Binding<Float> {
        binding(get: { $0.phaserCenterFrequency }, set: { $0.phaserCenterFrequency = $1 })
    }
    private var phaserSpread: Binding<Float> {
        binding(get: { $0.phaserStereoSpread }, set: { $0.phaserStereoSpread = $1 })
    }
}

struct FXSlotDropDelegate: DropDelegate {
    let item: FXSlotID
    @Binding var order: [FXSlotID]
    @Binding var draggedItem: FXSlotID?

    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              draggedItem != item,
              let from = order.firstIndex(of: draggedItem),
              let to = order.firstIndex(of: item) else { return }

        if order[to] != draggedItem {
            withAnimation(.default) {
                order.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
