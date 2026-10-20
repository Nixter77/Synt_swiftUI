//
//  ShimmerProcessor.swift
//  Synt_swiftUI
//
//  Real-time dual-grain octave (+12 st) pitch shifter for shimmer reverb.
//  Zero allocation, zero lock on the audio render thread.
//

import Foundation

final class ShimmerProcessor {
    private var bufferL: [Float]
    private var bufferR: [Float]
    private var writeIndex: Int = 0
    private let bufferSize: Int = 4096
    private var sampleRate: Double

    // Grain size: 1024 samples (~23 ms at 44.1 kHz)
    private let grainSize: Int = 1024
    private var phase: Double = 0.0

    init(sampleRate: Double = 44100.0) {
        self.sampleRate = max(8_000, sampleRate)
        self.bufferL = Array(repeating: 0.0, count: 4096)
        self.bufferR = Array(repeating: 0.0, count: 4096)
    }

    /// Processes stereo input and returns +1 octave pitch-shifted signal.
    @inline(__always)
    func process(inputL: Float, inputR: Float) -> (Float, Float) {
        bufferL[writeIndex] = inputL
        bufferR[writeIndex] = inputR

        let grainD = Double(grainSize)
        let phaseInc = 1.0 / grainD
        phase += phaseInc
        if phase >= 1.0 { phase -= 1.0 }

        // Grain A
        let phaseA = phase
        let delayA = (1.0 - phaseA) * grainD
        let winA = grainWindow(phaseA)
        let sAL = readBuffer(buffer: bufferL, delay: delayA)
        let sAR = readBuffer(buffer: bufferR, delay: delayA)

        // Grain B (offset by 0.5 phase)
        var phaseB = phase + 0.5
        if phaseB >= 1.0 { phaseB -= 1.0 }
        let delayB = (1.0 - phaseB) * grainD
        let winB = grainWindow(phaseB)
        let sBL = readBuffer(buffer: bufferL, delay: delayB)
        let sBR = readBuffer(buffer: bufferR, delay: delayB)

        writeIndex = (writeIndex + 1) % bufferSize

        let outL = sAL * winA + sBL * winB
        let outR = sAR * winA + sBR * winB
        return (outL, outR)
    }

    @inline(__always)
    private func grainWindow(_ p: Double) -> Float {
        // Triangular window peaking at 0.5 with unity height
        let dist = abs(p - 0.5)
        return Float(max(0.0, 1.0 - 2.0 * dist))
    }

    @inline(__always)
    private func readBuffer(buffer: [Float], delay: Double) -> Float {
        var readPos = Double(writeIndex) - delay
        while readPos < 0 { readPos += Double(bufferSize) }
        while readPos >= Double(bufferSize) { readPos -= Double(bufferSize) }

        let indexInt = Int(readPos)
        let frac = Float(readPos - Double(indexInt))
        let nextIndex = (indexInt + 1) % bufferSize

        let s0 = buffer[indexInt]
        let s1 = buffer[nextIndex]
        return s0 + (s1 - s0) * frac
    }

    func setSampleRate(_ newRate: Double) {
        sampleRate = max(8_000, newRate)
    }

    func reset() {
        for i in 0..<bufferSize {
            bufferL[i] = 0.0
            bufferR[i] = 0.0
        }
        writeIndex = 0
        phase = 0.0
    }
}
