//
//  AudioEngine+Metering.swift
//  Synt_swiftUI
//
//  Move-only split of AudioEngine.swift. Same symbols, zero behavior change.
//

import AVFoundation
import Combine
import SwiftUI

extension AudioEngine {
    // MARK: - Metering (UI poll; audio writes AtomicMeteringState in render)

    func startMeteringPoll() {
        // UI-side poll — never hop to main from the render callback
        Timer.publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.pollMetering()
            }
            .store(in: &cancellables)
    }

    /// Main-thread only: copy atomics into @Published properties for SwiftUI.
    func pollMetering() {
        outputLevel = meteringState.getOutputLevel()
        peakLevel = meteringState.getPeakLevel()
        scopeData = meteringState.readScopeBuffer()
    }
}
