//
//  DynamicsStatusReadout.swift
//  Synt_swiftUI
//
//  Live velocity, release velocity, and aftertouch. Read from atomics so a
//  steady output level still shows the last key.
//

import SwiftUI
import SynthCore

struct DynamicsStatusReadout: View {
    @Environment(\.theme) private var theme
    let metering: AtomicMeteringState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { _ in
            let vel = midi(metering.getInputVelocity())
            let rel = midi(metering.getReleaseVelocity())
            let at = midi(metering.getAftertouch())
            Text("Vel \(vel)  Rel \(rel)  AT \(at)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(theme.textDim)
                .lineLimit(1)
        }
        .accessibilityIdentifier("dynamicsStatus")
    }

    private func midi(_ value: Float) -> Int {
        Int((min(1, max(0, value)) * 127).rounded())
    }
}
