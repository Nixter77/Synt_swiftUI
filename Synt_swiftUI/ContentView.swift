//
//  ContentView.swift
//  Synt_swiftUI
//

import SwiftUI

struct ContentView: View {
    @Environment(\.theme) private var theme
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var keyboardHandler = KeyboardHandler()
    @StateObject private var midiHandler = MIDIHandler()
    @StateObject private var stepSequencer = StepSequencer()
    
    @State private var showSequencer: Bool = false
    @State private var sessionSaveTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            if theme.chromeWidth > 0 {
                WoodCheek().frame(width: theme.chromeWidth)
            }
            mainColumn
                .frame(minWidth: theme.chromeWidth > 0 ? 1000 : nil)
            if theme.chromeWidth > 0 {
                WoodCheek().frame(width: theme.chromeWidth)
            }
        }
        .background(theme.bg)
    }

    private var mainColumn: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    headerSection

                    controlsSection

                    if showSequencer {
                        StepSequencerView(
                            sequencer: stepSequencer,
                            playhead: stepSequencer.playhead,
                            bpm: $audioEngine.preset.bpm,
                            isPlaying: $stepSequencer.isPlaying
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding()
            }

            // Keyboard stays outside ScrollView so a drag cannot cancel noteOff.
            KeyboardView(
                keyboardHandler: keyboardHandler,
                keyDisplay: audioEngine.keyDisplay,
                startNote: 36,
                numberOfOctaves: 4
            )
            .padding(.bottom, 8)
        }
        // Playhead only. The clock itself runs on the audio thread.
        .onReceive(Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()) { _ in
            guard showSequencer, stepSequencer.isPlaying else { return }
            stepSequencer.currentStep = audioEngine.sequencerDisplayStep
        }
        .onChange(of: stepSequencer.isPlaying) { _, _ in
            publishSequencerSnapshot()
        }
        .onChange(of: stepSequencer.swing) { _, _ in
            publishSequencerSnapshot()
        }
        .onChange(of: stepSequencer.rootNote) { _, _ in
            publishSequencerSnapshot()
        }
        .onChange(of: stepSequencer.pattern) { _, _ in
            publishSequencerSnapshot()
        }
        .onChange(of: audioEngine.preset.bpm) { _, _ in
            publishSequencerSnapshot()
        }
        .onChange(of: audioEngine.preset) { _, preset in
            scheduleSessionSave(preset)
        }
        .onAppear {
            if let saved = PresetManager.loadLastSession() {
                audioEngine.preset = saved
            }
            keyboardHandler.audioEngine = audioEngine
            midiHandler.audioEngine = audioEngine
            keyboardHandler.startListening()
            audioEngine.start()
            publishSequencerSnapshot()
        }
        .onDisappear {
            sessionSaveTask?.cancel()
            PresetManager.saveLastSession(audioEngine.preset)
            keyboardHandler.stopListening()
            audioEngine.stop()
            stepSequencer.stop()
            publishSequencerSnapshot()
        }
    }

    /// Debounced off the audio thread. A burst of knob moves writes one file.
    private func scheduleSessionSave(_ preset: SynthPreset) {
        sessionSaveTask?.cancel()
        sessionSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            PresetManager.saveLastSession(preset)
        }
    }

    private func publishSequencerSnapshot() {
        audioEngine.updateSequencerSnapshot(
            playing: stepSequencer.isPlaying,
            swing: stepSequencer.swing,
            bpm: audioEngine.preset.bpm,
            rootNote: stepSequencer.rootNote,
            length: stepSequencer.pattern.length,
            generation: stepSequencer.transportGeneration,
            steps: stepSequencer.pattern.steps
        )
    }

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SYNTH")
                    .font(theme.titleFont)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.logoA, theme.logoB],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineLimit(1)

                Text("SwiftUI Synthesizer")
                    .themeCaption(theme, size: 12, weight: .regular)
                    .foregroundColor(theme.textDim)
                    .lineLimit(1)

                if !midiHandler.availableDevices.isEmpty {
                    Menu {
                        ForEach(midiHandler.availableDevices, id: \.self) { device in
                            Button(device) {
                                midiHandler.selectDevice(device)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.positive)
                                .frame(width: 6, height: 6)
                            Text("MIDI: \(midiHandler.selectedDevice)")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(theme.positive)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(theme.positive)
                        }
                        .padding(4)
                        .background(theme.positive.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer()

            PresetView(currentPreset: $audioEngine.preset)
            ThemePickerMenu()

            Spacer()

            HStack(spacing: 16) {
                // Meters observe AudioMeterModel, not AudioEngine, so knobs stay put.
                EngineMetersView(meters: audioEngine.meters, scope: audioEngine.meteringState)
                
                // Sequencer Controls
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("BPM")
                            .themeCaption(theme, size: 10)
                            .foregroundColor(theme.textDim)
                            .lineLimit(1)
                        Text("\(Int(audioEngine.preset.bpm))")
                            .font(theme.monoFont(size: 14, weight: .bold))
                            .foregroundColor(theme.accent2)
                            .lineLimit(1)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    ThemeSlider(value: $audioEngine.preset.bpm, range: 40...240, step: 1)
                        .frame(width: 80)
                }
                
                // Sequencer Toggle & Play
                VStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSequencer.toggle()
                        }
                    } label: {
                        Image(systemName: showSequencer ? "rectangle.compress.vertical" : "rectangle.expand.vertical")
                            .font(.caption)
                            .foregroundColor(showSequencer ? theme.aLFO : theme.textFaint)
                    }
                    .buttonStyle(.plain)
                    .help("Show/Hide Sequencer")
                    
                    Button {
                        if stepSequencer.isPlaying {
                            stepSequencer.stop()
                        } else {
                            stepSequencer.start()
                        }
                    } label: {
                        Image(systemName: stepSequencer.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(stepSequencer.isPlaying ? theme.destructive : theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Play/Stop Sequencer")
                }
                
                LargeKnobView(
                    value: $audioEngine.preset.masterVolume,
                    range: 0...1,
                    label: "Master"
                )

                Button {
                    if audioEngine.isPlaying {
                        audioEngine.stop()
                    } else {
                        audioEngine.start()
                    }
                } label: {
                    Image(systemName: audioEngine.isPlaying ? "stop.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(audioEngine.isPlaying ? theme.destructive : theme.positive)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(theme.panel)
                                .shadow(color: theme.cardShadow.color, radius: theme.cardShadow.radius, x: 0, y: theme.cardShadow.y)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    audioEngine.isPlaying ? theme.destructive.opacity(0.3) : theme.positive.opacity(0.3),
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .appleCard(cornerRadius: theme.rHeader)
    }

    private var controlsSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 12) {
                OscillatorView(preset: $audioEngine.preset, oscillatorNumber: 1, audioEngine: audioEngine)
                OscillatorView(preset: $audioEngine.preset, oscillatorNumber: 2, audioEngine: audioEngine)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                ADSRView(preset: $audioEngine.preset)
                FilterView(preset: $audioEngine.preset)
                UnisonView(preset: $audioEngine.preset)
            }
            .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                LFOView(preset: $audioEngine.preset)
                EffectsView(preset: $audioEngine.preset)
                AdvancedEffectsView(audioEngine: audioEngine)
                ModMatrixView(preset: $audioEngine.preset)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Header VU + scope. This is the only view that observes `AudioMeterModel`.
struct EngineMetersView: View {
    @ObservedObject var meters: AudioMeterModel
    let scope: AtomicMeteringState

    var body: some View {
        HStack(spacing: 16) {
            StereoVUMeterView(
                leftLevel: meters.outputLevel,
                rightLevel: meters.outputLevel,
                leftPeak: meters.peakLevel,
                rightPeak: meters.peakLevel
            )
            OscilloscopeView(metering: scope)
                .frame(width: 160, height: 100)
        }
    }
}

struct WoodCheek: View {
    @Environment(\.theme) private var theme

    var body: some View {
        LinearGradient(
            colors: [theme.chrome, theme.bg, theme.chrome],
            startPoint: .top,
            endPoint: .bottom
        )
        .accessibilityHidden(true)
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
        .environment(\.theme, Theme.baseline)
        .environmentObject(ThemeStore())
}
