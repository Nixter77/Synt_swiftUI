# SYNT_22 Report (branch feat/auv3)

## Commits
- 98ec195: task file GROK_BUILD_TASKS_SYNT_22.md
- ebadbb8: Stage 1, R18-1 guard and R14-4 interned LFO shapes
- da4bd98: Stage 2, wavetable perf (ARC-free Oscillator copies, pow only when a value changes) plus a budget gate
- acb66ec: Stage 4, R18-3 lossy fxOrder and R18-4 DEBUG log for tolerant fallbacks
- (this commit): report and GROK_BUILD_TASKS_SYNT_23.md

## Stage 1
- **R18-1 cannot happen.** `LFOShapeTable` shapes are immortal: `CompiledMipData` does not own them, so `tablePtr`/`prevTablePtr` cannot dangle.
  - `testR18_1_LFOShapePointersOutliveEvictedTablesDuringFade` is a stress guard. By design it also passes on the old code.
- **R14-4 fixed.** Each recompile leaked a new immortal shape, and the SYNT_21 LRU made the number of recompiles unbounded.
  - Shapes are now interned by content.
  - `testR14_4_RecompileReusesInternedLFOShape` fails on the old code.

## Stage 2: perf
The profile showed `outlined init with copy of Oscillator` and `destroy`:
- The `Oscillator` struct held a strong `wavetableEngine` reference, and it was copied on every `generateSample` call, per voice, per sample. That is ARC on the render thread.
- `pow` also ran per voice, per sample.

Fixes:
- `wavetableEngine` is now `unowned(unsafe)`. AudioEngine owns the engines strongly for its whole lifetime.
- There is one copy per sample, hoisted out of the voice loop.
- An `OscFreqMulCache` calls `pow` only when octave or detune changes. The result is bit-identical.
- Golden 0xd1b3635203a4799e is unchanged and the suite is green.
- The one old test that used a local engine got `withExtendedLifetime`. Its assertion is unchanged.

Numbers are thread CPU time, best of 3, 512×200 buffers at 44.1k. The Mac was **not** idle (load 8–18).

| Load | Before | After |
|---|---|---|
| wavetable 32×5 | 115.8% | 74.4% (83.9% at load 18) |
| wavetable 24×5 | — | 58.8% |
| classic 32×5 (LiveStep4 load) | ~80% | 45.5% |

- The new budget gate `Stage22WavetablePerfBudget.wavetable32x5WithinNinetyPercentBudget` checks ≤90%. It is opt-in with SYNT_RUN_PERF=1 and fails on the old code at 115.8%.
- **LiveStep4.** The `<85%` assertion now has about 40 points of margin, so it was not changed: no weakening and no load gate needed.
- **Idle A/B not run.** Load never dropped below 2.

## Stage 3: R14-9 / R14-10
Not done. They are carried into SYNT_23.

## Stage 4
- **R18-3:** `fxOrder` is decoded as `[LossyDecodable<FXSlotID>]`, then passed through `sanitizeFXOrder`, which drops unknown IDs and duplicates and appends the missing default slots.
  - Fails on old code: `testR18_3_UnknownFXSlotIsDroppedNotWholeOrder`.
  - Also added: `testR18_3_AllUnknownOrWrongTypeFallsBackToDefault`.
- **R18-4:** `tolerant()` now records the key and prints in DEBUG builds; it is a no-op in Release.
  - Test: `testR18_4_TolerantFallbackIsLoggedInDebug`. It does not compile on old code because the hook does not exist there. A clean preset logs nothing.

## R18-2
Each stage commit ran the full suite (build plus test) before committing. That is a superset of build-for-testing, so no separate build-for-testing was run.

## Final state
- **Full suite:** total 748 / passed 741 / skipped 6 / expected-fail 1 / failed 0. Runs: 846 passed + 6 skipped + 1 xfail = 853.
- **Release build:** reinstalled to /Applications.
- **pluginkit:** SyntAUv3 and SyntArpAUv3 now point at /Applications. The stale ~/.synt_abA registration from the A/B was removed.
- **auval:** `aumu Synt Nixr` passes (AU VALIDATION SUCCEEDED).
- **merge-base:** 1bb8a44 is an ancestor of HEAD.
