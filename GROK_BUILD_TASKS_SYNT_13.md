# GROK_BUILD_TASKS_SYNT_13

Base: `fff87e8` (feat/auv3). Review: ROUND10 (Resercher). 4 stages, one commit per stage, then SYNT_13_REPORT.md.

## STRICTLY FORBIDDEN
- No force-push, rebase, reset, squash, amend of pushed commits, branch swaps. Normal `git push` only.
- Report MUST show `git merge-base --is-ancestor fff87e8 HEAD` succeeding.
- Do not register plugins from DerivedData or ~/Applications. Do not touch the arpeggiator (SyntArpAUv3).
- Do not commit build binaries or dump files: `git restore GLASS_HORIZON_PROBE_DUMP.txt CHORD_HISS_MATRIX_DUMP.txt` before each commit. Remove the `main` binary committed in 4ca7944 (git rm, add to .gitignore).

## Pipeline rules (unchanged)
- Golden hash 0xd1b3635203a4799e must not change; every new feature OFF by default.
- New preset fields: decodeIfPresent with defaults; new enum cases at the end.
- New AU addresses appended after 162 (next free: 163); 0–162 never move.
- Render thread: no allocation, no locks, no per-sample exp/pow.
- Full test suite green after every stage: `xcodebuild -scheme Synt_swiftUI -derivedDataPath ~/.synt_dd test -destination 'platform=macOS'`.

## Stage 1 — Wavetable thread safety and UI lag (R10-2, R10-1)
- R10-2: `loadCompiledWavetable` must not swap `mipMaps` from main while render reads. Hand `CompiledMipData` to render via a lock-free pointer swap (triple buffer / atomic slot like R9-6); render picks it up at block start; old data released off the render thread.
- R10-1: `applyPreset` with a user table must not rebuild it on every knob move. Cache compiled data by content hash; rebuild only when the table data changes, always off main and off render.
- Tests: concurrent load-while-render stress (TSan-clean), applyPreset knob sweep triggers zero rebuilds.

## Stage 2 — Correctness (R10-3, R10-4, R7-10)
- R10-3: wavetable cache key must include sample rate; rebuild mips on SR change. Single shared formula for maxHarmonics (remove the duplicate; `compile()` and the oscillator use one function); remove the `= []` default.
- R10-4: seed applied only on the render path; remove the main-thread copy so editing a knob does not reset S&H.
- R7-10: right-channel phase fix (see ROUND7/ROUND10).
- Tests: maxHarmonics correct at 44.1/48/96 kHz; S&H unchanged after a knob edit; R7-10 phase test.

## Stage 3 — Sample import robustness and send tail (R9-2 rest, R10-5..10)
- Import: DC removal, zero-crossing search / crossfade at the loop seam (no click), downmix >2 channels, reject/clean NaN/Inf in float files, guard >2^32 frames.
- R9-2: when a send is turned to zero and back, fade the old tail out smoothly instead of cutting it; no large buffer zeroing on render (do it off-thread or incrementally).
- R10-5: widen seed space (no 256-value collapse); seed must not leak into the next patch.
- R10-9: cap or compress table data in presets (document the limit).
- Tests for each item.

## Stage 4 — MPE, part 1 (input only, OFF by default)
- Parse MPE: per-channel note-on/off, per-note pitch bend, channel pressure, CC74 on member channels; MPE zone config (lower zone, member channels 2–16), pitch-bend range per zone (default 48 semitones).
- Route per-note pitch bend to the owning voice only. Pressure and CC74 are parsed and stored per voice but NOT yet wired to modulation (that is SYNT_14).
- New AU param "mpeEnabled" (address 163, default off). With it off, MIDI behaviour and golden are byte-identical.
- Tests: two simultaneous notes with different bends; bend on note A does not move note B; mpeEnabled=off unchanged golden.

## Deferred to SYNT_14
- MPE part 2: pressure/CC74 as mod sources, UI, presets.
- Arpeggiator (deferred by nixter).

## Report (SYNT_13_REPORT.md)
Commits per stage, test counts, golden hash, ancestor check output, list of new AU addresses, anything not done and why.
