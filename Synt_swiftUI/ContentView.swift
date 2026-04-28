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

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerSection

                controlsSection
                
                // Step Sequencer (collapsible)
                if showSequencer {
                    StepSequencerView(
                        sequencer: stepSequencer,
                        bpm: $audioEngine.preset.bpm,
                        isPlaying: $stepSequencer.isPlaying
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                KeyboardView(
                    keyboardHandler: keyboardHandler,
                    pressedKeys: audioEngine.pressedKeys,
                    startNote: 36, // Fixed start note (C2)
                    numberOfOctaves: 4
                )
            }
            .padding()
        }
        .background(AppleTheme.windowBackground)
        // Timer for sequencer (runs at ~1000Hz for accurate timing)
        .onReceive(Timer.publish(every: 0.001, on: .main, in: .common).autoconnect()) { _ in
            if stepSequencer.isPlaying {
                // Call tick with ~44 samples per millisecond (44100 / 1000)
                stepSequencer.tick(bpm: audioEngine.preset.bpm, sampleCount: 44)
            }
        }
        .onAppear {
            keyboardHandler.audioEngine = audioEngine
            midiHandler.audioEngine = audioEngine
            keyboardHandler.startListening()
            audioEngine.start()
            
            // Connect step sequencer to audio engine
            stepSequencer.onStep = { [weak audioEngine] note, velocity, _ in
                audioEngine?.noteOn(midiNote: note, velocity: velocity)
            }
            stepSequencer.onNoteOff = { [weak audioEngine] note in
                audioEngine?.noteOff(midiNote: note)
            }
        }
        .onDisappear {
            keyboardHandler.stopListening()
            audioEngine.stop()
            stepSequencer.stop()
        }
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
                // VU Meter
                StereoVUMeterView(
                    leftLevel: audioEngine.outputLevel,
                    rightLevel: audioEngine.outputLevel,
                    leftPeak: audioEngine.peakLevel,
                    rightPeak: audioEngine.peakLevel
                )
                
                // Oscilloscope
                OscilloscopeView(data: audioEngine.scopeData)
                    .frame(width: 160, height: 100)
                
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
                OscillatorView(preset: $audioEngine.preset, oscillatorNumber: 1)
                OscillatorView(preset: $audioEngine.preset, oscillatorNumber: 2)
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
                ModMatrixView(preset: $audioEngine.preset)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 1000, height: 700)
}
