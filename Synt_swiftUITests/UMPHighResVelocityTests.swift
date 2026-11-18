//
//  UMPHighResVelocityTests.swift
//  SYNT_62 D1.3–D1.4: MIDI 2 note velocity stays 16-bit. The 7-bit chop is unchanged.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

@MainActor
struct UMPHighResVelocityTests {
    @Test func halfScaleIsWithinOneTenThousandthOfOneHalf() {
        let velocity = SyntRenderContext.midi2Velocity16(0x8000 << 16)
        #expect(abs(velocity - (Float(0x8000) / 65535)) < 1e-6)
        #expect(abs(velocity - 0.5) < 1e-4)
    }

    @Test func noteOnKeepsSixteenBitVelocity() {
        let message = SyntRenderContext.midi2NoteMessage(0x4090_3C00, 0x8000_0000)
        guard case let .noteOn(note, velocity, channel)? = message else {
            Issue.record("expected a note-on")
            return
        }
        #expect(note == 60)
        #expect(channel == 0)
        #expect(abs(velocity - 0.5) < 1e-4)
        #expect(AudioEngine.command(for: message!) == .keyDown(midiNote: 60, velocity: velocity))
    }

    @Test func noteOnVelocityZeroIsANeutralNoteOff() {
        let message = SyntRenderContext.midi2NoteMessage(0x4090_3C00, 0)
        #expect(message == .noteOff(note: 60, velocity: 0.5, channel: 0))
    }

    @Test func noteOffKeepsSixteenBitVelocity() {
        let message = SyntRenderContext.midi2NoteMessage(0x4080_3C00, 0x4000_0000)
        let expected = Float(0x4000) / 65535
        #expect(message == .noteOff(note: 60, velocity: expected, channel: 0))
    }

    @Test func otherOpcodesStayOnTheSevenBitPath() {
        #expect(SyntRenderContext.midi2NoteMessage(0x40B0_0100, 0xFFFF_0000) == nil)
        let (bytes, count) = SyntRenderContext.midi2ToMidi1(0x4090_3C00, 0xFFFF_0000)
        #expect(count == 3 && bytes.0 == 0x90 && bytes.1 == 60 && bytes.2 == 127)
    }

    @Test func ringKeepsReleaseVelocityAndAFullRingFallsBackToNeutral() {
        let open = AudioCommandQueue(capacity: 8)
        #expect(open.push(.noteOff(midiNote: 70, releaseVelocity: 0.2)))
        guard case let .noteOff(note, velocity)? = open.pop() else {
            Issue.record("missing note-off")
            return
        }
        #expect(note == 70)
        #expect(velocity == 0.2)

        let full = AudioCommandQueue(capacity: 4)
        #expect(full.push(.noteOn(midiNote: 60, velocity: 1)))
        #expect(full.push(.noteOn(midiNote: 61, velocity: 1)))
        #expect(full.push(.noteOn(midiNote: 62, velocity: 1)))
        #expect(full.push(.noteOff(midiNote: 70, releaseVelocity: 0.2)))
        var saw = false
        full.drain(limit: 16) { command in
            if case .noteOff(let n, let releaseVelocity) = command {
                #expect(n == 70)
                #expect(releaseVelocity == 0.5)
                saw = true
            }
        }
        #expect(saw)
    }
}
