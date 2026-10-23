# SYNT_16 Report

Branch `feat/auv3`, base 98feb1a. Golden Init hash 0xd1b3635203a4799e unchanged (golden tests green).

## Commits
| Stage | Commit | Content |
|---|---|---|
| Plan | 29eeaed | GROK_BUILD_TASKS_SYNT_16.md |
| 1 | a78fdc3 | R13-1 controller MPE persists in AU (MPEControllerOverride, mailbox → AU params 163–166) |
| 2 | 33bcdae | R13-2, R13-3, MCM-with-MPE-off documented, R13-9 |
| 3 | d7137a3 | R13-4 wavetable LFO follows oscillator table |
| 4 | 83ea9b1 | Perf suites + lows R13-8, R13-5, R13-6 |

## Tests per item (new tests fail on old code unless noted)
- R13-1: `Stage16Stage1Tests` (5; 4 fail on old code, `ExplicitParameterChangeReplacesControllerValue` is a guard). Includes the real AU path (SyntAudioUnit, coreOnly engine).
- R13-2: `Stage16Stage2Tests.testR13_2_MCMOnChannel16SwitchesFromLowerZone`, `..._MCMOnChannel1SwitchesFromUpperZone`, `..._RPNFromOutsideZoneIgnored`.
- R13-3: `Stage16Stage2Tests` MCM 48/2 reset test.
- MCM with MPE off stays off: `testMCMWithMPEOffDoesNotEnableMPE` — documents design (does not fail on old code).
- R13-9: `Stage16Stage2Tests` master-range test. **Intentional change to an old test:** `Stage15Stage2Tests` asserted `preset.pitchBendRange == 2`; it now asserts `controllerMasterPitchBendRange == 2` and `cachedPitchBendRange == 2` (master range is runtime-only by design).
- R13-4: `Stage16Stage3Tests.testR13_4_WavetableLFOFollowsOsc1Table`, `testR13_4_LFO2FollowsOsc2TableIndependently` (verified failing with the per-block adoption disabled); guard `testR13_4_Builtin0ShapeEqualsLegacyDefault`. Old R7-10/R12-8/SYNT_15 LFO tests unchanged and green. Design: each CompiledMipData owns an immortal shape (middle frame) built off-render; oscillator publishes its pointer via `Atomic<Int>`; LFO adopts it at the start of each renderBlock (no ARC, no alloc, morph untouched). Limitation: LFO uses the table's middle frame, it does not follow morph position.
- R13-8 (CC 38 cents for RPN 0): `Stage16Stage4Tests.testR13_8_DataEntryLSBAddsCentsToMemberRange`, `..._OnMasterChannel` (verified failing with CC 38 handling disabled); guard `testR13_8_LSBIgnoredForMCMAndIntegerRangeExact`. MPE mailbox now carries ranges in centi-semitones. RPN inc/dec (96/97) still unsupported.
- R13-5: `testR13_5_SameUserBlobSkipsRehash` — fast path when the same retained Data buffer + SR is applied again (no 512 KB FNV on main). Depends on a new counter, so on old code it is a compile failure, not a behavioural one. FNV non-crypto memo key unchanged.
- R13-6: `testR13_6_LoadBuiltin5NeverCompiles` — the `loadBuiltin(5)` branch that compiled mips is removed (falls back to builtin 0, counted). Uses a new counter too; the `currentBuiltinIndex == 0` assertion is behavioural.

## Totals (UI tests skipped)
`-skip-testing:Synt_swiftUIUITests`, because UI tests fail with "Failed to activate application" while the Mac screen is locked (environmental).
- Stage 1: 669 passed / 0 failed / 2 skipped / 1 expected failure
- Stage 2: 675 / 0 / 2 / 1
- Stage 3: 678 / 0 / 2 / 1
- Stage 4: 683 / 0 / 2 / 1

## Perf (SYNT_RUN_PERF=1, Debug, serial, after Stage 4)
- RenderBudget Init×7: 22.45% of 512-frame buffer (limit 50%); Flange Harp unison+phaser: 17.01%.
- LiveStep4 32 voices: block 74.02% of RT budget (limit 85%), per-sample 72.70%.
- After Stage 3 (before lows): 25.56% / 20.16% / block 82.61%. No regression.
- Note: running perf inside the full parallel suite fails (181% / 72%) due to CPU contention; the suites are meant to run serially.

## Install / validation
Release build installed to /Applications/Synt_swiftUI.app; `pluginkit -a` on SyntAUv3.appex and SyntArpAUv3.appex; `pluginkit -r` on DerivedData copies. `auval -v aumu Synt Nixr`: **AU VALIDATION SUCCEEDED**.

## Not done (→ SYNT_17)
Arpeggiator work, R11-6..13, R12-10..15, R13-7 (standalone CoreMIDI-thread race on word-sized MPE vars), RPN 96/97, ARC in generateSample.
