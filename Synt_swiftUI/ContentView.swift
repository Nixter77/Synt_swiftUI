//
//  ContentView.swift
//  Synt_swiftUI
//

import SwiftUI

struct ContentView: View {
    @StateObject private var audioEngine = AudioEngine()
    @StateObject private var keyboardHandler = KeyboardHandler()
    @StateObject private var midiHandler = MIDIHandler()
    @StateObject private var stepSequencer = StepSequencer()
    
    @State private var showSequencer: Bool = false
    @State private var sessionSaveTask: Task<Void, Never>?

    var body: some View {
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
        .background(AppleTheme.windowBackground)
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
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppleTheme.accentOscillator, AppleTheme.accentEffects],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("SwiftUI Synthesizer")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(AppleTheme.textSecondary)
                
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
                                .fill(AppleTheme.accentPositive)
                                .frame(width: 6, height: 6)
                            Text("MIDI: \(midiHandler.selectedDevice)")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(AppleTheme.accentPositive)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8))
                                .foregroundColor(AppleTheme.accentPositive)
                        }
                        .padding(4)
                        .background(AppleTheme.accentPositive.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .menuStyle(.borderlessButton)
                }
            }

            Spacer()

            PresetView(currentPreset: $audioEngine.preset)

            Spacer()

            HStack(spacing: 16) {
                // Meters observe AudioMeterModel, not AudioEngine, so knobs stay put.
                EngineMetersView(meters: audioEngine.meters, scope: audioEngine.meteringState)
                
                // Sequencer Controls
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("BPM")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(AppleTheme.textSecondary)
                        Text("\(Int(audioEngine.preset.bpm))")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(AppleTheme.accentOscillator)
                    }
                    Slider(value: $audioEngine.preset.bpm, in: 40...240, step: 1)
                        .frame(width: 80)
                        .tint(AppleTheme.accentOscillator)
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
                            .foregroundColor(showSequencer ? AppleTheme.accentLFO : AppleTheme.textTertiary)
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
                            .foregroundColor(stepSequencer.isPlaying ? AppleTheme.accentDestructive : AppleTheme.accentBlue)
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
                        .foregroundColor(audioEngine.isPlaying ? AppleTheme.accentDestructive : AppleTheme.accentPositive)
                        .frame(width: 50, height: 50)
                        .background(
                            Circle()
                                .fill(AppleTheme.surfaceSecondary)
                                .shadow(color: AppleTheme.shadowDark, radius: 6, x: 3, y: 4)
                                .shadow(color: AppleTheme.shadowLight, radius: 4, x: -2, y: -2)
                        )
                        .overlay(
                            Circle()
                                .stroke(
                                    audioEngine.isPlaying ? AppleTheme.accentDestructive.opacity(0.3) : AppleTheme.accentPositive.opacity(0.3),
                                    lineWidth: 2
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .appleCard(cornerRadius: AppleTheme.radiusLarge)
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

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
