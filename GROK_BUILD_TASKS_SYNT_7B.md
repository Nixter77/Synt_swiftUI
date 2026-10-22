# GROK_BUILD_TASKS_SYNT_7B (parallel track, must not get in the way of SYNT_7)

Another model works on SYNT_7 in the main folder at the same time. To avoid conflicts:
- Work ONLY in a separate worktree and branch:
  `git worktree add ../Synt_swiftUI_7b -b feat/synt7b-dsp eb69415`
  and do not touch the folder /Users/nikolay/gemini_projekts/Synt_swiftUI itself.
- Create ONLY NEW files: SynthCore/DSP/Experimental/* and Synt_swiftUITests/Experimental/*. Do not edit existing files (including AudioEngine*, SynthPreset*, the mod matrix, UI and .pbxproj), except adding new files to the targets. If you cannot avoid touching .pbxproj, only add the new files to the targets in one commit.
- Do not wire anything into render or presets: the modules stay standalone, so golden hashes cannot change.
- Use your own DerivedData: `-derivedDataPath ~/.synt_dd_7b`. Do NOT install into /Applications.
- Do not merge into feat/auv3 or main; one commit per stage, push the branch.
- DSP rules: no allocations, locks or ARC in process(); buffers are allocated in prepare(sampleRate:maxFrames:).

## Stage 1: Formant filter
DSPFormantFilter: vowels A/E/I/O/U with smooth morphing (0…4), Q, resonance; parallel bandpass filters on formant tables.
Tests: a formant peak in the spectrum, stable at all morph values, finite output with white noise for 10 s.

## Stage 2: MSEG engine
DSPMSEG: up to 32 points, curve per segment, loop/sustain point, sync to a beat or Hz, one-shot/retrigger. Pure model plus a render-safe tick(). Codable model with decodeIfPresent-compatible fields.
Tests: interpolation, loop, sustain, phase after retrigger.

## Stage 3: Second filter (standalone module)
DSPDualFilter: two filters (LP/HP/BP/Notch) in serial/parallel with balance; reuses the existing filter API only through a new wrapper, without editing it.
Tests: frequency response for serial vs parallel, stability.

Report: SYNT_7B-REPORT.md in the worktree: commits, tests, and an API description so that SYNT_8 can wire these modules into the synth.
