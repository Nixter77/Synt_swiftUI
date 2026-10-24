# GROK_BUILD_TASKS_SYNT_21 (feat/auv3, from ROUND17)

Rules: golden 0xd1b3635203a4799e unchanged; nothing into main, no force-push; each fix has a named test
that fails on old code; full suite green before each commit; restore dump files before commit; new
features off by default; decodeIfPresent for new preset fields; new AU addresses from 167; no
alloc/lock/exp/pow/ARC per sample on render. Counts reported as total / passed / skipped / runs.

1. Perf A/B (R17-1): b866d86 vs HEAD, alternating ≥5 each, load < 2 (discard above), median + min,
   incl. Stage18 wavetable suite on both sides where it exists; propose a wavetable budget target.
2. R15-6/7: bounded compiledCache (eviction), safe with the R16-1 hazard ack (slots retain their own ref).
3. R17-2: reset sequence instead of Bool + double-Reset-before-drain test. R17-3: comment on the wait.
4. R17-4: remaining test hooks under #if DEBUG (or document Debug-only test target).
   R17-5: tolerant decoding of remaining enums + stateVersion decision. R14-4/9/10 only if they fit.
Then: full suite, reinstall, pluginkit, auval, SYNT_21_REPORT.md, merge-base vs 09a82aa.
Leftovers → GROK_BUILD_TASKS_SYNT_22.md.
