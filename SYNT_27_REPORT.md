# SYNT_27 Report (2026-10-25)

Branch feat/auv3, base 2eac12e (CodeReviewer P2-1/P2-2/P3-3). Golden 0xd1b3635203a4799e unchanged.

## Commits
- e316453 R20-4: LFO shapes carved from a never-freed `ShapeArena` (bump allocator, header offset 64, chunks never deallocated). No shape header/samples pointer is a heap-block start, so there is no owning allocation to free: free impossible by design. Test `Stage27ShapeArenaTests` (verified failing on old code: `malloc_size` 16 / 256+ at shape pointers; final version asserts arena-interior via DEBUG `ShapeArena.ownsInteriorForTesting`).
- 40f7c18 Stage 1 Swift 6 prep: explicit `Sendable` on the 11 enums stored in `RTPresetSnapshot` (WaveformType, ArpeggiatorMode, TimeDivision, SyncSource, VoiceMode, NoiseColor, ChordMode, FilterType, LFOTarget, PhaserMode, DistortionType) + WaveformShape follows; `nonisolated` `PatchHistoryManager.defaultMaxSteps`. `Stage27SendableTests` pins conformances; cannot fail on old code in Swift 5/minimal concurrency (missing Sendable is only a warning there) — verified old code still compiles.
- this report + GROK_BUILD_TASKS_SYNT_28.md

Swift 6 inventory (clean build, 128 unique warnings): 31 Swift-6-mode issues; production ones (24 RTPresetSnapshot Sendable, PatchHistoryManager, WaveformShape) fixed. Remaining: test-only (4 non-Sendable captures in SyntAudioUnitRender/StateTests, 2 @MainActor parameterised @Test in LiveStep3, @preconcurrency import hints) + ~75 redundant `public` in public extensions + 10 never-mutated vars.

## Suite
- After e316453: 770 total / 763 passed / 6 skipped / 1 expected-fail; 868 passed runs.
- After 40f7c18 (final): 772 total / 765 passed / 6 skipped / 1 expected-fail / 0 failed; 870 passed runs.

## A/B b866d86 vs HEAD 40f7c18 — Debug -O, coverage OFF
build-for-testing + test-without-building, `-enableCodeCoverage NO` (0 `__profc` symbols in SynthCore), serial, separate worktrees/DerivedData, 5 alternations each. Load 1-min 4.7–7.1 (never < 2 after waiting; ROUND22 interleaved fallback, all runs kept). Budget 2322 ms.

| metric | A median | A min | B median | B min | Δ median |
|---|---|---|---|---|---|
| per-sample | 2112.49 | 2039.39 | 1097.21 | 1054.47 | −48.1% |
| block | 2107.53 | 2097.80 | 1112.32 | 1036.00 | −47.2% |
| classic 32×5 | 2173.59 | 2105.63 | 1103.77 (47.5%) | 986.75 | −49.2% |
| wavetable 32×5 | 3324.15 | 3258.69 | 1818.15 (78.3%) | 1791.01 | −45.3% |
| budget gate 32×5 | 3274.52 | 3206.24 | 1842.45 (79.3%) | 1788.82 | −43.7% |
| wavetable 24×5 | 2486.99 | 2433.10 | 1457.51 (62.8%) | 1402.61 | −41.4% |
| RenderBudget Init×7 | 3.43 | 3.27 | 2.48 | 2.17 | −27.6% |
| RenderBudget heavy Flange Harp | 2.76 | 2.65 | 2.45 | 2.24 | −11.3% |

Confirms SYNT_26 (coverage on: −45% classic / −39% wavetable); with coverage off and higher load the gain reads −47..−49% classic, −41..−45% wavetable. B is ~2.5% faster without coverage (1126→1097 per-sample); A numbers rose due to higher load.

### Coverage note (Stage 4)
Debug test builds have code coverage ON by default (scheme), visible as `__profc_*` symbols in SynthCore. All perf numbers from SYNT_27 on use `-enableCodeCoverage NO`; earlier (≤ SYNT_26) numbers include coverage overhead.

### Release-config A/B: NOT run
HEAD test target does not compile in Release (DEBUG-only hooks such as `applyPresetCallCountForTesting` used outside `#if DEBUG` in LiveStep2CCAndTemplateTests etc.). Forcing `DEBUG` into Release would not be Release. → SYNT_28.

## Release / AU
Release reinstalled to /Applications/Synt_swiftUI.app; pluginkit: SyntAUv3 + SyntArpAUv3; `auval -v aumu Synt Nixr`: AU VALIDATION SUCCEEDED.
