//
//  EffectsView.swift
//  Synt_swiftUI
//
//  Chorus, delay, and reverb. These have no enable flag: a mix above zero
//  counts as "on" only for the default expanded state.
//

import SwiftUI
import SynthCore

struct EffectsView: View {
    @Environment(\.theme) private var theme
    @Binding var preset: SynthPreset

    var body: some View {
        VStack(spacing: 10) {
            FXSlotCard(
                title: "Chorus",
                accent: theme.aFx,
                storageName: "chorus",
                startsExpanded: preset.chorusMix > 0.001,
                menu: {
                    HStack(spacing: 4) {
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
                HStack(spacing: 8) {
                    KnobView(value: $preset.chorusRate, range: 0.1...5.0, label: "Rate", format: "%.1fHz")
                    KnobView(value: $preset.chorusDepth, range: 0...1, label: "Depth")
                    KnobView(value: $preset.chorusMix, range: 0...1, label: "Mix", target: .chorusMix)
                }
            }

            FXSlotCard(
                title: "Delay",
                accent: theme.aFx,
                storageName: "delay",
                startsExpanded: preset.delayMix > 0.001,
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

            FXSlotCard(
                title: "Reverb",
                accent: theme.aFx,
                storageName: "reverb",
                startsExpanded: preset.reverbMix > 0.001,
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
    }
}

#Preview {
    EffectsView(preset: .constant(.defaultPreset))
        .frame(width: 240)
        .padding()
        .background(Theme.baseline.bg)
}
