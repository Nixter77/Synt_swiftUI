//
//  PostFXLimiterTests.swift
//  Apple Peak Limiter sits after Reverb and before the main mixer.
//

import AVFoundation
import Testing
@testable import Synt_swiftUI

struct PostFXLimiterTests {

    @Test func peakLimiterFollowsReverbIntoTheMixer() {
        let engine = AudioEngine()
        let chain = engine.postFXChainForTesting()
        #expect(chain.limiterIsAttached)
        #expect(chain.limiterFollowsReverb)
        #expect(chain.limiterFeedsMixer)
        #expect(abs(chain.attack - 0.001) < 0.0001)
        #expect(abs(chain.decay - 0.050) < 0.0001)
        #expect(abs(chain.preGain) < 0.0001)
    }

    /// Same 0.62 overall gain as before, but applied before the limiter.
    @Test func headroomSitsBeforeTheLimiterAndMixerIsUnity() {
        let engine = AudioEngine()
        #expect(abs(engine.headroomMixer.outputVolume - 0.62) < 0.0001)
        #expect(abs(engine.mainMixerVolumeForTesting - 1) < 0.0001)
    }
}
