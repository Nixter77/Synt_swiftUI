# SYNT_30 preset coverage matrix

Shipped banks after the body rewrite. Checkboxes match `FactoryPresetCoverageTests.coverageMinimumsHoldOnShippedBanks`. Init (`SynthPreset.defaultPreset`) is not part of any musical bank.

## Banks and owners

| Bank | Count | Owner | Browser |
|---|---|---|---|
| Legacy categories (bass, lead, pad, keys, pluck, strings, fx) | 38 | `SynthCore/Models/FactoryPresets.swift` | Inside `factoryPresets` |
| Showcase | 20 | `FactoryPresets+Showcase.swift` | Inside `factoryPresets`, after legacy |
| Library (2026-10-18) | 42 | `FactoryPresets+Library.swift` | Inside `factoryPresets`, after showcase |
| Stage 8 demos | 3 | `FactoryPresets+Stage8.swift` | Suffix of `libraryPresets` (still inside factory) |
| **factoryPresets** | **103** | assembly in `FactoryPresets.swift` | Main browser list. Categories: Bass 16, Lead 16, Pad 14, Keys 13, Pluck 13, Strings 11, Brass 5, Arp / Seq 4, FX 11 |
| expansionPresets | 50 | `FactoryPresets+Expansion.swift` | Second browser bank (E01 / 050 … E50 / 050), not inside the 103 |
| mpeFactoryPresets | 2 | `FactoryPresets+MPE.swift` | Dedicated MPE set, not inside the 103 |
| Factory FX snapshots | distortion, phaser, chorus, delay, reverb, rotary, frequency shifter, transient, trance gate, FX order: 4 each. EQ names = `EQPreset.allCases` | `FactoryFXPresets.swift` | Per-effect menus, not patch banks |

## Authoring policy (soft caps)

- `masterVolume` ≤ 0.75. Poly pads and strings stay quieter than mono bass/lead demos.
- `reverbMix` ≤ 0.35, `delayMix` ≤ 0.22, `chorusMix` ≤ 0.22 unless the patch is an explicit FX/ambient showcase.
- Unison ≤ 4. Pads and strings stay at 1–2.
- Every non-Init factory and expansion patch renders finite and non-silent for ≥ 1 s note-on.
- Matrix rows use live destinations and sources (`.mseg`, `.mseg2`, `.env2`, `.vowel`, macros, wavetable morph, filter-2 rows where that filter is routed).
- Init stays bit-identical (`0xd1b3635203a4799e`). No DSP, AU address, or user-preset changes.

## Coverage (factory ∪ expansion ∪ mpe)

Counts are the shipped arrays the coverage test scans (103 + 50 + 2).

| Capability | Minimum | Now | Met |
|---|---|---|---|
| Filter 2 serial | 3 | 3 | [x] |
| Filter 2 parallel | 2 | 7 | [x] |
| Formant (Filter 1 or 2) + vowel / vowel mod | 4 | 7 | [x] |
| MSEG 1 in the matrix | 4 | 7 | [x] |
| MSEG 2 in the matrix | 2 | 4 | [x] |
| Env2 / dedicated filter ADSR | 6 | 11 | [x] |
| Wavetable including morph and/or index | 12 | 34 | [x] |
| Dual wavetable or wavetable + classic osc | 3 | 21 | [x] |
| FM and/or hard sync | 4 | 15 | [x] |
| Non-default FX order | 3 | 7 | [x] |
| Rotary and/or freq shifter and/or transient | 3 | 9 | [x] |
| Macros driving the matrix | 4 | 9 | [x] |
| Arp / sequencer Pro | 4 | 13 | [x] |
| MPE on | 2 | 2 | [x] |
| Stereo bus | several | 9 | [x] |
| Character | several | 15 | [x] |
| Noise color other than white | several | 11 | [x] |

Names are unique across factory + expansion and non-empty. Factory stays at 103. Expansion stays at 50.

Env 2 counts only when the matrix destination is one the per-voice scan applies with the env2 value: pitch, amplitude, pan, pulse width, mix, fine pitch, or FM. Dedicated filter ADSR counts only when `filterEnvelopeAmount` is not 0, so the cutoff scale actually moves.
