# SYNT_17 Report (ROUND14)

Branch `feat/auv3`, base `bc4eefa`. Normal pushes only, no force-push, no merge into main.

## Commits
| Stage | Commit | Items |
|---|---|---|
| Task file | 0c78b82 | GROK_BUILD_TASKS_SYNT_17.md |
| 1 | 9bd5d48 | R14-3: built-in wavetables pre-built off render per sample rate; `loadBuiltin(0…4)` = atomic load, no lock, no compile (incl. the R13-6 fallback) |
| 2 | 7aca0b3 | R14-1/R14-2: controller MPE state is runtime only |
| 3 | d068e4b | R14-6, R14-7, R14-8, R14-5 (+ RPN 96/97, pulled forward from Stage 4) |
| 4 | 410d4c6 | R13-7 standalone race. ARC in `generateSample` deferred to SYNT_18 |

## Test totals (full suite, UI tests excluded, after each stage)
| After | Distinct tests passed | Runs passed | Failed | Skipped |
|---|---|---|---|---|
| Stage 1 | 686 | 791 | 0 | 2 (perf, gated) + 1 expected failure |
| Stage 2 | 689 | 794 | 0 | 2 |
| Stage 3 | 697 | 802 | 0 | 2 |
| Stage 4 | 700 | 805 | 0 | 2 |

The golden hash 0xd1b3635203a4799e is unchanged (its test is green in every run).
Perf (`SYNT_RUN_PERF=1`, run serially, each suite on its own): RenderBudgetTests 1/1 passed, LiveStep4BlockRenderTests 2/2 passed.
UI tests were NOT run because the Mac screen was locked (CGSSessionScreenIsLocked).
Reinstall: the app was copied to /Applications, both appex were registered with `pluginkit -a`, and the DerivedData copies were removed with `pluginkit -r`. `auval -v aumu Synt Nixr`: **AU VALIDATION SUCCEEDED**.

## Stage 1: R14-3
- Each sample rate gets an immortal static set of `Unmanaged<CompiledMipData>` pointers. It is built on main in `init`/`setSampleRate`, and an `Atomic<Int>` holds the active set.
- Tests in Stage17Stage1Tests:
  - no compile after an SR change (37.8k)
  - `loadBuiltin` does not wait while the cache lock is held (the old code deadlocks)
  - all builtins prepared for 88.2k

## Stage 2: R14-1 / R14-2 (nixter's decision: runtime only)
- What RPN 0 and MCM receive from a controller goes into `mpeCtl` on render and `controllerMPEMain` on main.
- It is **never** written to the preset, to AU params 163–166 or to fullState. It doesn't dirty the project and isn't recorded as automation.
- MCM N=0 ("zone off") turns MPE off as a runtime-only override. The user's saved MPE setting is untouched and comes back on reload.
- **Last change wins.** A host/user write of a *different* value replaces the controller override. A write that repeats the previous host value (a snapshot) keeps the controller value. A newer controller message replaces either. This is documented at the top of `MPEControllerOverride.swift`.
- Tests in Stage17Stage2Tests:
  - controller messages send no param notifications and leave fullState unchanged
  - MCM 0 never overrides the saved setting
  - last change wins on the main mirror

### Changed old tests (why: the design decision above, not masking)
Each one used to assert that the controller value reached the preset or parameters, which is exactly what the decision forbids. Each now asserts the runtime mirror/cached value AND that the preset/param is unchanged, so it is stricter, not weaker.
- **Stage15Stage1:** after the poll the preset is unchanged; `controllerMPEMain` and the routing mirror hold 24/10.
- **Stage16Stage1:**
  - "controller range saved in fullState" was replaced by `testR14_1_AUControllerRangeIsNotSavedInFullState`.
  - "AU timer drain writes params" was replaced by `testR14_1_AUTimerDrainDoesNotTouchParameterTree`.
  - The standalone test now expects preset 48 and mirror 20.
- **Stage14Stage3 `testRPN0ChangesBendRange`:** expects the 24 st controller range in `controllerMPEMain` / `mpePitchBendRange`, with `preset.mpePitchBendRange` still 48.
- **Stage16Stage3 (2 LFO tests):** these now set `oscillatorN.waveform = .wavetable` and compare against the peak-normalized frame, because of R14-5 below.

## Stage 3
- **R14-6:** selecting an RPN (CC 100/101) or the null RPN clears `dataMSB`, so a lone CC 38 is ignored. Tests: `testR14_6_LoneCC38AfterReselectIsIgnored`, `testR14_6_NullRPNClearsDataMSB`.
- **R14-7:** on ch1/ch16 outside the zone, only RPN 6 data entry is consumed as MPE. All other CCs (100/101 too, NRPN, data entry) go to the normal CC map. Tests:
  - `testR14_7_DataEntryOutsideZoneReachesCCMap`
  - guard `testR14_7_MCMOutsideZoneStillAccepted`
- **R14-8:** `controllerMasterPitchBendRange` is now `@Published`. The standalone MPE menu shows "Controller Master Bend: ±N st".
  - The AU view has no engine reference, so it doesn't show it (known limitation).
  - Test: `testR14_8_MasterBendLabel`.
- **R14-5:**
  - LFO1 follows osc1's table only while osc1 is in wavetable mode, otherwise the default shape; LFO2 likewise with osc2.
  - LFO shapes are peak-normalized when the immortal shape is built, off render.
  - Tests: `testR14_5_LFOUsesDefaultWhenOsc1NotWavetable`, `testR14_5_LFOShapeIsNormalized`.
- **RPN 96/97** (pulled forward from Stage 4): Data Increment/Decrement steps RPN 0 by 1 semitone (clamped 0…96). Increment/decrement is not supported for MCM. Without an RPN 0 selection, CC 96/97 stay plain CCs. Test: `testRPN96_97IncrementDecrementBendRange`.

## Stage 4
- **R13-7:** the standalone CoreMIDI thread no longer reads the main-thread vars `mpeEnabled`/`mpeZone`/`mpeMemberChannelCount`.
  - Their `didSet` publishes one packed `Atomic<Int>` (`standaloneMPERouting`).
  - `isStandaloneMPEMember` and `midiMPEControlChange` read only that word.
  - Tests:
    - `testR13_7_MainWritesPublishAtomicSnapshot`
    - `testR13_7_MIDIThreadHelpersReadOnlyTheAtomic` (fails on the old code)
    - `testR13_7_ConcurrentSnapshotsAreConsistent` (stress). TSan was not run.
- **ARC in `WavetableOscillator.generateSample`: deferred to SYNT_18.**
  - It reads `compiled.mipMaps` ([[[Float]]]) per sample, which means retain/release on nested arrays. It also does a `log2` per sample.
  - Removing that properly means flattening the mip data into raw immortal buffers, which touches every wavetable path and the bit-exact golden.
  - Too risky for this round.

## Known remaining issues (honest)
- **Per-instance write lock on render:** `publishCompiled` still takes the oscillator's own `writeLock`. When `applyPresetDSP` runs on render and loads a table through it, that is a short uncontended `os_unfair_lock` on the render thread. No compile, no global cache lock. To be removed in SYNT_18.
- **Bounded table leak:** each sample rate's builtin set is immortal (5 compiled tables per distinct SR), as are LFO shapes (R14-4, one per compile). Growth is bounded by unique (table, SR) pairs. It is never freed by design, so render can never see a dangling pointer.
- **UI tests:** not run (screen locked).
- **Deferred to SYNT_18:**
  - ARC in `generateSample`
  - removing the write lock
  - an arena for LFO shapes (R14-4)
  - R14-9, R14-10
  - the arpeggiator
  - R11-6…13, R12-10…15
