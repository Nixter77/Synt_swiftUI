# GROK_BUILD_TASKS_SYNT_29

(Old SYNT_28 items 1–2 were done by CodeReviewer in 4f14bab/b9ba7d2; items 3–4 were done in SYNT_28.)

1. Strict concurrency, part 1: make the static factory tables (FactoryPresets*, FactoryFXPresets, WavetableOscillator basic tables) concurrency-safe: Sendable types, or `nonisolated(unsafe)` with a justification. 57 of the 68 `complete` warnings.
2. Strict concurrency, part 2: the remaining 11 (8 `static var` globals, sending/captures in SyntAudioUnit, AudioEngine, MIDICCLearnStore, PresetManager); then set `SWIFT_STRICT_CONCURRENCY=complete` on SynthCore, suite green.
3. Release perf: a re-runnable perf path (script or test plan with Release + ENABLE_TESTABILITY + coverage off), and an idle (load < 2) Release A/B to confirm the ~−30% interleaved result; review the 90% wavetable gate margin in Release.
4. Optional P3s from the SYNT_27 audit; wavetable is still outside the gated preset set. pluginkit prefers the DerivedData path over /Applications: unregister stale paths.
