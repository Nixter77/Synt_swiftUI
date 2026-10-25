# GROK_BUILD_TASKS_SYNT_25 (leftovers from SYNT_24)

1. Idle perf A/B b866d86 vs HEAD (≥5 alternations) when load < 2 — never idle during SYNT_24.
2. R20-4 (optional): make freeing an immortal wavetable shape impossible by design (e.g. no deinit path / unmanaged storage) instead of the DEBUG deinit assert.
3. R20-3 follow-up: migrate tests that call applyPreset off-main (non-@MainActor Swift Testing suites, ~600 tests) to @MainActor, then turn `AudioEngine.strictMainThreadApplyPreset` on by default in DEBUG.
4. Optional: re-measure Stage 2 hot-spot gain on an idle machine.

Rules unchanged: golden 0xd1b3635203a4799e, nothing into main, no force-push, fail-on-old test per fix, full suite before each commit, restore dump files, new features off by default, decodeIfPresent, AU addresses from 167, RT-safe render.
