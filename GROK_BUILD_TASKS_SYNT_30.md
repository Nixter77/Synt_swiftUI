# GROK_BUILD_TASKS_SYNT_30 — Factory preset full rework

Branch: `feat/auv3` (HEAD ~`a967726`). Do **not** merge to `main`. Commit + push when green.

## Decision (nixter / Grok Bot)

**Fully rewrite** all factory / showcase / library / stage8 / MPE / expansion preset *bodies* so they showcase the **current** engine (SYNT_8…28), not the old “half-dead matrix / no filter env / cautious FX” authoring notes still sitting in `FactoryPresets.swift` headers.

Do **not** only append a few demos. Replace the musical content. Keep structure (split files + categories + Expansion pack) unless a small consolidation clearly helps tests.

## Hard rules

- `SynthPreset.defaultPreset` (**Init**) stays **bit-identical**. Golden `0xd1b3635203a4799e` / `InitGoldenTests` must still pass. Init is not a sound-design preset.
- No render-thread alloc/lock/ARC; no Theme in SynthCore; AU host UI main-thread only.
- New DSP stays safe when unused: do not change DSP defaults for “off” paths. This task is **presets + tests**, not a DSP rewrite.
- `decodeIfPresent` / sanitize contracts stay. Do not reorder enum cases mid-list.
- Before each commit: `git restore GLASS_HORIZON_PROBE_DUMP.txt` (and any other scratch dumps you did not mean to commit).
- One commit per stage; suite green after each stage (or after stage 2+3 if you batch hash updates carefully — prefer green each stage).
- ~4 stages max in this file. Leftovers → `GROK_BUILD_TASKS_SYNT_31.md`.
- SYNT_29 (strict concurrency / Release A/B) is **not** this task; leave it for later unless a one-line conflict forces a tiny fix.

## Why rewrite

Factory headers and many patches still assume dead or weak paths. Live engine now has (non-exhaustive): Filter ADSR / Env2, dual filter (serial/parallel/off), Formant + vowel mod, MSEG + MSEG2, dual LFO + raw matrix rows, wavetables (+ user WT fields), FM/sync/sub, ring/noise, macros 1–8, FX order, rotary, freq shifter, transient, trance gate, MPE, arp/seq Pro, stereo bus, character, sends, etc. Coverage today is thin outside Expansion / Stage8 / two MPE demos. Expansion is a **second** bank in the browser (50), not inside the 103 `factoryPresets` list — rewrite **both**.

## Authoring policy (replace the stale caps)

Rewrite the comment block at the top of `FactoryPresets.swift` (and Expansion helper docs) to match reality. New soft caps (adjust only with a test update + short note in the report if you must):

- `masterVolume` ≤ **0.75** (factory demos); keep poly pads quieter than monos.
- Sends: `reverbMix` ≤ **0.35**, `delayMix` ≤ **0.22**, `chorusMix` ≤ **0.22** unless the patch is explicitly an FX/ambient showcase.
- Unison ≤ **4** where the engine supports it; prefer 1–2 on dense pads.
- Every non-Init factory/expansion patch must render **finite**, non-silent for ≥1 s note-on (same spirit as `LibraryPresetTests` / `Phase7ExpansionTests`).
- Prefer **live** matrix destinations and sources that the render path actually uses (incl. `.mseg`, `.mseg2`, `.env2`, `.vowel`, macros, WT morph, filter2-relevant rows where wired).

## Coverage matrix (must be true after rewrite)

Across **factoryPresets ∪ expansionPresets ∪ mpeFactoryPresets** (MPE may stay a small dedicated set, but still refreshed), there must be at least:

| Capability | Minimum demos |
|---|---|
| Filter 2 serial | 3 |
| Filter 2 parallel | 2 |
| Formant (Filter 1 or 2) + audible vowel / vowel mod | 4 |
| MSEG 1 in matrix | 4 |
| MSEG 2 in matrix | 2 |
| Env2 / dedicated filter ADSR | 6 |
| Wavetable (incl. morph and/or index) | 12 |
| Dual WT or WT + classic osc | 3 |
| FM and/or hard sync | 4 |
| FX order non-default | 3 |
| Rotary and/or freq shifter and/or transient | 3 |
| Macros driving matrix | 4 |
| Arp / sequencer Pro | 4 |
| MPE on | 2 (refresh existing) |
| Stereo bus / character / noise color used intentionally | several |

Names may change. Unique names across factory + expansion. Categories stay the existing `PresetCategory` set; keep a balanced bank (**target ~100–120 factory**, **~50 expansion** — counts may move ±10% if tests and browser labels are updated together).

## Stage 1 — Inventory + policy + scaffolding

1. Write `SYNT_30_PRESET_MATRIX.md` in the repo root: current counts, which files own which banks, stale vs live authoring notes, and the coverage table above with empty checkboxes.
2. Update `FactoryPresets.swift` header to the new authoring policy (no preset body rewrite required yet beyond comments if needed).
3. Add or extend a small **coverage test** (e.g. `Synt_swiftUITests/FactoryPresetCoverageTests.swift`) that fails until the matrix minimums are met (scan `factoryPresets`, `expansionPresets`, `mpeFactoryPresets`). Keep Init out of musical assertions.
4. Commit: `SYNT_30 Stage 1: preset coverage matrix + authoring policy`.

## Stage 2 — Rewrite core factory banks

Rewrite bodies in:

- `FactoryPresets.swift` (legacy category arrays)
- `FactoryPresets+Showcase.swift`
- `FactoryPresets+Library.swift`
- `FactoryPresets+Stage8.swift`
- `FactoryPresets+MPE.swift`

Goals: musical, distinct, using the coverage features; fix Stage8 demos so they are not the *only* Filter2/Formant/MSEG examples. Update `LibraryPresetTests` / `ShowcasePresetTests` / `PresetBrowserTests` / Program Change expectations (counts, category tallies, any hard-coded names/hashes).

Commit: `SYNT_30 Stage 2: rewrite core factory / showcase / library / MPE presets`.

## Stage 3 — Rewrite Expansion + FX factories

1. Fully rework `FactoryPresets+Expansion.swift` (still ~50, browser Expansion section) for the same modern engine — wavetable/FM/formant/MSEG/FX-order heavy is fine here.
2. Refresh `FactoryFXPresets.swift` so FX snapshots match current FX slots / order / rotary / etc.
3. Update `Phase7ExpansionTests` and any FX preset tests.
4. Commit: `SYNT_30 Stage 3: rewrite expansion + FX factory presets`.

## Stage 4 — Verify, report, next tasks

1. Full test plan / scheme green (same as recent SYNT runs). Init golden unchanged.
2. Tick the matrix file; ensure coverage test is green.
3. Manual smoke note in the report: load 5–10 named patches in app and/or AU (no need for Logic deep dive).
4. Write `SYNT_30_REPORT.md`. If anything remains (UI browser polish, more banks, hash golden file dump tooling), put it in `GROK_BUILD_TASKS_SYNT_31.md`.
5. Commit + push: `SYNT_30 report + SYNT_31 tasks` (or omit SYNT_31 if nothing left).

## Out of scope

- SYNT_29 concurrency / Release A/B campaign.
- Changing DSP algorithms, AU parameter addresses, or LayoutTests grid.
- Merging `feat/auv3` → `main`.
- Rewriting user presets on disk.
