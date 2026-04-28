//
//  Filter.swift
//  Synt_swiftUI
//

import Foundation

class SynthFilter {
    var type: FilterType = .lowPass
    var cutoff: Float = 5000.0
    var resonance: Float = 0.5

    private var x1: Float = 0.0
    private var x2: Float = 0.0
    private var y1: Float = 0.0
    private var y2: Float = 0.0

    func reset() {
        x1 = 0.0
        x2 = 0.0
        y1 = 0.0
        y2 = 0.0
    }

    func process(_ input: Float, sampleRate: Float) -> Float {
        let normalizedCutoff = min(cutoff / sampleRate, 0.49)
        let omega = 2.0 * Float.pi * normalizedCutoff
        let sinOmega = sin(omega)
        let cosOmega = cos(omega)

        let q = max(0.1, resonance * 10.0)
        let alpha = sinOmega / (2.0 * q)

        var b0: Float = 0, b1: Float = 0, b2: Float = 0
        var a0: Float = 0, a1: Float = 0, a2: Float = 0

        switch type {
        case .lowPass:
            b0 = (1.0 - cosOmega) / 2.0
            b1 = 1.0 - cosOmega
            b2 = (1.0 - cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .highPass:
            b0 = (1.0 + cosOmega) / 2.0
            b1 = -(1.0 + cosOmega)
            b2 = (1.0 + cosOmega) / 2.0
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha

        case .bandPass:
            b0 = alpha
            b1 = 0.0
            b2 = -alpha
            a0 = 1.0 + alpha
            a1 = -2.0 * cosOmega
            a2 = 1.0 - alpha
        }

        b0 /= a0
        b1 /= a0
        b2 /= a0
        a1 /= a0
        a2 /= a0

        let output = b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2

        x2 = x1
        x1 = input
        y2 = y1
        y1 = output

        return output
    }
}
