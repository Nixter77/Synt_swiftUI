//
//  DSPChorus.swift
//  Synt_swiftUI
//

import Foundation

public class DSPChorus {
    private var bufferL: [Float]
    private var bufferR: [Float]
    private var writeIndex: Int = 0
    private var bufferSize: Int
    
    public var rate: Float = 1.5
    public var depth: Float = 0.5 // 0..1 corresponds to 0..maxDelay modulation
    public var mix: Float = 0.5
    public var stereo: Bool = true {
        didSet {
            if stereo && !oldValue {
                phaseR = phaseL + Double.pi / 2.0
                if phaseR >= 2.0 * Double.pi { phaseR -= 2.0 * Double.pi }
            } else if !stereo && oldValue {
                phaseR = phaseL
            }
        }
    }
    public var chorusStereo: Bool {
        get { stereo }
        set { stereo = newValue }
    }
    /// Off leaves `process` on the chorus body, including the mix early-out.
    public var flanger: Bool = false
    public var feedback: Float = 0
    
    // Internal LFO state
    private var phaseL: Double = 0.0
    private var phaseR: Double = Double.pi / 2.0 // 90 degree offset for stereo
    
    private let maxDelaySeconds: Double = 0.050 // 50ms max delay
    private var sampleRate: Double
    
    public init(sampleRate: Double = 44100.0) {
        self.sampleRate = sampleRate
        self.bufferSize = Int(sampleRate * maxDelaySeconds) + 100 // +margin
        self.bufferL = Array(repeating: 0.0, count: bufferSize)
        self.bufferR = Array(repeating: 0.0, count: bufferSize)
    }
    
    public func process(input: Float) -> (Float, Float) {
        process(inputL: input, inputR: input)
    }

    public func process(inputL: Float, inputR: Float) -> (Float, Float) {
        if flanger { return processFlanger(inputL: inputL, inputR: inputR) }
        if mix <= 0.001 { return (inputL, inputR) }
        
        // Write to buffer
        bufferL[writeIndex] = inputL
        bufferR[writeIndex] = inputR
        
        // Update LFO
        let phaseIncrement = (2.0 * Double.pi * Double(rate)) / sampleRate
        phaseL += phaseIncrement
        if phaseL >= 2.0 * Double.pi { phaseL -= 2.0 * Double.pi }

        if stereo {
            phaseR += phaseIncrement
            if phaseR >= 2.0 * Double.pi { phaseR -= 2.0 * Double.pi }
        } else {
            phaseR = phaseL
        }
        
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

    private func processFlanger(inputL: Float, inputR: Float) -> (Float, Float) {
        let fb = max(-0.95, min(0.95, feedback))
        if mix <= 0.001 && abs(fb) <= 0.001 { return (inputL, inputR) }

        let phaseIncrement = (2.0 * Double.pi * Double(rate)) / sampleRate
        phaseL += phaseIncrement
        if phaseL >= 2.0 * Double.pi { phaseL -= 2.0 * Double.pi }
        if stereo {
            phaseR += phaseIncrement
            if phaseR >= 2.0 * Double.pi { phaseR -= 2.0 * Double.pi }
        } else {
            phaseR = phaseL
        }

        let delayL = max(0.0003, 0.003 + 0.002 * Double(depth) * sin(phaseL))
        let delayR = max(0.0003, 0.003 + 0.002 * Double(depth) * sin(phaseR))
        let delayedL = readBuffer(buffer: bufferL, delaySeconds: delayL)
        let delayedR = readBuffer(buffer: bufferR, delaySeconds: delayR)
        bufferL[writeIndex] = inputL + delayedL * fb
        bufferR[writeIndex] = inputR + delayedR * fb
        let wet = max(0, min(1, mix))
        let outL = inputL * (1 - wet) + delayedL * wet
        let outR = inputR * (1 - wet) + delayedR * wet
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
    
    public func setSampleRate(_ newRate: Double) {
        let newRate = max(8_000, newRate)
        guard abs(newRate - sampleRate) > 0.5 else { return }
        sampleRate = newRate
        bufferSize = Int(sampleRate * maxDelaySeconds) + 100
        bufferL = Array(repeating: 0, count: bufferSize)
        bufferR = Array(repeating: 0, count: bufferSize)
        writeIndex = 0
    }

    public func reset() {
        // In place: reset runs on the render thread (no allocation, no free).
        for i in 0..<bufferL.count { bufferL[i] = 0 }
        for i in 0..<bufferR.count { bufferR[i] = 0 }
        writeIndex = 0
        phaseL = 0.0
        phaseR = stereo ? (Double.pi / 2.0) : 0.0
    }
}
