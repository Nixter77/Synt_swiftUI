# 07 — Финальный CodeReviewer (раунд swarm-code-review / SWARM-1)

Ветка: `feat/swarm-code-review` (origin, новая ветка; main не тронут).
Коммиты раунда: `768f72c` (фиксы + 01–03), `785b972` (откат busGlue-правки + 04–06), этот коммит (07).

## Вердикт: ACCEPT (с условиями Listen и решений ниже)

| AC | Статус |
|---|---|
| AC-1 steal de-click: ступень d2 0.0815 → 0.0028 (фон 0.0007) | ✅ тест VoiceStealDeclickTests (4) |
| AC-2 enum `==` без string-compare в render | ✅ EnumCaseEqualityTests (2), Time Profiler: strcmp-стек исчез |
| AC-3 Init golden 0xd1b3635203a4799e, Factory goldens | ✅ без recapture |
| AC-4 нет сдвигов AU-адресов параметров | ✅ (параметры не менялись) |
| AC-5 нет новых падений; busGlue — pre-existing | ✅ 830 Swift Testing: единственный FAIL busGlueFlagWiresIntoRenderPath (падает и на ebd9705/a651340); XCTest 173/173 |
| auval aumu Synt Nixr / aumi Arp1 Nixr | ✅ AU VALIDATION SUCCEEDED (Debug из ~/.synt_dd → /Applications) |
| Дубликат Debug AU | ✅ нет: pluginkit — ровно 2 записи (SyntAUv3, SyntArpAUv3), обе из /Applications |

Ревью diff: de-click — RT-safe (без аллокаций/локов, ветка только при ненулевом residual, flush < 1e-6), коэффициент пересчитывается в applySampleRate. Case-tag `==` эквивалентен синтезированному для всех 29 enum (тест на все case). В обычной игре звук не меняется; при краже голоса — меняется (мягче), это и есть цель → Listen-гейт.

## Решения для nixter
- **D-1** Merge `feat/swarm-code-review` → main — не делал.
- **D-2** Listen: Rhodes Warm + педаль, плотные аккорды в Logic (кражи голосов) — de-click на слух.
- **D-3** `-enforce-exclusivity=unchecked` для SynthCore (+~28% RT-запаса в A/B) — не применено.
- **D-4** WMO / Release-конфиг в auval-reinstall.sh (+~17%) — не применено.
- **D-5** busGlue: CleanBus (с c9fb618) держит RMS < −18 dB → glue-компрессор почти не работает (GR 0.02 dB). Дизайн (поднять порог/вход glue) или тест устарел?
- **D-6** Путь слияния: локальный main `bff3d99` (= origin/feat/auv3 `ebd9705`) не запушен; origin/main `06c40a6`. Мержить swarm-ветку через feat/auv3 или прямо в main?
- **D-7** (опц.) убрать лишний audio-input entitlement из SyntAUv3 (S-1).

## Отложено (P3)
N-5…N-10 из 01/02; утечки AVFoundation ListenerBinding (~13 KB, pre-existing, не в render); Audio System Trace в Logic не снимался (правило «не трогать живые окна»).

---
MODEL CONTRACT: изменения соблюдают docs/SYNT_MODEL_CONTRACT.md — без сдвига AU-адресов, Init golden не менялся, звуковое изменение (steal de-click) помечено под Listen nixter.
