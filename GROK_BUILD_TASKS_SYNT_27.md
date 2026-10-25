# GROK_BUILD_TASKS_SYNT_27

1. Swift 6 language-mode warnings: inventory and fix (concurrency/Sendable), no behaviour change; suite green.
2. R20-4 immortal shapes: make static shape tables immortal / no ARC on render path; test that fails on old code (allocation/retain counter or symbol check).
3. Re-run idle A/B at load < 2 (SYNT_26 was 3.3-4.8 post-reboot) to confirm -45%/-39% gains; add Release-config A/B.
4. Coverage instrumentation is on in Debug test builds (__profc symbols); consider perf runs with coverage off and document the config.
