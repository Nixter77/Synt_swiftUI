# SYNT_23 tasks (ROUND19 + SYNT_22 carry-over), branch feat/auv3
Stages:
1. **R14-9:** a stale `fullState` snapshot is read off the main thread. Make the snapshot lock-protected, and add a test that fails on the old code.
2. **R14-10:** `applyPreset` re-entrancy (coalesce nested calls) and a DEBUG off-main check. Add a test that fails on the old code.
3. **R19-1:** make the `Oscillator.wavetableEngine` setter internal and document it.
   - **R19-2:** add a deterministic "shapes never freed" guard (DEBUG registry plus an assert in deinit).
   - **R19-3:** make shape interning NaN-safe (bit-pattern key).
4. Optional:
   - idle A/B if load drops below 2;
   - wavetable hot spots (`pullNewWavetableRT` per call, frame-index math).

Rules (unchanged):
- Golden hash 0xd1b3635203a4799e unchanged.
- Nothing into main; no force-push.
- One test per fix that fails on the old code, or an explicit guard rationale.
- Full suite before each commit.
- Run `git restore` on the dump files before each commit.
- New features off by default.
- Counts given as total / passed / skipped / xfail / runs.
