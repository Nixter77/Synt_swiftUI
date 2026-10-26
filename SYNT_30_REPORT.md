# SYNT_30 report

Factory, showcase, library, stage 8, MPE, and expansion preset bodies now use the current engine (filter 2, formant vowel, MSEG, dedicated filter ADSR / Env 2, wavetable morph, FM, hard sync, FX order, rotary, frequency shifter, transient, trance gate, macros). Init is unchanged: golden hash `0xd1b3635203a4799e`.

## What landed

- Stage 1 (`906fc20`): coverage test and authoring policy. The coverage test was red on purpose.
- Stage 2 (`2bc560a`): legacy, showcase, library, stage 8, and MPE bodies. Factory stays 103 presets. Golden hashes recaptured for those factory names only.
- Stage 3 (`0e1ff94`): expansion stays a second bank of 50. `FactoryFXPresets` adds rotary, frequency shifter, transient, trance gate, and FX-order snapshots (4 each). EQ names stay `EQPreset.allCases`. New `FXKind` cases are appended.

`lfoRowsFollowDepth` stays true only on Analog Drift and Tremolo Strings. Glass Horizon keeps the phaser off (`phaserMode` still `.phaser2`).

Factory chord-safety tests still cap unison at 2, wavetable morph at 0.42, and wet stacks at two sends. Fat Unison Bass is 2 voices. Section Soft, String Machine, and Synth Brass Pad are single-voice. Whistle Lead and Pulse Sweep Pad morph at 0.42. Phase Cathedral keeps the phaser and drops chorus, so reverb plus phaser is the wet stack.

## Verification

Full `Synt_swiftUITests` on macOS: 776 tests, 769 passed, 6 skipped, 1 expected failure (the chord-hiss wet-stack note), 0 failed. Init golden hash stays `0xd1b3635203a4799e`.

## Smoke note

These patches are the ones to open if you want to hear the new paths. The bar in CI is finite, non-silent audio for at least one second, plus the wired fields below. This note is not a listening session.

1. Serial Glass Bass — filter 2 in series after the low-pass.
2. Breathing Glass — filter 2 in parallel, LFO 2 on amplitude.
3. Air Choir — formant filter with an LFO on the vowel.
4. Vowel Ah Lead — formant vowel, stage 8 suffix of the library.
5. MSEG Drift — three-point MSEG into pitch.
6. Wind Gust — MSEG 2 into cutoff.
7. Velvet Acid — Env 2 into cutoff on a mono bass.
8. Wavetable Growl — wavetable plus a saw, macro 1 into cutoff.
9. Deep House Organ Chord — rotary speaker on the expansion bank.
10. Trance Gate Runner — sixteenth trance gate with the arp on.
11. MPE Expressive Pad — MPE pressure into cutoff, filter 2 in parallel.

## Left out

No SYNT_31 task file. Browser polish, extra banks, and hash-dump tooling were not required once the banks and the FX snapshots matched the engine.
