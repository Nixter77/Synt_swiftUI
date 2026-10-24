# GROK_BUILD_TASKS_SYNT_22 (leftovers from SYNT_21)
1. Wavetable render perf: 32v×5 unison is 105–108% of real time (B, loaded Mac). Target <= 90%: profile mip/interp inner loop and SIMD the unison. Add a budget assertion once met.
2. R14-4, R14-9, R14-10 (from ROUND14): not attempted in SYNT_21.
3. Re-run perf A/B on a truly idle Mac (load < 2) if possible.
4. Same rules: golden hash unchanged, nothing to main, no force-push, failing-on-old-code test per fix.
