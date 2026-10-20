//
//  PatchHistoryTests.swift
//  Synt_swiftUITests
//
//  Stage 2: Patch undo/redo history, drag gesture single-step, and A/B compare.
//

import Foundation
@testable import SynthCore
import Testing

@MainActor
struct PatchHistoryTests {
    @Test func threeChangesThreeUndosRestoresInitialPresetAndGoldenHash() {
        let engine = AudioEngine(coreOnly: true)
        let history = PatchHistoryManager(maxSteps: 64)

        let initial = engine.preset
        let initialHash = InitGoldenTests.renderHash(initial)

        // Change 1
        var p1 = initial
        p1.filterCutoff = 1200
        history.recordChange(from: initial, to: p1)
        engine.preset = p1

        // Change 2
        var p2 = p1
        p2.filterResonance = 0.8
        history.recordChange(from: p1, to: p2)
        engine.preset = p2

        // Change 3
        var p3 = p2
        p3.attack = 0.25
        history.recordChange(from: p2, to: p3)
        engine.preset = p3

        #expect(engine.preset.attack == 0.25)
        #expect(history.undoActions.count == 3)

        // Undo 1
        let u1 = history.undo()
        #expect(u1 != nil)
        #expect(u1?.preset.attack == initial.attack)
        #expect(u1?.preset.filterResonance == 0.8)
        engine.preset = u1!.preset

        // Undo 2
        let u2 = history.undo()
        #expect(u2 != nil)
        #expect(u2?.preset.filterResonance == initial.filterResonance)
        #expect(u2?.preset.filterCutoff == 1200)
        engine.preset = u2!.preset

        // Undo 3
        let u3 = history.undo()
        #expect(u3 != nil)
        #expect(u3?.preset == initial)
        engine.preset = u3!.preset

        // Check hash matches golden
        let restoredHash = InitGoldenTests.renderHash(engine.preset)
        #expect(restoredHash == initialHash, "3 changes + 3 undos must produce identical golden render hash")
    }

    @Test func redoRestoresUndoneChangesInOrder() {
        let engine = AudioEngine(coreOnly: true)
        let history = PatchHistoryManager(maxSteps: 64)

        let initial = engine.preset
        var p1 = initial; p1.filterCutoff = 1200
        var p2 = p1; p2.filterResonance = 0.8
        var p3 = p2; p3.attack = 0.25

        history.recordChange(from: initial, to: p1)
        history.recordChange(from: p1, to: p2)
        history.recordChange(from: p2, to: p3)

        _ = history.undo()
        _ = history.undo()
        _ = history.undo()
        #expect(history.canRedo)

        let r1 = history.redo()
        #expect(r1?.preset.filterCutoff == 1200)

        let r2 = history.redo()
        #expect(r2?.preset.filterResonance == 0.8)

        let r3 = history.redo()
        #expect(r3?.preset.attack == 0.25)
        #expect(!history.canRedo)
    }

    @Test func abCompareMaintainsSeparateHistories() {
        let history = PatchHistoryManager(maxSteps: 64)
        let initialA = SynthPreset.defaultPreset

        var a1 = initialA
        a1.filterCutoff = 1000
        history.recordChange(from: initialA, to: a1)

        // Start A/B compare: current sound stored as A, active slot becomes B
        let abToggle1 = history.toggleAB(currentPreset: a1)
        #expect(abToggle1?.slot == .b)
        #expect(history.activeSlot == .b)

        // Make edits in B
        var b1 = a1
        b1.filterResonance = 0.9
        history.recordChange(from: a1, to: b1)

        var b2 = b1
        b2.decay = 0.5
        history.recordChange(from: b1, to: b2)

        #expect(history.undoStackB.count == 2)
        #expect(history.undoStackA.count == 1)

        // Toggle back to A
        let abToggle2 = history.toggleAB(currentPreset: b2)
        #expect(abToggle2?.slot == .a)
        #expect(history.activeSlot == .a)
        #expect(abToggle2?.preset.filterCutoff == 1000)
        #expect(abToggle2?.preset.filterResonance == initialA.filterResonance)

        // Undo in A restores initialA
        let undoneA = history.undo(in: .a)
        #expect(undoneA == initialA)

        // Switch to B and verify B's history is completely intact
        let abToggle3 = history.toggleAB(currentPreset: undoneA!)
        #expect(abToggle3?.slot == .b)
        #expect(history.activeSlot == .b)
        #expect(history.undoStackB.count == 2)

        let undoneB1 = history.undo(in: .b)
        #expect(undoneB1?.decay == a1.decay)
        #expect(undoneB1?.filterResonance == 0.9)

        let undoneB2 = history.undo(in: .b)
        #expect(undoneB2?.filterResonance == a1.filterResonance)
    }

    @Test func knobDragProducesSingleUndoStep() {
        let history = PatchHistoryManager(maxSteps: 64)
        var current = SynthPreset.defaultPreset
        history.registerPresetProvider { current }

        // Start drag gesture
        history.onDragStart()

        // Multiple intermediate ticks of drag
        current.filterCutoff = 6000
        current.filterCutoff = 7000
        current.filterCutoff = 8000

        // End drag gesture
        history.onDragEnd()

        #expect(history.undoActions.count == 1, "continuous drag gesture must record exactly one undo step")
        let undone = history.undo()
        #expect(undone?.preset.filterCutoff == SynthPreset.defaultPreset.filterCutoff)
    }

    @Test func historyCapacityIsAtLeast50Steps() {
        let history = PatchHistoryManager(maxSteps: 60)
        #expect(history.maxSteps >= 50)

        var curr = SynthPreset.defaultPreset
        for i in 1...65 {
            var next = curr
            next.bpm = Float(100 + i)
            history.recordChange(from: curr, to: next)
            curr = next
        }

        #expect(history.undoActions.count <= history.maxSteps)
        #expect(history.undoActions.count >= 50)
    }
}
