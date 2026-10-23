//
//  AudioEngine+Metering.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

public extension AudioEngine {
    // MARK: - Metering (UI poll; audio writes AtomicMeteringState in render)

    public func startMeteringPoll() {
        // UI-side poll — never hop to main from the render callback
        Timer.publish(every: 1.0 / 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollMetering()
            }
            .store(in: &cancellables)
    }

    /// Main-thread only. Copies levels into AudioMeterModel when they move.
    /// The scope buffer stays in AtomicMeteringState; the oscilloscope reads it.
    public func pollMetering() {
        // MIDI key highlight rides the same 30 Hz poll (no per-note main hop).
        refreshKeyDisplay()
        pollMPEConfigMailbox()
        let program = pendingProgram.exchange(-1, ordering: .acquiringAndReleasing)
        if program >= 0, let loaded = PresetBrowser.preset(forProgram: Int(program)) {
            preset = loaded
        }
        let tempoBits = externalBPMBits.load(ordering: .acquiring)
        if tempoBits != 0 {
            let bpm = Float(bitPattern: tempoBits)
            if abs(bpm - externalTempo) >= 0.5 {
                externalTempo = bpm
            }
        }
        meters.ingest(
            output: meteringState.getOutputLevel(),
            peak: meteringState.getPeakLevel()
        )
    }
}
