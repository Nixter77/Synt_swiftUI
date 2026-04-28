//
//  DSPChorus.swift
//  Synt_swiftUI
//

import Foundation

class DSPChorus {
    private var bufferL: [Float]
    private var bufferR: [Float]
    private var writeIndex: Int = 0
    private let bufferSize: Int
    
    var rate: Float = 1.5
    var depth: Float = 0.5 // 0..1 corresponds to 0..maxDelay modulation
    var mix: Float = 0.5
    
    // Internal LFO state
    private var phaseL: Double = 0.0
    private var phaseR: Double = Double.pi / 2.0 // 90 degree offset for stereo
    
    private let maxDelaySeconds: Double = 0.050 // 50ms max delay
    private let sampleRate: Double
    
    init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.bufferSize = Int(sampleRate * maxDelaySeconds) + 100 // +margin
        self.bufferL = Array(repeating: 0.0, count: bufferSize)
        self.bufferR = Array(repeating: 0.0, count: bufferSize)
    }
    
    func process(input: Float) -> (Float, Float) {
        process(inputL: input, inputR: input)
    }

    func process(inputL: Float, inputR: Float) -> (Float, Float) {
        if mix <= 0.001 { return (inputL, inputR) }
        
        // Write to buffer
        bufferL[writeIndex] = inputL
        bufferR[writeIndex] = inputR
        
        // Update LFO
        let phaseIncrement = (2.0 * Double.pi * Double(rate)) / sampleRate
        phaseL += phaseIncrement
        phaseR += phaseIncrement
        if phaseL >= 2.0 * Double.pi { phaseL -= 2.0 * Double.pi }
        if phaseR >= 2.0 * Double.pi { phaseR -= 2.0 * Double.pi }
        
        // Calculate delay modulation
        // Base delay typically 15-20ms. Modulation swings +/- depth.
        // Let's say center is 20ms, swing is depth * 5ms.
        let centerDelay = 0.020 // 20ms
        let modAmount = 0.005 // 5ms excursion
        
        let delayTimeL = centerDelay + modAmount * Double(depth) * sin(phaseL)
        let delayTimeR = centerDelay + modAmount * Double(depth) * sin(phaseR)
        
        let delayedL = readBuffer(buffer: bufferL, delaySeconds: delayTimeL)
        let delayedR = readBuffer(buffer: bufferR, delaySeconds: delayTimeR)
        
        // Mix
        // Wet = delayed, Dry = input
        let outL = inputL * (1.0 - mix) + delayedL * mix
        let outR = inputR * (1.0 - mix) + delayedR * mix
        
        // Advance write index
        writeIndex = (writeIndex + 1) % bufferSize
        
        return (outL, outR)
    }
    
    private func readBuffer(buffer: [Float], delaySeconds: Double) -> Float {
        let delaySamples = delaySeconds * sampleRate
        var readPos = Double(writeIndex) - delaySamples
        
        // Wrap
        while readPos < 0 { readPos += Double(bufferSize) }
        while readPos >= Double(bufferSize) { readPos -= Double(bufferSize) }
        
        // Linear Interpolation
        let indexInt = Int(readPos)
        let frac = Float(readPos - Double(indexInt))
        
        let nextIndex = (indexInt + 1) % bufferSize
        
        let s0 = buffer[indexInt]
        let s1 = buffer[nextIndex]
        
        return s0 + (s1 - s0) * frac
    }
    
    func reset() {
        bufferL = Array(repeating: 0.0, count: bufferSize)
        bufferR = Array(repeating: 0.0, count: bufferSize)
        writeIndex = 0
        phaseL = 0.0
        phaseR = Double.pi / 2.0
    }
}
