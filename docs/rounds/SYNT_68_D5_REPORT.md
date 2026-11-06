# SYNT_68 D5 report — CleanBus contrast (voice vs output)

Measured at Asia/Jerusalem. Probe: `DynamicsProbeTests` SUMMARY columns
VelRange_pre/post and ChordPre/ChordPost (= ChordContrast voice/output).

| Ref | SHA | Notes |
|---|---|---|
| before | `e5fffd8` | SYNT_65: CC7/CC11 + aftertouch; **CleanBus threshold left at 0.50** |
| after | `101202b` | SYNT_66 factory dynamics + SYNT_67 UI/golden; CleanBus still 0.50 |

## After (`101202b`) — per category (factory + Init bank in dump)

| Category | n | VelRange voice dB | VelRange output dB | vel ratio | ChordContrast voice dB | ChordContrast output dB | chord ratio |
|---|---:|---:|---:|---:|---:|---:|---:|
| Arp / Seq | 8 | 35.74 | 35.64 | 0.997 | 23.04 | 22.99 | 0.998 |
| Bass | 23 | 35.62 | 35.35 | 0.992 | 23.41 | 23.28 | 0.994 |
| Brass | 7 | 27.43 | 27.33 | 0.996 | 17.63 | 17.63 | 1.000 |
| FX | 15 | 14.13 | 14.10 | 0.998 | 8.14 | 8.13 | 0.999 |
| Keys | 23 | 39.92 | 39.68 | 0.994 | 25.89 | 25.39 | 0.981 |
| Lead | 23 | 35.63 | 35.54 | 0.998 | 23.20 | 22.54 | 0.972 |
| Pad | 28 | 19.71 | 19.80 | 1.004 | 11.90 | 11.93 | 1.002 |
| Pluck | 17 | 41.58 | 41.23 | 0.992 | 26.90 | 26.74 | 0.994 |
| Strings | 12 | 17.49 | 17.59 | 1.005 | 11.03 | 11.06 | 1.002 |

**D5 trigger:** ratio &lt; 0.7 anywhere → open CleanBus question for nixter.

**Result after:** every category vel/chord ratio ≥ 0.97. **No open CleanBus question.**
CleanBus threshold stays **0.50** (untouched).

## Before (`e5fffd8`)

Init SUMMARY is identical across the span (`VelRange_pre 16.48 / post 16.49`, chord 9.54/9.54) —
Init is not factory-dynamics authored. SYNT_65 explicitly left CleanBus alone; D0-era
Init already showed output/voice ≈ 1.0. A full category dump at `e5fffd8` was not
archived in-repo; factory absolute VelRange grew under SYNT_66, but the D5 ratio
(output/voice) is the gate, and after-state ratios clear it with margin.

| Check | before (e5fffd8) | after (101202b) |
|---|---|---|
| CleanBus threshold | 0.50 | 0.50 (unchanged) |
| Init VelRange out/voice | ≈1.00 | 16.49/16.48 ≈ 1.00 |
| Init Chord out/voice | ≈1.00 | 9.54/9.54 = 1.00 |
| Worst category chord ratio | (not archived; CleanBus untouched) | 0.972 (Lead) |
| Open CleanBus Q? | no | **no** |

## SoftHard threshold

Picks at after (v100/v30 RMS):
- Velvet Acid: 10.81×
- Round Reese: 20.08×
- Soft 808: 20.03×
- Silk Lead: 20.97×
- Warm Mono: 12.64×
- Wavetable Growl: 20.99×
- Overdrive Lead: 12.62×
- Hard Sync Screamer: 16.71×

Min measured ≈ 10.8×. Historical gate was 1.05×; SYNT_66 used 1.50×.
**SYNT_68 strengthens to 2.00×** (data-backed; all eight picks pass without preset edits).

## CleanBus

**Not changed.** No category ratio &lt; 0.7.

## SoftHard / Stage notes (Eng)

- SoftHard threshold: **2.00×** (was 1.50×). All 8 picks pass; min measured ≈ 10.8×.
- Stage 4 MIDI 2.0 protocol flag: **IN** (nixter GO S1–S4). Setting-gated `midi2ProtocolEnabled` default OFF → `audioUnitMIDIProtocol = ._1_0`. When on → `._2_0`. UMP fixtures covered in `MIDI2ProtocolTests`. Manual Logic check = **KEEP ME IN** (nixter).
- `busGlueEnabled` = AU address **192** (append-only after `aftertouchDeadzone` = 191). Default OFF / decodeIfPresent inert.
- CleanBus threshold **0.50** untouched.
