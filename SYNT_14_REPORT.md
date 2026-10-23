# SYNT_14_REPORT

## 1. Overview & Verification Summary
- **Base Commit**: `6ddb815`
- **Ancestor Check**: `git merge-base --is-ancestor 6ddb815 HEAD` succeeded (`OK: 6ddb815 is an ancestor of HEAD`).
- **Golden Audio Hash**: `0xd1b3635203a4799e` preserved 100% bit-identical across all 104 factory/init presets (`InitGoldenTests` passes).
- **AU Parameter Addresses**: 0–163 unmoved; new addresses start from 164:
  - Address 164: `mpePitchBendRange` (0.0 ... 96.0, default 48.0 semitones)
  - Address 165: `mpeZone` (0.0 = Lower / Ch 1, 1.0 = Upper / Ch 16)
  - Address 166: `mpeMemberChannelCount` (0.0 ... 15.0, default 15)
- **Render Thread Invariants**: Zero memory allocations, zero locks, zero per-sample `exp`/`pow` in voice DSP inner loops.
- **Git Hygiene**: Strict linear history, zero force-pushes, clean push after each stage.

---

## 2. Commits Per Stage
1. **Stage 1**: `b00ee35`
   `feat(core): Stage 1 - wavetable SR cache, persistent MPE channel state, MPE queue overflow, and LFO wavetable (R11-1, R11-2, R11-11, R7-10)`
2. **Stage 2**: `68ab409`
   `feat(core): Stage 2 - wavetable decompression limit, unified content hash, instance user tables, and 15ms send tail fade (R11-5, R11-3, R11-4, R9-2)`
3. **Stage 3**: `435be26`
   `feat(mpe): Stage 3 - per-voice MPE mod sources, AU params 164-166, and RPN 0/6 config`
4. **Stage 4**: `8d21d26`
   `feat(mpe): Stage 4 - MPE UI controls, preset roundtrip, and factory MPE presets`

---

## 3. Test Counts & Passing Test Matrix

### Test Counts
- **Stage 1 Suite (`Stage14Stage1Tests`)**: 7 tests, 7 passed
- **Stage 2 Suite (`Stage14Stage2Tests`)**: 7 tests, 7 passed
- **Stage 3 Suite (`Stage14Stage3Tests`)**: 7 tests, 7 passed
- **Stage 4 Suite (`Stage14Stage4Tests`)**: 5 tests, 5 passed
- **Total Stage 14 Tests**: **26 tests, 26 passed**
- **Golden Audio Harness (`InitGoldenTests`)**: Passed (104 presets bit-exact)

### Proof for Every Fixed Item
Every fixed item is backed by dedicated, passing unit tests:

| Issue / Item | Description | Proving Passing Test |
|---|---|---|
| **R11-1 (= R10-3)** | Built-in and user wavetable cache keyed by both index/content and sample rate; rebuilds on SR change at 44.1, 48, 96 kHz. | `Stage14Stage1Tests.testBuiltinWavetableCacheKeyedBySampleRateAndRebuildsOnSRChange` & `Stage14Stage1Tests.testUserWavetableRebuildsOnSRChange` |
| **R11-2** | Per-channel MPE state (bend, pressure, CC74) preserved on all 16 channels; note-on starts from channel's current bend and expression on sample 0. | `Stage14Stage1Tests.testMPEPitchBendSentBeforeNoteOnAppliesFromSampleZero` & `Stage14Stage1Tests.testMPEPressureAndTimbreSentBeforeNoteOnAreInherited` |
| **R11-11** | When event queue overflows, `mpeKeyUp` retains its channel and never releases notes on other channels. | `Stage14Stage1Tests.testMpeKeyUpQueueOverflowKeepsChannelAndDoesNotReleaseOtherChannels` |
| **R7-10** | LFO shape `.wavetable` reads actual wavetable data instead of falling back to a sine wave. | `Stage14Stage1Tests.testLFOWavetableShapeDiffersFromSine` |
| **R11-5 (Security)** | Checked decompressed size limit BEFORE inflating zlib table data (defends against zip-bombs with `"WTZ1"` safety header and 512KB cap; rejects without large allocation). | `Stage14Stage2Tests.testCraftedZipBombWithoutHeaderRejectsSafelyWithoutBigAllocation`, `Stage14Stage2Tests.testOversizedPayloadWithDeclaredSizeRejectsBeforeInflating`, `Stage14Stage2Tests.testOversizedUncompressedRawDataRejectsBeforeParsing` |
| **R11-3** | Unified canonical content hash for raw and compressed tables (`Wavetable.canonicalContentHash`); eliminates redundant compilation. | `Stage14Stage2Tests.testOneContentHashForRawAndCompressedTable` |
| **R11-4** | Async table load targets only the oscillator that requested it; user tables stored per AU instance (`instanceUserWavetable` / `instanceUserCompiled`). | `Stage14Stage2Tests.testLoadUserWavetableTargetsOnlyRequestingOscillator` & `Stage14Stage2Tests.testPerInstanceUserWavetableStorageBetweenEngines` |
| **R9-2** | Smooth ~15 ms tail fade (`sendFadeStep = 1.0 / (sampleRate * 0.015)`) when send drops to zero and back; zero click or discontinuity ($|\Delta s| < 0.02$). | `Stage14Stage2Tests.testSendTailFadeSmoothnessAndDuration` |
| **Stage 3 Mod Sources** | Per-voice MPE mod sources (`.mpePitchBend`, `.mpePressure`, `.mpeTimbre`) available in mod matrix; pressure on note A modulates only voice A; smoothed with 0.05 one-pole filter in RT voice loop. | `Stage14Stage3Tests.testPressureOnNoteAModulatesOnlyVoiceA` & `Stage14Stage3Tests.testTimbreCC74ModulatesOnlyTargetVoice` |
| **Stage 3 AU Params** | AU parameter addresses 164 (`mpePitchBendRange`), 165 (`mpeZone`), 166 (`mpeMemberChannelCount`) appended from 164 with valid ranges and identifiers. | `Stage14Stage3Tests.testNewAUParameterAddressesFrom164` & `Stage14Stage3Tests.testEngineParameterApplicationFrom164` |
| **Stage 3 RPN Handling** | Accepts MPE configuration via RPN 0 (bend range) and RPN 6 (MCM zone & member channel count). | `Stage14Stage3Tests.testRPN0ChangesBendRange` & `Stage14Stage3Tests.testRPN6SetsZoneAndMemberChannelCount` |
| **Stage 4 Presets** | Save/load MPE settings with `decodeIfPresent`; legacy presets load with MPE off. | `Stage14Stage4Tests.testPresetRoundTripWithMPESettings` & `Stage14Stage4Tests.testOldPresetsLoadWithMPEOff` |
| **Stage 4 Factory Presets** | 2 factory MPE presets provided (`SynthPreset.mpeFactoryPresets`): "MPE Expressive Pad" (pressure → filter cutoff) and "MPE Wavetable Morph" (timbre CC74 → wavetable position). | `Stage14Stage4Tests.testFactoryMPEPresets` |
| **Stage 4 UI Integration** | MPE controls (on/off, bend range, zone, member channel count, factory MPE preset selection) in `UnisonView`; mod matrix UI supports all 3 MPE sources. | `Stage14Stage4Tests.testModMatrixSourcesSelectable` |
| **Golden Hash** | FNV-1a audio hash `0xd1b3635203a4799e` preserved bit-identical across all stages. | `Stage14Stage1Tests.testGoldenHarnessPreserved`, `Stage14Stage2Tests.testGoldenHarnessPreserved`, `Stage14Stage3Tests.testGoldenHarnessPreserved`, `Stage14Stage4Tests.testGoldenHarnessPreserved`, `InitGoldenTests.initAndFactoryPresetsRenderBitIdenticalToGolden` |

---

## 4. Deferred Items (As Directed in GROK_BUILD_TASKS_SYNT_14)
The following items were explicitly designated for SYNT_15 and remain untouched in accordance with task specification:
1. **Per-sample retain/release in `generateSample`**: Passing unowned pointers inside the render block to eliminate ARC overhead (~1.4M/s).
2. **ROUND11 minor items R11-6 through R11-13**: Deferred per spec.
3. **Arpeggiator (`SyntArpAUv3`)**: Untouched and deferred per nixter instruction.
