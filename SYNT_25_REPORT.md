# SYNT_25 Report (feat/auv3)

## Commits
- d7ce1be — task file (ROUND21 plan)
- db6c162 — Stage 1: R21-1 `@inline(__always)` back on `pullNewWavetableRT` (no observable behaviour → no fail-on-old test possible); R21-2 frame split factored into `frameSplit(_:_:)`, new test `testCachedFrameSplitMatchesReferenceFormula` pins cached split vs the pre-SYNT_24 formula (bit patterns, repeated keys, count changes, edges). It passes on old arithmetic by design (it's a pin, not a bug fix).
- 480f51e — Stage 3: every Swift Testing suite is now `@MainActor` (73 suites in 73 files; `InitGoldenTests.renderHash` made `nonisolated` for XCTest callers); `AudioEngine.strictMainThreadApplyPreset` defaults to **true** in DEBUG. First attempt missed 5 files that had `@MainActor` elsewhere (MIDIPerformanceTests etc.) and trapped — the trap correctly caught them. Test `testStrictMainThreadApplyPresetDefaultOnInDebug` fails on old code (default was false).
- Each code commit: full suite green on its own before commit.

## Suite (final, 480f51e)
758 total / 751 passed / 6 skipped / 1 expected-fail / 0 failed; 856 passed runs (+6 skipped +1 xfail = 863). Golden 0xd1b3635203a4799e unchanged.

## Stage 2 idle A/B — NOT RUN
Load never < 2: 4.3 (02:05), 7.8 (02:08), 3.5 (02:30), 3.6–4.0 (02:31–02:34 Asia/Jerusalem). Spot perf at HEAD (load ~3.5): wavetable 32×5 79.00%, gate run 78.65%, 24×5 57.87%, classic 47.27%. SYNT_24 spot was 73.45 / 71.39 / 59.12 / 44.20 — classic (untouched code) moved +3% too, so the spread is load noise; still under the 90% gate.

## Release
Release build OK, reinstalled, pluginkit lists SyntAUv3 + SyntArpAUv3, auval: AU VALIDATION SUCCEEDED.

## merge-base
`git merge-base --is-ancestor 4a0da1d HEAD` → true.

## Not done → SYNT_26
Idle A/B; R20-4 (optional).
