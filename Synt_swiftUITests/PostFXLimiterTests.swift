//
//  PostFXLimiterTests.swift
//  Apple Peak Limiter sits after Reverb and before the main mixer.
//

import Foundation
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
}
