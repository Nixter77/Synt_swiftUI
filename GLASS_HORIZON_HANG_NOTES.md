# Glass Horizon hang investigation (2026-09-12 ~23:11 IDT)

Branch: `feat/glass-horizon-safe` (from `main` @ `9a86e45`). **Do not merge** until Nikolay A/B listens.
Sacred: no VoiceManager rewrite, no broad sound rewrite, no soft-limit/gain redesign on this branch.

## Factory param dump (pre-fix / stock on main)

`FactoryPresets.swift` ~216 — explicit + inherited defaults:

| Field | Value |
|-------|-------|
| osc1 | wavetable, vol 0.50, oct 0, morph 0.16 |
| osc2 | enabled sine, vol 0.36, oct 0, detune 4 |
| ADSR | A 1.200 / D 0.8 / S 0.8 / R 1.800 |
| filter | LPF cutoff 2000, res 0.16, envAmt 0 (unused) |
| LFO | on, rate 0.10, depth 0.14, → filter |
| reverbMix / room | **0.18** / **0.50** → Apple wet% **18**, room slot 2 = mediumHall |
| delayMix | **0** (default time/fb unused) |
| chorusMix | **0** |
| masterVolume | **0.42** |
| unison | **1** / detune 0 / spread 0 |
| phaser (stock main) | **ON**, mode **phaser2**, rate 0.10, depth 0.22, fb 0.08, center 700, mix 0.12, spread default 0.5 |
| distortion / EQ | off |

This branch’s factory tweak: **`phaserEnabled: false`** (params retained for easy re-enable).

## Offline matrix (stock phaser ON) — tip `feat/soft-limit-before-send` = D

Hooks: `renderFramesMetricsForTesting`. Apple Delay/Reverb **invisible**. Soft-limit D knee 0.70; Glass peaks ≪ knee → **D ≈ main offline** for this preset.

| n | peak | RMS | nearClip | preClip | held |
|---|------|-----|----------|---------|------|
| 1 | 0.059 | 0.035 | 0 | 0.059 | 1 |
| 2 | 0.112 | 0.048 | 0 | 0.112 | 2 |
| 3 | 0.157 | 0.057 | 0 | 0.158 | 3 |
| 4 | 0.186 | 0.062 | 0 | 0.188 | 4 |
| 7 | 0.344 | 0.088 | 0 | 0.360 | 7 |

**No BLOW** (nearClip≥8 / peak≥0.95 / preClip≥1.15). Hang **not** reproduced offline.

### Phaser ON vs OFF (same voices)

| n | phaser | peak | nearClip | preClip | relative render cost |
|---|--------|------|----------|---------|----------------------|
| 1 | ON | 0.059 | 0 | 0.059 | ~1.46× vs OFF |
| 1 | OFF | 0.062 | 0 | 0.062 | baseline |
| 2 | ON | 0.112 | 0 | 0.112 | ~1.46× |
| 2 | OFF | 0.119 | 0 | 0.120 | baseline |
| 4 | ON | 0.186 | 0 | 0.188 | ~1.45× |
| 4 | OFF | 0.199 | 0 | 0.202 | baseline |
| 7 | ON | 0.344 | 0 | 0.360 | ~1.10× |
| 7 | OFF | 0.360 | 0 | 0.378 | baseline |

Longer AB window: phaser ON slower (~1.22–1.46×); **nearClip stays 0** — phaser does **not** elevate offline crest (slightly quieter via mix).

Raw dump: `GLASS_HORIZON_PROBE_DUMP.txt` / probe `GlassHorizonHangProbeTests`.

## Hang hypotheses (ranked)

1. **Phaser + wavetable + polyphony + live Apple Reverb (CPU / underrun) — PRIMARY for hang@4**  
   - NEWPLAN historic: `tan()`×N/sample underruns; LUT removed `tan` from RT, but `processPhaserMode` still does per-sample `sin`×2, per-stage `pow` + `log` LUT lookup (`Phaser.swift` ~124–175).  
   - Glass uses wavetable osc1 + phaser2 in DSP chain (`AudioEngine+Render` ~202–206) then Apple Delay→Reverb live (`setupAudioEngine` serial graph).  
   - Offline: phaser ON costs ~+20–45% render time at 2–4 notes. Live adds Apple units → hang plausible at 4.  
   - **D soft-limit does not address this axis.**

2. **Apple Reverb (mediumHall) always in live graph** — contributes live CPU; wet% 18 is modest; delay mix 0 (dry-through). Alone weaker than (1); combines with phaser.

3. **Per-sample Swift render** (`sourceNode` loops `renderOneSample` per frame) — amplifies (1)+(2). Not Glass-specific but relevant under load.

4. **Command queue / metering / UI** — LOW for hang@4. Queue drains **once per buffer** (comment: was per-sample underruns). Metering every `levelUpdateInterval` samples.

5. **VoiceManager / `[Int:[ActiveNote]]` steal thrash** — **REJECTED for Glass@4**. VoiceManager **rolled back**; render is fixed pool `voices: [ActiveNote]` `maxVoices=32` (no Dictionary). Glass `unisonVoices=1`; multi-key collapses unison. Probe `held==n` at 1…7 — no steal at 4.

6. **Option D soft-limit / voice explosion** — **REJECTED for hang**. Peaks ≪ 0.70 knee; D≈identity offline. Unison not exploding.

## Hiss@2 vs hang@4

- Hiss@2: live wet rasp (Apple FX after clipper) — separate; offline clean; D may help hiss, **not hang**.  
- Hang@4: CPU/underrun axis (phaser primary).

## Smallest safe fix proposals

| Option | Scope | Notes |
|--------|-------|-------|
| **A. Factory `phaserEnabled: false` on Glass Horizon** | this branch | Implemented. Narrowest hang mitigation; changes pad color. Re-enable after (B). |
| **B. Phaser control-rate coeffs** | Phaser.swift only | Preferred DSP fix (CodeReviewer): update LFO→allpass coeffs every N samples; keep `tan`/LUT off RT. Not done here (no broad rewrite). |
| **C. Cap reverbMix further** | factory | Helps rasp, **not** hang (AU still processes). Skip as hang fix. |
| **D. Soft-limit before send** | other branch | Hiss axis; **will not fix hang@4**. |

## Ask Nikolay (live A/B)

1. **main vs D** at Glass Horizon 4 notes — expect **similar hang** (D not the hang fix).  
2. On main: toggle **Phaser OFF** (Advanced FX) then 4 notes — does hang disappear?  
3. Debug vs Release build?  
4. After this branch: Glass Horizon should be hang-safer but less “glassy”; confirm hiss@2 separately.

## Hang offline?

**No.** Offline never freezes; metrics stay clean. Live Apple FX + real-time callback required to observe hang.
