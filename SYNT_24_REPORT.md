# SYNT_24 Report (feat/auv3)

## Commits
- dee5dc4 — task file (GROK_BUILD_TASKS_SYNT_24.md)
- 770b666 — Stage 2: wavetable hot spots (no per-voice `pullNewWavetableRT` on render via `generateSampleNoPull` / `Oscillator.generateSample(pullWavetable:false)`; frame split cached on (framePosition bits, frameCount)). Test: Stage24HotSpotTests bit-exact vs reference path. Perf is a speed-up, so no "fails on old code" correctness test is possible; Stage22 budget gate is the guard.
- 74496f4 — Stage 3: R20-1 adopt generation counter. Main `presetSnapshot()` uses the mirror while an off-main adopt hop is pending; stale hops (overtaken by a newer applied adopt) are skipped. Test `testR20_1_MainSnapshotBeforeHopDoesNotClobberMirror` — verified FAILING on old code, passing with fix.
- 6f17a85 — Stage 4: R20-2 cap-hit counter + DEBUG assertionFailure (suppressible) + NSLog; R20-3 test counters gated `#if DEBUG`, main-thread check = counter+NSLog, hard `dispatchPrecondition` opt-in via `AudioEngine.strictMainThreadApplyPreset` (default off: default-on crashed ~600 non-@MainActor tests); R19-5 TolerantDecodeLog capped at 256 (newest kept). Tests: testR20_2_ApplyPresetCapHitIsCounted (5 writes via pass hook; fails on old code by construction — counter/hook API absent), testR19_5_TolerantDecodeLogIsBounded.
- Each code commit was built and full-suite tested on its own (no post-hoc splitting).

## Suite (final, 6f17a85)
756 total / 749 passed / 6 skipped / 1 expected-fail / 0 failed; 854 passed runs (+6 skipped +1 xfail). Golden 0xd1b3635203a4799e unchanged (golden tests green).

## Perf (after Stage 2, Mac under load ~4–6)
- wavetable 32×5: 73.45% (was 75.9%); budget gate run 71.39% (was 78.0%)
- wavetable 24×5: 59.12% (was 59.4%)
- classic 32×5: 44.20% (was 45.1%)

## Stage 1 idle A/B
Not run: load average never below 2 (5.41 at 01:32, 3.8–6.2 at 01:33–01:35, 9.4/24.8 at 02:00 Asia/Jerusalem). Carried to SYNT_25.

## Release
Release build OK (DEBUG gating compiles out), reinstalled /Applications/Synt_swiftUI.app, pluginkit lists SyntAUv3 + SyntArpAUv3, `auval -v aumu Synt Nixr`: AU VALIDATION SUCCEEDED.

## merge-base
`git merge-base --is-ancestor c0ab84d HEAD` → true.

## Not done
- R20-4 (immortal shape un-freeable by design) → SYNT_25.
