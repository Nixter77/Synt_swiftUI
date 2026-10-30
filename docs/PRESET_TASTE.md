# Synt factory preset taste (permanent)

> Grok Bot syncs the synt-preset-taste skill from this file.

Init golden `0xd1b3635203a4799e` must not change. Values only; nixter final-listens.

See also local `GROK_BUILD_TASKS_SYNT_31.md` (gitignored) and shared skill «Synt preset taste».

## Soft caps
master ≤0.75; reverb ≤0.35 (FX/showcase ≤0.45); delay/chorus ≤0.22 (exc. ≤0.30); peak >0.005; pads/strings unison ≤2.

## Hierarchy (master)
bass 0.58–0.65 > lead 0.52–0.62 > keys/pluck 0.45–0.55 > pad/strings 0.32–0.40.

## Dull = Init-like / baseline
Too little deviation from soft FactoryAuthoring (master~0.46, res~0.16, dirt mix~0.08). Target ≥20 meaningful overrides on named presets.

## Must hear
Layers (osc2/sub), filter body + env, audible dirt or character FX, ≥1 modulator, category gesture distinguishable in ≤2s.

## SYNT_32 floors (character pass)
SYNT_31 sat at the safe low end of every band and sounded flat. These are floors, not only caps.

Raised caps: bass/lead res up to 0.65–0.70 (acid); dirt mix up to 0.35; master ≤0.75; pad/strings unison ≤2; reverb ≤0.35 (FX ≤0.45); delay/chorus ≤0.22 everyday (≤0.30 FX).

Character bands (upper third in brackets):
- resonance: bass/lead/brass/arp/fx 0.20–0.70 [≥0.54]; keys/pluck 0.15–0.55 [≥0.42]; pad/strings 0.10–0.45 [≥0.34]
- filter env amount: 0.10–0.70 [≥0.50]
- dirt mix: 0.18–0.35 when on, floor 0.12 [≥0.29]
- strongest mod depth: 0.30–0.60 [≥0.40]
- FX wet (max of reverb/delay/chorus): 0.12–0.35 [≥0.26]

**A — Placement.** ≥30% of presets in each category sit in the upper third of ≥2 character bands. Acid-named: res ≥0.60, filter env ≥0.55, porta 0.02–0.08, dirt ≥0.20.

**B — Dirt.** ≥60% of bass + lead + brass have audible dirt (mix 0.18–0.35). Dirt on with mix <0.12 is banned. Pads/strings: dirt ~none.

**C — Motion.** Every preset has ≥1 live modulator ≥0.30 (matrix row from LFO1/LFO2/MSEG/velocity/env1/key, or an enabled LFO direct target). No matrix row with |amount| <0.15. Pads/strings: LFO or MSEG ≥0.30 → cutoff or WT morph (formant: vowel) at 0.05–0.30 Hz. Lead vibrato depth ≥0.10.

**D — FX.** Delay ≥0.12 on lead / pluck / arp when used. Chorus ≥0.14 on pads / strings / keys. Pad + strings reverb 0.20–0.30. FX category: ≥1 wet ≥0.30. `dspReverbEnabled = true` wherever reverb should take part in fxOrder / matrix.

**E — Width / voices / FM.** Unison 2 on ≥50% of bass, lead, pad (each). stereoWidth varies: ≤3 presets per category within ±0.02. FM keys/bells: fmAmount ≥0.15.

Loudness hierarchy stays (bass > lead > keys/pluck > pad/strings; FX 0.30–0.55). After raising dirt/res, re-check peaks: >0.005, no clipping.

## Dead paths (never target)
1. Env2 / Mod Env / Random / S&H as a matrix SOURCE into a global destination (cutoff, resonance, WT morph, vowel, FX mix, LFO rate/depth) — ignored by the engine. Use LFO1/LFO2/MSEG/velocity/aftertouch/mod wheel instead.
2. Formant filter ignores cutoff, resonance and filter env. Move `.vowel` only (LFO/MSEG → vowel).
3. `dspReverbEnabled` defaults off, so reverb in fxOrder / matrix is weak. Set it true explicitly where reverb should participate.

## SYNT_33 identity (the name decides the sound)
Applied after the SYNT_32 floors; floors win on conflict. Audited by `FactoryIdentityAuditTests`.
- Soft / Velvet / Warm / Whisper / Silk / Round / Mellow → dirt mix ≤0.22, res ≤ band mid (acid exempt), width lower half.
- Dark / Noir / Muted → cutoff ≤1400 Hz (non-formant).
- Bright / Crystal / Glass / Air → cutoff ≥2200 Hz, res ≥ band mid (not bass).
- Wide / Super / Cloud / Horizon → width upper third (wins over Soft).
- Hard / Growl / Screamer / Grit / Dirty / Overdrive → dirt ≥0.28 on bass/lead/brass.
- Drift / Motion / Morph / Wobble → strongest live mod ≥0.40.
- Factory names unique across factory, expansion and MPE banks.
