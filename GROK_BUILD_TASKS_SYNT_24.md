# SYNT_24 tasks (ROUND20 + SYNT_23 carry-over), branch feat/auv3
Stages:
1. **Idle perf A/B.** If load drops below 2, run b866d86 vs HEAD, alternating at least 5 times. If it never does, record that and continue.
2. **Wavetable hot spots:** `pullNewWavetableRT` per call and the frame-index math. Golden must stay unchanged.
3. **R20-1:** add a generation counter to the fullState mirror, with a test that fails on the old code.
4. **R20-2/3 and optional items:**
   - R20-2: a Debug assert and counter when the applyPreset cap is hit.
   - R20-3: a Debug main-thread check, and test counters under `#if DEBUG`.
   - Optional R19-5: cap the TolerantDecodeLog.
   - Optional R20-4: make freeing an immortal shape impossible by design.

Rules (unchanged):
- Golden hash 0xd1b3635203a4799e unchanged.
- Nothing into main; no force-push.
- One test per fix that fails on the old code, or state why that is impossible.
- Build and test each commit on its own, or say so explicitly.
- Run `git restore` on the dump files before each commit.
- Counts given as total / passed / skipped / xfail / runs.
