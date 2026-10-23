# SYNT_13 Implementation & Verification Report

**Branch**: `feat/auv3`  
**Base Ancestor**: `fff87e8` (`git merge-base --is-ancestor fff87e8 HEAD` verified)  
**Golden Audio Hash**: `0xd1b3635203a4799e` (bit-identical preserved)  
**Status**: All 4 Stages Completed & Verified

---

## 1. Commit History

| Stage | Commit SHA | Message |
|---|---|---|
| **Stage 1** | `53b9e68` | `feat(wt): Stage 1 - lock-free wavetable RT handoff and content-hash caching (R10-1, R10-2)` |
| **Stage 2** | `2c5e6cc` | `feat(wt): Stage 2 - wavetable SR correctness, single maxHarmonics formula, render-only seed, and R7-10 phase (R10-3, R10-4, R7-10)` |
| **Stage 3** | `1f71275` | `feat(wt): Stage 3 - sample import robustness, send tail smooth fade, wide seed, and compressed wavetable presets (R9-2 rest, R10-5..10)` |
| **Stage 4** | `ad794e5` | `feat(mpe): Stage 4 - MPE input parsing, per-note pitch bend, and AU param 163 (MPE part 1)` |

---

## 2. Stage Breakdown

### Stage 1: Lock-Free Wavetable RT Handoff & Content-Hash Caching (`53b9e68`)
- **R10-1 Lock-Free RT Table Handoff**:
  - Implemented Chen's wait-free 3-buffer algorithm (`pullNewWavetableRT`) using atomic triple indexing (`active`, `pending`, `nextSlot`), eliminating mutex locks from the render thread.
- **R10-2 Content-Hash Caching**:
  - Replaced pointer equality caching with `WavetableCacheKey(name:contentHash:sampleRate:)` using 64-bit FNV-1a hashing over table sample frames.
  - Repeated `applyPreset()` calls with identical table data do zero recompilations.
- **Test Suite**: `Stage13ThreadSafetyTests.swift` passes.

### Stage 2: Wavetable SR Correctness, Single Harmonic Formula, Render-Only Seed (`2c5e6cc`)
- **R10-3 Wavetable SR Correctness**:
  - Unified `CompiledMipData` initialization without default empty mip arrays.
  - Unified `WavetableOscillator.maxHarmonic(forOctave:sampleRate:)` with `mipMaxHarmonics(count:sampleRate:)` matching Nyquist limit at 44.1, 48, and 96 kHz.
- **R10-4 Render-Only Seed Application**:
  - Removed main-thread seed writes during preset changes; seed application is strictly deferred to `resetPatchStateRT()`, ensuring knob edits do not re-seed S&H or Perlin noise generators.
- **R7-10 LFO Right-Channel Phase Wrapping**:
  - Standardized phase normalization via `norm -= floor(norm)` across all LFO waveforms.
- **Test Suite**: `Stage13CorrectnessTests.swift` passes.

### Stage 3: Sample Import Robustness, Send Tail Fade, Wide Seed, Compressed Presets (`1f71275`)
- **R9-2 Send Tail Smooth Fade-Out & Incremental Clear**:
  - Replaced abrupt `sendReverb.reset()` on render with smooth 8-sample anti-click fade-out (`sendFadeA`, `sendFadeB`), followed by bounded incremental SIMD `memset`/loop zeroing across 8 render slices ($O(1)$ constant time, zero locks/allocs).
- **R10-5 Wide Seed Space**:
  - Fixed `SmoothRandom.reset(seed:)` to use full 32-bit space `Double(s) / Double(UInt32.max) * 256.0` instead of `s & 255`, eliminating the 256-value collapse.
  - Added patch-reset cleanup to restore default seed `0x12345678` when `cachedRandomSeed == nil`, preventing seed leakage across patches.
- **R10-6..8 Sample Import Conditioning**:
  - Added `cleanAndConditionFrame`: NaN/Inf sanitization, raised-cosine seam loop crossfade, DC offset removal via `vDSP_meanv`, and peak normalization.
  - Added file size limit ($2^{32}$ samples) and multi-channel downmixing in audio file parser.
- **R10-9..10 Compressed Wavetable Serialization**:
  - Added zlib compression/decompression to wavetable serialization, enforcing safety limits ($64$ frames, $2048$ samples, $512$ KB max).
- **Test Suite**: `Stage13SampleImportTests.swift` passes.

### Stage 4: MPE Input Parsing, Per-Note Pitch Bend, AU Parameter 163 (`ad794e5`)
- **AU Parameter Address 163**:
  - Allocated `SynthParameterAddress.mpeEnabled = 163` (`identifier: "mpeEnabled"`, `displayName: "MPE Enabled"`, min: 0.0, max: 1.0). Addresses $0 \le \text{address} \le 162$ remain untouched.
- **MPE Audio Commands**:
  - Added `.mpeKeyDown`, `.mpeKeyUp` (critical), `.mpePitchBend`, `.mpePressure`, `.mpeTimbre` to `AudioCommand`.
- **Channel Routing**:
  - Member channels 1–15 (MIDI channels 2–16) route to per-note MPE commands when `mpeEnabled` is true. Master channel 0 (MIDI channel 1) routes to global commands.
- **Per-Note Independent Pitch Bend**:
  - Evaluated on bend change: `v.mpePitchBendMultiplier = exp2(Double(v.mpePitchBend) * Double(cachedMpePitchBendRange) / 12.0)`. Zero per-sample `exp2` calls in the audio block.
- **Test Suite**: `Stage13MPETests.swift` passes.

---

## 3. Test Suite & Golden Hash Verification

```text
Test Suite 'Stage13ThreadSafetyTests' passed
Test Suite 'Stage13CorrectnessTests' passed
Test Suite 'Stage13SampleImportTests' passed
Test Suite 'Stage13MPETests' passed
  - testGoldenHarnessBitExactness: PASSED (hash: 0xd1b3635203a4799e)
  - testIndependentPerNotePitchBend: PASSED
  - testMIDICommandParsingLegacyVsMPE: PASSED
  - testMpeParameterAddressMetadataAndPresetDefaults: PASSED
  - testPerVoicePressureAndTimbreStorage: PASSED

Full Test Suite: ** TEST SUCCEEDED ** (0 failures)
```

---

## 4. Constraint Compliance Checklist

- [x] Ancestor `fff87e8` verified via `git merge-base --is-ancestor fff87e8 HEAD`
- [x] Golden FNV-1a hash preserved bit-identically: `0xd1b3635203a4799e`
- [x] AU Parameter addresses $\le 162$ unmoved; next parameter allocated at 163
- [x] Zero real-time audio thread allocations or locks
- [x] All 4 commits cleanly created in sequential order
- [x] Dump files `GLASS_HORIZON_PROBE_DUMP.txt` and `CHORD_HISS_MATRIX_DUMP.txt` restored before committing
