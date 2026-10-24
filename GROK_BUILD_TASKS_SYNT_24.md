# SYNT_24 tasks (carried over from SYNT_23)

1. Idle perf A/B (load < 2): wavetable 32x5 and 24x5, plus classic, for absolute figures and user guidance.
2. Wavetable hot spots: pullNewWavetableRT per call, frame-index math.
3. R19-5: cap the DEBUG TolerantDecodeLog array (optional).

Rules unchanged from SYNT_23 (golden 0xd1b3635203a4799e, no main, no force-push, one test per fix that fails on the old code, full suite before each commit, git restore on the dump files).
