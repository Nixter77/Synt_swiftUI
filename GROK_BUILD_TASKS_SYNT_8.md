# GROK_BUILD_TASKS_SYNT_8

Base: 896ef85 on feat/auv3 (SYNT_7 + the merged SYNT_7B). Do not merge into main.
Rules: no allocations, locks or ARC on the render thread; golden hashes (0xd1b3635203a4799e, InitGoldenTests) do not change, so everything new is OFF by default and bit-exact when off; new preset fields use decodeIfPresent; new enum cases go at the end; no Theme in core; AU sizing and hosting view only on the main thread; panels never overlap (LayoutTests); run `git restore GLASS_HORIZON_PROBE_DUMP.txt` before each commit; one commit per stage, tests green.
API of the modules: SYNT_7B-REPORT.md (in ../Synt_swiftUI_7b) and SynthCore/DSP/Experimental/*.


## MANDATORY in stages 1–3 (from the ROUND6 review)
- R6-1: on NaN in the feedback, also call v.filter.reset() (Render.swift:896-900), not only clear the fb state.
- R6-10: DSPMSEG.swift:214-222. MSEG with sustain, without a loop and not one-shot, must NOT repeat after note release: go to the release segment and stop.
- R6-11: DSPMSEG.swift:109. Do not rewrite the MSEG tables from the main thread while render reads them; pass points only through the preset snapshot (atomic swap of a ready model).
- R6-9: DSPMSEG.swift:94. When loading from a preset, sort points by time and clamp them to the valid range.
- Tests for each one.

## Stage 1: Second filter in the voice
- Wire DSPDualFilter into the voice: Filter 2 (type, cutoff, reso), routing Serial/Parallel/Off (Off is the default), balance.
- Buffers in allocateRenderResources; parameters in the AU parameter tree (a new group at the end).
- UI: a FILTER 2 tab inside the FILTER panel (no new panel; LayoutTests stay green).
- Tests: Off = bit-exact; serial/parallel change the spectrum; finite at max resonance.

## Stage 2: Formant filter
- Add Formant as a filter type (enum case at the end) for Filter 1 and Filter 2; Vowel (0…4) is a mod-matrix destination.
- Tests: the vowel morph is smooth (no clicks), finite with noise for 10 s.

## Stage 3: MSEG as a modulation source
- MSEG 1 as a mod-matrix source: tick() on the render thread, the model is swapped atomically from the UI.
- UI: a simple point editor (add/move/delete, curve per segment, loop/sustain, sync) in the MOD panel, within the 520 pt height.
- Preset: MSEG points in the preset (decodeIfPresent), empty by default.
- Tests: retrigger per note, loop, sync to host tempo, preset round-trip.

## Stage 4: Cleanup after the merge
- Move the modules out of Experimental/ into their working folders, remove duplicates and dead code.
- Factory presets: 3 new presets showing off Filter 2, Formant and MSEG (new presets only; do not touch the old ones or their hashes).

Report: SYNT_8-REPORT.md with commits, tests, and what was not verified in Logic.
