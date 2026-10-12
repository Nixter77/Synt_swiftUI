# GROK_BUILD_TASKS — Synt_swiftUI

Синтезатор для macOS на SwiftUI + AVAudioEngine: 2 осциллятора (VA + wavetable), фильтр на голос, ADSR, LFO, unison, 32 голоса, арпеджиатор, степ-секвенсор, MIDI, DSP-эффекты (chorus/distortion/EQ/phaser) + Apple Delay/Reverb, 38 фабричных пресетов.
Состояние на 2026-10-12: ветка `feat/phaser-control-rate`, юнит-тесты зелёные (121 passed, 0 failed). Ниже — задачи по приоритету: сначала исправления, потом фичи. Делай по порядку, не спрашивая.

## Правила
- Работай в текущей ветке `feat/phaser-control-rate` (она впереди `main`). Не мержи в `main`.
- После КАЖДОЙ задачи: сборка + тесты зелёные → отдельный коммит (`fix:`/`feat:`/`perf:` + номер задачи) → `git push` в существующий `origin`. Без `--force`, без новых репозиториев, без переписывания истории.
- Init и фабричные пресеты «священны»: не меняй их параметры и тембр, кроме случаев, явно описанных в задаче.
- Аудиопоток (render / `renderOneSample` / всё, что вызывается из `AVAudioSourceNode`): без аллокаций, без локов, без `print`, без `DispatchQueue`, без `@Published`. Только предвыделенные буферы и атомики/SPSC-очередь (`AudioCommandQueue`).
- Сохранение пресетов — только обратно-совместимый `decodeIfPresent ... ?? default` (см. `SynthPreset.init(from:)`).
- Не трогай `*_NOTES.md`, `*_PLAN.md`, `*_DUMP.txt`.
- Если задача не получается — откати её изменения, запиши причину в конец этого файла (раздел «Журнал») и переходи к следующей.

## Команда сборки и тестов
```bash
cd /Users/nikolay/gemini_projekts/Synt_swiftUI
xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI \
  -destination 'platform=macOS' -derivedDataPath ~/.synt_dd \
  -only-testing:Synt_swiftUITests
```
Ожидается `** TEST SUCCEEDED **`. Полный прогон ~3 минуты.

---

## Задача 1 — Оптимизация Swift для приложения в Debug (fix, хрип от CPU)
**Зачем:** в Debug у таргета стоит `SWIFT_OPTIMIZATION_LEVEL = -Onone`. DSP рендерится по одному сэмплу на Swift; без оптимизации буфер не успевает → хрипы (в DrumMashine именно это давало треск: 97–112% бюджета буфера, с `-O` стало ~2.5%).
**Файлы:** `Synt_swiftUI.xcodeproj/project.pbxproj`.
**Шаги:**
1. В Debug-конфигурации таргета приложения `Synt_swiftUI` поставить `SWIFT_OPTIMIZATION_LEVEL = "-O"` (Release уже оптимизирован — проверить, что там `-O`/`-Osize` не `-Onone`).
2. Тестовые таргеты не трогать. `ENABLE_TESTABILITY = YES` оставить, чтобы `@testable import` работал.
3. Добавить тест `RenderBudgetTests.swift`: рендер 512 кадров ×200 через `renderFramesMetricsForTesting` для пресета Init с 7 нотами и для самого тяжёлого фабричного (unison + phaser), замерить время; среднее на буфер < 50% от 512/44100 с. В DEBUG-сборке тестов (если тестовый бандл всё же неоптимизирован) порог можно ослабить, но тест должен существовать и печатать процент.
**Приёмка:** приложение в Debug собирается с `-O`; тесты зелёные; новый тест логирует процент бюджета.

## Задача 2 — Секвенсор без таймера 1000 Гц на главном потоке (fix, тайминг + CPU)
**Зачем:** `ContentView.swift` (~стр. 46) крутит `Timer.publish(every: 0.001, on: .main)` и вызывает `stepSequencer.tick(... sampleCount: 44)`. Это ~1000 срабатываний SwiftUI-`onReceive` в секунду на главном потоке: джиттер нот, лишние перерисовки, плывущий темп при нагрузке на UI. В рендере уже есть сэмпл-точный клок (`clockPhase`/`samplesPerTick` в `AudioEngine+Render.swift`) для арпеджиатора.
**Файлы:** `Synt_swiftUI/ContentView.swift`, `Synt_swiftUI/Audio/StepSequencer.swift`, `Synt_swiftUI/Audio/AudioEngine+Render.swift`, `Synt_swiftUI/Audio/AudioEngine.swift`, `Synt_swiftUI/Audio/AudioCommandQueue.swift`, `Synt_swiftUI/Views/StepSequencerView.swift`.
**Шаги:**
1. Перенести продвижение шагов в аудиопоток (по образцу арпеджиатора): снимок паттерна (фиксированный массив шагов: нота/велосити/active/gate) передаётся в рендер через `AudioCommandQueue` или атомарный двойной буфер — без аллокаций в рендере.
2. Свинг, BPM и rootNote берутся из снимка. noteOn/noteOff шага — прямо в голосовом пуле на аудиопотоке.
3. Текущий шаг для UI отдавать атомиком; UI читает его не чаще 30 Гц (`TimelineView(.periodic(from:by: 1/30))` или таймер 30 Гц) и обновляет `currentStep` только при изменении.
4. Удалить таймер 0.001 из `ContentView`.
**Тесты:** офлайн-рендер N сэмплов при BPM 120, 16 шагов → проверить, что noteOn происходят точно на границах шагов (±1 сэмпл) и что свинг сдвигает чётные шаги на ожидаемое число сэмплов; старые тесты секвенсора адаптировать, не удалять смысл.
**Приёмка:** нет `Timer.publish(every: 0.001` в проекте; тесты зелёные; секвенсор играет ровно.

## Задача 3 — Мягкий потолок после Apple Delay/Reverb (fix, «хрип мокрых аккордов»)
**Зачем:** граф `sourceNode (DSP + softClip) → Apple Delay → Apple Reverb → mainMixer`. Мокрые хвосты не имеют потолка после FX, и офлайн-тесты этого не видят (см. `CHORD_HISS_NOTES.md`, вариант C).
**Файлы:** `Synt_swiftUI/Audio/AudioEngine.swift` (сборка графа), новый `Synt_swiftUI/Audio/Effects/PostFXLimiter.swift` (или `AVAudioUnitEffect` с `kAudioUnitSubType_PeakLimiter`), тесты.
**Шаги:**
1. Вставить после Reverb и перед `mainMixer` прозрачный пиковый лимитер / софт-клип с порогом ≈ −1 dBFS (ниже порога сигнал бит-в-бит не меняется, если это свой DSP-узел).
2. Предпочтительно: Apple `AUPeakLimiter` (attack ~1 мс, release ~50 мс, pre-gain 0) — без своего кода на аудиопотоке. Если свой узел — RT-safe правила.
3. Не менять уровни пресетов, sends и существующий softClip.
**Тесты:** юнит-тест на свой лимитер (если свой): синус 0.5 проходит без изменений, синус 2.0 ограничен ≤ 0.9 без NaN; тест, что граф содержит лимитер после reverb (через доступ к `engine.attachedNodes`/хук для тестов).
**Приёмка:** тесты зелёные; голдены (`AudioGoldenHarnessTests`) не изменились.

## Задача 4 — Частота дискретизации устройства вместо жёстких 44100 (fix)
**Зачем:** `AudioEngine.swift`: `sampleRate = 44100`, `ParametricEQ(sampleRate: 44100)`, `Phaser(sampleRate: 44100)`, `Compressor(sampleRate: 44100.0)`. На 48 кГц-выходе (большинство Mac/наушников) Apple ресэмплит — лишняя нагрузка и сдвиг частот секвенсора/LFO, если где-то считается от 44100.
**Файлы:** `AudioEngine.swift`, `AudioEngine+Render.swift`, `Effects/*.swift`, `WavetableOscillator.swift`, `LFO.swift`, `ADSREnvelope.swift`, `StepSequencer.swift`.
**Шаги:**
1. При `start()` брать `engine.outputNode.outputFormat(forBus: 0).sampleRate`, создавать формат sourceNode с ним.
2. Пробросить sampleRate во все DSP-объекты (метод `setSampleRate(_:)`, пересчёт коэффициентов, перестройка mip-уровней wavetable по Найквисту) — вызывать ДО старта движка, не из рендера.
3. Найти все литералы `44100`/`44_100` (`rg -n "44100|44_100" Synt_swiftUI`) и заменить на значение движка. Тесты могут явно задавать 44100.
4. При смене устройства (`AVAudioEngineConfigurationChange`) — остановить, пересобрать с новой частотой, перезапустить.
**Тесты:** рендер ноты A4 при 44100 и 48000 → основная частота (по пересечениям нуля / FFT) 440 Гц ±1 Гц в обоих случаях; LFO-период совпадает в секундах.
**Приёмка:** нет захардкоженных 44100 в продакшн-коде (кроме дефолта); тесты зелёные.

## Задача 5 — Меньше перерисовок UI (perf)
**Зачем:** много двойных `.shadow` (KnobView, PianoKeyView, WaveformPicker, OscilloscopeView, SpectrumAnalyzerView, KeyboardView). Осциллограф/спектр/VU обновляются часто → каждый кадр пересчитывает размытые тени десятков ручек. Это грузит главный поток и косвенно мешает звуку.
**Файлы:** `Views/Components/KnobView.swift`, `PianoKeyView.swift`, `WaveformPicker.swift`, `OscilloscopeView.swift`, `VUMeterView.swift`, `Views/SpectrumAnalyzerView.swift`, `AudioEngine+Metering.swift`, `ContentView.swift`.
**Шаги:**
1. Статичные тени ручек/клавиш: `.compositingGroup()` + `.drawingGroup()` или заменить двойную тень одной/градиентом; неизменяемые части — в отдельный `Equatable`-view.
2. Метеринг (`outputLevel`, `peakLevel`, `scopeData`) публиковать не чаще 30 Гц и только при изменении > порога; осциллограф/спектр рисовать через `Canvas` в `TimelineView(.animation(minimumInterval: 1/30))`, без `@Published`-массивов на 512 элементов каждый кадр.
3. Изолировать метеринг в отдельный `ObservableObject`, чтобы изменения уровня не инвалидировали весь `ContentView` с ручками.
4. Внешний вид не менять (тот же цвет, радиусы, «объём»).
**Тесты:** тест на троттлинг метеринга (N обновлений за 1 с ≤ 31); остальные зелёные.
**Приёмка:** `ContentView` не наблюдает объект с метерами напрямую; визуал идентичен; тесты зелёные.

## Задача 6 — Гигиена: предупреждения и мёртвые файлы (fix, мелочь)
**Файлы:** `Synt_swiftUITests/GlassHorizonHangProbeTests.swift:71` (`var base` → `let`), `firebase-debug.log` и `.DS_Store` (добавить в `.gitignore`, удалить из индекса через `git rm --cached`, если они отслеживаются), `print(...)` в `AudioEngine.swift` → `os.Logger`.
**Приёмка:** сборка без предупреждений Swift в наших файлах; тесты зелёные.

## Задача 7 — Сохранение и загрузка пользовательских пресетов в файл + «последнее состояние» (feature)
**Зачем:** сделать работу непрерывной: при запуске открывается последний патч, пресеты можно экспортировать/импортировать.
**Файлы:** `Utils/PresetManager.swift`, `Models/SynthPreset.swift`, `Views/PresetView.swift`, `ContentView.swift`.
**Шаги:**
1. Автосохранение текущего пресета (debounce 1 с, вне аудиопотока) в Application Support `last_session.json`; загрузка при старте; при ошибке декодирования — Init, без падения.
2. Кнопки Export / Import (`NSSavePanel`/`NSOpenPanel`, `.synthpreset` = JSON) в `PresetView`.
3. Только `decodeIfPresent` для новых полей.
**Тесты:** round-trip encode/decode всех фабричных пресетов; декодирование «старого» JSON без новых полей; повреждённый JSON → nil/Init без краша.
**Приёмка:** тесты зелёные.

## Задача 8 — MIDI: pitch bend, mod wheel, sustain (feature)
**Файлы:** `Input/MIDIHandler.swift`, `Audio/AudioCommandQueue.swift`, `Audio/AudioEngine+Voices.swift`, `AudioEngine+Render.swift`, `Models/SynthPreset.swift` (поле `pitchBendRange`, по умолчанию 2 полутона, `decodeIfPresent`).
**Шаги:**
1. Pitch bend (0xE0) → команда в очередь → сглаженный (≈5 мс) множитель частоты всех голосов.
2. CC1 (mod wheel) → глубина LFO (0…1 поверх пресета), CC64 (sustain) → отложенный noteOff, отпускание педали отпускает удерживаемые ноты.
3. Всё через `AudioCommandQueue`, без локов.
**Тесты:** офлайн: bend +2 → частота ×2^(2/12) ±0.5%; sustain удерживает голос после noteOff и отпускает после CC64=0; без MIDI звук Init бит-в-бит как раньше (голден).
**Приёмка:** тесты зелёные.

---
## Журнал
(сюда Grok Build пишет пропущенные задачи и причины)
