# SYNT_19 Report (feat/auv3, base 41b0849, review ROUND16)

## Commits
| Commit | Stage | Items |
|---|---|---|
| 34bf8f5 | — | GROK_BUILD_TASKS_SYNT_19.md |
| — | 1 | Perf A/B, no code change (results below) |
| e227693 | 2 | R16-1: render ack (hazard pointer) before main releases retired user tables |
| 6d1e69f | 3 | R16-2: `syncFromRenderMain()` in `setSampleRate` and in the AU 0.1 s main timer; R16-4 behavioural deinit test |
| 44f2d4d | 4 | R15-8 in the AU view: override summary + "Reset to My Settings" in the gear menu |

Golden 0xd1b3635203a4799e unchanged (golden test green in every suite run). No old test changed.

## Tests (final, Stage 4)
723 tests total: 718 passed (823 runs passed), 0 failed, 4 skipped (perf, SYNT_RUN_PERF-gated).
(1 test is in neither count, same as SYNT_18.) Per stage: Stage 2 719/714 passed (819 runs); Stage 3 722/717 (822 runs).
**UI tests:** tried (`-only-testing:Synt_swiftUIUITests`); failed to start: "Early unexpected exit, operation never
finished bootstrapping … Lost connection to testmanagerd". 0 UI tests ran. This is a test-runner/automation problem, not a test failure.

## Stage 1 — perf A/B (R16-3)
A = b866d86, B = 41b0849. Separate worktrees and DerivedData, same config (Debug, SWIFT_OPTIMIZATION_LEVEL = -O),
built with build-for-testing, then run alternately with test-without-building, serial, SYNT_RUN_PERF=1. 5 runs each; each value is already best-of-3.
**The Mac never got idle:** the load average stayed 3.7–7.2 for all 10 runs (Safari WebKit GPU ~90% CPU,
fskit). By ROUND16 §3 every run should be discarded (load > 2). The waits were 600 s for A1 and 60 s after that. Recorded as-is:

| Suite (% of budget) | A median | A min | B median | B min |
|---|---|---|---|---|
| LiveStep4 block render (limit 85%) | 92.39 | 90.36 | 97.93 | 90.34 |
| RenderBudget Init×7 | 30.27 | 28.29 | 30.85 | 29.15 |
| RenderBudget Flange Harp | 24.75 | 23.37 | 23.62 | 23.34 |
| Stage18 classic (B only) | — | — | 97.47 | 89.83 |
| Stage18 wavetable (B only) | — | — | 135.30 | 123.79 |

Reading:
- **Baseline A also fails LiveStep4 in 5/5 runs** under this load, so the SYNT_18 red is environmental.
- The minima are identical (90.36 vs 90.34). There is no evidence of a classic-path regression.
- The wavetable numbers have no A counterpart, because that suite doesn't exist at b866d86.
- A clean idle-machine run is still required before merge (quit Safari first).

## Stage 2 — R16-1
- `instanceUserCompiled` didSet:
  - publishes the table as an unretained `Unmanaged` word (`userCompiledBits`, seq-cst);
  - appends the old table to a main-only retire list;
  - drains the list.
- `drainRetiredUserTablesMain()` releases every retired table except the one named by render's ack `rtUserAck`.
  It also runs from `syncFromRenderMain()`.
- `loadBuiltinRT(5)`:
  - ack ← bits, then re-reads the bits until stable (hazard pointer, seq-cst on both sides);
  - reads the view and the LFO shape from the **same** object through `_withUnsafeGuaranteedRef` (no ARC);
  - a builtin choice clears the ack.
- `pullNewWavetableRT` clears the ack once per main publish. This is not per sample.
- Render never releases and never allocates; the loop retries only while main is swapping.

Tests (`Stage19Stage2Tests`):
- `testR16_1_UnownedTableReadByRenderSurvivesSeveralSwapsUntilAck`:
  - table A is uncached with no other owner, and render reads it;
  - 3 main swaps → A is still alive and B/C are freed;
  - ack cleared → `syncFromRenderMain` frees A on main.
- `testR16_1_MainPublishClearsAckSoRetiredTableIsReleased`.

Failing on old code:
- Against the real old code they only fail to compile (`rtUserAck` is new).
- Behaviourally verified: with the old "keep one swap" policy put back temporarily, the first test fails with "table render still reads must not be freed by main swaps".

## Stage 3 — R16-2 / R16-4
- `setSampleRate` starts with `syncFromRenderMain()`.
- `SyntAudioUnit.syncWavetablesFromRender()` (both wavetable engines) runs in the 0.1 s main timer.

Tests:
- `testR16_2_RenderSwitchThenSampleRateChangePlaysRenderChoice` **fails at runtime on old code**. Verified by temporarily removing the line: "(2) is not equal to (4)".
- `testR16_2_AUMainTimerMirrorsRenderSwitch`: compile-only failure on old code (new method).
- `testR16_4_RenderSwitchFreesNothingUnownedTableFreedLaterOnMain`:
  - the user table has no cache entry and no test reference;
  - it is still alive after the render-side switch;
  - it is freed after main-thread slot rotation, and every deinit runs on the main thread.
  - The old vacuous R15-1 assertion is left in place; this test is the behavioural guard.

Remaining transient (pre-existing, ROUND16 R16-2 second half): if render switches again between main's
`rtPendingIndex.exchange` and its publish, the older table plays until the next timer tick (≤ 100 ms).

## Stage 4 — R15-8 in the AU view
- `SyntAudioUnit` adds:
  - `controllerMPEOverrideSummary`;
  - `controllerMPEOverrideSummaryPublisher` (Combine);
  - `resetControllerMPEOverrides()`.
- `AUParameterSurface` mirrors the summary. The gear menu shows the summary and "Reset to My Settings" (`pluginResetMPEOverrides`); the gear icon is filled while an override is active.
- Test `testR15_8_AUExposesOverrideSummaryAndReset`: compile-only failure on old code (new API).
- The view itself is not UI-tested (UI runner does not start).

## Install / validation
- `/Applications/Synt_swiftUI.app` reinstalled.
- `pluginkit -a` for SyntAUv3 + SyntArpAUv3 (both registered from /Applications); `pluginkit -r` for the DerivedData copies.
- `auval -v aumu Synt Nixr`: **AU VALIDATION SUCCEEDED**.

## Not done (→ SYNT_20)
Idle-machine perf; UI tests (testmanagerd); R16-5/6/8; R15-6/7; R14-4/9/10; R15-4 semantics; arpeggiator; R11-6…13; R12-10…15.
