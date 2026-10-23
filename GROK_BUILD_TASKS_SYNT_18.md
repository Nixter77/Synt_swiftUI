# GROK_BUILD_TASKS_SYNT_18 (from ROUND15)

Branch `feat/auv3`, base `b866d86`. Normal push after each green stage; no force-push, no merge into main.

## Rules
- Golden hash `0xd1b3635203a4799e` must stay bit-identical. New features off by default. New preset fields use `decodeIfPresent`. New AU addresses start at 167.
- Render thread: no allocation, lock, exp/pow or ARC per sample.
- An item counts as fixed only with a named test that fails on old code.
- Whole suite green before each commit; old tests are not weakened (any change is explained in the report).
- `git restore GLASS_HORIZON_PROBE_DUMP.txt CHORD_HISS_MATRIX_DUMP.txt` before every commit.
- Report counts as distinct tests AND runs. Try UI tests; if the screen is locked, say so.
- Perf runs serially with `SYNT_RUN_PERF=1`, each suite on its own, `-parallel-testing-enabled NO`.

## Stage 1: R15-2 (generateSample without ARC and per-sample log2)
- `CompiledMipData` also owns one flat raw buffer `[octave][frame][sample]` plus an immortal-for-its-lifetime POD view (`FlatMipView`).
- The triple buffer publishes the POD view pointer next to the retained reference; `generateSample` reads only the POD view (no class/array access, no ARC).
- The mip octave comes from the binary exponent of `max(20,f)/20` (floor(log2 x) without `log2`); interpolation math unchanged.
- Tests: bit-identical output vs. the array path for all builtins/octaves/morphs; mip octave = old `Int(log2)` over a dense frequency sweep; golden unchanged.
- Perf: new `Stage18WavetablePerfBenchmarks` (32 wavetable voices) before/after, plus the existing perf suites.

## Stage 2: R15-1 (render-safe table loading)
- `loadBuiltin` on the render thread (`applyPresetDSP`) must not take `writeLock`, must not retain/release, and must not free a user table.
- Render path publishes the immortal builtin view through an atomic word; main takes over (retain/release, `activeCompiled`) on its next sync.
- Test: user table → builtin switch on the render path with a dealloc counter and the write lock held elsewhere; old code blocks / frees on render.

## Stage 3: R15-5, R14-5, R15-3
- LFO gating from render-owned state (set in `applyPresetDSP` / `applyAddressedParameterRT`), not from main-written class state.
- Short crossfade (~5 ms) in the LFO when its wavetable shape changes (table or osc mode switch).
- R15-3: when render clears a controller override, main is told (mailbox), so the main mirror / standalone routing follow.

## Stage 4: R15-8, R15-9, R15-4
- UI (standalone and AU view) showing the controller MPE override (member range, master range, zone, count) with a "Reset to my settings" button → `clearOverrides`.
- R15-9: CC 100/101 on ch1/ch16 outside the zone are not double-routed to RPN and the CC map.
- R15-4: document RPN 96/97 semantics (cheap).

## Deferred to SYNT_19
R15-6, R15-7, R14-4/9/10, arpeggiator, R11-6..13, R12-10..15.

## Report
`SYNT_18_REPORT.md`: commits per stage, tests and runs, perf before/after, auval, not-done items, `git merge-base --is-ancestor b866d86 HEAD`.
