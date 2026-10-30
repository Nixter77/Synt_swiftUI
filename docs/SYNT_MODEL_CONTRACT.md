# SYNT model contract (paste into every GROK_BUILD_TASKS_SYNT_n.md)

Any coding model (Grok Build, Gemini, Cursor, …) working on Synt_swiftUI or SyntHost must treat this block as binding. PM cuts and QA AC packs reuse the same STOP / KEEP ME IN / checklist.

## STOP — escalate to nixter (Grok Bot Decision), do not “fix and hope”
- P0/P1 audit finding
- Failed `Synt_swiftUITests` (new failures) or `auval` not SUCCEEDED
- Merge / push to `main`, force-push, history rewrite, new repo
- Init / Default / Template change, or Init golden ≠ `0xd1b3635203a4799e`
- AU parameter **address** shifts (new addresses OK only if task explicitly allows and Init path unused)
- Sound / factory golden drift not called for by the task
- Ambiguity that changes product meaning

## KEEP ME IN — nixter only (agents never decide)
- Final listen acceptance
- Merge to `main`
- Live/Cloud Agents on this Mac for Synt
- Changing frozen Init golden or factory Init lines

## Do-not-disturb (overnight / multi-model)
- No per-step widgets to nixter; no empty «Ок/Принял/жду»
- Report only: tip SHA + PASS/FAIL, or STOP item above
- Listen = DEFER unless the task says otherwise
- Brass/chord-safety and similar Eng drops: record in report + CUT OUT; not a FAIL if CUT says OUT

## Checklist before claiming DONE (every model)
1. **Init** — `InitGoldenTests` green; `git grep` / fixture still `0xd1b3635203a4799e`; Init line untouched vs task base SHA
2. **AU addresses** — no silent renumber; if new params, Init/default leave them inert (flags off / mix 0 / bypass)
3. **Tests** — serial Coverage + InitGolden + Character/Identity (when values) green; document known pre-existing only
4. **auval** — after Release install to `/Applications/Synt_swiftUI.app`: `auval -v aumu Synt Nixr` and `auval -v aumi Arp1 Nixr` → SUCCEEDED
5. **Branch** — commit + normal push to task branch only (`feat/auv3` or named parallel); never `main`
6. **Surface** — stay inside task OUT (no drive-by SyntHost↔Synt_swiftUI edits unless task says so)
7. **QA** — same AC pack as PM CUT; PASS only if all BLOCK ACs green; Listen DEFER ≠ FAIL

## Parallel strips (safe for any model)
| Strip | Branch / folder | May touch | Must not |
|---|---|---|---|
| A values/UI/flags-off | `feat/auv3` | Models, authoring, tests, UI that does not change Init render, feature flags **default off** | Init golden, AU address renumber, merge main |
| B host | `SyntHost/` | Host only; AU API to installed app | `Synt_swiftUI` source/goldens |
| C experimental DSP | `feat/synt7b-dsp` worktree | New Experimental modules + unit tests | Wire into render with flags **on**; touch main project Init |

Wire C → A only with flags default **off**, decodeIfPresent defaults inert, Init bit-identical, then QA AC-1…auval.

## Paste footer for task files
```
## ⛔ MODEL CONTRACT (see docs/SYNT_MODEL_CONTRACT.md)
STOP / KEEP ME IN / checklist / parallel strips above are binding for every model.
Init golden 0xd1b3635203a4799e. No main merge. Listen DEFER unless task says otherwise.
```
