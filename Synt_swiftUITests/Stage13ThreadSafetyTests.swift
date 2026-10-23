//
//  Stage13ThreadSafetyTests.swift
//  Synt_swiftUITests
//
//  Stage 1 tests for GROK_BUILD_TASKS_SYNT_13:
//  - R10-2: Concurrent load-while-render stress (lock-free handoff, TSan-clean)
//  - R10-1: applyPreset with user wavetable triggers zero rebuilds on knob sweeps
//

import XCTest
import AVFoundation
import Synchronization
@testable import SynthCore

final class Stage13ThreadSafetyTests: XCTestCase {

    func testConcurrentLoadWhileRenderStress() throws {
        let engine = AudioEngine()
        engine.preset.osc1Waveform = .wavetable
        engine.preset.osc1WavetableIndex = 5
        engine.applyPreset()
        engine.noteOn(midiNote: 60, velocity: 100)

        // Generate 4 different wavetables
        var testTables: [CompiledMipData] = []
        for t in 0..<4 {
            var frames: [[Float]] = []
            for f in 0..<8 {
                var frame = [Float](repeating: 0, count: 2048)
                let harmonic = Float(t * 8 + f + 1)
                for s in 0..<2048 {
                    frame[s] = sin(Float(s) / 2048.0 * 2.0 * .pi * harmonic)
                }
                frames.append(frame)
            }
            let wt = Wavetable(name: "StressTable\(t)", frames: frames)
            testTables.append(WavetableOscillator.compile(wavetable: wt, sampleRate: engine.sampleRate))
        }

        let isRunning = Atomic<Bool>(true)
        let swapCount = Atomic<Int>(0)
        let renderCount = Atomic<Int>(0)

        let group = DispatchGroup()

        // Background thread rapidly swapping compiled wavetables
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            var idx = 0
            while isRunning.load(ordering: .acquiring) {
                let compiled = testTables[idx % testTables.count]
                engine.wavetableEngine1.loadCompiledWavetable(compiled)
                engine.wavetableEngine2.loadCompiledWavetable(compiled)
                swapCount.wrappingAdd(1, ordering: .relaxed)
                idx &+= 1
                if idx % 10 == 0 {
                    Thread.sleep(forTimeInterval: 0.0001)
                }
            }
            group.leave()
        }

        // Render thread rendering audio blocks
        let bufferCapacity = 256
        let bufL = UnsafeMutablePointer<Float>.allocate(capacity: bufferCapacity)
        let bufR = UnsafeMutablePointer<Float>.allocate(capacity: bufferCapacity)
        defer {
            bufL.deallocate()
            bufR.deallocate()
        }

        // Render 200 blocks (51,200 samples) concurrently with swaps
        for _ in 0..<200 {
            engine.renderBlock(intoL: bufL, intoR: bufR, frameCount: bufferCapacity)
            for i in 0..<bufferCapacity {
                XCTAssertTrue(bufL[i].isFinite, "Rendered non-finite float on L: \(bufL[i])")
                XCTAssertTrue(bufR[i].isFinite, "Rendered non-finite float on R: \(bufR[i])")
            }
            renderCount.wrappingAdd(bufferCapacity, ordering: .relaxed)
        }

        isRunning.store(false, ordering: .releasing)
        group.wait()

        XCTAssertGreaterThan(swapCount.load(ordering: .relaxed), 10, "Swaps should have occurred concurrently")
        XCTAssertEqual(renderCount.load(ordering: .relaxed), 200 * bufferCapacity)
        engine.noteOff(midiNote: 60)
    }

    func testApplyPresetKnobSweepTriggersZeroRebuilds() throws {
        let engine = AudioEngine()
        
        // Build a user wavetable and embed into preset
        var frames: [[Float]] = []
        for f in 0..<8 {
            var frame = [Float](repeating: 0, count: 2048)
            for s in 0..<2048 {
                frame[s] = sin(Float(s) / 2048.0 * 2.0 * .pi * Float(f + 1))
            }
            frames.append(frame)
        }
        let table = Wavetable(name: "UserSweepTest", frames: frames)
        let serialized = table.serializedData()

        engine.preset.osc1Waveform = .wavetable
        engine.preset.osc1WavetableIndex = 5
        engine.preset.userWavetableName = table.name
        engine.preset.userWavetableData = serialized

        // First apply: compiles and caches
        engine.applyPreset()
        
        // Wait for background compilation to populate cache
        let key = WavetableCacheKey(contentHash: serialized.fnv1aHash(), sampleRate: engine.sampleRate)
        let start = Date()
        while WavetableOscillator.getCachedCompiled(for: key) == nil && Date().timeIntervalSince(start) < 2.0 {
            Thread.sleep(forTimeInterval: 0.01)
        }
        let cached = WavetableOscillator.getCachedCompiled(for: key)
        XCTAssertNotNil(cached, "Wavetable should be cached after first compile/apply")

        let compileCountBefore = WavetableOscillator.compileCountForTesting.load(ordering: .relaxed)

        // Perform 100 simulated knob moves calling applyPreset()
        for i in 1...100 {
            engine.preset.filterCutoff = 200.0 + Float(i) * 50.0
            engine.preset.filterResonance = Float(i % 10) * 0.1
            engine.preset.attack = 0.01 + Float(i) * 0.001
            engine.applyPreset()
        }

        let compileCountAfter = WavetableOscillator.compileCountForTesting.load(ordering: .relaxed)
        XCTAssertEqual(compileCountAfter, compileCountBefore, "applyPreset knob sweep must trigger ZERO wavetable rebuilds")
    }

    func testCacheMissOnContentChangeTriggersRebuild() throws {
        let engine = AudioEngine()

        var frames1: [[Float]] = []
        for _ in 0..<4 {
            frames1.append([Float](repeating: 0.5, count: 2048))
        }
        let data1 = Wavetable(name: "Table1", frames: frames1).serializedData()

        var frames2: [[Float]] = []
        for _ in 0..<4 {
            frames2.append([Float](repeating: -0.5, count: 2048))
        }
        let data2 = Wavetable(name: "Table2", frames: frames2).serializedData()

        engine.preset.osc1Waveform = .wavetable
        engine.preset.osc1WavetableIndex = 5
        engine.preset.userWavetableData = data1
        engine.applyPreset()

        let key1 = WavetableCacheKey(contentHash: data1.fnv1aHash(), sampleRate: engine.sampleRate)
        let start1 = Date()
        while WavetableOscillator.getCachedCompiled(for: key1) == nil && Date().timeIntervalSince(start1) < 2.0 {
            Thread.sleep(forTimeInterval: 0.01)
        }
        let countAfterFirst = WavetableOscillator.compileCountForTesting.load(ordering: .relaxed)

        // Same data again: 0 new compiles
        engine.applyPreset()
        XCTAssertEqual(WavetableOscillator.compileCountForTesting.load(ordering: .relaxed), countAfterFirst)

        // Explicitly compile/load different data
        try engine.loadUserWavetable(samples: [Float](repeating: 0.2, count: 2048 * 4), name: "Table3")
        let countAfterThird = WavetableOscillator.compileCountForTesting.load(ordering: .relaxed)
        XCTAssertGreaterThan(countAfterThird, countAfterFirst, "Different content must compile")
    }
}
