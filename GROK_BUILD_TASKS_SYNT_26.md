# GROK_BUILD_TASKS_SYNT_26 (leftovers from SYNT_25)
1. Idle perf A/B b866d86 vs HEAD, ≥5 alternations at load < 2 (never idle in SYNT_24/25); include hot-spot gain.
2. Optional R20-4: immortal wavetable shapes impossible to free by design.
3. Optional: Swift 6 warnings surfaced by @MainActor migration (non-Sendable closures crossing isolation in parameterized tests, MIDIPerformanceTests.golden autoclosure).
Rules unchanged (golden pinned, no main, no force-push, fail-on-old test per fix, full suite per commit, restore dump files, RT-safe render).

## SYNT_26 plan (after ROUND22 + NIGHTLY_AUDIT_SYNT25 + CodeReviewer eabdaee..c3d9dd6)
R22-1 closed by CR in 0aa9cdb (init exempt + Stage26AuditTests off-main construction test) — verify only.
1. Verify CR counts (full suite).
2. Idle A/B b866d86 vs HEAD ≥5 alternations at load < 2; else interleaved A/B at current load, median delta; check frameSplit inlined.
3. R22-3 renderHash `@MainActor` (drop nonisolated) / R22-4 seeded RNG in R21-2 test / R22-2 label strict test as config pin.
4. Optional: Swift 6 warnings, R20-4.
