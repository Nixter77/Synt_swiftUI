//
//  Synt_swiftUITests.swift
//  Synt_swiftUITests
//
//  Created by Nikolay Nikolayenko on 26/01/2026.
//

import Foundation
import Testing
@testable import Synt_swiftUI

struct Synt_swiftUITests {

    @Test func audioCommandQueueMaintainsFIFOOrder() async throws {
        let queue = AudioCommandQueue(capacity: 4)

        #expect(queue.push(.noteOn(midiNote: 60, velocity: 0.5)))
        #expect(queue.push(.noteOff(midiNote: 60)))
        #expect(queue.count == 2)

        guard let first = queue.pop() else {
            Issue.record("Expected first command")
            return
        }
        if case let .noteOn(midiNote, velocity) = first {
            #expect(midiNote == 60)
            #expect(abs(velocity - 0.5) < 0.0001)
        } else {
            Issue.record("Expected noteOn as first command")
        }

        guard let second = queue.pop() else {
            Issue.record("Expected second command")
            return
        }
        if case let .noteOff(midiNote) = second {
            #expect(midiNote == 60)
        } else {
            Issue.record("Expected noteOff as second command")
        }

        #expect(queue.pop() == nil)
        #expect(queue.isEmpty)
    }

    @Test func audioCommandQueueReportsFullWithoutOverwritingUnreadCommands() async throws {
        let queue = AudioCommandQueue(capacity: 3)

        #expect(queue.push(.noteOn(midiNote: 60, velocity: 1.0)))
        #expect(queue.push(.noteOn(midiNote: 61, velocity: 1.0)))
        #expect(!queue.push(.noteOn(midiNote: 62, velocity: 1.0)))

        guard let first = queue.pop() else {
            Issue.record("Expected queued command after full push attempt")
            return
        }
        if case let .noteOn(midiNote, _) = first {
            #expect(midiNote == 60)
        } else {
            Issue.record("Expected first original noteOn to remain queued")
        }
    }

    @Test func voiceManagerCapsActiveVoicesAtPreallocatedLimit() async throws {
        let manager = VoiceManager()

        for midiNote in 0..<80 {
            manager.addVoices(
                midiNote: midiNote,
                velocity: 1.0,
                unisonVoices: 1,
                detuneAmount: 0.0,
                spreadAmount: 0.0,
                portamento: 0.0
            )
        }

        #expect(manager.activeCount == VoiceManager.maxVoices)
    }

    @Test func voiceManagerMarksReleasedVoicesWithoutAllocatingNewCollections() async throws {
        let manager = VoiceManager()
        manager.addVoices(
            midiNote: 60,
            velocity: 0.75,
            unisonVoices: 3,
            detuneAmount: 7.0,
            spreadAmount: 0.8,
            portamento: 0.0
        )

        manager.releaseVoices(midiNote: 60)

        var releasingCount = 0
        manager.forEachActiveVoice { voice in
            if voice.midiNote == 60 && voice.isReleasing {
                releasingCount += 1
            }
            return true
        }

        #expect(releasingCount == 3)
        #expect(manager.activeCount == 3)
    }

    @Test func noteCalculatesFrequencyNameAndBlackKey() async throws {
        let a4 = Note(midiNote: 69)
        let cSharp4 = Note(midiNote: 61)

        #expect(abs(a4.frequency - 440.0) < 0.0001)
        #expect(a4.name == "A4")
        #expect(!a4.isBlack)
        #expect(cSharp4.name == "C#4")
        #expect(cSharp4.isBlack)
    }

    @Test func compressorLimiterClampsFirstTransient() async throws {
        let limiter = Compressor(sampleRate: 48_000)
        limiter.enabled = true
        limiter.limiterMode = true
        limiter.kneeWidth = 0.0
        limiter.setAttack(0.001)
        limiter.setRelease(0.080)

        let (left, right) = limiter.processStereo(inputL: 4.0, inputR: -4.0)

        #expect(abs(left) <= 1.0)
        #expect(abs(right) <= 1.0)
    }

    @Test func adsrDecayUsesExponentialCurve() async throws {
        var envelope = ADSREnvelope()
        envelope.attack = 0.01
        envelope.decay = 1.0
        envelope.sustain = 0.5
        envelope.release = 1.0

        var phase: EnvelopePhase = .decay
        var time = 0.0
        let sampleRate = 10.0

        let first = envelope.process(
            currentValue: 1.0,
            phase: &phase,
            time: &time,
            releaseStartValue: 0.0,
            isReleasing: false,
            sampleRate: sampleRate
        )

        // Exponential decay should drop quickly at first, unlike the old linear
        // curve which would have returned 0.95 for this setup.
        let expected = Float(0.5 + (1.0 - 0.5) * exp(-5.0 / sampleRate))
        #expect(abs(first - expected) < 0.0001)
        #expect(first < 0.95)
        #expect(phase == .decay)
    }

    @Test func adsrReleaseUsesExponentialCurve() async throws {
        var envelope = ADSREnvelope()
        envelope.release = 1.0

        var phase: EnvelopePhase = .release
        var time = 0.0
        let sampleRate = 10.0

        let first = envelope.process(
            currentValue: 0.8,
            phase: &phase,
            time: &time,
            releaseStartValue: 0.8,
            isReleasing: true,
            sampleRate: sampleRate
        )

        // Old linear release would have returned 0.8 on the first release sample.
        let expected = Float(0.8 * exp(-5.0 / sampleRate))
        #expect(abs(first - expected) < 0.0001)
        #expect(first < 0.8)
        #expect(phase == .release)
    }

    @Test func oscillatorPolyBLEPGuardKeepsHighDtOutputFinite() async throws {
        var oscillator = Oscillator()
        oscillator.waveform = .square
        oscillator.volume = 1.0

        let sample = oscillator.generateSample(
            phase: 0.0,
            phaseIncrement: AudioMath.twoPi * 2.0,
            noiseValue: 0.0
        )

        #expect(sample.isFinite)
        #expect(sample >= -1.0 && sample <= 1.0)
    }
}
