# SYNT_18 Report (branch feat/auv3, base b866d86)

## Commits
| Stage | Commit | Items |
|---|---|---|
| Task file | cc25938 | GROK_BUILD_TASKS_SYNT_18.md |
| 1 | 7c30040 | R15-2: flat POD mip view, no ARC / per-sample log2 in `generateSample` |
| 2 | b1b6f3a | R15-1: lock/ARC-free table switch on render (`loadBuiltinRT` + `syncFromRenderMain`) |
| 3 | 6bbb7a8 | R14-5/R15-5: render-owned LFO gate + 5 ms shape crossfade; R15-3: cleared overrides published to main |
| 4 | 5ab6209 | R15-8: controller MPE override summary + "Reset to My Settings"; R15-9: MCM select not double-routed |

Golden hash 0xd1b3635203a4799e unchanged (golden test green at every stage).

## Test counts (final, Stage 4)
717 tests total: 712 passed (817 runs passed), 0 failed, 4 skipped (perf, SYNT_RUN_PERF-gated).
UI tests (Synt_swiftUIUITests) were **excluded** (`-skip-testing`) in all runs — not run.

## Per item
- **R15-2** (`Stage18Stage1Tests`): flat path bit-identical to the old array path for all builtins/octaves/morphs;
  exponent-based octave matches `log2` (dense sweep + power-of-two edges; falls back to `log2` when the
  significand is ≥ 1.999999999 for exact parity). **Honest note:** these tests only fail to *compile* on old
  code (new API), not at runtime (same as the R12-9 precedent).
- **R15-1** (`Stage18Stage2Tests`): user→builtin switch via `pullPresetSnapshotRT` with `isRenderingActive`
  takes no `writeLock` (`publishLockCountForTesting`) and frees no `CompiledMipData` (deinit hook); audio
  bit-identical to builtin 0; main mirrors later. Compile-only-fail on old code (new probe).
  Limitations: main mirrors render switches only on its next `applyPreset()`; the previous user table is
  kept alive for exactly one swap (`retiredUserCompiled`).
- **R15-5/R14-5** (`Stage18Stage3Tests`): `testR15_5_LFOGateReadsRenderOwnedStateNotOscillatorWaveform`
  and `testR15_5_ShapeSwitchIsCrossfadedNotAJump` fail at runtime on old code. First shape adoption is
  immediate (no fade at start → golden unchanged).
  **Old test change:** `Stage16Stage3Tests` R13-4 tests set `engine.oscillator1/2.waveform` directly; they now
  also set `engine.rtOsc1/2IsWavetable = true` (the gate is render-owned now). Assertions/tolerances unchanged.
- **R15-3**: `testR15_3_RenderClearingOfOverrideReachesMain` fails at runtime on old code (mailbox stayed empty).
- **R15-9**: `testR15_9_MCMSelectOutsideZoneDoesNotMoveLearnedCC` fails at runtime on old code; guard test that
  other CC 100/101 values stay plain CCs (R14-7 preserved).
- **R15-8**: published `controllerMPEOverrideSummary` + `resetControllerMPEOverrides()` (main mirror + render
  command `.clearMPEControllerOverrides`), shown in the standalone UnisonView MPE menu. Tests compile-only-fail
  on old code. The AU view still has no engine reference → standalone only.
- **R15-4**: not changed; 96/97 semantics stay MIDI 1.0 coarse ±1 (documented in code comment and here).

## Perf (serial, SYNT_RUN_PERF=1, Intel Mac mini) — UNRELIABLE
| | b866d86 baseline | after Stage 4 (s1b) |
|---|---|---|
| Wavetable 32 voices ×5 unison | 114.5% / 126.3% | 140.6% |
| Classic (LiveStep4 load) | 80.4% | 97.0% |
| LiveStep4PerfBenchmarks (<85%) | pass | **fail (94.25%)** |
| RenderBudgetTests | pass | pass |

The s1b run was taken at load average ~29 (Safari WebKit GPU ~100% CPU, Spotlight indexing). The classic load,
which none of the SYNT_18 changes touch, also got ~17 points worse, so the numbers are mostly noise. Single attempt as instructed.
**Perf is PENDING**: rerun `/tmp/perf18.sh` on an idle machine (and baseline b866d86 the same session) before
claiming any R15-2 gain.

## Install / validation
App copied to /Applications, `pluginkit -a` for SyntAUv3 + SyntArpAUv3, `pluginkit -r` for DerivedData copies.
`auval -v aumu Synt Nixr`: **AU VALIDATION SUCCEEDED**.

## Not done (→ SYNT_19)
R15-6/7, R14-4/9/10, arpeggiator, R11-6..13, R12-10..15; R15-8 for the AU view; idle-machine perf.
