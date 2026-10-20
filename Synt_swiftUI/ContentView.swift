//
//  ContentView.swift
//  Synt_swiftUI
//

import AppKit
import SynthCore
import SwiftUI
import UniformTypeIdentifiers

/// One engine + one MIDI handler per app run, wired before any MIDI source connects.
@MainActor
final class SynthRuntime {
    static let shared = SynthRuntime()
    let engine: AudioEngine
    let midi: MIDIHandler

    private init() {
        engine = AudioEngine()
        midi = MIDIHandler(audioEngine: engine)
    }
}

struct ContentView: View {
    @Environment(\.theme) private var theme
    @StateObject private var audioEngine: AudioEngine
    @StateObject private var keyboardHandler = KeyboardHandler()
    /// Built with the engine already in place, so the CoreMIDI thread never
    /// sees the engine reference change.
    @StateObject private var midiHandler: MIDIHandler
    @StateObject private var stepSequencer = StepSequencer()
    
    @State private var showSequencer: Bool = false
    @State private var sessionSaveTask: Task<Void, Never>?

    init() {
        // StateObject evaluates these autoclosures once per view identity.
        _audioEngine = StateObject(wrappedValue: SynthRuntime.shared.engine)
        _midiHandler = StateObject(wrappedValue: SynthRuntime.shared.midi)
    }

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
            // The scroll view proposes an unbounded width. Pin the column to the
            // window so tracked titles cannot shove the cards off the left edge.
            GeometryReader { geo in
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
                    .frame(width: geo.size.width)
                }
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
        .onChange(of: stepSequencer.pattern) { _, pattern in
            if audioEngine.preset.sequencerData != pattern.steps {
                audioEngine.preset.sequencerData = pattern.steps
            }
            publishSequencerSnapshot()
        }
        .onChange(of: audioEngine.preset.bpm) { _, _ in
            publishSequencerSnapshot()
        }
        .onChange(of: audioEngine.preset) { oldPreset, preset in
            if (oldPreset.id != preset.id || oldPreset.name != preset.name),
               preset.sequencerData.count == 16,
               stepSequencer.pattern.steps != preset.sequencerData {
                stepSequencer.pattern.steps = preset.sequencerData
            }
            scheduleSessionSave(preset)
        }
        .onAppear {
            if let saved = PresetManager.loadLastSession() {
                audioEngine.preset = saved
            }
            if audioEngine.preset.sequencerData.count == 16 {
                stepSequencer.pattern.steps = audioEngine.preset.sequencerData
            }
            keyboardHandler.audioEngine = audioEngine
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

    private func toggleRecording() {
        if audioEngine.isRecording {
            guard let tempURL = audioEngine.stopRecording() else { return }
            #if os(macOS)
            let savePanel = NSSavePanel()
            if let wavType = UTType(filenameExtension: "wav") {
                savePanel.allowedContentTypes = [wavType]
            }
            savePanel.canCreateDirectories = true
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            savePanel.nameFieldStringValue = "Synt_Recording_\(formatter.string(from: Date())).wav"
            savePanel.begin { response in
                if response == .OK, let destination = savePanel.url {
                    try? FileManager.default.removeItem(at: destination)
                    try? FileManager.default.copyItem(at: tempURL, to: destination)
                }
            }
            #endif
        } else {
            audioEngine.startRecording()
        }
    }

    /// External clock shows the locked tempo. Internal clock shows the slider.
    private var headerBPM: Int {
        let bpm = audioEngine.preset.syncSource == .midiClock && audioEngine.externalTempo >= 20
            ? audioEngine.externalTempo
            : audioEngine.preset.bpm
        return Int(bpm.rounded())
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

                MIDIStatusView(midi: midiHandler, activity: midiHandler.activity)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer()

            PresetView(currentPreset: $audioEngine.preset)
            ThemePickerMenu()

            // Audio Output Recorder (● REC)
            Button {
                toggleRecording()
            } label: {
                HStack(spacing: 4) {
                    Circle()
                        .fill(audioEngine.isRecording ? Color.red : theme.textFaint)
                        .frame(width: 7, height: 7)
                    Text("REC")
                        .font(theme.monoFont(size: 11, weight: .bold))
                        .foregroundColor(audioEngine.isRecording ? Color.red : theme.textDim)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(audioEngine.isRecording ? Color.red.opacity(0.18) : theme.panel)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(audioEngine.isRecording ? Color.red : theme.border, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            .help(audioEngine.isRecording ? "Stop Recording & Save WAV" : "Record Output to WAV")

            Spacer()

            HStack(spacing: 16) {
                // Meters observe AudioMeterModel, not AudioEngine, so knobs stay put.
                EngineMetersView(meters: audioEngine.meters, scope: audioEngine.meteringState, isRunning: audioEngine.isPlaying)
                
                // Sequencer Controls
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("BPM")
                            .themeCaption(theme, size: 10)
                            .foregroundColor(theme.textDim)
                            .lineLimit(1)
                        Text("\(headerBPM)")
                            .font(theme.monoFont(size: 14, weight: .bold))
                            .foregroundColor(theme.accent2)
                            .lineLimit(1)
                        Button {
                            audioEngine.updatePreset { preset in
                                preset.syncSource = preset.syncSource == .midiClock ? .`internal` : .midiClock
                            }
                        } label: {
                            Text(audioEngine.preset.syncSource == .midiClock ? "EXT" : "INT")
                                .font(theme.monoFont(size: 10, weight: .bold))
                                .foregroundColor(audioEngine.preset.syncSource == .midiClock ? theme.accent : theme.textDim)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("syncSourceToggle")
                        .help("INT uses the BPM slider. EXT follows MIDI clock from Logic.")
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
        SynthControlGrid(audioEngine: audioEngine)
    }
}

/// Header VU + scope. This is the only view that observes `AudioMeterModel`.
struct EngineMetersView: View {
    @ObservedObject var meters: AudioMeterModel
    let scope: AtomicMeteringState
    var isRunning: Bool = true

    var body: some View {
        HStack(spacing: 16) {
            StereoVUMeterView(
                leftLevel: meters.outputLevel,
                rightLevel: meters.outputLevel,
                leftPeak: meters.peakLevel,
                rightPeak: meters.peakLevel
            )
            OscilloscopeView(metering: scope, isRunning: isRunning)
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
