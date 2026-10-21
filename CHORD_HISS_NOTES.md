# Chord hiss matrix — measurement notes (NO sound fix)

Branch: `feat/chord-hiss-matrix`  
Sacred: **no DSP / VoiceManager / FX-order / clipper changes** without a separate GO.

## What this branch does

- Offline factory + dry/wet × **1 / 3 / 7 notes** matrix via existing hooks:
  - `AudioEngine.renderFramesMetricsForTesting` → `peak`, `rms`, `nearClipCount`, `preClipPeak`
- Documents which factory presets **blow up** (elevated nearClip / peak / preClip) at 3 vs 7 notes.
- A/B proposals below are **documentation only** — not implemented.

## Critical gap: Apple FX after clipper

Live graph (see `AudioEngine` connect path):

`sourceNode (DSP + softClip) → Apple Delay → Apple Reverb → mainMixer`

So:

| Path | Sees soft-clip / nearClip hooks? | Sees Apple Delay/Reverb rasp? |
|------|----------------------------------|-------------------------------|
| Offline `renderOneSample` / goldens | Yes | **No** |
| Live device playback | Yes (pre-FX) | Yes (post-clipper) |

Wet chords that “rasp” in the app can still look clean offline. High `reverbMix` / `delayMix` alone do **not** move offline metrics. DSP **chorus** / distortion / EQ / phaser **are** in the offline path and can move peak/preClip.

Authoring comment in `FactoryPresets.swift` already states this: *Apple Delay/Reverb sit after our clipper. Wet chords rasp.*

## Blow rule (matrix)

A row is marked **BLOW** when any of:

- `nearClipCount >= 8` (post-softClip samples with `|x| > 0.98`)
- `peak >= 0.95`
- `preClipPeak >= 1.15`
- `nanCount > 0`

Exact blow list is filled from the test dump after `xcodebuild test` (see `CHORD_HISS_MATRIX_DUMP.txt` / report section below).

## A/B notes (document only — do NOT implement)

### A — Dry

- Zero `reverbMix` / `delayMix` / `chorusMix`, distortion/phaser off.
- Expected: linear note-sum only; nearClip should track voice density + master, not “hiss from hall”.

### B — Wet-only (current architecture)

- Stock or boosted Apple sends; DSP chorus may also be up.
- Live: Delay→Reverb **after** clipper → wet energy can fold/rasp without raising offline nearClip.
- Offline: only DSP-wet (chorus etc.) shows up in metrics.

### C — Proposed: clipper **before** FX (still not implemented)

- Soft-limit (or clip) **after** Apple Delay/Reverb (or move Apple FX before the existing clipper and add a post-FX limiter).
- Goal: stop post-FX crest from hard-rasping; keep pre-FX headroom policy explicit.
- Risk: changes wet tail character; needs separate GO + goldens.

### D — Proposed: soft-limit **before send** (still not implemented)

- Soft-limit / drive reduction on the bus **entering** Delay/Reverb wet sends (pre-send), keep dry path as today.
- Goal: tame send input so Apple units get less clipped-ish crest.
- Risk: quieter halls; pad presets may need send remapping.

## Risks

1. **False clean offline** — matrix may under-report live wet rasp (Apple-FX-after-clipper gap).
2. **False blow on dry dense chords** — linear sum of 7 notes can elevate preClip without being the “hiss” users hear on wet pads.
3. **Unison collapse** — second held key collapses unison; chord tests are not “unison×notes”.
4. **No sound fix on this branch** — failing documenting goldens are intentional repro signals, not a license to change DSP.

## Report (Mac run 2026-09-12 ~22:13 IDT)

Offline hooks: `renderFramesMetricsForTesting` only (no Apple Delay/Reverb).

### Blow list (threshold nearClip≥8 / peak≥0.95 / preClip≥1.15)

| Density | Presets that BLOW |
|--------|-------------------|
| 3 notes | **none** |
| 7 notes | **none** |
| BLOW@3 but OK@7 | **none** |

So: no factory preset “blows up at 3 vs OK at 7” on the **offline DSP path**. Live wet rasp remains a separate Apple-FX-after-clipper problem.

### Hottest stock runners-up (not BLOW)

| Preset | n | peak | preClip | nearClip |
|--------|---|------|---------|----------|
| Muted Funk | 7 | ~0.78 | ~1.09 | 0 |
| Clean Sub | 7 | ~0.60 | ~0.71 | 0 |
| Cello Warm | 7 | ~0.53 | ~0.59 | 0 |
| Init dry (synthetic) | 7 | ~0.73 | ~0.98 | 0 |
| Muted Funk | 3 | ~0.48 | ~0.53 | 0 |

### Dry vs stock vs wetBoost (Crystal Lead)

- **dry == stock** peak/RMS/nearClip at 1/3/7 → Apple `reverbMix`/`delayMix` invisible offline (**gap proven**).
- wetBoost (adds DSP chorus 0.14) was **slightly quieter**, not hotter — chorus dilutes crest; still nearClip=0.

### Test counts (`ChordHissMatrixTests`)

- 4 tests: CrystalLead dry/stock/wet ×1/3/7; full factory stock ×1/3/7; wet-complex 3-note documenting; synthetic Init dry/wet ×1/3/7.
- Matrix cells: 9 (Crystal) + 38×3=114 (factory) + 8×2=16 (wet-complex) + 6 (Init) ≈ **145** metric rows.

### Risks

1. False clean offline while live wet chords rasp (Apple FX after clipper).
2. Dense dry chords (Muted Funk / Init @7) approach soft-clip without being the “hiss” users report on wet pads.
3. No sound fix on this branch — A/B C/D above are proposals only.
