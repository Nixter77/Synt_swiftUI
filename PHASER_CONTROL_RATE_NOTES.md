# Phaser control-rate rewrite (feat/phaser-control-rate)

## Recipe (musicdsp.org Effects/78 — Bencina + Thaddy)

- Allpass coeff: `a1 = (1-d)/(1+d)` with `d = tan(π·fc/SR)` (same bilinear form as before).
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
