# SYNT_28 Report (2026-10-26)

Branch feat/auv3, base b9ba7d2. Golden 0xd1b3635203a4799e unchanged (InitGolden/golden tests pass).

## Items 1–2 (closed by CodeReviewer before this run)
- 4f14bab P2-1: `publishPresetSet` (MSEG→MSEG2→matrix→snapshot) + writing/pulling handshake; render mid-publish keeps the previous set whole. Epoch-in-snapshot was NOT used: the writer waits while render is mid-pull, so a handshake was chosen instead. Stage28AuditTests.
- b9ba7d2 P2-2: `suppressParameterObserver` removed; only same-thread echoes matching the store are ignored.

## Stage A — 6cdcb20: Release-buildable tests
11 test files that use DEBUG-only hooks (`applyPresetCallCountForTesting`, `onDeinitForTesting`, `publishLockCountForTesting`, `retiredUserTableCountForTesting`, `afterTakeForTesting`, `factoryPresetsForTesting`, `ShapeArena.ownsInteriorForTesting`, …) wrapped whole-file in `#if DEBUG`: LiveStep2CCAndTemplate, Stage15Stage1, Stage18Stage2, Stage19Stage2, Stage19Stage3, Stage20Audit, Stage23Stage12, Stage26Audit, Stage27Audit, Stage27ShapeArena, Stage28Audit. DEBUG is not forced into Release.
Release `build-for-testing` needs `ENABLE_TESTABILITY=YES` on the command line (Release has testability off, so `@testable import` fails otherwise). Optimization stays Release `-O`; shipped Release is unchanged.
Suite after: 777 total / 770 passed / 6 skipped / 1 expected-fail / 0 failed.

## Release A/B — b866d86 vs 6cdcb20
Release, `ENABLE_TESTABILITY=YES`, `-enableCodeCoverage NO` (0 `__profc` in SynthCore), worktrees with only the perf suites + InitGoldenTests (B's perf files copied to A), separate DerivedData, serial, 5 alternations. Load 1-min 5.3–19.5, never < 2 → ROUND22 interleaved fallback, all runs kept (B5 hit a 19.5 load spike). Budget 2322 ms.

| metric | A median | A min | B median | B min | Δ median |
|---|---|---|---|---|---|
| per-sample | 1488.62 | 1451.06 | 1037.26 | 910.08 | −30.3% |
| block | 1509.73 | 1475.37 | 1101.81 | 905.56 | −27.0% |
| classic 32×5 | 1461.97 | 1431.86 | 1031.72 | 873.31 | −29.4% |
| wavetable 32×5 | 2566.67 | 2414.31 | 1777.63 | 1640.84 | −30.7% |
| budget gate 32×5 | 2496.76 | 2400.37 | 1705.42 (73.4%) | 1577.03 | −31.7% |
| wavetable 24×5 | 1904.01 | 1895.08 | 1304.03 | 1228.15 | −31.5% |
| RenderBudget Init×7 (ms) | 2.53 | 2.48 | 2.46 | 2.02 | −2.7% |
| RenderBudget heavy Flange Harp (ms) | 2.19 | 2.16 | 2.38 | 2.00 | +8.7% |

A fails the 90% wavetable gate (~103–107%); B passes (~73%). The Release gain (~−30%) is smaller than Debug -O (−41..−49%, SYNT_27) because A's baseline is much faster in Release. RenderBudget sits at the noise floor (~2 ms); B's numbers are noisy (B4/B5 under load), so the Flange Harp +8.7% is not a real regression (B min 2.00 < A min 2.16).

## Stage B — 611594b: warnings cleanup
- Test: 4 non-Sendable captures → `nonisolated(unsafe)` locals (SyntAudioUnitRender/StateTests); the `@preconcurrency` hints went away with them; never-mutated vars → `let` (Stage9 ×5, SynthCoreRenderAPI, PhaseV2ArpGroove, Stage10Visuals, Stage21Stage2 `weak let`); unused `data2` dropped.
- SynthCore: 75 redundant `public` in public extensions removed; `public` in private Array extension; `if fast != nil`; redundant `_ =`.
- LiveStep3 `@MainActor` parameterised `@Test`: no warning in the current toolchain/mode (VoiceMode is Sendable), left as is.
- Clean build of app + tests: 0 compiler warnings.
- Suite: 777 / 770 passed / 6 skipped / 1 xfail / 0 failed. (One earlier run lost the whole test host to SIGTERM at the same moment as the UI launch tests; it did not happen on the rerun, so it's not a real failure.)

## SWIFT_STRICT_CONCURRENCY=complete on SynthCore (scoped try, command line only)
BUILD SUCCEEDED with 68 unique warnings (all would be errors in Swift 6 mode):
- 57 static properties not concurrency-safe (mostly `static let` of non-Sendable types: factory preset tables in FactoryPresets*/FactoryFXPresets, WavetableOscillator tables; 8 `static var` global mutable state)
- 3 "sending … risks data races", 3 non-Sendable captures, 2 non-Sendable function conversions, 1 task-isolated return, 1 captured var in concurrent code, 1 non-Sendable param (SyntAudioUnit, WavetableOscillator, AudioEngine, MIDICCLearnStore, PresetManager).
The project setting stays `minimal`; nothing left unbuildable.

## Release / AU
Release rebuilt and installed to /Applications/Synt_swiftUI.app; `pluginkit -a` on both appex. `pluginkit -m` still lists the ~/.synt_rel build path (same build). `auval -v aumu Synt Nixr`: AU VALIDATION SUCCEEDED. No sound.
