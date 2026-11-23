# Eng — CUT «SWARM-1» @ `768f72c` (+ доки/откат теста в следующем коммите)

## Изменения
1. **Steal de-click** (`Note.swift`, `AudioEngine.swift`, `AudioEngine+Voices.swift`, `AudioEngine+Render.swift`)
   - `ActiveNote.lastOutL/R` — последний вклад голоса в микс (после amp/pan); сбрасывается в `deactivate()`.
   - `absorbStolenVoiceOutput(at:)` перед каждым `deactivate()` в `findFreeVoiceSlot` (quiet-release, <0.08, last resort).
   - Остаток `stealDeclickL/R` добавляется к сумме голосов и затухает с τ = 0.7 мс (−60 dB ≈ 5 мс), флаш < 1e-6; коэффициент пересчитывается при смене sample rate; `clearAllVoices` обнуляет.
   - Без кражи ветка не выполняется → бит-в-бит.
2. **Case-tag `==`** (`SynthCore/Utils/EnumCaseEquality.swift`) для 29 аудио-enum'ов со String raw value (LFOTarget, FilterType, EnvelopeModel, ModSource, ModDestination, WaveformType, …). Сравнение 1-байтного тега вместо строк; Codable/rawValue не тронуты.
3. Тесты: `VoiceStealDeclickTests` (4), `EnumCaseEqualityTests` (2).

## Замеры
| Что | До (`a651340`) | После |
|---|---|---|
| d2 (ступенька) в момент жёсткой кражи, 8 синусов, пул 8 | **0.0815** | **0.0028** (фон 0.0007) |
| Realtime-фактор render-нагрузки (Rhodes/Supersaw/Glass, педаль, ≤32 голоса, блок 256, Debug `-O` как в `/Applications`) | **0.65×** | **0.98×** (+50 %) |
| + WMO (`SWIFT_COMPILATION_MODE=wholemodule`, только A/B, не закоммичено) | — | 1.15× |
| + WMO + `-enforce-exclusivity=unchecked` (только A/B) | — | 1.47× |
| Полный serial-прогон | 716 с | 530 с |

## Instruments
- **Time Profiler** (attach к test-host, 25 с, ~21 k сэмплов): до — `specialized ==`/`_stringCompare*`/`rawValue`-геттеры ≈ 12 % self + retain/release; после — строковых сравнений в топе нет; остались `swift_beginAccess`/`AccessSet::insert` ≈ 18 % (exclusivity, см. решение D-3) и `renderOneSample` 19 % self.
- **Allocations / RT-safety:** в 20 995 сэмплах внутри `AudioEngine.render(frames:)` — **0** кадров `malloc`/`swift_allocObject`/`free`/mutex/unfair_lock. (Шаблон Allocations записан, таблицы xctrace не экспортирует — проверка по стекам Time Profiler.)
- **Leaks** (`leaks <pid>` во время нагрузки): база 329 / 12.6 KB, после 336 / 13.0 KB — все корни `ListenerBinding`/`ParameterListenerBinding` из AVFoundation при создании `AVAudioEngine` (нагрузка создаёт 4 движка на цикл). Не рендер-путь и не из этого CUT; в AU один движок на инстанс. P3, записано.
- Audio System Trace в Logic не снимался: правило «не трогать живые окна nixter».

## Не сделано / вне CUT
- `busGlueFlagWiresIntoRenderPath` — pre-existing, нужен дизайн-ответ (см. 02).
- Build-флаги (WMO / exclusivity / Release-установка) — только замер, решение nixter.
