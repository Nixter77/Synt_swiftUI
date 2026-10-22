# SYNT_4 FINAL REPORT: AUv3 Audit Leftovers, UI Scaling, Undo/Redo (A/B), and FX Chain Reordering

**Branch:** `feat/auv3`  
**Base commit:** `a88ee23` (rebased on `bd8649f`)  
**Target branch status:** Up-to-date with `origin/feat/auv3`. `main` (`e9c2eb520590efd8e16bd84cde37ba1324bdbbe8`) is completely untouched; no force-push, no history rewrites.  
**Test execution:** `-derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests`  
**Test status:** 0 failed, 2 skipped under `SYNT_RUN_PERF=1`, 1 known expected failure (`ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`).  
**AU Validation:** `auval -v aumu Synt Nixr` -> `AU VALIDATION SUCCEEDED.`

---

## Stage Summary & Commits

### Stage 0 — Logic Pro AUv3 UI Layout & Responsive View Scaling
- **Commit:** `2f1474d` — `feat(ui): Step 0 - Logic Pro AUv3 responsive view scaling and 1100x520 base canvas`
- **Files Modified / Added:**
  - `SyntAUv3/SyntAUViewController.swift:23-48` — Configured `preferredContentSize = CGSize(width: 1100, height: 520)`, clamped min/max sizes, added host scale observer.
  - `SynthUI/Views/Components/ResponsivePluginContainer.swift:1-42` — Dynamic responsive container scaling the fixed 1100×520 base canvas proportionally (`scaleEffect(scale)`) to fit host window dimensions without overlapping, panel wrapping, or layout clipping.
  - `Synt_swiftUI/ContentView.swift:15-38` — Integrated container so that both standalone (fixed height $\le 520\text{ pt}$) and AUv3 views scale uniformly.
- **Verification:**
  - Interface tested at 100% (1100×520) and scaled modes (e.g. 179% / smaller window sizes). Panels stay locked in grid proportions without collision.

---

### Stage 1 — AUv3 Audit Leftovers & SYNT_2 Tails
- **Commit:** `74f651b` — `fix(auv3): Step 1 - AUv3 audit leftovers and SYNT_2 tails`
- **Files Modified / Added:**
  - `SynthCore/Audio/RTPresetBuffer.swift:1-318` — Lock-free double-buffered `RTPresetBuffer` with atomic active buffer flipping for RT audio thread snapshot consumption.
  - `SynthCore/Audio/SyntAudioUnit.swift:24, 211, 465` — Converted `suppressParameterObserver` to `Atomic<Bool>`; pulled `engine.pullPresetSnapshotRT()` before parameter drain in `SyntRenderContext.render()`.
  - `SynthCore/Audio/AudioEngine.swift:49-65` — Replaced `isUpdatingSingleParamFromMIDI` crutch with explicit `@Published private var _storedPreset` and `updatePresetDisplayOnly(_:)`.
  - `SynthCore/Audio/AudioEngine+Preset.swift:17-45, 105-204` — `applyPreset()` now publishes atomic snapshots to `rtPresetBuffer` instead of mutating DSP state on non-audio threads.
  - `SynthCore/Models/SynthPreset.swift:204, 247` — Appended `public var pan: Float = 0.0` at end of preset; added `SynthParameterAddress.pan = 120` with neutral default 0.0.
  - `Synt_swiftUI/ContentView.swift:145-168` — EXT sync mode disables and dims the BPM slider and Sequencer Play button.
  - `SynthCore/Audio/AudioEngine+CCSmoothing.swift:18-42, 280-310` — Added sample-rate smoothed glide for filter ADSR, wtMorph, and lfoDepth.
  - `Synt_swiftUITests/SyntAudioUnitRenderTests.swift:90-175` — Added unit tests `fullStateWithModMatrixRoutingIsAudibleInRender()` and `concurrentPresetChangeDuringBackgroundRender()`.
- **Verification:**
  - All golden hashes matched bit-for-bit. Full test suite: 0 failed, 1 expected failure.

---

### Stage 2 — Undo/Redo with A/B Compare
- **Commit:** `e4d6e7b` — `feat(ui): Step 2 - Undo/Redo history and A/B compare`
- **Files Modified / Added:**
  - `SynthCore/Models/PatchHistoryManager.swift:1-180` — Dual-stack history engine with separate `undoStackA`/`redoStackA` and `undoStackB`/`redoStackB` ($\ge 50$ steps capacity, default 64) and a global unified action timeline so that A/B switching is undoable without cross-slot contamination.
  - `SynthUI/Views/Components/KnobView.swift:105-180` — Coalesced drag gesture tracking (`onDragStart` / `onDragEnd`) so an entire continuous knob adjustment records exactly 1 undo step.
  - `Synt_swiftUI/ContentView.swift:42-88` — Wired Cmd-Z and Shift-Cmd-Z shortcuts.
  - `SynthCore/Input/KeyboardHandler.swift:315-320` — Passes through key events when `event.modifierFlags.contains(.command)` so Cmd-Z is not swallowed as musical key 'Z'.
  - `SynthUI/Views/PresetView.swift:24-60` — Integrated with A/B compare toggle.
  - `Synt_swiftUITests/PatchHistoryTests.swift:1-140` — 5 unit tests covering edit tracking, redo ordering, A/B isolation, single-drag coalescing, and capacity limits.
- **Verification:**
  - Test suite: 0 failed. Init golden hash matches after multiple undos.

---

### Stage 3 — FX Chain Reordering
- **Commit:** `0c8a26d` — `feat(fx): Step 3 - FX chain reordering`
- **Files Modified / Added:**
  - `SynthCore/Models/FXSlotID.swift:1-85` — Defined `FXSlotID` (`.eq`, `.distortion`, `.phaser`, `.chorus`, `.delay`, `.reverb`) and `FXOrderTable` (6-slot inline struct for zero-allocation RT audio thread access).
  - `SynthCore/Models/SynthPreset.swift:205, 251, 370, 487, 609` — Added `public var fxOrder: [FXSlotID] = FXSlotID.defaultOrder` at end with `decodeIfPresent` fallback to default.
  - `SynthCore/Models/SynthPreset+Sanitize.swift:162-185` — Added `sanitizeFXOrder(_:)` ensuring deduplication, discarding corrupt/unknown IDs, and guaranteeing all 6 slots are always present.
  - `SynthCore/Audio/AudioCommandQueue.swift:54, 63, 157` — Added `case setFXOrder(table: FXOrderTable)` to `AudioCommand`.
  - `SynthCore/Audio/AudioEngine.swift:227` — Preallocated `public var cachedFXOrder: FXOrderTable = FXOrderTable()`.
  - `SynthCore/Audio/AudioEngine+Preset.swift:258-272` — Added `setFXOrder(_ order:)` pushing reordered table to audio thread at buffer boundary.
  - `SynthCore/Audio/AudioEngine+Render.swift:700-755, 942` — Dynamic per-sample rendering loop unrolled over `cachedFXOrder`. Preserves exact cleanBus position when EQ is first for bit-identical reproduction across all 50 factory presets.
  - `SynthCore/Audio/RTPresetBuffer.swift:148, 285` — Included `fxOrder` in `RTPresetSnapshot`.
  - `SynthUI/Views/Components/FXSlotCard.swift:23, 36, 71, 98` — Added `onMoveUp` and `onMoveDown` header arrows and context menu actions.
  - `SynthUI/Views/FXChainView.swift:1-240` — Reorderable FX column supporting macOS drag-and-drop (`.onDrag` / `.onDrop`) and move buttons while keeping all cards collapsed by default (height $\le 520\text{ pt}$).
  - `SynthUI/SynthControlGrid.swift:50` — Replaced static two-view effects column with `FXChainView`.
  - `Synt_swiftUITests/FXOrderTests.swift:1-95` — 5 unit tests verifying golden hash match on default order, audibly distinct hash on reordered slots, sanitization, fullState persistence, and lock-free engine updates.
- **Verification:**
  - `InitGoldenTests` passed: All 50 factory presets and Init matched bit-for-bit (`0xd1b3635203a4799e`).
  - `LayoutTests` passed: All themes $\le 520\text{ pt}$.
  - Full test suite passed: 0 failed, 1 expected failure.

---

## Verification & Test Results

### 1. Full Test Suite (`xcodebuild test`)
Command:
```bash
xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests
```
Summary:
```text
Test case 'ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip()' recorded an expected failure
** TEST SUCCEEDED **
0 failed, 1 expected failure, 2 skipped (perf tests under SYNT_RUN_PERF=1).
```

### 2. Apple AU Validation (`auval`)
Command:
```bash
auval -v aumu Synt Nixr
```
Tail Log:
```text
Output Format: AudioStreamBasicDescription:  2 ch,  44100 Hz, Float32, deinterleaved
Render Test at 512 frames
Slicing Render Test at 64 frames
  PASS

Render Test at 64 frames, sample rate: 22050 Hz
Render Test at 137 frames, sample rate: 96000 Hz
Render Test at 4096 frames, sample rate: 48000 Hz
Render Test at 4096 frames, sample rate: 192000 Hz
Render Test at 4096 frames, sample rate: 11025 Hz
Render Test at 512 frames, sample rate: 44100 Hz
  PASS

Bad Max Frames - Render should fail
  PASS

Checking parameter setting
Using AudioUnitSetParameter
Using AudioUnitScheduleParameter
  PASS

Test MIDI
  PASS

* * PASS
--------------------------------------------------
AU VALIDATION SUCCEEDED.
--------------------------------------------------
```

---

## What Was NOT Done & Known Limitations (Deferred to SYNT_5)

Per task instructions, the following items are intentionally deferred to `SYNT_5`:
1. **Microtuning (.scl / Scala support)**: Deferred to `SYNT_5`.
2. **MPE (MIDI Polyphonic Expression)**: Per-note pitch bend and pressure — deferred to `SYNT_5`.
3. **AU MIDI FX Variant**: Creating a separate MIDI effect target — deferred to `SYNT_5`.
4. **User Presets in AU**: Negative indexing for custom user presets in AU host menus — deferred to `SYNT_5`.
5. **Apple Delay/Reverb inside AU render**: Complete porting of system audio nodes into pure DSP blocks — deferred to `SYNT_5`.

---

## Open Questions & Risks

1. **Host-initiated preset change timing during live audio playback**: In AUv3, preset snapshots are pushed to double-buffered storage and picked up on render buffer boundaries. While delay and filter states remain continuous, radical parameter shifts (e.g., instant octave jumps or resonance extremes) can cause transient sound artifacts unless the host silences or crossfades.
2. **Trackpad drag precision in small AU window sizes**: When scaled down below 100%, the drag-and-drop hitbox shrinks proportionally. The dedicated Move Up / Move Down buttons and context menu ensure reordering is always accessible regardless of window scale.

---

## Git History Verification

```text
0c8a26d (HEAD -> feat/auv3, origin/feat/auv3) feat(fx): Step 3 - FX chain reordering
e4d6e7b feat(ui): Step 2 - Undo/Redo history and A/B compare
74f651b fix(auv3): Step 1 - AUv3 audit leftovers and SYNT_2 tails
2f1474d feat(ui): Step 0 - Logic Pro AUv3 responsive view scaling and 1100x520 base canvas
a88ee23 refactor(auv3): build the plugin hosting view once per surface (P3-18)
21c2357 refactor(auv3): drop fullStateForDocument override that duplicated the base class (P3-15)
```

**Main branch confirmation:**
- `origin/main` commit: `e9c2eb520590efd8e16bd84cde37ba1324bdbbe8`
- `main` was NEVER merged into, touched, or force-pushed. All changes live strictly on `feat/auv3`.
