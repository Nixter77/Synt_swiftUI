//
//  DSPStereoTool.swift
//  Synt_swiftUI
//
//  Width, mid/side balance, Haas delay and mono bass. The render path calls
//  this only while the preset enables it, so the default stays bit-exact.
//

import Foundation

public final class DSPStereoTool {
    public static let maxDelaySamples = 8192

    private var delay: [Float]
    private var write: Int = 0
    private var lpL: Float = 0
    private var lpR: Float = 0
    private var lpCoeff: Float = 0
    private var lpFreq: Float = -1
    private var lpRate: Float = 0
    /// -1 until the first call, so a delay that starts above zero stays a plain line.
    private var lastHaasMs: Float = -1
    private var haasFade: Float = 1
    private var haasFadeStep: Float = 1

    public init() {
        delay = [Float](repeating: 0, count: Self.maxDelaySamples)
    }

    public func reset() {
        for i in 0..<delay.count {
            delay[i] = 0
        }
        write = 0
        lpL = 0
        lpR = 0
        lpFreq = -1
        lpRate = 0
        lastHaasMs = -1
        haasFade = 1
        haasFadeStep = 1
    }

    /// Haas delays the right channel by 0...30 ms. Width 0 collapses to mono.
    /// Mid/side is −1 (mid) ... +1 (side). Mono bass ≤ 0 leaves the split off.
    public func process(
        left: Float,
        right: Float,
        width: Float,
        midSide: Float,
        haasMs: Float,
        monoBassHz: Float,
        sampleRate: Float
    ) -> (Float, Float) {
        var l = left
        var r = right
        let ms = max(0, min(30, haasMs))
        if ms > 0, sampleRate > 0 {
            var samples = Int(ms * 0.001 * sampleRate)
            if samples < 1 { samples = 1 }
            if samples >= Self.maxDelaySamples { samples = Self.maxDelaySamples - 1 }
            if lastHaasMs == 0 {
                for i in 0..<delay.count { delay[i] = 0 }
                write = 0
                haasFade = 0
                let fadeSamples = max(1, Int(0.005 * sampleRate))
                haasFadeStep = 1 / Float(fadeSamples)
            }
            var read = write - samples
            if read < 0 { read += Self.maxDelaySamples }
            let delayed = delay[read]
            delay[write] = r
            write += 1
            if write >= Self.maxDelaySamples { write = 0 }
            if haasFade < 1 {
                r = r * (1 - haasFade) + delayed * haasFade
                haasFade = min(1, haasFade + haasFadeStep)
            } else {
                r = delayed
            }
            lastHaasMs = ms
        } else {
            lastHaasMs = 0
        }

        let hz = max(0, min(400, monoBassHz))
        if hz > 1, sampleRate > 0 {
            if hz != lpFreq || sampleRate != lpRate {
                lpFreq = hz
                lpRate = sampleRate
                lpCoeff = 1 - exp(-2 * Float.pi * hz / sampleRate)
            }
            lpL += lpCoeff * (l - lpL)
            lpR += lpCoeff * (r - lpR)
            let low = (lpL + lpR) * 0.5
            l = low + (l - lpL)
            r = low + (r - lpR)
        }

        let w = max(0, min(2, width))
        let balance = max(-1, min(1, midSide))
        var mid = (l + r) * 0.5
        var side = (l - r) * 0.5
        mid *= 1 - max(balance, 0)
        side *= w * (1 + min(balance, 0))
        return (mid + side, mid - side)
    }
}
