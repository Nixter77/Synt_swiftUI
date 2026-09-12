# Soft-limit before send (option D)

Branch: `feat/soft-limit-before-send`  
Base: `main` @ matrix merge (`9a86e45`, PR #3).  
Sacred: **do not merge until Nikolay A/B listens.** No VoiceManager. No option C.

## What changed

### 1) Sample soft-limit (bus entering Apple FX) — `AudioEngine+Render.renderOneSample`

After synth `softClip(…, 0.95)`:

- If `max(delay.wetDryMix, reverb.wetDryMix) > 0.25` → apply `AudioMath.softLimitBeforeSend`
- Else → identity (dry-zero presets stay bit-identical offline)

Curve (`AudioMath`):

- Knee `0.70` (linear below = unchanged)
- Ceiling `0.85` (prefer quieter send over harder clip)

### 2) Constant drive reduction (live AVAudio graph) — `AudioEngine.setupAudioEngine`

```
sourceNode → preSendDrive (volume = AudioMath.preSendDriveGain = 0.88)
          → Apple Delay → Apple Reverb → mainMixer (0.62)
```

Offline `renderOneSample` / goldens **do not** include `preSendDrive` or Apple FX.

WetDryMix mapping (`appleFXWetPercent`) and factory authoring limits are **unchanged**.

## How to A/B listen (live app)

Compare this branch vs `main` on the same wet pad:

1. **1 note** — hall/delay tail a bit quieter; dry body should stay familiar.
2. **3-note wet pad** — main rasp/hiss check; prefer calmer send over residual rasp.
3. **7-note** — dense chord; no new dry-body damage; sends calmer than `main`.

Also zero reverb/delay once: sample soft-limit off (gate); only live `preSendDrive` remains on AU dry-through (~−1.1 dB) — should feel near-neutral.

## Tests

- `AudioGoldenHarnessTests` / `ChordHissMatrixTests`: dry-zero offline ≈ baseline (gate off).
- `SoftLimitBeforeSendTests`: curve + drive gain + dry offline smoke; documents live A/B gap.

## Risks

1. Serial graph: when sends are up, soft-limit also shapes the dry body (same bus). Mild by design.
2. Live `preSendDrive` always attenuates into Apple units (including dry-through at mix 0).
3. Offline still misses Apple FX tails — green tests ≠ live OK.
4. Quieter halls intentional; send remapping is a later GO if pads feel too dry.
