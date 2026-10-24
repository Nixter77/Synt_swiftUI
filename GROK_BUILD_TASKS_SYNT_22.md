# GROK_BUILD_TASKS_SYNT_22 (from SYNT_21 leftovers + ROUND18)

Rules: feat/auv3 only, nothing into main, no force-push. Golden 0xd1b3635203a4799e unchanged.
Every fix gets a named test that fails on the old code. Full suite green before each commit.
R18-2: every stage commit gets its own `build-for-testing` (or the skip is documented).
Restore the dump files before each commit. New features off by default; new AU addresses start at 167.
Render: no allocation, lock, exp/pow or ARC per sample.

## Stage 1: R18-1 (first)
Check the LFO `tablePtr`/`prevTablePtr` lifetime during the 5 ms fade after LRU eviction. Either defer the free
or extend the ack. Add a stress test: more than 16 tables, rapid publishes during a fade.

## Stage 2: wavetable perf
Move 32×5 toward ≤90% of RT. Add a budget assertion once met. Measure the 24×5 guidance (don't extrapolate).

## Stage 3: R14-4/9/10, if they fit

## Stage 4: R18-3 and R18-4
R18-3: lossy fxOrder (drop unknown IDs, append missing default slots).
R18-4: DEBUG-only log when a tolerant decode falls back.
Idle perf A/B if load ever drops under 2. Give the LiveStep4 assertion margin, or gate it on load.

Then: full suite, reinstall, pluginkit, auval, SYNT_22_REPORT.md, merge-base vs 1bb8a44.
Leftovers go to GROK_BUILD_TASKS_SYNT_23.md.
