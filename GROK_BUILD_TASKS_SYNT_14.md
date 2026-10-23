# GROK_BUILD_TASKS_SYNT_14

Base: `6ddb815` (feat/auv3). Review: ROUND11 (Resercher). 4 stages, one commit per stage, then SYNT_14_REPORT.md. PUSH after every green stage (normal `git push`).

## STRICTLY FORBIDDEN
- No force-push, rebase, reset, squash, amend of pushed commits, branch swaps. Do not rewrite history (leave the old `main` binary in 4ca7944 alone).
- Report MUST show `git merge-base --is-ancestor 6ddb815 HEAD` succeeding.
- Do not register plugins from DerivedData or ~/Applications. Do not touch the arpeggiator (SyntArpAUv3).
- `git restore GLASS_HORIZON_PROBE_DUMP.txt CHORD_HISS_MATRIX_DUMP.txt` before each commit.
- The report may mark an item "fixed" ONLY if a test proves it; name that test. (SYNT_13 report claimed R10-3 and R7-10 fixed; they were not.)

## Pipeline rules (unchanged)
- Golden hash 0xd1b3635203a4799e must not change; every new feature OFF by default (mpeEnabled=false keeps MIDI byte-identical).
- New preset fields: decodeIfPresent with defaults; new enum cases at the end.
- New AU addresses appended from 164; 0–163 never move.
- Render thread: no allocation, no locks, no per-sample exp/pow.
- Full test suite green after every stage: `xcodebuild -scheme Synt_swiftUI -derivedDataPath ~/.synt_dd test -destination 'platform=macOS'`.

## Stage 1 — Leftovers that were reported fixed but are not (R11-1/R10-3, R11-2, R11-11, R7-10)
- R11-1 (= R10-3): built-in wavetable cache keyed by index only. Key must include sample rate; rebuild on SR change. Test at 44.1/48/96 kHz for built-in AND user tables.
- R11-2: keep per-channel MPE state (bend, pressure, CC74) on all 16 channels; a note-on starts from the channel's current bend. Test: bend sent before note-on gives correct pitch from the very first sample.
- R11-11: when the event queue overflows, mpeKeyUp must keep its channel and never release notes on other channels. Test with a forced overflow.
- R7-10: LFO shape `.wavetable` is still a sine. Make it read the wavetable. Test that its output differs from a sine.

## Stage 2 — Robustness and safety (R11-3, R11-4, R11-5, R9-2)
- R11-5 (security): check the decompressed size limit BEFORE inflating zlib table data in presets (zip-bomb). Test with a crafted oversized payload: error, no big allocation.
- R11-3: one content hash for a table (no double compilation of raw vs compressed).
- R11-4: async table load must target the oscillator that requested it (no stale index); user table storage per AU instance, not static/shared.
- R9-2: tail fade when a send goes to zero and back: ~10–20 ms smooth fade (not 8 samples), no click. Test for no discontinuity above threshold.

## Stage 3 — MPE part 2: modulation sources and params
- Per-voice mod sources: MPE pitch bend, pressure, CC74 (timbre), available in the mod matrix. Smoothed, RT-safe.
- New AU params from 164: MPE bend range (default 48), zone (lower/upper), member channel count. Accept MPE config via RPN 0 (bend range) and RPN 6 (MCM).
- All off by default; with mpeEnabled=false nothing changes (golden).
- Tests: pressure on note A modulates only voice A; RPN 0 changes bend range; RPN 6 sets the zone.

## Stage 4 — MPE UI and presets
- UI: MPE on/off, bend range, zone, and the three sources selectable in the mod matrix.
- Presets: save/load MPE settings (decodeIfPresent); 2 factory MPE presets (one pressure → filter, one CC74 → wavetable position).
- Tests: preset round-trip; old presets load with MPE off.

## Deferred to SYNT_15
- Per-sample retain/release in generateSample (ARC overhead, ~1.4M/s): pass unowned pointers inside the render block.
- ROUND11 minor items R11-6..R11-13.
- Arpeggiator (deferred by nixter).

## Report (SYNT_14_REPORT.md)
Commits per stage, test counts, golden hash, ancestor check output, new AU addresses, and for every fixed item the test that proves it; anything not done and why.
