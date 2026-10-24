# SYNT_23 tasks (carried over from SYNT_22)
1. **R14-9:** a stale `fullState` snapshot is read off the main thread. Make the snapshot atomic or main-only, and add a test that fails on the old code.
2. **R14-10:** `applyPreset` re-entrancy and a main-thread precondition. Add a test that fails on the old code.
3. Idle perf A/B (load < 2): wavetable 32×5 and 24×5, plus classic, before and after SYNT_22 Stage 2.
4. Optional: remaining wavetable hot spots, i.e. `pullNewWavetableRT` per call and frame-index math.
5. Rules are unchanged from SYNT_22: golden 0xd1b3635203a4799e, no main, no force-push, a test per fix that fails on the old code, and run `git restore` on the dump files before each commit.
