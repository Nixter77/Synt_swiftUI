//
//  EffectEnableResetTests.swift
//  Enabling an effect is a plain flag write; the anti-pop reset runs on the
//  first processed sample (audio thread), so no setter does DSP work.
//

import Foundation
import Testing
@testable import SynthCore

struct EffectEnableResetTests {
    @Test func eqHistoryIsClearedOnTheFirstSampleAfterReEnable() {
        let eq = ParametricEQ()
        eq.lowGain = 12
        eq.enabled = true
        for _ in 0..<64 { _ = eq.process(1) }
        eq.enabled = false
        eq.enabled = true
        #expect(eq.process(0) == 0, "stale biquad history must not ring after re-enable")
    }

    @Test func phaserStateIsClearedOnTheFirstSampleAfterLeavingBypass() {
        let phaser = Phaser()
        phaser.mix = 1
        phaser.feedback = 0.8
        phaser.bypass = false
        for _ in 0..<512 { _ = phaser.process(inputL: 1, inputR: 1) }
        phaser.bypass = true
        phaser.bypass = false
        let out = phaser.process(inputL: 0, inputR: 0)
        #expect(out.left == 0 && out.right == 0)
    }
}
