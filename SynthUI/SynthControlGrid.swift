//
//  SynthControlGrid.swift
//  The main-screen columns. Standalone passes the engine. The plugin passes a preset binding.
//

import SwiftUI
import SynthCore

/// Four columns at every window width from 900 up. Columns shrink via minWidth
/// and never wrap. Shape is wider so four 50 pt envelope knobs still fit.
struct SynthControlGrid: View {
    private var preset: Binding<SynthPreset>
    private var audioEngine: AudioEngine?

    init(audioEngine: AudioEngine) {
        self.audioEngine = audioEngine
        self.preset = Binding(
            get: { audioEngine.preset },
            set: { audioEngine.preset = $0 }
        )
    }

    init(preset: Binding<SynthPreset>) {
        self.preset = preset
        self.audioEngine = nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                OscillatorView(preset: preset, oscillatorNumber: 1, audioEngine: audioEngine)
                OscillatorView(preset: preset, oscillatorNumber: 2, audioEngine: audioEngine)
            }
            .frame(minWidth: 240, maxWidth: .infinity, alignment: .top)

            VStack(spacing: 10) {
                ADSRView(preset: preset)
                FilterView(preset: preset)
                UnisonView(preset: preset)
            }
            .frame(minWidth: 280, maxWidth: .infinity, alignment: .top)

            VStack(spacing: 10) {
                LFOView(preset: preset)
                ModMatrixView(preset: preset)
            }
            .frame(minWidth: 140, maxWidth: .infinity, alignment: .top)

            VStack(spacing: 10) {
                AdvancedEffectsView(preset: preset)
                EffectsView(preset: preset)
            }
            .frame(minWidth: 160, maxWidth: .infinity, alignment: .top)
        }
        .accessibilityIdentifier("controlsSection")
    }
}
