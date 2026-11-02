# Synt — architecture (short)

## Layers
- **SynthCore** (framework) — DSP, voices, FX, `AudioEngine`, models and factory presets (`SynthCore/Models`).
- **SynthUI** — SwiftUI views shared by the app and the AU views.
- **Synt_swiftUI** — standalone macOS app; embeds both AUv3 extensions.
- **SyntAUv3** — AUv3 instrument `aumu Synt Nixr`.
- **SyntArpAUv3** — AUv3 MIDI processor `aumi Arp1 Nixr`.
- **SyntHost** — sibling repo (`../SyntHost`), test host; kept separate.

## Factory presets: pass list
`SynthCore/Models/FactoryAuthoring.swift`: `characterPass` → `character(&p)` runs inline floors, then
`FactoryAuthoring.passes` — an ordered `[Pass(name, apply)]` list. **Order is load-bearing** (goldens depend on it).
`engineLimits` (delay feedback ≤ 0.22, ≤ 2 wet FX) is a named step in its historical slot and runs once more after
the whole list. Init is never run through `characterPass`.

## Goldens
- `Synt_swiftUITests/InitGoldenTests.swift` — Init only, `0xd1b3635203a4799e`. **Sacred: never re-capture.**
  A mismatch means the code regressed.
- `Synt_swiftUITests/FactoryGoldenTests.swift` — factory hashes. Re-capture only via
  `-only-testing:Synt_swiftUITests/FactoryGoldenTests` (see file header), and only when a round intends a sound change.

## Branches
- `main` — released line. `feat/auv3` — strip A (AUv3 + preset rounds); merge to main only on nixter's say after Listen.

## Round gate (SYNT / refactor)
Mandatory: `Synt_swiftUITests` unit tests (incl. Init + Factory goldens) green, build → `/Applications`, `auval` both AUs
(`Tools/auval-reinstall.sh`). **UITests are not part of the mandatory gate** (kept, run ad hoc).
Long matrix tests (ChordHiss / LoudnessPeaks) can hit the 3-minute allowance under load — re-run them solo before calling it a failure.

## Escalation
STOP / KEEP ME IN rules: `docs/SYNT_MODEL_CONTRACT.md` (binding). Taste rules: `docs/PRESET_TASTE.md`.
Historical round tasks/reports/dumps: `docs/rounds/` (most are gitignored, local only).
