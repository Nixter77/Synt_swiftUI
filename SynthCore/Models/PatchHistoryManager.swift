//
//  PatchHistoryManager.swift
//  SynthCore
//
//  Main-thread patch undo/redo history with isolated A/B compare stacks.
//  Zero audio-thread interaction.
//

import Foundation

@MainActor
public final class PatchHistoryManager: ObservableObject {
    public static let shared = PatchHistoryManager()
    public static let defaultMaxSteps = 64

    public enum Slot: String, Sendable, CaseIterable {
        case a = "A"
        case b = "B"
    }

    public enum Action: Equatable {
        case edit(slot: Slot, before: SynthPreset, after: SynthPreset)
        case switchSlot(from: Slot, to: Slot)
    }

    public let maxSteps: Int

    @Published public private(set) var activeSlot: Slot = .a
    @Published public private(set) var isComparing: Bool = false
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false

    // Stacks for Slot A
    public private(set) var undoStackA: [SynthPreset] = []
    public private(set) var redoStackA: [SynthPreset] = []

    // Stacks for Slot B
    public private(set) var undoStackB: [SynthPreset] = []
    public private(set) var redoStackB: [SynthPreset] = []

    // Global timeline of actions
    public private(set) var undoActions: [Action] = []
    public private(set) var redoActions: [Action] = []

    // Preset snapshots
    public private(set) var presetA: SynthPreset?
    public private(set) var presetB: SynthPreset?

    // Drag gesture tracking
    private var isDragging = false
    private var dragStartPreset: SynthPreset?
    private var currentPresetProvider: (() -> SynthPreset)?

    public init(maxSteps: Int = defaultMaxSteps) {
        self.maxSteps = max(50, maxSteps)
    }

    public func registerPresetProvider(_ provider: @escaping () -> SynthPreset) {
        currentPresetProvider = provider
    }

    // MARK: - Drag Gesture Tracking

    public func onDragStart() {
        guard !isDragging else { return }
        isDragging = true
        dragStartPreset = currentPresetProvider?()
    }

    public func onDragEnd() {
        guard isDragging else { return }
        isDragging = false
        if let before = dragStartPreset, let current = currentPresetProvider?(), before != current {
            recordChange(from: before, to: current)
        }
        dragStartPreset = nil
    }

    public func beginGesture(preset: SynthPreset) {
        guard !isDragging else { return }
        isDragging = true
        dragStartPreset = preset
    }

    public func endGesture(currentPreset: SynthPreset) {
        guard isDragging else { return }
        isDragging = false
        if let before = dragStartPreset, before != currentPreset {
            recordChange(from: before, to: currentPreset)
        }
        dragStartPreset = nil
    }

    // MARK: - Recording Changes

    public func recordChange(from before: SynthPreset, to after: SynthPreset) {
        guard before != after else { return }

        if activeSlot == .a {
            undoStackA.append(before)
            if undoStackA.count > maxSteps { undoStackA.removeFirst() }
            redoStackA.removeAll()
            presetA = after
        } else {
            undoStackB.append(before)
            if undoStackB.count > maxSteps { undoStackB.removeFirst() }
            redoStackB.removeAll()
            presetB = after
        }

        undoActions.append(.edit(slot: activeSlot, before: before, after: after))
        if undoActions.count > maxSteps { undoActions.removeFirst() }
        redoActions.removeAll()

        updateFlags()
    }

    // MARK: - A/B Compare

    public func storeAsA(preset: SynthPreset) {
        presetA = preset
        presetB = preset
        activeSlot = .b
        isComparing = true
        updateFlags()
    }

    public func toggleAB(currentPreset: SynthPreset) -> (preset: SynthPreset, slot: Slot)? {
        if !isComparing {
            // First time clicking A/B: current sound is stored as A, we switch to B
            storeAsA(preset: currentPreset)
            undoActions.append(.switchSlot(from: .a, to: .b))
            if undoActions.count > maxSteps { undoActions.removeFirst() }
            redoActions.removeAll()
            updateFlags()
            return (preset: currentPreset, slot: .b)
        }

        let newSlot: Slot = (activeSlot == .a) ? .b : .a
        if activeSlot == .a {
            presetA = currentPreset
        } else {
            presetB = currentPreset
        }

        undoActions.append(.switchSlot(from: activeSlot, to: newSlot))
        if undoActions.count > maxSteps { undoActions.removeFirst() }
        redoActions.removeAll()

        activeSlot = newSlot
        updateFlags()

        let target = (newSlot == .a) ? (presetA ?? currentPreset) : (presetB ?? currentPreset)
        return (preset: target, slot: newSlot)
    }

    public func clearAB() {
        isComparing = false
        activeSlot = .a
        presetB = nil
        updateFlags()
    }

    // MARK: - Undo / Redo

    public func undo() -> (preset: SynthPreset, slot: Slot)? {
        guard let action = undoActions.popLast() else { return nil }
        redoActions.append(action)

        switch action {
        case .edit(let slot, let before, let after):
            if slot == .a {
                _ = undoStackA.popLast()
                redoStackA.append(after)
                presetA = before
                activeSlot = .a
            } else {
                _ = undoStackB.popLast()
                redoStackB.append(after)
                presetB = before
                activeSlot = .b
            }
            updateFlags()
            return (preset: before, slot: slot)

        case .switchSlot(let from, _):
            activeSlot = from
            updateFlags()
            let target = (from == .a) ? (presetA ?? .defaultPreset) : (presetB ?? presetA ?? .defaultPreset)
            return (preset: target, slot: from)
        }
    }

    public func redo() -> (preset: SynthPreset, slot: Slot)? {
        guard let action = redoActions.popLast() else { return nil }
        undoActions.append(action)

        switch action {
        case .edit(let slot, let before, let after):
            if slot == .a {
                _ = redoStackA.popLast()
                undoStackA.append(before)
                presetA = after
                activeSlot = .a
            } else {
                _ = redoStackB.popLast()
                undoStackB.append(after)
                presetB = after
                activeSlot = .b
            }
            updateFlags()
            return (preset: after, slot: slot)

        case .switchSlot(_, let to):
            activeSlot = to
            updateFlags()
            let target = (to == .a) ? (presetA ?? .defaultPreset) : (presetB ?? presetA ?? .defaultPreset)
            return (preset: target, slot: to)
        }
    }

    // MARK: - Slot-Specific Undo/Redo

    public func undo(in slot: Slot) -> SynthPreset? {
        if slot == .a {
            guard let before = undoStackA.popLast() else { return nil }
            if let current = presetA {
                redoStackA.append(current)
            }
            presetA = before
            activeSlot = .a
            updateFlags()
            return before
        } else {
            guard let before = undoStackB.popLast() else { return nil }
            if let current = presetB {
                redoStackB.append(current)
            }
            presetB = before
            activeSlot = .b
            updateFlags()
            return before
        }
    }

    public func redo(in slot: Slot) -> SynthPreset? {
        if slot == .a {
            guard let next = redoStackA.popLast() else { return nil }
            if let current = presetA {
                undoStackA.append(current)
            }
            presetA = next
            activeSlot = .a
            updateFlags()
            return next
        } else {
            guard let next = redoStackB.popLast() else { return nil }
            if let current = presetB {
                undoStackB.append(current)
            }
            presetB = next
            activeSlot = .b
            updateFlags()
            return next
        }
    }

    public func reset() {
        undoStackA.removeAll()
        redoStackA.removeAll()
        undoStackB.removeAll()
        redoStackB.removeAll()
        undoActions.removeAll()
        redoActions.removeAll()
        presetA = nil
        presetB = nil
        activeSlot = .a
        isComparing = false
        isDragging = false
        dragStartPreset = nil
        updateFlags()
    }

    private func updateFlags() {
        canUndo = !undoActions.isEmpty
        canRedo = !redoActions.isEmpty
    }
}
