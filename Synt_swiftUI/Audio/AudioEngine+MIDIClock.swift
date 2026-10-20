//
//  AudioEngine+MIDIClock.swift
//  Synt_swiftUI
//
//  MIDI timing clock on the audio thread. Twenty-four ticks per quarter note,
//  averaged over one quarter. Internal sync never reads this state.
//

import Foundation

extension AudioEngine {
    private static let midiClockTicksPerQuarter = 24

    /// Drop a running external transport when the user switches back to INT,
    /// and wait for a new Start after switching to EXT.
    func adoptSyncSourceRT() {
        let source = cachedSyncSource
        if source == appliedSyncSource { return }
        appliedSyncSource = source
        midiClockRunning = false
        midiClockHaveLast = false
    }

    /// One 0xF8. The first tick only marks the time; BPM updates once a quarter is full.
    func receiveMIDIClockRT() {
        guard cachedSyncSource == .midiClock else { return }
        let now = midiClockSample
        if midiClockHaveLast {
            let interval = now &- midiClockLastSample
            if interval > 0 && interval < 50_000_000 {
                let slot = midiClockIntervalWrite
                midiClockIntervals[slot] = Float(interval)
                midiClockIntervalWrite = (slot + 1) % Self.midiClockTicksPerQuarter
                if midiClockIntervalCount < Self.midiClockTicksPerQuarter {
                    midiClockIntervalCount += 1
                }
                if midiClockIntervalCount == Self.midiClockTicksPerQuarter {
                    var sum: Float = 0
                    for i in 0..<Self.midiClockTicksPerQuarter {
                        sum += midiClockIntervals[i]
                    }
                    let bpm = Float(60.0 * sampleRate) / sum
                    if bpm.isFinite {
                        cachedBPM = min(400, max(20, bpm))
                        externalBPMBits.store(cachedBPM.bitPattern, ordering: .releasing)
                    }
                }
            }
        }
        midiClockLastSample = now
        midiClockHaveLast = true
    }

    /// Start resets the arp, the sequencer and both LFOs. Continue does not.
    /// Stop releases sounding notes and leaves the phase where it is.
    func applyMIDITransportRT(resetPhase: Bool, running: Bool) {
        guard cachedSyncSource == .midiClock else { return }
        midiClockHaveLast = false
        if resetPhase {
            if let note = arp.currentNote {
                releaseHeldNote(note)
                arp.currentNote = nil
            }
            arpGateSamplesLeft = 0
            clockPhase = 0
            arpStepIndex = 0
            arp.reset()
            arp.mode = cachedArpMode
            arp.octaves = cachedArpOctaves
            arp.setHeldKeys(heldKeysForArp)
            releaseSequencerNote()
            seqMirror.stepIndex = 0
            seqMirror.phase = 0
            seqMirror.ratchetIndex = 0
            seqMirror.stepSkipped = false
            seqMirror.armed = true
            seqMirror.playing = true
            lfo.reset()
            lfo2.reset()
            sequencerTransport.setDisplayStep(0)
        }
        midiClockRunning = running
        if running && !resetPhase {
            seqMirror.playing = true
        }
        if !running {
            seqMirror.playing = false
            releaseSequencerNote()
            if let note = arp.currentNote {
                releaseHeldNote(note)
                arp.currentNote = nil
            }
            arpGateSamplesLeft = 0
        }
    }
}
