# Phaser control-rate rewrite (feat/phaser-control-rate)

## Recipe (musicdsp.org Effects/78 — Bencina + Thaddy)

- Allpass coeff: `a1 = (d-1)/(d+1)` with `d = tan(π·fc/SR)` — **same as main LUT path** (equals −musicdsp `(1-d)/(1+d)`; do not flip).
- Process **every sample** through the staged allpasses + feedback.
- Update `d` / `a1` **once per control block** (N = 32 samples here), **not** every sample.
- **Interpolate `a1` inside the block** (linear start→target). Hard per-block steps zipper; smooth a1 keeps sweep clean.
- LFO phase still advances every sample; `sin` only at control-rate refresh.
- Stage frequency spread (`pow(2, t·1.5)` over stages) and feedback clamps are **unchanged** in this diff so Glass Horizon A/B stays meaningful.
- One phaser on the bus (existing architecture) — not per-voice.

## What changed in `Phaser.swift`

- Phaser 2/4/6/8 hot path: no per-sample `tan` / `sin` / `pow` / `log`.
- Coeffs computed at control rate; `a1` lerped per sample.
- Flanger / chorus paths left alone (not used by Glass Horizon).
- Public API (`process`, mix, rate, depth, feedback, mode, bypass, LUT helpers) preserved.

## Glass Horizon

- Factory `phaserEnabled` stays **OFF** until a listen GO after this rewrite.
- Params retained on the preset for easy re-enable.
- Do **not** merge this branch to `main` without further listen GO.

## How to A/B new vs old phaser

No factory preset other than Glass Horizon carried phaser params; Glass Horizon is intentionally OFF.

**Listen A/B (recommended):**

1. Keep factory Glass Horizon phaser OFF.
2. Pick a non-Glass pad (e.g. **Analog Drift** or **Cloud Bed**).
3. In Advanced FX: enable Phaser, mode **Phaser 2**, mild mix (~0.12–0.25), low feedback.
4. Play 1→4 notes; compare CPU / cleanliness vs memory of old dirt.
5. Optional Glass check: temporarily force Glass Horizon phaser ON in the UI only (do not commit factory ON).

**Code A/B (old algorithm):**

```bash
git show main:Synt_swiftUI/Audio/Effects/Phaser.swift > /tmp/Phaser_old.swift
# diff against current, or briefly checkout that blob on a throwaway branch
```

Old tip before this branch’s Phaser commit is merge `e9c2eb5` (post glass-horizon-safe) / prior `Phaser.swift` on `main`.

## Risks

- Control-rate + lerp slightly softens the fastest LFO sweeps vs per-sample coeff (rate up to 8 Hz still fine at N=32).
- First control block after engage starts from a1=0 targets then jumps to first LFO-derived targets over 32 samples (short settle); bypass→engage still `reset()`s.
- Flanger/chorus still use per-sample `sin` (out of scope).
- Do not re-enable Glass Horizon factory phaser until live listen confirms clean + hang@4 OK.


## Regression listen (2026-09-13) — hiss vs main

Nikolay: new control-rate tip sounded **worse / more hiss** than memory of old phaser.

### Ranked root causes (offline A/B vs main `e9c2eb52` Phaser.swift)

1. **Cold-start a1=0 lerp (FIXED on this branch)** — After `reset()` / bypass→engage, `a1Start/Target` were 0. `a1=0` is allpass at ~sr/4, **not** neutral. First N=32 samples lerped 0→LFO target and poisoned AP + feedback state. Offline (Python twin of both paths):
   - Mild Glass-like Phaser2: no-prime maxAbsDiff≈0.028 vs old LUT; **with prime ≈ 0**.
   - Hot Phaser4+softclip: no-prime peak 0.85 vs old 0.70 (maxAbsDiff≈0.26); **with prime peak≈0.70, maxAbsDiff≈8e-4**.
2. **Block-boundary a1 derivative zipper** — Linear lerp has large `|Δ²a1|` at every N boundary → HF grain that can read as hiss with feedback. Mitigated with **smoothstep** on the in-block fraction (same control period N=32).
3. **Polarity NOT a regression** — Main LUT and branch both use `(d-1)/(d+1)`. That equals **−**musicdsp `(1-d)/(1+d)`. Notes previously claimed ≡; corrected. Flipping would diverge from main, not fix hiss.
4. **fMin/fMax mapping** — Same `clampFreq` / stageRatios / center×(1+0.5·depth·lfo) as main. No mapping bug found.
5. **Wet/softClip/bus order** — Unchanged (`distortion → EQ → phaser → chorus → softClip`). Hotter peaks from (1) could drive softClip harder → rasp; not an ordering bug.

### Follow-up commit intent

- Prime `a1Start = a1Target` on first control update after reset.
- Smoothstep in-block a1 interpolation.
- Correct polarity documentation.
- **Still do not merge to main.** Glass factory phaser stays OFF.

### Ask Nikolay next listen

1. Stay on `feat/phaser-control-rate` tip (this fix), **not** merged main.
2. Main listen baseline remains Glass OFF / clean.
3. Same one stimulus: e.g. Analog Drift (or Cloud Bed), Advanced FX → Phaser ON, mode Phaser 2, mild mix (~0.12–0.25), low feedback — compare to memory of old phaser dirt, and to previous branch tip if still in ears.
4. Report: zipper/steps vs louder rasp/distortion vs still more hiss than old.
