# GROK_BUILD_TASKS_SYNT_20 (feat/auv3, base 35a6e5f; ROUND16 + NIGHTLY_AUDIT_SYNT19)

Rules unchanged from SYNT_19: golden hash unchanged; nothing into main; no force-push; every fix has a named test
that fails on old code; full suite green before each commit; restore the dump files before each commit; new
features off by default; decodeIfPresent; AU addresses from 167; render: no alloc/lock/exp/pow/ARC per sample;
counts as tests AND runs; old tests not weakened.

0. Pull 42b418c..35a6e5f and verify the claimed counts (729 passed) with the full suite.
1. Clean perf A/B (ROUND16 §3): b866d86 vs HEAD, alternating, 5 each, load < 2 (wait for idle), median + min.
2. UI tests: attempt; if testmanagerd fails, record it.
3. Low items where safe: R16-5 (LFO fade restart from the current mixed output), R16-6 (stale mailbox after reset),
   R16-8 (document/limit CC101=0 swallow), audit P3-9 (tolerant enum decoding), P3-10 (test hooks under #if DEBUG),
   P3-11 (document the SysEx/>3-byte drop).
4. If time: R15-6/7 compile-cache eviction (safe after R16-1).
Then: full suite, reinstall, pluginkit, auval, SYNT_20_REPORT.md, merge-base check vs 35a6e5f.
