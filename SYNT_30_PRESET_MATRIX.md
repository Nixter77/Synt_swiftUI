# SYNT_30 preset coverage matrix

Inventory before the body rewrite. Checkboxes flip when the shipped banks meet the row. Init (`SynthPreset.defaultPreset`) is not part of any musical bank.

## Banks and owners

| Bank | Count now | Owner | Browser |
|---|---|---|---|
| Legacy categories (bass, lead, pad, keys, pluck, strings, fx) | 38 | `SynthCore/Models/FactoryPresets.swift` | Inside `factoryPresets` |
| Showcase | 20 | `FactoryPresets+Showcase.swift` | Inside `factoryPresets`, after legacy |
| Library (2026-10-18) | 42 | `FactoryPresets+Library.swift` | Inside `factoryPresets`, after showcase |
| Stage 8 demos | 3 | `FactoryPresets+Stage8.swift` | Suffix of `libraryPresets` (still inside factory) |
| **factoryPresets** | **103** | assembly in `FactoryPresets.swift` | Main browser list. Categories: Bass 16, Lead 16, Pad 14, Keys 13, Pluck 13, Strings 11, Brass 5, Arp / Seq 4, FX 11 |
| expansionPresets | 50 | `FactoryPresets+Expansion.swift` | Second browser bank (E01…), not inside the 103 |
| mpeFactoryPresets | 2 | `FactoryPresets+MPE.swift` | Dedicated MPE set, not inside the 103 |
| Factory FX snapshots | distortion 4, eq = `EQPreset.allCases`, phaser/chorus/delay/reverb 4 each | `FactoryFXPresets.swift` | Per-effect menus, not patch banks |

## Stale authoring notes (replaced in this stage)

`FactoryPresets.swift` header still told authors that filter-envelope amount and matrix→cutoff are stored but not heard, that only pitch/amp/pan matrix rows sound, that unison collapses on a second key, and that sends must stay at the old caps (reverb ≤ 0.24, delay ≤ 0.10, chorus ≤ 0.14, Env Amt = 0). Expansion's header still describes the pack as "next-generation" without the current filter-2 / MSEG / FX-order / rotary / shifter / transient engine. Those notes are replaced by the policy below. Preset bodies are not rewritten in the inventory stage.

## Authoring policy (soft caps)

- `masterVolume` ≤ 0.75. Poly pads and strings stay quieter than mono bass/lead demos.
- `reverbMix` ≤ 0.35, `delayMix` ≤ 0.22, `chorusMix` ≤ 0.22 unless the patch is an explicit FX/ambient showcase.
- Unison ≤ 4. Pads and strings prefer 1–2.
- Every non-Init factory and expansion patch renders finite and non-silent for ≥ 1 s note-on.
- Matrix rows use live destinations and sources (`.mseg`, `.mseg2`, `.env2`, `.vowel`, macros, wavetable morph, filter-2 rows where that filter is routed).
- Init stays bit-identical. No DSP, AU address, or user-preset changes.

## Coverage (factory ∪ expansion ∪ mpe)

| Capability | Minimum | Now | Met |
|---|---|---|---|
| Filter 2 serial | 3 | 1 (Serial Glass Bass) | [ ] |
| Filter 2 parallel | 2 | 0 | [ ] |
| Formant (Filter 1 or 2) + vowel / vowel mod | 4 | 1 (Vowel Ah Lead) | [ ] |
| MSEG 1 in the matrix | 4 | 1 (MSEG Drift) | [ ] |
| MSEG 2 in the matrix | 2 | 0 | [ ] |
| Env2 / dedicated filter ADSR | 6 | thin outside Expansion's stored env amount | [ ] |
| Wavetable including morph and/or index | 12 | present, not the bar for the other rows | [ ] |
| Dual wavetable or wavetable + classic osc | 3 | a few Expansion pairs | [ ] |
| FM and/or hard sync | 4 | mostly Expansion | [ ] |
| Non-default FX order | 3 | 0 | [ ] |
| Rotary and/or freq shifter and/or transient | 3 | 0 | [ ] |
| Macros driving the matrix | 4 | 0 | [ ] |
| Arp / sequencer Pro | 4 | arp category is 4; Pro steps are thin | [ ] |
| MPE on | 2 | 2 (needs a refresh, not a new bank) | [ ] |
| Stereo bus / character / noise color, used on purpose | several | rare | [ ] |

Names stay unique across factory + expansion and non-empty. Counts stay about 100–120 factory and about 50 expansion.
