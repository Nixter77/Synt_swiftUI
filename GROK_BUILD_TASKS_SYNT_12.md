# GROK_BUILD_TASKS_SYNT_12

Repo: /Users/nikolay/gemini_projekts/Synt_swiftUI, branch `feat/auv3`. Base: `823e70c` (SYNT_11).
Review source: /workspace/tmp/synt_review/ROUND9.md (Resercher). One commit per stage. Don't touch main.

## STRICTLY FORBIDDEN (violated in SYNT_11)
- `git push --force` / `--force-with-lease`, `git rebase`, `git reset --hard` on pushed commits, cherry-picking onto a new branch with a branch substitution, squashing history. Only ordinary commits on top of `823e70c` and an ordinary `git push`. If something goes wrong, stop and describe it in the report.
- Don't register the plugin from DerivedData or from `~/Applications`. For auval, Logic uses only `/Applications/Synt_swiftUI.app` (it gets installed during the check). After auval from DerivedData, run `pluginkit -r` on that appex.
- Don't touch the arpeggiator (SyntArpAUv3). It's deferred.

## Mandatory rules
- Render: no allocations, locks, ARC (including Swift arrays as render-function parameters), or `exp/pow/sin` per sample where a table or a per-block coefficient would do. All tables are created in init/prepare.
- Golden hashes (`0xd1b3635203a4799e`, InitGoldenTests) don't change. Everything new is OFF by default and bit-exact.
- New preset fields use `decodeIfPresent`. New enum cases go at the end. New AU parameters get addresses from 153 onward, with defaults inside [min,max]. Check AddressedParameterStore capacity and AUParameterRangeTests.
- No Theme in core. AU sizing only on the main thread. LayoutTests must pass. `git restore GLASS_HORIZON_PROBE_DUMP.txt` before committing.
- After each stage, `xcodebuild -scheme Synt_swiftUI -derivedDataPath ~/.synt_dd test` must be green.

## Stage 1. ROUND9 fixes
- R9-1: the sine table in DSPRotary.swift:15 is lazy and gets created on render. Create it in init/prepare.
- R9-2: with send=0 the reverb/delay tail gets cut off and the buffer isn't cleared (AudioEngine+Render.swift:1261-1277). Either let the tail fade out, or clear the state when it drops to 0 so the old tail doesn't sound when the level goes back up. Add a test.
- R9-3: `snapSpeeds` in AudioEngine+Preset.swift:326 cuts off the Leslie spin-up on any preset apply. Snap only when the preset is actually loaded, not on every apply.
- R9-4: Send B Delay Time/Feedback don't respond to automation/CC. Wire them up the same way as the R6-2 fix.
- R9-5: a pre/post-insert switch for the send (default = current behaviour); the return goes through headroom/the limiter.
- R9-6: the remaining race in MSEG's three banks. R9-7: remove the Swift array from the render parameters. R9-8: `rotaryFast` should be discrete in the model (0/1), the same as in the AU.
- R8-4 leftovers: reset the global highlighting after routes are removed. R7-10: start phase/wavetable in the right channel the same as the left.

## Stage 2. Seed in the preset + macros 5–8
- `randomSeed` in the preset (decodeIfPresent). If it's set, random phase/S&H/random LFO are reproducible from note to note on load. If it's missing, behaviour is the same as before.
- Macros 5–8 (AU addresses at the end, default 0, no destinations), shown in the modulation matrix and the UI.

## Stage 3. Transient shaper
- Attack/Sustain (±), output, mix, in the FX chain next to the existing effects (not a 7th FXSlotID, the same way as rotary). Off = bit-exact. Envelopes with coefficients per block. Tests for NaN/denormals and bit-exactness.

## Stage 4. Sample → wavetable
- Import a WAV/AIFF (on the main thread, outside render): split into N frames (default 64 × 2048), normalise, build mipmap tables, and swap them into the engine through the existing lock-free handoff.
- Store it in the preset as a reference + embedded data (or a hash plus a copy in Application Support; choose and describe). Without an imported table, everything is the same as before.
- UI: an "Import…" button in the wavetable section, with a preview of the frames.
- Tests: import a test file → the number of frames and normalisation are correct; there's no import in render.

## Deferred to SYNT_13
MPE (a big job, 1.5–3 weeks; split it into parts).

## Finish
`SYNT_12_REPORT.md`: commits, tests, `auval -v aumu Synt Nixr` against `/Applications`, confirmation that the history wasn't rewritten (`git merge-base --is-ancestor 823e70c HEAD` = 0).
