# GROK_BUILD_TASKS_SYNT_11

Repo: /Users/nikolay/gemini_projekts/Synt_swiftUI, branch `feat/auv3`. Base: `9fd54c5` (SYNT_10 + CodeReviewer test fix).
Review source: /workspace/tmp/synt_review/ROUND8.md (Resercher). One commit per stage. Don't touch main.

## Mandatory rules (same as before)
- Render thread: no allocations, locks, ARC, or `exp()`/`pow()` on every sample where a table or a per-block calculation would do.
- Golden hashes (`0xd1b3635203a4799e`, InitGoldenTests) must not change. Every new feature is OFF by default and bit-exact when it's off.
- New preset fields use `decodeIfPresent`. New enum cases go at the END. New AU parameters get new addresses appended at the end, with defaults inside [min,max]. Check AddressedParameterStore capacity (256) and AUParameterRangeTests.
- No Theme in core. AU sizing and hosting-view work only on the main thread. LayoutTests must pass.
- Before committing: `git restore GLASS_HORIZON_PROBE_DUMP.txt`.
- After each stage: `xcodebuild -scheme Synt_swiftUI -derivedDataPath ~/.synt_dd test` must be green (except the known environment-related UI-automation timeout).

## Stage 1. ROUND8 fixes
- R8-1: double LFO1 on amplitude when LFO2's stereo phase ≠ 0 (AudioEngine+Render.swift ~902-907 and ~1066-1075). Apply LFO1 exactly once. Add a test.
- R8-2: MSEG publish spins `sched_yield` up to 1000 times on the main thread, and tick doesn't run without MSEG or while stopped. Replace it with a non-blocking handoff (double buffer/atomic index, the latest version wins, no waiting). Add a test: loading a preset when MSEG is off or the engine is stopped doesn't block.
- R8-3: `LiveModulationSnapshot.shared` is one per process. Make it per engine/AU instance.
- R8-4: modulation highlighting comes only from voice 0 and isn't reset. Use the max or latest active voice, and reset when there are no voices.
- R8-5: torn scope frame. Publish whole frames only.
- R8-6: `OscPhaseMode.random` changed its meaning. Restore the old behaviour and add a separate case `.randomPerNote` AT THE END of the enum. Old presets must sound the same as before.
- R8-7: `exp()` per sample in DSPCharacterTone.swift:54. Compute the coefficient per block or when the parameter changes.
- R7-10 leftovers: start phase / wavetable in the right channel should match the left.

## Stage 2. Send/parallel FX bus
- Two send buses (Send A: reverb, Send B: delay) with per-scene send levels. The existing insert chain stays as it is. Default send = 0, so the output is bit-exact.
- AU parameters with new addresses at the end. Fields in the preset. Knobs in the FX panel.
- Tests: send=0 → hash unchanged; send>0 → signal on the bus; no allocations in render.

## Stage 3. Rotary (Leslie)
- Rotary effect in the FX chain: horn/drum with separate speeds, slow/fast with acceleration, drive, mix. Off by default.
- Speed switch available as an AU parameter (for automation in Logic).
- Tests: off = bit-exact; with no NaN/denormals; stereo separation when enabled.

## Stage 4. Arpeggiator as AUv3 MIDI FX: prototype only
- New target `SyntArpAUv3` of type `aumi` (manufacturer Nixr), with no changes to the main synth.
- Minimum: up/down/up-down/random, rate 1/4..1/32 synced to host tempo, gate, octaves 1-4, hold.
- MIDI output via `MIDIOutputEventBlock`. Check `auval -v aumi <subtype> Nixr`.
- Write a short note in the SYNT_11 report on whether Logic 11.0.1 (Intel) sees the plugin under MIDI FX and whether notes reach the Synt instrument. If MIDI output doesn't work in Logic, describe it honestly and don't build anything on top of it.

## Deferred to SYNT_12
MPE; seed random in the preset; sample → wavetable; transient shaper.

## Finish
A short report `SYNT_11_REPORT.md`: commits, tests (passed/failed), auval for aumu and aumi, what didn't work.
