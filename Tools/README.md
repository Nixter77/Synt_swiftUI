# Tools
- `auval-reinstall.sh` — build (~/.synt_dd) → /Applications → auval `aumu Synt Nixr` + `aumi Arp1 Nixr` with retries. `SKIP_BUILD=1` to skip the build.
- `midi_test_keys.swift` — MIDI key test helper.

Round gate: unit tests (Init + Factory goldens) + auval. UITests are not mandatory. Flaky long matrix tests (ChordHiss / LoudnessPeaks timeouts) → re-run solo.
See `docs/ARCHITECTURE.md`.
