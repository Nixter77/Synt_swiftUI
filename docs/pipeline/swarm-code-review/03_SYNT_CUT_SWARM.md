# PM CUT «SWARM-1» — `feat/swarm-code-review` @ `a651340` → APPROVED-for-Eng

**Цель:** снять две измеримые причины щелчков/треска Key/Rhodes в Logic (жёсткая кража голоса и CPU-перегруз от String-сравнений enum'ов) без изменения Init/factory звука; профиль Instruments до/после.

**IN:** `AudioEngine+Voices.swift`, `AudioEngine+Render.swift`, `AudioEngine.swift`, `Models/Note.swift`, новый `Utils/EnumCaseEquality.swift`, тесты (`VoiceStealDeclickTests`, `EnumCaseEqualityTests`), `docs/pipeline/swarm-code-review/*`.
**OUT:** factory/Init значения, AU-адреса, SyntHost, build-настройки (exclusivity / WMO), UI, `main`.

## AC
| AC | Gate | Проверка |
|---|---|---|
| AC-1 | BLOCK | Кража при полном пуле не даёт ступеньки: `VoiceStealDeclickTests.hardStealDecaysInsteadOfSteppingToZero` (d2 на краже < 3·фон + 0.1·уровень жертвы); на базе тот же замер ≥ 0.08. |
| AC-2 | BLOCK | Без кражи остаток = 0 и не влияет (`noStealLeavesResidualUntouched`), `clearAllVoices` обнуляет, коэффициент зависит от sample rate. |
| AC-3 | BLOCK | `EnumCaseEqualityTests`: для всех 29 enum'ов и всех пар кейсов `(a == b) == (a.rawValue == b.rawValue)`, размер 1 байт, Codable не изменился. |
| AC-4 | BLOCK | Init golden `0xd1b3635203a4799e` зелёный; FactoryGolden зелёный (без перезаписи хешей). |
| AC-5 | BLOCK | Полный serial-прогон: новых падений нет (единственный красный `busGlueFlagWiresIntoRenderPath` — pre-existing, красный и на `ebd9705`). |
| AC-6 | BLOCK | Instruments: Time Profiler до/после на одной нагрузке — String-сравнения исчезли из топа, realtime-фактор вырос; Allocations — нет malloc в `render`; Leaks — 0 утечек. |
| AC-7 | BLOCK | `auval -v aumu Synt Nixr` и `aumi Arp1 Nixr` → SUCCEEDED после установки в `/Applications`. |
| AC-8 | BLOCK | AU-адреса не сдвинуты (`SynthParameterAddress.swift` и дерево Arp не менялись). |
| AC-9 | INFO | Listen в Logic (Rhodes Warm + педаль, плотная игра) — **DEFER → nixter**. |

## ⛔ MODEL CONTRACT (see docs/SYNT_MODEL_CONTRACT.md)
STOP / KEEP ME IN / checklist / parallel strips above are binding for every model.
Init golden 0xd1b3635203a4799e. No main merge. Listen DEFER unless task says otherwise.
