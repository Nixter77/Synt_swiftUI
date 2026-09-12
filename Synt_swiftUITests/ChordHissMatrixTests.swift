//
//  ChordHissMatrixTests.swift
//  Synt_swiftUITests
//
//  MEASUREMENT / REPRO ONLY — do not change DSP, VoiceManager, FX order, or sound.
//  Uses existing golden hooks: renderFramesMetricsForTesting (peak / RMS / nearClip / preClipPeak).
//
//  IMPORTANT GAP: Apple Delay/Reverb sit AFTER the soft-clipper on the live graph.
//  Offline renderOneSample() never sees those AVAudioUnits, so post-FX rasp/hiss may be
//  invisible here even when wet chords rasp in the app. DSP chorus / distortion / EQ / phaser
//  ARE in the offline path and can still elevate preClipPeak / nearClip.
//

import Foundation
import Testing
@testable import Synt_swiftUI

private enum HissMatrixTol {
    static let sampleRate: Double = 44_100
    static let blockSize: Int = 256
    static let warmBlocks: Int = 16
    static let measureBlocks: Int = 48 // ~279 ms sustain window
    /// Soft-clip threshold in AudioMath.softClip is 0.95; nearClip counts |sample| > 0.98.
    static let peakHot: Float = 0.95
    static let preClipHot: Float = 1.15
    static let nearClipElevated = 8
}

private struct HissRow: Sendable {
    var presetName: String
    var mode: String // dry | stock | wetBoost
    var noteCount: Int
    var peak: Float
    var rms: Float
    var nearClipCount: Int
    var preClipPeak: Float
    var nanCount: Int
    var heldPartials: Int
    var reverbMix: Float
    var delayMix: Float
    var chorusMix: Float

    var blowsUp: Bool {
        nanCount > 0
            || nearClipCount >= HissMatrixTol.nearClipElevated
            || peak >= HissMatrixTol.peakHot
            || preClipPeak >= HissMatrixTol.preClipHot
    }

    var summaryLine: String {
        let blow = blowsUp ? " **BLOW**" : ""
        let nan = nanCount > 0 ? " NAN" : ""
        return "\(presetName) \(mode) n=\(noteCount) peak=\(peak) rms=\(rms) nearClip=\(nearClipCount) preClip=\(preClipPeak) held=\(heldPartials) rev=\(reverbMix) dly=\(delayMix) cho=\(chorusMix)\(blow)\(nan)"
    }
}

private enum HissMatrixHarness {
    static let chord3: [Int] = [60, 64, 67]
    static let chord7: [Int] = [48, 52, 55, 60, 64, 67, 71]
    static let oneNote: [Int] = [60]

    static func notes(count: Int) -> [Int] {
        switch count {
        case 1: return oneNote
        case 3: return chord3
        case 7: return chord7
        default: return Array(oneNote.prefix(count))
        }
    }

    /// Stock factory preset with arp forced off so note density is what we play.
    static func stock(_ preset: SynthPreset) -> SynthPreset {
        var p = preset
        p.arpMode = .off
        return p
    }

    /// Dry: zero Apple sends + zero DSP chorus (still no Apple FX in offline path).
    static func dry(_ preset: SynthPreset) -> SynthPreset {
        var p = stock(preset)
        p.reverbMix = 0
        p.delayMix = 0
        p.chorusMix = 0
        p.distortionEnabled = false
        p.phaserEnabled = false
        return p
    }

    /// Wet boost: high delay/reverb sends (Apple — offline gap) + high DSP chorus (visible offline).
    static func wetBoost(_ preset: SynthPreset) -> SynthPreset {
        var p = stock(preset)
        p.reverbMix = 0.24
        p.reverbRoomSize = max(p.reverbRoomSize, 0.55)
        p.delayMix = 0.10
        p.delayFeedback = max(p.delayFeedback, 0.22)
        p.delayTime = max(p.delayTime, 0.25)
        p.chorusMix = 0.14
        p.chorusDepth = max(p.chorusDepth, 0.30)
        return p
    }

    static func makeEngine(preset: SynthPreset) -> AudioEngine {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        return engine
    }

    static func measure(preset: SynthPreset, notes: [Int], mode: String) -> HissRow {
        let engine = makeEngine(preset: preset)
        for n in notes {
            engine.noteOn(midiNote: n, velocity: 1.0)
        }
        engine.processCommandsForTesting()
        let held = engine.heldPartialCountForTesting
        let warmFrames = HissMatrixTol.warmBlocks * HissMatrixTol.blockSize
        let measureFrames = HissMatrixTol.measureBlocks * HissMatrixTol.blockSize
        _ = engine.renderFramesMetricsForTesting(warmFrames)
        let m = engine.renderFramesMetricsForTesting(measureFrames)
        return HissRow(
            presetName: preset.name,
            mode: mode,
            noteCount: notes.count,
            peak: m.peak,
            rms: m.rms,
            nearClipCount: m.nearClipCount,
            preClipPeak: m.preClipPeak,
            nanCount: m.nanCount,
            heldPartials: held,
            reverbMix: preset.reverbMix,
            delayMix: preset.delayMix,
            chorusMix: preset.chorusMix
        )
    }

    static func reportPath() -> URL {
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("CHORD_HISS_MATRIX_DUMP.txt")
    }

    static func writeDump(_ rows: [HissRow], extra: String) {
        var text = """
        # Chord hiss matrix dump (offline DSP path only)
        # Apple Delay/Reverb AFTER clipper → post-FX rasp NOT visible here.
        # Blow rule: nearClip>=\(HissMatrixTol.nearClipElevated) OR peak>=\(HissMatrixTol.peakHot) OR preClip>=\(HissMatrixTol.preClipHot) OR nan>0
        #
        """
        text += extra + "\n"
        for r in rows {
            text += r.summaryLine + "\n"
        }
        let url = reportPath()
        try? text.write(to: url, atomically: true, encoding: .utf8)
        // Also try repo-relative if cwd is DerivedData.
        let homeCandidates = [
            "/Users/nikolay/gemini_projekts/Synt_swiftUI/CHORD_HISS_MATRIX_DUMP.txt",
            "/tmp/CHORD_HISS_MATRIX_DUMP.txt"
        ]
        for path in homeCandidates {
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
        }
        print(text)
    }
}

struct ChordHissMatrixTests {

    // MARK: - Dry vs wet × 1 / 3 / 7 on a complex wet factory preset

    @Test func matrix_crystalLead_dryStockWet_1_3_7() async throws {
        guard let base = SynthPreset.factoryPresets.first(where: { $0.name == "Crystal Lead" }) else {
            Issue.record("Missing Crystal Lead")
            return
        }
        var rows: [HissRow] = []
        for (mode, preset) in [
            ("dry", HissMatrixHarness.dry(base)),
            ("stock", HissMatrixHarness.stock(base)),
            ("wetBoost", HissMatrixHarness.wetBoost(base))
        ] {
            for n in [1, 3, 7] {
                rows.append(HissMatrixHarness.measure(
                    preset: preset,
                    notes: HissMatrixHarness.notes(count: n),
                    mode: mode
                ))
            }
        }
        HissMatrixHarness.writeDump(rows, extra: "stimulus=Crystal Lead dry/stock/wetBoost")

        for r in rows {
            #expect(r.nanCount == 0, "\(r.summaryLine)")
            #expect(r.peak.isFinite && r.rms.isFinite)
            #expect(r.rms <= r.peak + 1.0e-6)
        }

        // Document: wetBoost vs dry at 3 notes — Apple sends do not change offline metrics;
        // DSP chorus in wetBoost MAY raise peak/preClip. Capture deltas for the report.
        let dry3 = rows.first { $0.mode == "dry" && $0.noteCount == 3 }!
        let wet3 = rows.first { $0.mode == "wetBoost" && $0.noteCount == 3 }!
        let stock3 = rows.first { $0.mode == "stock" && $0.noteCount == 3 }!
        print(String(
            format: "CrystalLead 3-note deltas: wet-dry peak=%.5f preClip=%.5f nearClip=%d | stock peak=%.4f nearClip=%d",
            wet3.peak - dry3.peak,
            wet3.preClipPeak - dry3.preClipPeak,
            wet3.nearClipCount - dry3.nearClipCount,
            stock3.peak,
            stock3.nearClipCount
        ))
    }

    // MARK: - Full factory preset matrix at 1 / 3 / 7 (stock sends)

    @Test func matrix_factoryPresets_stock_1_3_7_documentBlowUps() async throws {
        let presets = SynthPreset.factoryPresets
        #expect(!presets.isEmpty)

        var rows: [HissRow] = []
        for preset in presets {
            let stock = HissMatrixHarness.stock(preset)
            for n in [1, 3, 7] {
                rows.append(HissMatrixHarness.measure(
                    preset: stock,
                    notes: HissMatrixHarness.notes(count: n),
                    mode: "stock"
                ))
            }
        }
        HissMatrixHarness.writeDump(rows, extra: "stimulus=ALL factory stock @ 1/3/7")

        let blow3 = rows.filter { $0.noteCount == 3 && $0.blowsUp }.map(\.presetName)
        let blow7 = rows.filter { $0.noteCount == 7 && $0.blowsUp }.map(\.presetName)
        let blow3ok7 = Set(blow3).subtracting(blow7).sorted()
        let ok3blow7 = Set(blow7).subtracting(blow3).sorted()

        print("BLOW@3: \(blow3)")
        print("BLOW@7: \(blow7)")
        print("BLOW@3 but OK@7: \(blow3ok7)")
        print("OK@3 but BLOW@7: \(ok3blow7)")

        for r in rows {
            #expect(r.nanCount == 0, "NaN/Inf on \(r.summaryLine)")
        }

        // Documenting golden: if any stock 3-note blows on the offline DSP path, surface it.
        // This is allowed to FAIL when elevated nearClip/peak is reproducible pre-Apple-FX.
        // If the live rasp is only post-Apple-FX, blow3 may be empty — see NOTES.md gap.
        if !blow3.isEmpty {
            let detail = rows.filter { $0.noteCount == 3 && $0.blowsUp }.map(\.summaryLine).joined(separator: "\n")
            Issue.record(
                Comment(rawValue: "Documenting: elevated nearClip/peak on stock 3-note (offline DSP):\n\(detail)")
            )
            #expect(
                blow3.isEmpty,
                "Repro: stock 3-note elevated nearClip/peak on \(blow3). Offline path only — Apple FX still after clipper."
            )
        }
    }

    // MARK: - Wet-boost factory subset (pads / keys / leads with complex timbre)

    @Test func matrix_wetComplex_3note_documentNearClip() async throws {
        let names = [
            "Crystal Lead", "Silk Lead", "Cloud Bed", "Slow Motion",
            "Bell Keys", "Soft EP", "Section Soft", "Shimmer Rise"
        ]
        var rows: [HissRow] = []
        for name in names {
            guard let base = SynthPreset.factoryPresets.first(where: { $0.name == name }) else {
                Issue.record("Missing factory preset \(name)")
                continue
            }
            let wet = HissMatrixHarness.wetBoost(base)
            let dry = HissMatrixHarness.dry(base)
            rows.append(HissMatrixHarness.measure(preset: dry, notes: HissMatrixHarness.chord3, mode: "dry"))
            rows.append(HissMatrixHarness.measure(preset: wet, notes: HissMatrixHarness.chord3, mode: "wetBoost"))
        }
        HissMatrixHarness.writeDump(rows, extra: "stimulus=wet-complex 3-note dry vs wetBoost")

        for r in rows {
            #expect(r.nanCount == 0, "\(r.summaryLine)")
        }

        let wetBlows = rows.filter { $0.mode == "wetBoost" && $0.blowsUp }
        if !wetBlows.isEmpty {
            let detail = wetBlows.map { $0.summaryLine }.joined(separator: "\n")
            #expect(
                wetBlows.isEmpty,
                "Repro: wetBoost 3-note elevated nearClip/peak:\n\(detail)"
            )
        } else {
            // Documenting golden: offline stays clean → live rasp is post-clipper Apple FX.
            withKnownIssue(
                "Apple-FX-after-clipper gap: Delay→Reverb sit after softClip; offline metrics miss wet rasp. See CHORD_HISS_NOTES.md."
            ) {
                #expect(Bool(false), "Expected live wet rasp invisible offline (documenting).")
            }
        }
    }

    // MARK: - Synthetic dry/wet control (Init-like) — 1 / 3 / 7

    @Test func matrix_syntheticInit_dryVsWetSends_1_3_7() async throws {
        var dry = SynthPreset.defaultPreset
        dry.arpMode = .off
        dry.lfoEnabled = false
        dry.distortionEnabled = false
        dry.eqEnabled = false
        dry.phaserEnabled = false
        dry.chorusMix = 0
        dry.reverbMix = 0
        dry.delayMix = 0
        dry.attack = 0.01
        dry.decay = 0.05
        dry.sustain = 0.85
        dry.release = 0.08
        dry.filterCutoff = 8000
        dry.masterVolume = 0.5
        dry.osc2Enabled = false
        dry.name = "InitDry"

        var wet = dry
        wet.name = "InitWetBoost"
        wet.reverbMix = 0.24
        wet.delayMix = 0.10
        wet.delayFeedback = 0.22
        wet.chorusMix = 0.14

        var rows: [HissRow] = []
        for (mode, preset) in [("dry", dry), ("wetBoost", wet)] {
            for n in [1, 3, 7] {
                rows.append(HissMatrixHarness.measure(
                    preset: preset,
                    notes: HissMatrixHarness.notes(count: n),
                    mode: mode
                ))
            }
        }
        HissMatrixHarness.writeDump(rows, extra: "stimulus=synthetic Init dry vs wetBoost")

        let dry1 = rows.first { $0.mode == "dry" && $0.noteCount == 1 }!
        let dry3 = rows.first { $0.mode == "dry" && $0.noteCount == 3 }!
        let dry7 = rows.first { $0.mode == "dry" && $0.noteCount == 7 }!
        #expect(dry1.nearClipCount == 0)
        #expect(dry3.peak > dry1.peak * 1.05, "3-note should exceed 1-note on linear sum")
        #expect(dry7.peak > dry3.peak * 1.02 || dry7.preClipPeak >= dry3.preClipPeak,
                "7-note should be at least as hot as 3-note (linear sum / steal)")

        // Apple send knobs alone must not change offline metrics (gap proof).
        let wet1 = rows.first { $0.mode == "wetBoost" && $0.noteCount == 1 }!
        // Chorus IS in offline path — wet may differ; reverb/delay alone would not.
        #expect(dry1.nanCount == 0 && wet1.nanCount == 0)
        print(String(
            format: "Init dry1 peak=%.4f wet1 peak=%.4f (chorus in-path; Apple FX not)",
            dry1.peak, wet1.peak
        ))
    }
}
