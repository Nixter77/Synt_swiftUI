# GROK_BUILD_TASKS_SYNT_7

Base: eb69415 on branch feat/auv3. Do not merge into main.
Rules: no allocations, locks or ARC on the render thread; golden hashes (0xd1b3635203a4799e and InitGoldenTests) must not change, so every new feature defaults to OFF and is bit-exact when off; new preset fields use decodeIfPresent; new enum cases go at the end; no Theme in core; AU sizing and hosting-view work only on the main thread (see eb69415); run `git restore GLASS_HORIZON_PROBE_DUMP.txt` before each commit; one commit per stage, tests green.
Source: ROUND5 review by Resercher (bug lines as of eb69415).

## Stage 1: SYNT_6 bugs
- B1 (high): AudioEngine+Render.swift:775-776. Filter feedback in the biquad branch without drive is unbounded; add soft clipping (tanh or an equivalent) inside the loop, and keep fb within the sanitize range (SynthPreset+Sanitize.swift:190).
- B2: NaN/Inf check of the feedback state BEFORE writing it (:778), not after (:813); on NaN reset the state, do not mute the voice.
- B3: Trance gate locked to the host bar/beat (musicalContext/transportState), correct after locate and loop (Render.swift:175-187).
- B4: DSPStereoTool.swift:51-58. Clear or crossfade the Haas buffer when the delay goes up from 0.
- B5: RTModMatrix.swift:86. Linear interpolation of the remap curve.
- Tests for each one: feedback=1 with high resonance stays finite for 10 s; gate phase after a jump in the host position; no clicks from Haas.

## Stage 2: Reverb in AUv3
Problem: in the plugin the .reverb slot only does shimmer; Mix/Room do nothing in Logic (AVAudioUnitReverb is only in standalone).
- Own RT-safe reverb in the DSP (FDN or Freeverb-like, buffers allocated in allocateRenderResources), with Mix/Room/Damping; shimmer stays.
- Behind a new flag that is off by default, so that hashes of presets with reverbMix>0 do not change; turn it on for new presets / Init via an explicit migration only if the golden tests stay unchanged.
- Test: Mix>0 in AUv3 render gives a tail after note-off.

## Stage 3: Sound
- Fixed frequency for OSC2 (Hz mode, default off).
- Scene HPF (a high-pass before the FX, default off).
- Ensemble mode for the chorus (enum case at the end).

## Stage 4: Modulation and control
- Raise the number of mod-matrix destinations (now 13): FM, fine pitch, pan, FX parameters.
- FM: ratio (coarse/fine) and route (OSC2→OSC1 / OSC1→OSC2).
- XY pad in the UI, assigned to macros (UI only, nothing on the RT thread).

Report: SYNT_7-REPORT.md with commits, tests, and what was not verified in Logic.
Deferred to SYNT_8: formant filter and the rest of ROUND5 (/workspace/tmp/synt_review/ROUND5.md on the bot's computer).
