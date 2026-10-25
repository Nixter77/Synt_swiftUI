# GROK_BUILD_TASKS_SYNT_26 (leftovers from SYNT_25)
1. Idle perf A/B b866d86 vs HEAD, ≥5 alternations at load < 2 (never idle in SYNT_24/25); include hot-spot gain.
2. Optional R20-4: immortal wavetable shapes impossible to free by design.
3. Optional: Swift 6 warnings surfaced by @MainActor migration (non-Sendable closures crossing isolation in parameterized tests, MIDIPerformanceTests.golden autoclosure).
Rules unchanged (golden pinned, no main, no force-push, fail-on-old test per fix, full suite per commit, restore dump files, RT-safe render).
