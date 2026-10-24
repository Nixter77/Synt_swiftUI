# SYNT_21 Report

Branch `feat/auv3`. Commits: 8a67799 (task file), 83859bd (Stage 2), 321fe3a (Stage 3), a03bbc2 (Stage 4), + this report.
Golden hash 0xd1b3635203a4799e unchanged (golden test green).

## Stage 1 — perf A/B (b866d86 = A vs 8a67799 = B)
Mac never idle: load stayed >= 2 after a 600 s wait (A1 load 2.55); continued with a 60 s cap. Loads 2.5–6.1.
Alternating A/B, 5 runs each, Debug -O, TEST_RUNNER_SYNT_RUN_PERF=1. A also ran Stage18WavetablePerfBenchmarks (file copied in).

| metric (% RT budget) | A median | A min | B median | B min |
|---|---|---|---|---|
| Block render (LiveStep4) | 81.93 | 79.76 | 79.48 | 76.83 |
| Per-sample render | 90.04 | 78.94 | 82.81 | 79.15 |
| SYNT18 classic 32v×5 | 79.64 | 75.07 | 76.54 | 74.11 |
| SYNT18 wavetable 32v×5 | 117.83 | 115.13 | 107.55 | 105.75 |

No regression from b866d86; B is equal or better. A2 failed the 85% block assertion (85.58) under load; that is noise, not code.
Wavetable budget proposal: 32 voices × 5 unison wavetable is over real time (about 106–108%). Target: <= 90% for that stress case
(SYNT_22 optimisation). Until then, guidance is <= 24 voices × 5 unison (or 32 × 3) for wavetable patches, which scales to about 80%.

## Stage 2 — R15-6/7: LRU eviction of the compiled-table cache
`compiledCacheLimit = 16`. Evicted tables are released outside `cacheLock`; tables that slots or the retired list still use stay alive.
Tests: Stage21Stage2Tests (3).
R17-4: `deinitCountForTesting`, `retiredUserTableCountForTesting` and `afterTakeForTesting` are under `#if DEBUG`.
The test target is Debug-only; the other `*ForTesting` funcs are documented as Debug-only test surface.

## Stage 3 — R17-2/3
The Bool ack is replaced by sequence counters `mpeResetIssued` (main) and `rtMPEResetApplied` (render), stamped into mailbox bits 44–51.
Poll accepts only the stamp equal to the latest issued reset. R17-3 comment added on the reset wait.
Test: `testR17_2_DoubleResetBeforeDrainIgnoresEntryBetweenResets`.

## Stage 4 — R17-5
All enum fields decode tolerantly (unknown value → default). modMatrix is lossy: only the bad routing is dropped. fxOrder falls back to default.
Decision: no stateVersion bump; the encoded format is unchanged.
Tests: Stage21Stage4Tests (2).

All 6 new tests fail on old SynthCore (stash method) and pass on new.

## Verification
Full suite (UI skipped): 741 tests; 736 passed, 4 skipped, 1 expected failure, 0 failed; 846 runs (841 passed + 4 skipped + 1 xfail).
729 reconciled: SYNT_20's 735 = 730 passed + 4 skipped + 1 xfail; +6 new tests = 741.
Release reinstall OK. pluginkit now lists SyntAUv3 and SyntArpAUv3. `auval -v aumu Synt Nixr`: AU VALIDATION SUCCEEDED.
Merge-base: 09a82aa is an ancestor of HEAD.

## Leftovers → GROK_BUILD_TASKS_SYNT_22.md
R14-4/9/10 (did not fit), wavetable perf target.
