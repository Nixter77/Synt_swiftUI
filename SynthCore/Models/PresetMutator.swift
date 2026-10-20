//
//  PresetMutator.swift
//  Synt_swiftUI
//
//  Smart variation of preset parameters (±15%) while strictly maintaining
//  safe headroom and valid parameter bounds.
//

import Foundation

public enum PresetMutator {
    /// Mutates the given preset by ±amount (default 0.15 = 15%).
    /// Master volume is left intact to preserve exact headroom balancing.
    public static func mutate(preset: SynthPreset, amount: Float = 0.15) -> SynthPreset {
        var p = preset
        let amt = max(0.01, min(amount, 0.5))

        // Oscillators
        p.osc1WavetableMorph = clamp(p.osc1WavetableMorph + randOffset(amt), 0.0, 1.0)
        p.osc1PulseWidth = clamp(p.osc1PulseWidth + randOffset(amt * 0.5), 0.1, 0.9)
        p.osc1Detune = clamp(p.osc1Detune + randOffset(amt * 40.0), -50.0, 50.0)

        p.osc2WavetableMorph = clamp(p.osc2WavetableMorph + randOffset(amt), 0.0, 1.0)
        p.osc2PulseWidth = clamp(p.osc2PulseWidth + randOffset(amt * 0.5), 0.1, 0.9)
        p.osc2Detune = clamp(p.osc2Detune + randOffset(amt * 40.0), -50.0, 50.0)

        if p.subOscVolume > 0 {
            p.subOscVolume = clamp(p.subOscVolume + randOffset(amt * 0.5), 0.0, 1.0)
        }
        if p.fmAmount > 0 {
            p.fmAmount = clamp(p.fmAmount + randOffset(amt * 0.5), 0.0, 1.0)
        }

        // Filter
        p.filterCutoff = clamp(p.filterCutoff * (1.0 + randOffset(amt)), 20.0, 20000.0)
        p.filterResonance = clamp(p.filterResonance * (1.0 + randOffset(amt * 0.8)), 0.0, 0.95)
        p.filterEnvelopeAmount = clamp(p.filterEnvelopeAmount + randOffset(amt), -1.0, 1.0)
        p.filterKeyTracking = clamp(p.filterKeyTracking + randOffset(amt * 0.5), 0.0, 1.0)

        // Envelope
        p.attack = clamp(p.attack * (1.0 + randOffset(amt)), 0.001, 5.0)
        p.decay = clamp(p.decay * (1.0 + randOffset(amt)), 0.01, 10.0)
        p.sustain = clamp(p.sustain + randOffset(amt), 0.0, 1.0)
        p.release = clamp(p.release * (1.0 + randOffset(amt)), 0.01, 10.0)

        if p.filterEnvUseDedicatedADSR {
            p.filterAttack = clamp(p.filterAttack * (1.0 + randOffset(amt)), 0.001, 5.0)
            p.filterDecay = clamp(p.filterDecay * (1.0 + randOffset(amt)), 0.01, 10.0)
            p.filterSustain = clamp(p.filterSustain + randOffset(amt), 0.0, 1.0)
            p.filterRelease = clamp(p.filterRelease * (1.0 + randOffset(amt)), 0.01, 10.0)
        }
        if p.velocityToCutoff > 0 {
            p.velocityToCutoff = clamp(p.velocityToCutoff + randOffset(amt * 0.25), 0.0, 1.0)
        }
        if abs(p.velocityToEnvAmount) > 0 {
            p.velocityToEnvAmount = clamp(p.velocityToEnvAmount + randOffset(amt * 0.25), -1.0, 1.0)
        }

        // LFOs
        p.lfoRate = clamp(p.lfoRate * (1.0 + randOffset(amt)), 0.05, 20.0)
        p.lfoDepth = clamp(p.lfoDepth + randOffset(amt * 0.5), 0.0, 1.0)
        p.lfo2Rate = clamp(p.lfo2Rate * (1.0 + randOffset(amt)), 0.05, 20.0)
        p.lfo2Depth = clamp(p.lfo2Depth + randOffset(amt * 0.5), 0.0, 1.0)

        // Effects
        p.chorusRate = clamp(p.chorusRate * (1.0 + randOffset(amt * 0.5)), 0.1, 5.0)
        p.chorusDepth = clamp(p.chorusDepth + randOffset(amt * 0.4), 0.0, 1.0)

        p.delayTime = clamp(p.delayTime * (1.0 + randOffset(amt * 0.5)), 0.01, 2.0)
        p.delayFeedback = clamp(p.delayFeedback * (1.0 + randOffset(amt * 0.4)), 0.0, 0.85)
        p.delayMix = clamp(p.delayMix + randOffset(amt * 0.3), 0.0, 0.8)

        p.reverbMix = clamp(p.reverbMix + randOffset(amt * 0.3), 0.0, 0.8)
        p.reverbRoomSize = clamp(p.reverbRoomSize + randOffset(amt * 0.4), 0.0, 1.0)
        if p.reverbShimmer > 0 {
            p.reverbShimmer = clamp(p.reverbShimmer + randOffset(amt * 0.25), 0.0, 1.0)
        }
        if p.ringModAmount > 0 {
            p.ringModAmount = clamp(p.ringModAmount + randOffset(amt * 0.25), 0.0, 1.0)
        }

        // Unison & Drift
        p.unisonSpread = clamp(p.unisonSpread + randOffset(amt * 0.3), 0.0, 1.0)
        p.analogDrift = clamp(p.analogDrift + randOffset(amt * 0.25), 0.0, 1.0)

        // Arp Groove
        if p.arpMode != .off {
            p.arpGateLength = clamp(p.arpGateLength + randOffset(amt * 0.2), 0.1, 1.0)
            p.arpSwing = clamp(p.arpSwing + randOffset(amt * 0.2), 0.0, 0.75)
        }

        // Mutated preset name marker
        if !p.name.hasSuffix(" *") {
            p.name = "\(p.name) *"
        }

        return p
    }

    private static func randOffset(_ maxSpan: Float) -> Float {
        Float.random(in: -maxSpan...maxSpan)
    }

    private static func clamp(_ val: Float, _ minVal: Float, _ maxVal: Float) -> Float {
        max(minVal, min(val, maxVal))
    }
}

/// 4 Performance Macros (Brightness, Timbre, Movement, Space) applied relative to a base preset.
public struct PerformanceMacros: Equatable {
    public init(brightness: Float = 0.0, timbre: Float = 0.0, movement: Float = 0.0, space: Float = 0.0) {
        self.brightness = brightness
        self.timbre = timbre
        self.movement = movement
        self.space = space
    }
    /// -1.0 (dark) ... 0.0 (neutral) ... +1.0 (bright)
    public var brightness: Float = 0.0
    /// -1.0 (warm) ... 0.0 (neutral) ... +1.0 (rich/metallic)
    public var timbre: Float = 0.0
    /// -1.0 (static) ... 0.0 (neutral) ... +1.0 (animated)
    public var movement: Float = 0.0
    /// -1.0 (dry) ... 0.0 (neutral) ... +1.0 (lush)
    public var space: Float = 0.0

    public var isNeutral: Bool {
        abs(brightness) < 0.001 && abs(timbre) < 0.001 && abs(movement) < 0.001 && abs(space) < 0.001
    }

    public func apply(to base: SynthPreset) -> SynthPreset {
        guard !isNeutral else { return base }
        var p = base

        // 1. Brightness: Filter Cutoff (±2 octaves) + Filter Env Amount
        if abs(brightness) >= 0.001 {
            p.filterCutoff = max(20.0, min(20000.0, base.filterCutoff * exp2(brightness * 2.0)))
            p.filterEnvelopeAmount = max(-1.0, min(1.0, base.filterEnvelopeAmount + brightness * 0.35))
        }

        // 2. Timbre: Wavetable Morph + FM Amount
        if abs(timbre) >= 0.001 {
            p.osc1WavetableMorph = max(0.0, min(1.0, base.osc1WavetableMorph + timbre * 0.5))
            p.osc2WavetableMorph = max(0.0, min(1.0, base.osc2WavetableMorph + timbre * 0.5))
            p.fmAmount = max(0.0, min(1.0, base.fmAmount + timbre * 0.3))
        }

        // 3. Movement: LFO 1 & LFO 2 Depth + Rate
        if abs(movement) >= 0.001 {
            if movement > 0 && !base.lfoEnabled {
                p.lfoEnabled = true
            }
            p.lfoDepth = max(0.0, min(1.0, base.lfoDepth + movement * 0.45))
            p.lfoRate = max(0.05, min(20.0, base.lfoRate * exp2(movement * 0.8)))
            if base.lfo2Enabled {
                p.lfo2Depth = max(0.0, min(1.0, base.lfo2Depth + movement * 0.45))
            }
        }

        // 4. Space: Reverb Mix + Delay Mix + Chorus Mix
        if abs(space) >= 0.001 {
            p.reverbMix = max(0.0, min(0.85, base.reverbMix + space * 0.3))
            p.reverbRoomSize = max(0.0, min(1.0, base.reverbRoomSize + space * 0.25))
            p.delayMix = max(0.0, min(0.75, base.delayMix + space * 0.2))
            p.chorusMix = max(0.0, min(0.8, base.chorusMix + space * 0.15))
        }

        return p
    }
}
