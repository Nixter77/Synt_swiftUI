# GROK_BUILD_TASKS_SYNT_19 (feat/auv3, base 41b0849, review ROUND16)

Rules (unchanged): golden 0xd1b3635203a4799e unchanged; nothing into main; no force-push; every fix has a named
test that fails on the old code; full suite green before each commit; `git restore GLASS_HORIZON_PROBE_DUMP.txt
CHORD_HISS_MATRIX_DUMP.txt` before commit; new features off by default; new preset fields decodeIfPresent; new AU
addresses from 167; render thread: no alloc/lock/exp/pow/ARC per sample; counts reported as tests AND runs;
old tests not weakened.

## Stage 1 — R16-3 clean perf A/B (ROUND16 §3)
Wait for load < 2 (quit Safari etc.). Worktrees b866d86 (A) and 41b0849 (B), separate DerivedData, same config.
Run LiveStep4PerfBenchmarks + RenderBudgetTests (+ Stage18WavetablePerfBenchmarks on B) alternately A,B ≥5 each,
serial, SYNT_RUN_PERF=1; record uptime before/after; drop runs with load > 2; report median + min.
If the machine never gets idle: record it and continue.

## Stage 2 — R16-1 render ack before releasing retired user tables
Render publishes the view it uses (atomic `rtViewInUse` ack word). Main keeps a retire list and releases a
retired table only when render's ack no longer references it (drained on main). Tests: unowned table + several
swaps before drain → no deinit while render may still read it; deinit after ack, on main.

## Stage 3 — R16-2 + R16-4
`syncFromRenderMain()` at the start of `setSampleRate` and in the AU 0.1 s main timer. Test: render switch → SR
change → correct table plays. R16-4: behavioural R15-1 deinit test (no other owner; freed only on main after sync).

## Stage 4 — R15-8 in the AU view (if feasible) + UI tests
Show the controller-MPE override summary + "Reset to My Settings" in the AU view. Try running UI tests.

Then: full suite, reinstall, pluginkit, auval, SYNT_19_REPORT.md, merge-base check vs 41b0849.
