# GROK_BUILD_TASKS_SYNT_9

Base: the result of SYNT_8 on feat/auv3. Do not merge into main. Rules are the same as in SYNT_8 (RT safety, golden hashes unchanged, default-off, decodeIfPresent, enum cases at the end, main thread for UI/AU sizing, LayoutTests, restore GLASS_HORIZON_PROBE_DUMP.txt, one commit per stage).
Source: /workspace/tmp/synt_review/ROUND6.md on the bot's computer (line numbers as of 896ef85, check them after SYNT_8).

## Stage 1: SYNT_7 fixes
- R6-2: Render.swift:1535-1536. .reverbMix/.reverbRoomSize must reach the DSP reverb right away (automation and knobs in AUv3).
- R6-3: Render.swift:178-190. Trance gate locks to the host only while the transport is playing; when stopped, it runs on its own clock (notes from the keyboard are not muted).
- R6-4: standalone. With the DSP reverb on, bypass the Apple reverb (no double reverb).
- R6-5: standalone. Reallocate the reverb buffer when the audio device changes only with render stopped / through a safe swap (no use-after-free).
- R6-6: Render.swift:664,683. Fixed OSC2 and FM ratio: pick a clear priority and show it in the UI, no silent ignoring.
- R6-7: MIDICCLearnStore.swift:85. MIDI learn for Fine Pitch maps to the right parameter.
- R6-8: Render.swift:976-982,1051-1052. Modulation of Chorus/Delay Mix must not write into the main-thread field (a separate modulated value).
- Tests for each one.

## Stage 2: Envelopes and modulation
- ADSR curves (curve per segment). With curve=0 the old code stays word for word (golden).
- Envelope follower as a mod-matrix source (default off).
- Stereo modulation (L/R phase offset for LFOs), default 0.

## Stage 3: Sound
- Frequency shifter in FX (default off).
- Comb/Resonator as a filter type or FX (enum case at the end).
- Character Warm/Bright (a gentle tone curve on the output, Off by default).

## Stage 4: UI
- Modulation highlighting on knobs (rings with the modulation amount).
- Preset browser with search and tags (UI only, presets are not changed).

Report: SYNT_9-REPORT.md. Deferred: MIDI output from arp/sequencer (check Logic support first).
