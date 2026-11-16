//
//  AudioEngine+CommandsAndMPERT.swift
//  Synt_swiftUI
//
//  Real-time preset snapshot pull, command queue dispatch, parameter CCs,
//  and MPE RPN/MCM handling extracted from AudioEngine+Render.swift.
//

import Foundation
import Synchronization

public extension AudioEngine {
    /// SYNT_27 P2-1: adopts snapshot, matrix and MSEG 1/2 together or not at all. If a writer
    /// is mid-publish, render keeps the whole previous set and retries next block.
    func pullPresetSnapshotRT() {
        guard rtPresetBuffer.hasPendingRT || rtModMatrix.hasPendingRT
            || mseg.hasPendingRT || mseg2.hasPendingRT else { return }
        publicationRenderPulling.store(true, ordering: .sequentiallyConsistent)
        if publicationWriterActive.load(ordering: .sequentiallyConsistent) {
            publicationRenderPulling.store(false, ordering: .sequentiallyConsistent)
            return
        }
        let snap = rtPresetBuffer.pullNewSnapshot()
        rtModMatrix.pullRT()
        mseg.pullRT()
        mseg2.pullRT()
        publicationRenderPulling.store(false, ordering: .sequentiallyConsistent)
        if let snap {
            applyPresetDSP(snap)
        }
    }

    func processCommandQueue() {
        pullPresetSnapshotRT()
        commandQueue.drain(limit: 128) { [self] command in
            handleCommand(command)
        }
        midiQueue.drain(limit: 128) { [self] command in
            handleCommand(command)
        }
        if midiResetRequested.exchange(false, ordering: .acquiringAndReleasing) {
            // Whatever is still queued came from before the reset; drop it.
            midiQueue.discardPendingRT()
            applyMIDIResetRT()
        }
        // After the whole batch, so releasing a chord (held ends at 0) still rings.
        // A new chord in the same batch is already held, and only its oldest tails go.
        trimAbandonedTails()
    }

    func handleCommand(_ command: AudioCommand) {
            switch command {
            case .resetPatchState:
                resetPatchStateRT()
            case .allNotesOff:
                releaseAllHeldNotesRT()
            case .clearMPEControllerOverrides:
                clearMPEControllerOverridesRT()
            case .keyDown(let midiNote, let velocity):
                meteringState.setInputVelocity(velocity)
                if cachedArpMode != .off {
                    let idx = midiNote < 0 ? 0 : min(127, midiNote)
                    arpNoteVelocities[idx] = velocity
                    handleCommand(.arpKeyDown(midiNote: midiNote))
                } else {
                    handleNoteOn(midiNote: midiNote, velocity: velocity)
                }
            case .keyUp(let midiNote, let releaseVelocity):
                meteringState.setReleaseVelocity(releaseVelocity)
                // Follow where the key went, so an arp toggle mid-hold cannot strand it.
                if heldKeysForArp.contains(midiNote) {
                    handleCommand(.arpKeyUp(midiNote: midiNote))
                } else {
                    handleNoteOff(midiNote: midiNote, releaseVelocity: releaseVelocity)
                }
            case .noteOn(let midiNote, let velocity):
                meteringState.setInputVelocity(velocity)
                handleNoteOn(midiNote: midiNote, velocity: velocity)
            case .noteOff(let midiNote, let releaseVelocity):
                meteringState.setReleaseVelocity(releaseVelocity)
                handleNoteOff(midiNote: midiNote, releaseVelocity: releaseVelocity)
            case .mpeKeyDown(let midiNote, let velocity, let channel):
                meteringState.setInputVelocity(velocity)
                handleNoteOn(midiNote: midiNote, velocity: velocity, channel: channel)
            case .mpeKeyUp(let midiNote, let channel, let releaseVelocity):
                meteringState.setReleaseVelocity(releaseVelocity)
                handleNoteOff(midiNote: midiNote, channel: channel, releaseVelocity: releaseVelocity)
            case .mpePitchBend(let channel, let value):
                let ch = Int(channel & 15)
                mpeChannelStates[ch].pitchBend = value
                let mul = exp2(Double(value) * Double(cachedMpePitchBendRange) / 12.0)
                mpeChannelStates[ch].pitchBendMultiplier = mul
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiChannel == channel {
                        voices[i].mpePitchBend = value
                        voices[i].mpePitchBendMultiplier = mul
                    }
                }
            case .mpePressure(let channel, let value):
                let ch = Int(channel & 15)
                mpeChannelStates[ch].pressure = value
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiChannel == channel {
                        voices[i].mpePressure = value
                    }
                }
            case .mpeTimbre(let channel, let value):
                let ch = Int(channel & 15)
                mpeChannelStates[ch].timbre = value
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiChannel == channel {
                        voices[i].mpeTimbre = value
                    }
                }
            case .setPitchBend(let amount):
                pitchBendTarget = amount
            case .setModWheel(let amount):
                modWheel = amount
            case .setAftertouch(let amount):
                meteringState.setAftertouch(amount)
                aftertouchTarget = amount
            case .setPolyAftertouch(let midiNote, let pressure):
                meteringState.setAftertouch(pressure)
                for i in 0..<AudioEngine.maxVoices {
                    if voices[i].isActive && voices[i].midiNote == midiNote {
                        voices[i].polyAftertouch = pressure
                    }
                }
                // Poly pressure is per-voice only; channel aftertouch owns aftertouchTarget.
            case .setChannelVolume(let value):
                applyExpressionController(cc: 7, value: value, target: &channelVolumeTarget)
            case .setExpression(let value):
                applyExpressionController(cc: 11, value: value, target: &expressionTarget)
            case .setSustain(let down):
                setSustainPedal(down: down)
            case .controlChange(let cc, let value):
                applyPlainCCRT(cc: cc, value: value)
            case .mpeControlChange(let channel, let cc, let value):
                handleRPNCC(channel: channel, cc: cc, value: value)
            case .midiClock:
                receiveMIDIClockRT()
            case .midiStart:
                applyMIDITransportRT(resetPhase: true, running: true)
            case .midiContinue:
                applyMIDITransportRT(resetPhase: false, running: true)
            case .midiStop:
                applyMIDITransportRT(resetPhase: false, running: false)
            case .setAddressedParameter(let id, let value):
                applyAddressedParameterRT(id: id, value: value)
            case .setFXOrder(let table):
                cachedFXOrder = table
            case .clearAll:
                clearAllVoices()
                // A new patch / panic must not inherit a bent pitch or a stuck pedal.
                pitchBendTarget = 0
                pitchBendSmoothed = 0
                cachedPitchBendMultiplier = 1
                cachedPitchBendMultiplierSmoothed = 0
                cachedPitchBendMultiplierRange = 0
                aftertouchTarget = 0
                aftertouchSmoothed = 0
                resetExpressionControllersRT()
                cachedMacro1 = 0
                cachedMacro2 = 0
                cachedMacro3 = 0
                cachedMacro4 = 0
                for i in 0..<16 {
                    mpeChannelStates[i] = MPEChannelState()
                }
                sustainPedalDown = false
                sustainedLo = 0
                sustainedHi = 0
                heldKeysForArp.removeAll()
                latchedKeysForArp.removeAll()
                playedKeysForArp.removeAll(keepingCapacity: true)
                arp.reset()
                for n in 0..<128 { arpNoteVelocities[n] = 0 }
                lastTriggeredSlot = -1
                arpGateSamplesLeft = 0
                arpStepIndex = 0
                seqMirror.heldNote = -1
                seqMirror.gateSamplesLeft = 0
                filterL.reset()
                filterR.reset()
                lfo.reset()
            case .arpKeyDown(let midiNote):
                if cachedArpLatch && heldKeysForArp.isEmpty {
                    latchedKeysForArp.removeAll()
                    playedKeysForArp.removeAll(keepingCapacity: true)
                }
                heldKeysForArp.insert(midiNote)
                if !playedKeysForArp.contains(midiNote) {
                    playedKeysForArp.append(midiNote)
                }
                arp.mode = cachedArpMode
                arp.octaves = cachedArpOctaves
                arp.latch = cachedArpLatch
                if cachedArpLatch {
                    latchedKeysForArp.insert(midiNote)
                    arp.setHeldKeys(latchedKeysForArp, playedOrder: playedKeysForArp)
                } else {
                    arp.setHeldKeys(heldKeysForArp, playedOrder: playedKeysForArp)
                }
            case .arpKeyUp(let midiNote):
                heldKeysForArp.remove(midiNote)
                arp.mode = cachedArpMode
                arp.octaves = cachedArpOctaves
                arp.latch = cachedArpLatch
                if !cachedArpLatch {
                    playedKeysForArp.removeAll { $0 == midiNote }
                    arp.setHeldKeys(heldKeysForArp, playedOrder: playedKeysForArp)
                } else {
                    arp.setHeldKeys(latchedKeysForArp, playedOrder: playedKeysForArp)
                }
            }
    }

    func applySingleParameterRT(target: MIDIControlTarget, rawValue: UInt8) {
        let norm = Float(rawValue) / 127.0
        switch target {
        case .cutoff:
            cachedFilterCutoff = 20.0 * pow(1000.0, norm)
        case .resonance:
            ccResonanceRT = norm * 0.95
            ccResonanceBaseRT = filterL.resonance
        case .amp:
            cachedMasterVolume = norm
        case .pan:
            ccPanTarget = (norm - 0.5) * 2.0
        case .pitch1:
            ccDetune1Target = (norm - 0.5) * 100.0
        case .pitch2:
            ccDetune2Target = (norm - 0.5) * 100.0
        case .finePitch:
            ccDetune1Target = (norm - 0.5) * 100.0
            ccDetune2Target = (norm - 0.5) * 100.0
        case .pwm1:
            ccPwm1Target = 0.1 + norm * 0.8
        case .pwm2:
            ccPwm2Target = 0.1 + norm * 0.8
        case .wtMorph1:
            ccWtMorph1Target = norm
        case .wtMorph2:
            ccWtMorph2Target = norm
        case .lfoRate:
            ccLfoRateTarget = 0.05 + norm * 19.95
        case .lfoDepth:
            ccLfoDepthTarget = norm
        case .mix, .osc2Volume:
            ccMixTarget = norm
        case .attack:
            ccAttackTarget = 0.001 + norm * 1.999
        case .decay:
            ccDecayTarget = 0.001 + norm * 1.999
        case .sustain:
            ccSustainTarget = norm
        case .release:
            ccReleaseTarget = 0.001 + norm * 2.999
        case .filterAttack:
            ccFilterAttackTarget = 0.001 + norm * 1.999
        case .filterDecay:
            ccFilterDecayTarget = 0.001 + norm * 1.999
        case .filterSustain:
            ccFilterSustainTarget = norm
        case .filterRelease:
            ccFilterReleaseTarget = 0.001 + norm * 2.999
        case .filterEnvelopeAmount:
            cachedFilterEnvAmount = (norm - 0.5) * 2.0
        case .reverbMix:
            cachedReverbMix = max(0, min(1, norm))
            parameterReverbMix = cachedReverbMix
        case .reverbRoomSize:
            cachedReverbRoom = max(0, min(1, norm))
            parameterReverbRoom = cachedReverbRoom
        case .reverbShimmer:
            cachedReverbShimmer = norm
        case .delayMix:
            pingPongDelay.mix = norm
        case .delayTime:
            pingPongDelay.delayTime = 0.01 + norm * 0.99
        case .delayFeedback:
            pingPongDelay.feedback = norm * 0.9
        case .chorusMix:
            dspChorus.mix = norm
        case .chorusRate:
            dspChorus.rate = 0.1 + norm * 4.9
        case .chorusDepth:
            dspChorus.depth = norm
        case .distortionMix:
            distortion.mix = norm
        case .distortionDrive:
            distortion.drive = norm
        case .phaserMix:
            phaser.mix = norm
        case .phaserRate:
            phaser.rate = 0.05 + norm * 4.95
        case .phaserDepth:
            phaser.depth = norm
        case .osc1Volume:
            oscillator1.volume = norm
        case .subOscVolume:
            cachedSubOscVolume = norm
        case .fmAmount:
            cachedFmAmount = norm
        case .ringModAmount:
            cachedRingModAmount = norm
        case .unisonDetune:
            cachedUnisonDetune = norm * 50.0
        case .unisonSpread:
            cachedUnisonSpread = norm
        case .analogDrift:
            cachedAnalogDrift = norm
        case .portamento:
            cachedPortamento = norm
        case .macro1:
            cachedMacro1 = (norm - 0.5) * 2.0
        case .macro2:
            cachedMacro2 = (norm - 0.5) * 2.0
        case .macro3:
            cachedMacro3 = (norm - 0.5) * 2.0
        case .macro4:
            cachedMacro4 = (norm - 0.5) * 2.0
        case .macro5:
            cachedMacro5 = (norm - 0.5) * 2.0
        case .macro6:
            cachedMacro6 = (norm - 0.5) * 2.0
        case .macro7:
            cachedMacro7 = (norm - 0.5) * 2.0
        case .macro8:
            cachedMacro8 = (norm - 0.5) * 2.0
        }
    }

    // MARK: - MPE RPN Handling (RPN 0 and RPN 6)

    func handleRPNCC(channel: UInt8, cc: UInt8, value: UInt8) {
        let ch = Int(channel & 0x0F)
        // SYNT_17 R14-7: ch1/ch16 outside the current zone reach this path only so an MCM can
        // switch zones. Everything except RPN 6 data entry there stays a plain CC (CC learn / NRPN).
        let inZone = AudioEngine.isMPEMasterChannel(channel, zone: cachedMpeZone)
            || AudioEngine.isMPEMemberChannel(channel, zone: cachedMpeZone, memberCount: cachedMpeMemberChannelCount)
        if !inZone {
            switch cc {
            case 100, 101:
                handleRPNSelectRT(ch: ch, cc: cc, value: value)
                // SYNT_18 R15-9: the MCM selection (CC101 = 0, CC100 = 6) is consumed as RPN only,
                // so a learned CC 100/101 does not also move a parameter during MCM. Any other
                // value stays a plain CC (CC learn / device NRPN).
                // SYNT_20 R16-8 (documented, accepted): only ch1/ch16 reach this path out of zone, and
                // there CC101 = 0 is ambiguous (MCM select or RPN 0 bend-range select), so a learned
                // CC 101 at value 0 on ch1/ch16 outside the zone is consumed as RPN select, never as a CC.
                let isMCMSelect = (cc == 101 && value == 0) || (cc == 100 && value == 6 && rpnStates[ch].rpnMSB == 0)
                if !isMCMSelect { applyPlainCCRT(cc: cc, value: value) }
            case 6 where rpnStates[ch].rpnMSB == 0 && rpnStates[ch].rpnLSB == 6:
                rpnStates[ch].dataMSB = value
                handleRPN(channel: channel, rpn: 6, value: value)
            default:
                applyPlainCCRT(cc: cc, value: value)
            }
            return
        }
        switch cc {
        case 100, 101:
            handleRPNSelectRT(ch: ch, cc: cc, value: value)
        case 96, 97:
            // SYNT_17: RPN Data Increment (96) / Decrement (97), MIDI 1.0. Steps the coarse value of the
            // selected RPN by 1 (value byte ignored). Only RPN 0 is steppable; MCM is not.
            if rpnStates[ch].rpnMSB == 0 && rpnStates[ch].rpnLSB == 0 {
                let cur = Int(rpnStates[ch].dataMSB ?? UInt8(currentBendRangeSemisRT(channel: channel)))
                let next = UInt8(max(0, min(96, cur + (cc == 96 ? 1 : -1))))
                rpnStates[ch].dataMSB = next
                handleRPN(channel: channel, rpn: 0, value: next)
            } else {
                applyPlainCCRT(cc: cc, value: value)
            }
        case 6:
            if let msb = rpnStates[ch].rpnMSB, let lsb = rpnStates[ch].rpnLSB {
                let rpn = (UInt16(msb) << 7) | UInt16(lsb)
                rpnStates[ch].dataMSB = value
                handleRPN(channel: channel, rpn: rpn, value: value)
            }
        case 38:
            // SYNT_16 low: Data Entry LSB. For RPN 0 it is cents (MIDI 1.0); other RPNs ignore it.
            if let msb = rpnStates[ch].rpnMSB, let lsb = rpnStates[ch].rpnLSB,
               (UInt16(msb) << 7) | UInt16(lsb) == 0, let coarse = rpnStates[ch].dataMSB {
                handleRPN(channel: channel, rpn: 0, value: coarse, cents: value)
            }
        default:
            break
        }
    }

    /// SYNT_17 R14-6: selecting an RPN (or the null RPN) forgets the previous Data Entry MSB,
    /// so a lone CC 38 can never refine a stale value from another RPN.
    @inline(__always)
    func handleRPNSelectRT(ch: Int, cc: UInt8, value: UInt8) {
        rpnStates[ch].dataMSB = nil
        if cc == 101 {
            rpnStates[ch].rpnMSB = value == 127 ? nil : value
        } else {
            rpnStates[ch].rpnLSB = value == 127 ? nil : value
        }
    }

    @inline(__always)
    func currentBendRangeSemisRT(channel: UInt8) -> Int {
        let r = AudioEngine.isMPEMasterChannel(channel, zone: cachedMpeZone) ? cachedPitchBendRange : cachedMpePitchBendRange
        return Int(r)
    }

    /// Render thread. The ordinary CC path (CC map / MIDI learn), shared with `.controlChange`.
    func applyPlainCCRT(cc: UInt8, value: UInt8) {
        let rtIdx = (rtCCMap + Int(cc & 127)).pointee.load(ordering: .acquiring)
        if rtIdx >= 0, let target = MIDIControlTarget.from(rtIndex: rtIdx) {
            if !target.writesAudioParameter || ccTakeoverShouldApply(cc: cc, raw: value, current: liveUnit(for: target), target: target) {
                applySingleParameterRT(target: target, rawValue: value)
            }
        }
    }

    /// Render thread. Touches only `cached*` / plain RT state and the lock-free mailbox.
    /// Never writes `preset` (its setter runs applyPreset + @Published) — main picks it up in `pollMPEConfigMailbox`.
    func handleRPN(channel: UInt8, rpn: UInt16, value: UInt8, cents: UInt8 = 0) {
        switch rpn {
        case 0:
            // RPN 0: Pitch Bend Sensitivity (semitones).
            // R12-4: on the zone's master channel it is the master (global) bend range;
            // on a member channel it is the per-note range.
            let range = Float(min(Int(value) * 100 + Int(min(cents, 99)), 9600)) / 100
            if AudioEngine.isMPEMasterChannel(channel, zone: cachedMpeZone) {
                mpeCtl.masterRange = range
                cachedPitchBendRange = range
                publishMPEConfigRT(masterRangeChanged: true)
                return
            }
            // SYNT_16 R13-2: RPN 0 from a channel outside the current zone is ignored.
            guard AudioEngine.isMPEMemberChannel(channel, zone: cachedMpeZone, memberCount: cachedMpeMemberChannelCount) else { return }
            mpeCtl.memberRange = range
            cachedMpePitchBendRange = range
            recomputeMPEBendMultipliersRT()
            publishMPEConfigRT()
        case 6:
            // RPN 6: MPE Configuration Message (MCM). Only on ch1 / ch16 (zone masters);
            // SYNT_16 R13-2: accepted whatever the current zone is, so the controller can switch zones.
            guard channel & 15 == 0 || channel & 15 == 15 else { return }
            let memberCount = min(Int(value), 15)
            // SYNT_17 R14-1: N = 0 ("zone off", e.g. controller disconnect) turns MPE off at RUNTIME only
            // (MPE 1.0). It is an override in `mpeCtl`, never written into params 163–166 / preset /
            // fullState, so the user's saved MPE setting is untouched and comes back on reload.
            cachedMpeMemberChannelCount = memberCount
            mpeCtl.memberCount = memberCount
            if channel == 0 {
                cachedMpeZone = .lower
                mpeCtl.zone = .lower
            } else if channel == 15 {
                cachedMpeZone = .upper
                mpeCtl.zone = .upper
            }
            cachedMpeEnabled = memberCount > 0
            mpeCtl.enabled = memberCount > 0
            // SYNT_16 R13-3: MCM resets member bend to ±48 and master bend to ±2 (MPE 1.0).
            mpeCtl.memberRange = 48
            cachedMpePitchBendRange = 48
            mpeCtl.masterRange = 2
            cachedPitchBendRange = 2
            recomputeMPEBendMultipliersRT()
            publishMPEConfigRT(masterRangeChanged: true)
        default:
            break
        }
    }

    /// SYNT_18 R15-8: render side of "Reset to my settings".
    func clearMPEControllerOverridesRT() {
        rtMPEResetApplied &+= 1
        mpeCtl.clearOverrides()
        cachedMpeEnabled = mpeCtl.baseEnabled
        cachedMpeZone = mpeCtl.baseZone
        cachedMpeMemberChannelCount = mpeCtl.baseMemberCount
        cachedMpePitchBendRange = mpeCtl.baseMemberRange
        cachedPitchBendRange = mpeCtl.baseMasterRange
        recomputeMPEBendMultipliersRT()
        publishMPEConfigRT(masterRangeChanged: true)
    }

    /// Render thread. Per event (RPN), not per sample.
    func recomputeMPEBendMultipliersRT() {
        let rangeD = Double(cachedMpePitchBendRange)
        for c in 0..<16 {
            mpeChannelStates[c].pitchBendMultiplier = exp2(Double(mpeChannelStates[c].pitchBend) * rangeD / 12.0)
        }
        for i in 0..<AudioEngine.maxVoices {
            if voices[i].isActive {
                voices[i].mpePitchBendMultiplier = exp2(Double(voices[i].mpePitchBend) * rangeD / 12.0)
            }
        }
    }

    @inline(__always)
    static func isMPEMasterChannel(_ channel: UInt8, zone: MPEZone) -> Bool {
        zone == .lower ? channel == 0 : channel == 15
    }

    @inline(__always)
    func publishMPEConfigRT(masterRangeChanged: Bool = false) {
        var packed = AudioEngine.packMPEConfig(
            enabled: cachedMpeEnabled,
            zone: cachedMpeZone,
            memberCount: cachedMpeMemberChannelCount,
            memberRange: cachedMpePitchBendRange,
            masterRange: cachedPitchBendRange,
            overrides: mpeCtl
        )
        if masterRangeChanged { packed |= AudioEngine.mpeMailboxMasterFlag }
        packed |= UInt64(rtMPEResetApplied) << AudioEngine.mpeMailboxResetSeqShift
        // Keep a not-yet-polled master-range change sticky (lock-free CAS, bounded by main's exchange).
        var current = mpeConfigMailbox.load(ordering: .acquiring)
        while true {
            var next = packed
            if current & AudioEngine.mpeMailboxFlag != 0 {
                next |= current & AudioEngine.mpeMailboxMasterFlag
            }
            let (exchanged, original) = mpeConfigMailbox.compareExchange(
                expected: current, desired: next, ordering: .acquiringAndReleasing)
            if exchanged { break }
            current = original
        }
    }

    static let mpeMailboxFlag: UInt64 = 1 << 63
    static let mpeMailboxMasterFlag: UInt64 = 1 << 62
    /// SYNT_21 R17-2: bits 44–51 carry render's applied-reset count (mod 256).
    static let mpeMailboxResetSeqShift: UInt64 = 44

    /// Bits 38–42: which values are controller overrides (SYNT_17 R14-1: main mirrors them, runtime only).
    static func packMPEConfig(enabled: Bool, zone: MPEZone, memberCount: Int, memberRange: Float, masterRange: Float,
                              overrides: MPEControllerOverride = MPEControllerOverride()) -> UInt64 {
        var v: UInt64 = mpeMailboxFlag
        if overrides.enabled != nil { v |= 1 << 38 }
        if overrides.zone != nil { v |= 1 << 39 }
        if overrides.memberCount != nil { v |= 1 << 40 }
        if overrides.memberRange != nil { v |= 1 << 41 }
        if overrides.masterRange != nil { v |= 1 << 42 }
        if enabled { v |= 1 }
        if zone == .upper { v |= 2 }
        v |= UInt64(max(0, min(15, memberCount)) & 0x1F) << 2
        // SYNT_16: ranges in centi-semitones (14 bits each) so a CC 38 fine value survives.
        v |= UInt64(max(0, min(9600, Int((memberRange * 100).rounded())))) << 8
        v |= UInt64(max(0, min(9600, Int((masterRange * 100).rounded())))) << 24
        return v
    }

    /// Main thread. Mirrors RPN/MCM changes made on the render thread into the display preset
    /// without `applyPreset()` (render already has the values).
    @discardableResult
    func pollMPEConfigMailbox() -> Bool {
        let v = mpeConfigMailbox.exchange(0, ordering: .acquiringAndReleasing)
        guard v & AudioEngine.mpeMailboxFlag != 0 else { return false }
        // SYNT_20 R16-6: after a reset on main, entries render published before applying it are
        // stale (they would briefly restore the old override); wait for render's ack.
        // SYNT_21 R17-2: an entry is current only if render had applied every reset main issued.
        // R17-3: if render never drains (e.g. the AU stays unallocated after Reset), main keeps
        // dropping entries — harmless, because only render produces them; the first render block
        // applies the reset and the stamps match again.
        guard UInt8(truncatingIfNeeded: v >> AudioEngine.mpeMailboxResetSeqShift) == mpeResetIssued else { return false }
        let enabled = v & 1 != 0
        let zone: MPEZone = v & 2 != 0 ? .upper : .lower
        let count = Int((v >> 2) & 0x1F)
        let memberRange = Float((v >> 8) & 0x3FFF) / 100
        let masterRange = Float((v >> 24) & 0x3FFF) / 100
        // SYNT_17 R14-1: runtime only. The preset, AU params 163–166 and fullState are NOT touched;
        // the controller values live in `controllerMPEMain` and the routing mirror.
        controllerMPEMain.enabled = v & (1 << 38) != 0 ? enabled : nil
        controllerMPEMain.zone = v & (1 << 39) != 0 ? zone : nil
        controllerMPEMain.memberCount = v & (1 << 40) != 0 ? count : nil
        controllerMPEMain.memberRange = v & (1 << 41) != 0 ? memberRange : nil
        controllerMPEMain.masterRange = v & (1 << 42) != 0 ? masterRange : nil
        mpeEnabled = enabled
        mpeZone = zone
        mpeMemberChannelCount = count
        mpePitchBendRange = memberRange
        // SYNT_16 R13-9: the controller's master range is runtime state, never written into the preset.
        if v & AudioEngine.mpeMailboxMasterFlag != 0 { controllerMasterPitchBendRange = controllerMPEMain.masterRange }
        controllerMPEConfigDidChange?()
        return true
    }
}
