# SYNT_20 Report (feat/auv3)

## Pull of CodeReviewer fixes (42b418c..35a6e5f)
Fast-forward OK. Suite at 8e5bac2: 731 tests, **726 passed**, 831 runs, 0 failed, 4 skipped — not the claimed 729 passed.

## Stage 1 — perf A/B (b866d86 = A, 2bbc5d4-base 8e5bac2 = B), alternating, 5 runs each
Load never dropped below 2 (1-min load 2.41–4.79 before runs; run 1 waited 900 s cap, runs 2–5 120 s cap).
**Not a clean measurement**; all runs reported, none discarded (all would be).

| % of RT budget | A median | A min | B median | B min |
|---|---|---|---|---|
| Block render (after) | 73.22 | 72.38 | 74.36 | 72.85 |
| Per-sample render (before) | 75.76 | 75.41 | 77.06 | 76.28 |

B only: SYNT18 classic 32v×5 median 72.58 / min 69.00; wavetable median 101.85 / min 101.23.
Min difference block render +0.5 % (within noise). All 10 runs exit 0 (LiveStep4 passed in all).

## Stage 2 — UI tests
Passed: 4 tests, 0 failures (testmanagerd worked this time).

## Stage 3 — 2bbc5d4
- R16-5: switch during a running LFO shape fade starts from the current mixed output (decaying offset); first switch identical to before (golden unchanged). Fade finished instantly outside wavetable mode.
- R16-6: reset sets `mpeResetAwaitingAck`; main ignores mailbox entries until render's sticky reset-ack bit (1<<43).
- R16-8: documented (only ch1/ch16 reach that path; CC101=0 ambiguous there).
- P3-9: unknown MPEZone decodes to .lower (ModSource tolerant decode deferred: needs lossy array decoding; stateVersion not bumped).
- P3-10: test hooks under #if DEBUG. P3-11: SysEx / >3-byte MIDI drop documented.
Tests: Stage20Stage3Tests (3), Stage20AuditP3Tests (1); all 4 fail with the SynthCore changes stashed.

## Stage 4 — R15-6/7: not done (time).

## Final
Full suite: 735 tests, 730 passed, 835 runs, 0 failed, 4 skipped. Release reinstalled; auval: AU VALIDATION SUCCEEDED.
