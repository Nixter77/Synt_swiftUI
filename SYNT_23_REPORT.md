# SYNT_23 Report (branch feat/auv3)

## Commits
- db3f3ec: task file GROK_BUILD_TASKS_SYNT_23.md (4 stages)
- 0b705f7: Stage 1, R14-9
- c7c5434: Stage 2, R14-10, plus the tests for Stage 1 and Stage 2 (Stage23Stage12Tests)
- 43df894: Stage 3, R19-1, R19-2 and R19-3
- (this commit): report

**R18-2 (deviation).** Stages 1–3 were written first, then the full suite ran once on the combined tree (green), and the tree was split into stage commits. The intermediate commits were not each built on their own.
- 0b705f7 contains only the SyntAudioUnit change, which is self-contained.
- The tests for 0b705f7 arrive in c7c5434.

## Stage 1: R14-9
- **Problem:** a host thread that called the `fullState` getter built the snapshot from `engine.preset`. That property is owned by main, so the read was racy, and it lagged a whole-preset adopt by one main hop. A background set followed immediately by a get returned the old non-addressed fields, such as fxOrder or the mod matrix.
- **Fix:** `adoptPreset` now writes a mirror under a lock, synchronously. Main refreshes the mirror on every snapshot. Off main, the snapshot is built from the mirror. Addressed values still come from the store.
- **Test:** `testR14_9_OffMainFullStateRoundTripSeesAdoptedPreset`. **It was verified to FAIL on the old SyntAudioUnit.swift.**

## Stage 2: R14-10
- **Fix:** `applyPreset` is guarded. A nested call is coalesced into one follow-up full pass, capped at 4 passes. A typical trigger is a `controllerMPEConfigDidChange` callback that writes `preset` from inside `pollMPEConfigMailbox`. In DEBUG, an off-main call is counted and logged.
- **Current state:** today no production code assigns `controllerMPEConfigDidChange`. The R14-1 work had already removed the AU chain, so this is hardening.
- **Test:** `testR14_10_ApplyPresetReentryIsCoalesced` checks one coalesced rerun and that the callback's value gets applied. On the old code it fails to compile because the new hooks don't exist.

## Stage 3
- **R19-1:** the setter is now `public internal(set) unowned(unsafe)` and documented. This is enforced at compile time, so no runtime test can fail on the old code.
- **R19-2:** a DEBUG registry records every allocated shape, and `CompiledMipData.deinit` asserts its shape is still registered. There is a doc note on deinit too.
  - Guard test: `testR19_2_ShapesOfFreedTablesStayRegistered`. It is deterministic and does not re-read freed memory.
  - As with R18-1, there was no bug, so the test cannot fail on the old code.
- **R19-3:** the intern key is now the frame's bit pattern (`[UInt32]`).
  - `testR19_3_NaNFrameInternsToOneShape` **fails on the old code**: NaN != NaN, so each compile allocated a new shape.

## Stage 4
- **Idle A/B not run:** load was 8.8–11.8 and never dropped below 2.
- **Hot spots:** not attempted; carried over.
- **Perf** (render path unchanged; thread CPU, best of 3, load about 9–12):

| Load | % of real time |
|---|---|
| wavetable 32×5 | 75.9% |
| wavetable 32×5 (budget gate run) | 78.0%, gate ≤90% passes |
| wavetable 24×5 | 59.4% |
| classic 32×5 | 45.1% |

## Final
- **Full suite:** total 752 / passed 745 / skipped 6 / xfail 1 / failed 0. Runs: 850 + 6 + 1 = 857.
- **Golden:** the golden test is in the suite and passed.
- **Release:** reinstalled to /Applications.
- **pluginkit:** both appex are registered from /Applications. They needed one re-add.
- **auval:** passes.
- **merge-base:** e9f6bc5 is an ancestor of HEAD.

## Leftovers (SYNT_24)
- Idle perf A/B (load < 2).
- Wavetable hot spots: `pullNewWavetableRT` per call and the frame-index math.
- R19-5: the DEBUG fallback-log array is unbounded. Negligible.
