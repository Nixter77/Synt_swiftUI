//
//  DynamicsProbeTests.swift
//  SYNT_61 D0: measure velocity contrast before CleanBus and at the output.
//  Report-only, except Init pre-bus RMS must be monotonic.
//

import Foundation
@testable import SynthCore
import Testing
@testable import Synt_swiftUI

enum DynamicsProbe {
    static let sampleRate = 44_100.0
    static let totalFrames = 13_230 // 300 ms
    static let rmsStart = 2_205 // 50 ms
    static let midiVelocities = [1, 16, 32, 48, 64, 80, 96, 112, 127]
    static let dumpPath = "/Users/nikolay/gemini_projekts/Synt_swiftUI/docs/rounds/DYNAMICS_BASELINE_DUMP.txt"

    struct Take {
        var prePeak: Float = 0
        var preRMS: Float = 0
        var postPeak: Float = 0
        var postRMS: Float = 0
        var centroidHz: Float = 0
        var attackSeconds: Float = 0
        var nonFinite = false
    }

    static func dbfs(_ linear: Float) -> Float {
        guard linear > 1e-10, linear.isFinite else { return -160 }
        return 20 * log10(linear)
    }

    static func midi(_ velocity: Int) -> Float { Float(velocity) / 127 }

    static func prepare(_ engine: AudioEngine) {
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        engine.clockPhase = 0
        engine.cleanBus.reset()
        engine.dspChorus.reset()
        engine.dspReverb.reset()
        engine.sendReverb.reset()
        engine.pingPongDelay.reset()
        engine.sendDelay.reset()
        engine.phaser.reset()
        engine.distortion.reset()
        engine.parametricEQL.reset()
        engine.parametricEQR.reset()
        engine.shimmer.reset()
        engine.rotary.reset()
        engine.transientShaper.reset()
        engine.sceneHPF.reset()
        engine.stereoTool.reset()
        engine.characterToneL.reset()
        engine.characterToneR.reset()
        engine.frequencyShifter.reset()
        engine.filterL.reset()
        engine.filterR.reset()
        engine.lfo.reset()
        engine.lfo2.reset()
        engine.mseg.reset()
        engine.mseg2.reset()
    }

    static func render(engine: AudioEngine, notes: [(Int, Float)]) -> Take {
        prepare(engine)
        for (note, velocity) in notes {
            engine.noteOn(midiNote: note, velocity: velocity)
        }
        engine.processCommandsForTesting()
        var preSum: Double = 0
        var postSum: Double = 0
        var prePeak: Float = 0
        var postPeak: Float = 0
        var nonFinite = false
        var mono = [Float](repeating: 0, count: totalFrames)
        let rmsCount = totalFrames - rmsStart
        for i in 0..<totalFrames {
            let (l, r) = engine.renderOneSample()
            let preL = engine.dynamicsPreCleanBusL
            let preR = engine.dynamicsPreCleanBusR
            if !l.isFinite || !r.isFinite || !preL.isFinite || !preR.isFinite { nonFinite = true }
            let preAbs = max(abs(preL), abs(preR))
            let postAbs = max(abs(l), abs(r))
            if preAbs > prePeak { prePeak = preAbs }
            if postAbs > postPeak { postPeak = postAbs }
            mono[i] = 0.5 * (preL + preR)
            if i >= rmsStart {
                preSum += Double(preL * preL + preR * preR)
                postSum += Double(l * l + r * r)
            }
        }
        let denom = Double(rmsCount * 2)
        return Take(
            prePeak: prePeak,
            preRMS: Float((preSum / denom).squareRoot()),
            postPeak: postPeak,
            postRMS: Float((postSum / denom).squareRoot()),
            centroidHz: centroid(mono),
            attackSeconds: attack10to90(mono),
            nonFinite: nonFinite
        )
    }

    static func centroid(_ mono: [Float]) -> Float {
        let n = 4096
        let start = rmsStart
        guard mono.count >= start + n else { return 0 }
        var re = [Float](repeating: 0, count: n)
        var im = [Float](repeating: 0, count: n)
        let nm1 = Float(n - 1)
        for i in 0..<n {
            let w = 0.5 - 0.5 * cos(2 * Float.pi * Float(i) / nm1)
            re[i] = mono[start + i] * w
        }
        var j = 0
        for i in 1..<n {
            var bit = n >> 1
            while j & bit != 0 {
                j ^= bit
                bit >>= 1
            }
            j |= bit
            if i < j {
                re.swapAt(i, j)
                im.swapAt(i, j)
            }
        }
        var len = 2
        while len <= n {
            let ang = -2 * Float.pi / Float(len)
            let wlenRe = cos(ang)
            let wlenIm = sin(ang)
            var i = 0
            while i < n {
                var wRe: Float = 1
                var wIm: Float = 0
                let half = len / 2
                for k in 0..<half {
                    let uRe = re[i + k]
                    let uIm = im[i + k]
                    let vRe = re[i + k + half] * wRe - im[i + k + half] * wIm
                    let vIm = re[i + k + half] * wIm + im[i + k + half] * wRe
                    re[i + k] = uRe + vRe
                    im[i + k] = uIm + vIm
                    re[i + k + half] = uRe - vRe
                    im[i + k + half] = uIm - vIm
                    let nextRe = wRe * wlenRe - wIm * wlenIm
                    wIm = wRe * wlenIm + wIm * wlenRe
                    wRe = nextRe
                }
                i += len
            }
            len <<= 1
        }
        var num: Float = 0
        var den: Float = 0
        let df = Float(sampleRate) / Float(n)
        for k in 1..<(n / 2) {
            let mag = (re[k] * re[k] + im[k] * im[k]).squareRoot()
            num += df * Float(k) * mag
            den += mag
        }
        return den > 1e-8 ? num / den : 0
    }

    /// 10→90 % of a 2 ms peak follower on the pre-bus mono signal.
    static func attack10to90(_ mono: [Float]) -> Float {
        let hop = 88 // ~2 ms at 44.1 kHz
        let limit = min(mono.count, 8_820)
        var env: [Float] = []
        env.reserveCapacity(limit / hop + 1)
        var i = 0
        while i < limit {
            var peak: Float = 0
            let end = min(limit, i + hop)
            for j in i..<end { peak = max(peak, abs(mono[j])) }
            env.append(peak)
            i += hop
        }
        guard let peak = env.max(), peak > 1e-6 else { return 0 }
        let lo = 0.1 * peak
        let hi = 0.9 * peak
        var i10: Int?
        var i90: Int?
        for (idx, sample) in env.enumerated() {
            if i10 == nil, sample >= lo { i10 = idx }
            if i10 != nil, sample >= hi {
                i90 = idx
                break
            }
        }
        guard let a = i10, let b = i90 else { return 0 }
        return Float(b - a) * Float(hop) / Float(sampleRate)
    }

    static func rmsWindow(engine: AudioEngine, skip: Int, count: Int) -> Float {
        var sum: Double = 0
        for i in 0..<(skip + count) {
            let (l, r) = engine.renderOneSample()
            if i >= skip {
                sum += Double(l * l + r * r)
            }
        }
        return Float((sum / Double(count * 2)).squareRoot())
    }

    static func monotonic(_ db: [Float], tolerance: Float) -> Bool {
        for i in 1..<db.count where db[i] + tolerance < db[i - 1] { return false }
        return true
    }
}

@MainActor
@Suite(.serialized)
struct DynamicsProbeTests {
    @Test func legacyVelGainMatchesFormulaAndTracksAmount() {
        let velocities: [Float] = [0, 0.15, 0.37, 0.8, 1]
        let legacyCurves: [VelocityCurve] = [.linear, .exponential, .logarithmic]
        for curve in legacyCurves {
            for amount: Float in [0, 0.5, 1] {
                for velocity in velocities {
                    let gain = AudioEngine.legacyVelocityGain(velocity: velocity, curve: curve, toVolume: amount)
                    let curved: Float
                    switch curve {
                    case .linear:
                        curved = max(0.15, min(1.0, velocity))
                    case .exponential:
                        let clamped = max(0.0, min(1.0, velocity))
                        curved = max(0.15, clamped * clamped)
                    case .logarithmic:
                        let clamped = max(0.0, min(1.0, velocity))
                        curved = max(0.15, sqrt(clamped))
                    case .decibel:
                        curved = 1
                    }
                    let expected = 1.0 - amount * (1.0 - curved)
                    #expect(gain.bitPattern == expected.bitPattern)
                }
            }
        }

        let engine = AudioEngine()
        engine.preset = .defaultPreset
        engine.applyPresetForTesting()
        engine.noteOn(midiNote: 60, velocity: 0.37)
        engine.processCommandsForTesting()
        let voice = engine.voices.first { $0.isActive }
        let stored = voice?.velGain ?? -1
        let expected = AudioEngine.legacyVelocityGain(velocity: 0.37, curve: .linear, toVolume: 1)
        #expect(stored.bitPattern == expected.bitPattern)

        engine.applyAddressedParameterRT(id: SynthParameterAddress.velocityToVolume.rawValue, value: 0)
        let after = engine.voices.first { $0.isActive }?.velGain ?? -1
        #expect(after.bitPattern == Float(1).bitPattern)
    }

    @Test func initPreBusRmsIsMonotonicAndLouderWhenStruckHarder() {
        let engine = AudioEngine()
        engine.preset = .defaultPreset
        engine.applyPresetForTesting()
        var preDB: [Float] = []
        var sawEnergy = false
        for midi in DynamicsProbe.midiVelocities {
            let take = DynamicsProbe.render(engine: engine, notes: [(60, DynamicsProbe.midi(midi))])
            #expect(!take.nonFinite)
            #expect(take.postPeak.isFinite)
            if take.prePeak > 1e-5 { sawEnergy = true }
            preDB.append(DynamicsProbe.dbfs(take.preRMS))
        }
        #expect(sawEnergy)
        #expect(DynamicsProbe.monotonic(preDB, tolerance: 0.05), "Init pre RMS dB \(preDB)")
        #expect(preDB.last! > preDB.first! + 6, "Init vel range \(preDB.last! - preDB.first!) dB")
    }

    @Test(.timeLimit(.minutes(45)))
    func factoryDynamicsBaselineDump() {
        let presets = [SynthPreset.defaultPreset] + FactoryCharacterAuditTests.all
        var lines: [String] = []
        lines.append("# DYNAMICS_BASELINE_DUMP SYNT_61 D0")
        lines.append("# pre = preInsert (voices * 0.65 * master) before CleanBus")
        lines.append("# post = renderOneSample after CleanBus, inserts, cleanCeiling")
        lines.append("# C4, RMS 50..300 ms, velocities MIDI 1 16 32 48 64 80 96 112 127 as v/127")
        lines.append("# Chord = MIDI 48 52 55 60 at vel 40 vs 120. PhraseDrop on unison>1: C4 then G4, 40..120 ms RMS.")
        lines.append("# columns: name cat uni arp | vel prePeak_dB preRMS_dB postPeak_dB postRMS_dB centroid_Hz attack_s")
        lines.append("# SUMMARY name VelRange_pre VelRange_post VelBright ChordPre ChordPost PhraseDrop rmsMono centMono nan")
        var initMonotonic = false
        var worstDrop: Float = 0
        var worstName = ""
        for preset in presets {
            let engine = AudioEngine()
            engine.preset = preset
            engine.applyPresetForTesting()
            var takes: [DynamicsProbe.Take] = []
            var anyNaN = false
            for midi in DynamicsProbe.midiVelocities {
                let take = DynamicsProbe.render(engine: engine, notes: [(60, DynamicsProbe.midi(midi))])
                if take.nonFinite { anyNaN = true }
                takes.append(take)
                lines.append(String(
                    format: "%@ | %@ | %d | %@ | %d | %.2f | %.2f | %.2f | %.2f | %.1f | %.4f",
                    preset.name,
                    preset.category.rawValue,
                    preset.unisonVoices,
                    preset.arpMode == .off ? "off" : "arp",
                    midi,
                    DynamicsProbe.dbfs(take.prePeak),
                    DynamicsProbe.dbfs(take.preRMS),
                    DynamicsProbe.dbfs(take.postPeak),
                    DynamicsProbe.dbfs(take.postRMS),
                    take.centroidHz,
                    take.attackSeconds
                ))
            }
            let preDB = takes.map { DynamicsProbe.dbfs($0.preRMS) }
            let postDB = takes.map { DynamicsProbe.dbfs($0.postRMS) }
            let velRangePre = preDB.last! - preDB.first!
            let velRangePost = postDB.last! - postDB.first!
            let c32 = takes[2].centroidHz
            let c127 = takes.last!.centroidHz
            let bright: Float = c32 > 1 ? c127 / c32 : 0
            let mono = DynamicsProbe.monotonic(preDB, tolerance: 0.5)
            if preset.name == "Init" { initMonotonic = mono && !anyNaN }
            if !mono {
                for i in 1..<preDB.count where preDB[i - 1] - preDB[i] > worstDrop {
                    worstDrop = preDB[i - 1] - preDB[i]
                    worstName = preset.name
                }
            }
            let soft = DynamicsProbe.render(engine: engine, notes: [(48, DynamicsProbe.midi(40)), (52, DynamicsProbe.midi(40)), (55, DynamicsProbe.midi(40)), (60, DynamicsProbe.midi(40))])
            let hard = DynamicsProbe.render(engine: engine, notes: [(48, DynamicsProbe.midi(120)), (52, DynamicsProbe.midi(120)), (55, DynamicsProbe.midi(120)), (60, DynamicsProbe.midi(120))])
            let chordPre = DynamicsProbe.dbfs(hard.preRMS) - DynamicsProbe.dbfs(soft.preRMS)
            let chordPost = DynamicsProbe.dbfs(hard.postRMS) - DynamicsProbe.dbfs(soft.postRMS)
            var phrase = "—"
            if preset.unisonVoices > 1 {
                DynamicsProbe.prepare(engine)
                engine.noteOn(midiNote: 60, velocity: DynamicsProbe.midi(100))
                engine.processCommandsForTesting()
                let first = DynamicsProbe.rmsWindow(engine: engine, skip: 1_764, count: 3_528)
                engine.noteOff(midiNote: 60)
                engine.noteOn(midiNote: 67, velocity: DynamicsProbe.midi(100))
                engine.processCommandsForTesting()
                let second = DynamicsProbe.rmsWindow(engine: engine, skip: 1_764, count: 3_528)
                phrase = String(format: "%.2f", DynamicsProbe.dbfs(first) - DynamicsProbe.dbfs(second))
            }
            lines.append(String(
                format: "SUMMARY %@ | %.2f | %.2f | %.3f | %.2f | %.2f | %@ | %@ | %@ | %@",
                preset.name,
                velRangePre,
                velRangePost,
                bright,
                chordPre,
                chordPost,
                phrase,
                mono ? "Y" : "N",
                DynamicsProbe.monotonic(takes.map(\.centroidHz), tolerance: 1) ? "Y" : "N",
                anyNaN ? "NAN" : "ok"
            ))
            print(lines.last!)
        }
        let text = lines.joined(separator: "\n") + "\n"
        try? text.write(toFile: DynamicsProbe.dumpPath, atomically: true, encoding: .utf8)
        try? text.write(toFile: "/tmp/DYNAMICS_BASELINE_DUMP.txt", atomically: true, encoding: .utf8)
        #expect(FileManager.default.fileExists(atPath: DynamicsProbe.dumpPath))
        #expect(initMonotonic, "Init pre-bus RMS was not monotonic in the dump")
        print(String(format: "SYNT_61 worst pre-RMS dip %.2f dB on %@", worstDrop, worstName))
    }
}
