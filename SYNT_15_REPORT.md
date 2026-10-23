# SYNT_15 Report (branch feat/auv3, base 5537eea)

Done directly by Grok Bot (no Grok Build / Gemini). Golden hash 0xd1b3635203a4799e unchanged (golden tests green). Never force-pushed; no merge to main.

## Commits
| Stage | Commit | Suite (runs passed / failed / skipped, tests) |
|---|---|---|
| Task file | a3290aa | – |
| 1 (R12-1, R12-8) | 4c52702 | 756 / 0 / 2 (653) |
| 2 (R12-2, R12-4) | 94db9c8 | 761 / 0 / 2 (658) |
| 3 (R12-3, R12-5) | c4a7753 | 767 / 0 / 2 (664) |
| 4 (R12-6, R12-7, R12-9, weak tests) | 4259d1d | **773 / 0 / 2 (670)** |

## Items and tests
- **R12-1** RPN/MCM on the render thread no longer calls applyPreset. It writes cached* values and publishes through the lock-free `mpeConfigMailbox` (Atomic<UInt64>). The main thread applies the change in `pollMPEConfigMailbox()` (from pollMetering). Test: `Stage15Stage1Tests.testR12_1_RPNOnRenderThreadDoesNotApplyPresetAndPublishesViaMailbox`.
- **R12-8** The wavetable LFO reads an immortal copy of `LFO.defaultWavetable`. It does not touch the oscillator morph and has no sine fallback. Tests: `testR12_8_WavetableLFODoesNotMutateOscillatorMorph`, `testR12_8_WavetableLFOMatchesIndependentTableReference`.
- **R12-2** CC 6/38/100/101 are plain CCs while MPE is off. Tests: `Stage15Stage2Tests.testR12_2_RPNControllersAreOrdinaryCCsWhenMPEOff`, `testR12_2_DAWRPN0WithMPEOffDoesNotTouchMPERange`. Design choice: MCM is ignored while MPE is off.
- **R12-4** RPN 0 on the master channel (1 for lower, 16 for upper) sets the global pitch-bend range. On a member channel it sets the MPE member range and recomputes the multipliers. Tests: `testR12_4_TypicalControllerSequenceKeepsMemberRange48`, `testR12_4_UpperZoneMasterIsChannel16`, `testR12_4_RPN0RecomputesPendingChannelBendMultiplier`. The old `Stage14Stage3Tests.testRPN0ChangesBendRange` locked in the wrong behaviour (master RPN changing the member range). It now uses member channel 1 and adds master checks. No separate `mpeMasterPitchBendRange` field was added: the master range is the existing global bend range.
- **R12-3** Member routing respects zone and member count. Tests: `Stage15Stage3Tests.testR12_3_LowerZoneMemberCountLimitsRouting`, `testR12_3_UpperZoneMasterIsCh16AndMembersBelowIt`, `testR12_3_ZeroMembersMeansNoPerNoteRouting`, `testR12_3_AURenderPathUsesCachedZone`.
- **R12-5** Standalone MIDI delivers MCM/RPN to the render thread through midiQueue. Tests: `testR12_5_StandaloneMCMAndRPNReachRender`, `testR12_5_StandaloneRPNCCsArePlainWhenMPEOff`.
- **R12-6 / R11-1** `setSampleRate` with user table (index 5) rebuilds the mips for the new SR, using the cache keyed by SR. `CompiledMipData.sampleRate` was added. Test: `Stage15Stage4Tests.testR12_6_UserTableRecompiledForNewSampleRateViaIndex5`.
- **R12-7 / R11-4** `loadBuiltin(5)` uses only the per-instance table. The statics `userWavetable` and `userCompiledWavetable` remain only as UI-display mirrors (OscillatorView), and audio never reads them. Test: `testR12_7_Index5NeverFallsBackToStaticUserTable`.
- **R12-9** The WTZ1 header hash is no longer trusted. Each distinct blob is decoded once and its verified hash is memoised by a stored-bytes FNV fingerprint, so repeat applyPreset calls do not decompress again. Tests: `testR12_9_ForgedWTZ1HeaderHashIsIgnored`, `testR12_9_LegacyHashDecodedOncePerBlob`.
- **Stronger tests:**
  - R9-2: `testR9_2_SendFadeWithRealTailIsClickFree` uses a real reverb tail in the send.
  - R11-1: covered via setSampleRate→index 5 (above).
  - R7-10: `testR7_10_EngineWavetableLFORendersFromTableWithoutTouchingOsc` renders the engine on a non-main thread.
  - `Stage11Round8Tests` stereo wavetable LFO now checks against an independent table interpolation. The check is stricter than before.

## Install / validation
- App reinstalled to /Applications.
- `pluginkit -a` run on both appex. `pluginkit -r` run on the DerivedData copies.
- `auval -v aumu Synt Nixr`: **AU VALIDATION SUCCEEDED**.
- `git merge-base --is-ancestor 5537eea HEAD`: exit 0.

## Notes and limitations
- `loadBuiltin(5)` can still be reached from `applyPresetDSP` on the render thread. In that case it uses the existing compiled table, even if it was built for the old SR, so it never compiles on the render thread. The SR rebuild happens in `setSampleRate`, which runs on main.
- R12-7 tests that fail on old code: the static fallback test fails on 5537eea. The R12-9 memo test depends on a new counter, so it does not compile on old code.
- Deferred to SYNT_16: arpeggiator items, R11-6..13, ARC in generateSample, R12-10..15.
