//
//  GlassHorizonHangProbeTests.swift
//  MEASUREMENT ONLY — Glass Horizon offline @ 1/2/3/4/7 + phaser ON/OFF.
//

import Foundation
import Testing
@testable import Synt_swiftUI

@Suite(.serialized)
struct GlassHorizonHangProbeTests {

    private static let block = 256
    private static let warmBlocks = 16
    private static let measureBlocks = 48

    private static let densities: [(Int, [Int])] = [
        (1, [60]),
        (2, [60, 64]),
        (3, [60, 64, 67]),
        (4, [60, 64, 67, 71]),
        (7, [48, 52, 55, 60, 64, 67, 71]),
    ]

    private static func stockGlass() -> SynthPreset? {
        guard var p = SynthPreset.factoryPresets.first(where: { $0.name == "Glass Horizon" }) else {
            return nil
        }
        p.arpMode = .off
        return p
    }

    private static func measure(preset: SynthPreset, notes: [Int], label: String, measureMul: Int = 1) -> String {
        let engine = AudioEngine()
        engine.preset = preset
        engine.applyPresetForTesting()
        engine.clearAllNotes()
        engine.processCommandsForTesting()
        for midi in notes {
            engine.noteOn(midiNote: midi, velocity: 1.0)
        }
        engine.processCommandsForTesting()
        let held = engine.heldPartialCountForTesting
        let warm = warmBlocks * block
        let measureFrames = measureBlocks * block * measureMul
        _ = engine.renderFramesMetricsForTesting(warm)
        let t0 = DispatchTime.now().uptimeNanoseconds
        let m = engine.renderFramesMetricsForTesting(measureFrames)
        let t1 = DispatchTime.now().uptimeNanoseconds
        let ms = Double(t1 - t0) / 1_000_000.0
        let realtimeMs = Double(measureFrames) / 44_100.0 * 1000.0
        let load = ms / max(0.001, realtimeMs)
        return "\(label) n=\(notes.count) peak=\(m.peak) rms=\(m.rms) nearClip=\(m.nearClipCount) preClip=\(m.preClipPeak) nan=\(m.nanCount) held=\(held) renderMs=\(String(format: "%.2f", ms)) rtMs=\(String(format: "%.2f", realtimeMs)) cpuLoad≈\(String(format: "%.3f", load))"
    }

    private static func writeDump(_ lines: [String]) {
        let text = lines.joined(separator: "\n") + "\n"
        let paths = [
            FileManager.default.currentDirectoryPath + "/GLASS_HORIZON_PROBE_DUMP.txt",
            NSHomeDirectory() + "/gemini_projekts/Synt_swiftUI/GLASS_HORIZON_PROBE_DUMP.txt",
            "/tmp/GLASS_HORIZON_PROBE_DUMP.txt",
        ]
        for path in paths {
            try? text.write(toFile: path, atomically: true, encoding: .utf8)
        }
        print(text)
    }

    @Test(.timeLimit(.minutes(3)))
    func glassHorizon_stock_1_2_3_4_7_and_phaserAB() async throws {
        guard var base = Self.stockGlass() else {
            Issue.record("Missing Glass Horizon")
            return
        }

        var lines: [String] = []
        lines.append("# Glass Horizon offline probe")
        lines.append("# Apple Delay/Reverb NOT offline; phaser/wavetable/LFO ARE")
        lines.append("# factory: rev=\(base.reverbMix) room=\(base.reverbRoomSize) dly=\(base.delayMix) unison=\(base.unisonVoices) master=\(base.masterVolume) phaser=\(base.phaserEnabled)/\(base.phaserMode.rawValue) mix=\(base.phaserMix)")
        lines.append("# appleWet%=\(AudioMath.appleFXWetPercent(base.reverbMix)) softLimitGate=(wetDryMix>0.25) knee=0.70 → Glass peaks << knee so D≈main offline")

        var on = base
        on.phaserEnabled = true  // force ON for hang evidence even if factory is safe-OFF
        for (_, notes) in Self.densities {
            lines.append(Self.measure(preset: on, notes: notes, label: "GlassHorizon forced/phaserON"))
        }

        var off = base
        off.phaserEnabled = false
        for (_, notes) in Self.densities {
            lines.append(Self.measure(preset: off, notes: notes, label: "GlassHorizon phaserOFF"))
        }

        for nNotes in [[60, 64], [60, 64, 67, 71]] {
            for phaserOn in [true, false] {
                var p = base
                p.phaserEnabled = phaserOn
                let tag = phaserOn ? "AB/phaserON" : "AB/phaserOFF"
                lines.append(Self.measure(preset: p, notes: nNotes, label: "GlassHorizon \(tag)", measureMul: 4))
            }
        }

        Self.writeDump(lines)
        #expect(lines.count > 10)
    }
}
