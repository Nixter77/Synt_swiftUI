# GROK_BUILD_TASKS_SYNT_6

Base: 3236a49 (SYNT_5 is done) on branch feat/auv3. Do not merge into main.
Rules (as before): no allocations, locks or ARC on the render thread; Golden hash 0xd1b3635203a4799e and InitGoldenTests must not change, so every new feature defaults to OFF and is bit-exact when off; new preset fields use decodeIfPresent; new enum cases go at the end; no Theme in core; run `git restore GLASS_HORIZON_PROBE_DUMP.txt` before each commit; one commit per stage, tests green.

## Stage 1: plugin UI without overlaps (PRIORITY)
Problem (Logic, View 161%): OSC 2 goes under FILTER, FILTER covers LFO, UNISON overlaps OSC 2 and FILTER.
- Replace absolute/offset positioning with a grid of fixed columns (Grid/HStack+VStack); panels never overlap at any size.
- Expose supportedViewConfigurations in the AU: compact (≤520 pt high) and extended layouts, both without overlaps.
- Zoom menu 75/100/125/150/200%, remembered in fullState (decodeIfPresent).
- Test: a snapshot/geometry test that checks the frames of all panels do not intersect at each zoom and layout.

## Stage 2: Stereo and voices
- Stereo tool in FX: Width, Mid/Side, Haas (0–30 ms), mono bass below a frequency (default off).
- Oscillator phase: Reset (current, default) / Free / Random.
- Polyphony limit per preset (1–32; default = current value).

## Stage 3: Modulation
- Trance Gate: 16 steps, tempo-sync, depth, smoothing (default off).
- Smooth random source (Perlin), rate plus sync, as a mod-matrix source.
- Remap curves on mod-matrix routes (linear/exp/log/S/steps); build the table off the render thread and swap it atomically.

## Stage 4: Sound
- Flanger mode on top of the chorus (feedback, sync).
- Filter → mixer feedback like Diva (default 0, bit-exact).

Report: SYNT_6-REPORT.md with commits, test results, and what was not verified in Logic.
Deferred to SYNT_7: the rest of ROUND4 (/workspace/tmp/synt_review/ROUND4.md on the bot's computer) and the old SYNT_6 list (MSEG, MPE, 2 filters, preset browser and so on).
