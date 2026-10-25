# GROK_BUILD_TASKS_SYNT_28

1. CR caveat: mid-single-publish window (new preset + old mod matrix visible together). Put a publication epoch inside the snapshot and have render take preset/MSEG/matrix only when epochs match; test that fails on old code.
2. Audit item 6: `suppressParameterObserver` — review thread/ordering, make it race-free (scoped/atomic), test.
3. Release-config perf A/B: make perf suites (or a dedicated perf test target) build in Release (gate DEBUG hooks behind `#if DEBUG` in tests), then A/B b866d86 vs HEAD in Release, coverage off, load < 2 if possible.
4. Remaining Swift 6 warnings (test-only Sendable captures, @MainActor parameterised @Test, @preconcurrency imports) + cleanup of ~75 redundant `public` modifiers and never-mutated vars; then try SWIFT_STRICT_CONCURRENCY=complete on SynthCore.
