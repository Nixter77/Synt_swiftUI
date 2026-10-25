//
//  SynthCoreRenderAPITests.swift
//  A note that starts mid-block must stay silent until its sample offset.
//  CleanBus delays every sample by its lookahead, so the note is heard
//  lookahead frames after the offset.
//

import Foundation
import Testing
@testable import Synt_swiftUI
@testable import SynthCore

@MainActor
struct SynthCoreRenderAPITests {
    @Test func noteOnAtOffsetStaysSilentUntilThatSample() {
        let lookahead = CleanBus.lookahead
        let offset = 100
        let frames = offset + lookahead + 400
        let engine = AudioEngine()
        engine.prepare(sampleRate: 44_100, maxFrames: frames)
        let bytes: [UInt8] = [0x90, 60, 100]
        bytes.withUnsafeBufferPointer { raw in
            engine.enqueueMIDI(raw.baseAddress!, count: 3, sampleOffset: offset)
        }
        let left = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer {
            left.deallocate()
            right.deallocate()
        }
        engine.render(frames: frames, intoL: left, intoR: right)

        let emerge = offset + lookahead
        var before: Float = 0
        var after: Float = 0
        for i in 0..<emerge {
            before = max(before, abs(left[i]), abs(right[i]))
        }
        for i in (emerge + 200)..<frames {
            after = max(after, abs(left[i]), abs(right[i]))
        }
        #expect(before < 1e-5)
        #expect(after > 0.001)
    }
}
