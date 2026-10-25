# SYNT_26 Report (2026-10-25)

Branch feat/auv3. Golden 0xd1b3635203a4799e unchanged. c3d9dd6 (CodeReviewer P1/P2) is an ancestor of HEAD.

## Commits
- 55bec4e task file (plan)
- 853d859 R22-3 renderHash @MainActor (+@MainActor on 5 XCTest golden callers: Stage13MPE, Stage14Stage1-4), R22-4 seeded SplitMix64 in frameSplit reference test, R22-2 config-pin comment
- this report + GROK_BUILD_TASKS_SYNT_27.md
- R22-1 closed by CR in 0aa9cdb (testP1_1_AUConstructedOffMainDoesNotTripStrictCheck).

No new failing-on-old-code tests for R22-2/3/4: test-only hygiene. R22-3 is enforced by the compiler (isolation errors), R22-4 is determinism of an already-passing test, R22-2 is a comment.

## Suite
Before (HEAD 55bec4e incl. CR) and after 853d859: 766 total / 759 passed / 6 skipped / 1 expected-fail / 0 failed; 864 passed runs. CR's claim of 759 verified.
(Earlier same day: test runner hung before connection, also on pre-CR code -> stale testmanagerd; fixed by reboot.)

## Idle A/B (b866d86 vs 55bec4e)
Debug -O, build-for-testing + test-without-building, serial, separate worktrees + DerivedData, 5 alternations each. Load 1-min before runs 3.3-4.8 (just after reboot; never < 2; all runs kept). RT budget 2322 ms.

| metric | A median | A min | B median | B min | delta (median) |
|---|---|---|---|---|---|
| per-sample (LiveStep4) | 2056.05 | 2031.28 | 1126.37 | 1073.65 | -45.2% |
| block (LiveStep4) | 2060.80 | 1993.26 | 1113.57 | 1102.35 | -46.0% |
| classic 32x5 | 2034.84 (87.6%) | 1981.88 | 1095.49 (47.2%) | 1081.96 | -46.2% |
| wavetable 32x5 | 3108.87 (133.9%) | 3070.71 | 1880.42 (81.0%) | 1856.84 | -39.5% |
| SYNT22 budget gate 32x5 | 3062.33 | 3011.10 | 1908.34 (82.2%) | 1837.53 | -37.7% |
| wavetable 24x5 | 2342.32 (100.9%) | 2308.39 | 1443.79 (62.2%) | 1371.96 | -38.4% |
| RenderBudget Init x7 avg | 3.33 | | 2.40 | | -28.0% |
| RenderBudget heavy Flange Harp | 2.59 | | 2.36 | | -9.2% |

Hot-spot gain b866d86 -> HEAD: ~45% classic, ~38-40% wavetable. Wavetable 32x5 now under RT budget.
frameSplit: private `frameSplit` has no text symbol in SynthCore (only coverage counters) -> inlined; `frameSplitForTesting` is exported.

## Release / AU
Release build installed to /Applications/Synt_swiftUI.app; pluginkit lists SyntAUv3 and SyntArpAUv3; `auval -v aumu Synt Nixr`: AU VALIDATION SUCCEEDED.

## Not done
Optional Stage 4 (Swift 6 warnings, R20-4 immortal shapes) -> SYNT_27.
