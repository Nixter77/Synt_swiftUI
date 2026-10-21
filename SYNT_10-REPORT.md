# Отчёт по GROK BUILD — SYNT_10: DSP fixes, модуляция, MSEG 2, редактор огибающих и визуализаторы (осциллограф/спектр)

**Ветка:** `feat/auv3` (tracking `origin/feat/auv3`)  
**Базовый коммит:** `44afb0f`  
**Итоговый статус:** Все 4 этапа полностью выполнены, протестированы и верифицированы.  
**Golden FNV Hash (Init):** `0xd1b3635203a4799e` сохранён бит-в-бит во всех тестах (`InitGoldenTests`).  
**Высота сетки (Layout):** `SynthControlGrid` $\le 520\text{ pt}$ во всех темах (`ThemeID.allCases`, проверено `LayoutTests`).  
**AU Validation:** `AU VALIDATION SUCCEEDED` (`auval -v aumu Synt Nixr`).

---

## Этап 1 — Критические DSP-исправления

### Выполненные пункты:
1. **R7-1 (Фазовращатель / сеть Гильберта):**
   - Файл: `SynthCore/DSP/Effects/DSPFrequencyShifter.swift`
   - Реализация: Полная перестройка фазосдвигающей сети Гильберта на 4 пары фазовых фильтров Ниемитало (Direct Form II) с задержкой в 1 семпл во второй ветви. Подавление второй боковой полосы при сдвиге синусоиды +100 Гц достигло $\le -54\text{ dB}$ (при требовании $\le -40\text{ dB}$).
2. **R7-3 (Защита от NaN/Inf в фильтре перед fastTanh):**
   - Файл: `SynthCore/Audio/AudioEngine+Render.swift`
   - Реализация: Добавлена проверка `isFinite` до вызова `fastTanh`. При обнаружении нечислового значения состояние биквадратного фильтра и кольцевой буфер обратной связи немедленно сбрасываются в ноль, предотвращая зависание или постоянное смещение (DC).
3. **R7-4 (Кривая Release в ADSREnvelope):**
   - Файл: `SynthCore/Audio/ADSREnvelope.swift`
   - Реализация: Экспоненциальная кривая сегмента Release теперь начинается строго с фактического текущего уровня сигнала, а не с 1.0, исключая щелчки при отпускании недоигранных нот.
4. **R7-5 (Кривая Attack при повторном запуске / legato):**
   - Файл: `SynthCore/Audio/ADSREnvelope.swift`
   - Реализация: При ретриггере во время звучания ноты кривая атаки стартует от текущего уровня огибающей вверх без провалов в ноль.
5. **R7-2 (Amp LFO со стереофазой):**
   - Файл: `SynthCore/Audio/AudioEngine+Render.swift`
   - Реализация: Устранено дублирование тремоло. Модуляция амплитуды стерео-LFO применяется ровно один раз на семпл с точной глубиной.

- **Коммит:** `bfd5d52` (`fix(dsp): Stage 1 - critical DSP fixes (Hilbert network, filter feedback NaN, ADSR curves, stereo tremolo)`)
- **Тесты:** `Synt_swiftUITests/Stage10CriticalTests.swift` — все тесты пройдены.

---

## Этап 2 — Дополнительные исправления DSP и стабильности

### Выполненные пункты:
1. **R7-6 (Двойная буферизация MSEG с подтверждением рендера):**
   - Файл: `SynthCore/DSP/Modulation/DSPMSEG.swift`
   - Реализация: Внедрено атомарное отслеживание `acknowledgedBank`. Аудиопоток рендера при выполнении `tick()` подтверждает прочитанный банк. Метод `publish()` главного потока ожидает подтверждения (до 1000 итераций со `sched_yield()`), исключая перезапись активного банка во время рендера.
2. **R7-7 (Фильтр Comb в параметрах AU):**
   - Файлы: `SynthCore/Audio/SyntAudioUnit.swift`, `SynthCore/Models/SynthParameterAddress.swift`
   - Реализация: В список типов фильтра добавлен тип Comb (индекс 6, в конце списка). Диапазон параметра `filterType` и `filter2Type` расширен до `0...6`.
3. **R7-8 (DC blocker в Character Warm и чистый обход в Off):**
   - Файл: `SynthCore/DSP/Effects/DSPCharacterTone.swift`
   - Реализация: В режиме Warm интегрирован 1-полюсный DC-блокер на 10 Гц. Режим `.off` является чистым passthrough (без сатурации `tanh`), гарантируя 100% бит-в-бит совпадение.
4. **R7-9 (Оптимизация смены частоты дискретизации):**
   - Файл: `SynthCore/Audio/AudioEngine.swift`
   - Реализация: В `applySampleRate` добавлена проверка `needsRateChange || needsGraph`. Если частота дискретизации не изменилась, остановка и перезапуск графа не выполняются.
5. **R7-10 (Правый канал стерео LFO):**
   - Файл: `SynthCore/Audio/LFO.swift`
   - Реализация: Правый канал стерео LFO строго повторяет состояние one-shot, начальную фазу и форму волны; при завершении one-shot оба канала возвращают `(0.0, 0.0)`.
6. **R7-11 (Устранение ARC на массивах фильтров голосов):**
   - Файлы: `SynthCore/Audio/AudioEngine.swift`, `SynthCore/Audio/AudioEngine+Render.swift`
   - Реализация: Массивы фильтров (`voiceDualFilters`, `voiceFormantFilters`, `voiceCombFilters`) обернуты в предварительно выделенные `Unmanaged` указатели (`voiceDualPtr`, `voiceFormantPtr`, `voiceCombPtr`). Доступ в цикле рендера происходит через `.takeUnretainedValue()` с нулевым оверхедом ARC.
7. **R7-12 (Comb-фильтр на 20 Гц при 192 кГц и сброс денормалов):**
   - Файлы: `SynthCore/DSP/Filters/DSPCombFilter.swift`, `SynthCore/DSP/Effects/DSPFrequencyShifter.swift`
   - Реализация: Кольцевой буфер Comb расширен до 16384 семплов (поддержка частот от 20 Гц при частотах дискретизации до 192 кГц). Добавлен сброс денормализованных чисел (`flushToZero`) в гребенчатом фильтре и фазовращателе.

- **Коммит:** `839df89` (`fix(dsp): Stage 2 - other DSP and engine stability fixes`)
- **Тесты:** `Synt_swiftUITests/Stage10OtherFixesTests.swift` — все тесты пройдены.

---

## Этап 3 — Модуляция

### Выполненные пункты:
1. **Live Modulation Highlighting на ручках управления:**
   - Файлы: `SynthCore/Audio/LiveModulationSnapshot.swift`, `SynthUI/Views/Components/KnobView.swift`, `SynthCore/Audio/AudioEngine+Render.swift`
   - Реализация: Создан lock-free синглтон `LiveModulationSnapshot` на атомарных битовых масках `Atomic<UInt32>`. Аудиопоток рендера публикует текущие уровни модуляции для каждого назначения `ModDestination`. В `KnobChrome` анимированная точка модулированного значения обновляется с частотой ~30 Гц через `TimelineView` только в том случае, если ручка имеет активную модуляцию (`modulationAmount != 0`), не расходуя ресурсы UI на немодулированные параметры.
2. **Параметры атаки и спада Envelope Follower:**
   - Файлы: `SynthCore/Models/SynthPreset.swift`, `SynthCore/Models/SynthParameterAddress.swift`, `SynthCore/Audio/SyntAudioUnit.swift`, `SynthCore/Audio/AudioEngine.swift`, `SynthCore/Audio/AudioEngine+Render.swift`, `SynthUI/Views/ModMatrixView.swift`
   - Реализация: Добавлены параметры `envFollowerAttack` (по умолчанию 0.01 с) и `envFollowerRelease` (по умолчанию 0.05 с). Значения зарегистрированы в дереве параметров AU (адреса 140, 141), коэффициенты сглаживания предрассчитываются вне аудиотреда с посемпловым $O(1)$ применением. В интерфейсе `ModMatrixView` при выборе `Env Follower` в источнике динамически отображаются ручки Attack и Release.
3. **Случайная начальная фаза осцилляторов на каждую ноту:**
   - Файлы: `SynthCore/Models/SynthPreset.swift`, `SynthCore/Audio/VoiceState.swift`, `SynthCore/Audio/AudioEngine+Voices.swift`
   - Реализация: Добавлен режим `OscPhaseMode.random` в конце enum. В метод `ActiveNote.activate(...)` добавлен параметр `randomSeed`. При нажатии ноты per-voice xorshift генератор обновляет сид, обеспечивая уникальную случайную фазу на каждой ноте.

- **Коммит:** `7cc970c` (`feat(modulation): Stage 3 - live modulation highlighting, envelope follower attack/release, random note phase`)
- **Тесты:** `Synt_swiftUITests/Stage10ModulationTests.swift` — все тесты пройдены.

---

## Этап 4 — MSEG 2, редактор огибающих и визуализаторы (осциллограф/спектр)

### Выполненные пункты:
1. **MSEG 2 (второй многоточечный генератор огибающей):**
   - Файлы: `SynthCore/Models/SynthPreset.swift`, `SynthCore/Models/SynthPreset+Sanitize.swift`, `SynthCore/Audio/AudioEngine.swift`, `SynthCore/Audio/AudioEngine+Preset.swift`, `SynthCore/Audio/AudioEngine+Voices.swift`, `SynthCore/Audio/AudioEngine+Render.swift`, `SynthCore/Audio/SyntAudioUnit.swift`
   - Реализация:
     - В `ModSource` добавлен `case mseg2 = "MSEG 2"` (в конце enum).
     - В `SynthPreset` добавлено поле `public var mseg2 = MSEGPreset()` с безопасной десериализацией через `decodeIfPresent` и санитацией индексов петли и сустейна.
     - В `AudioEngine` инициализирован независимый DSP-генератор `mseg2: DSPMSEG`, подготавливаемый при смене частоты дискретизации и триггерируемый при ноте.
     - В `matrixSource(...)` и `renderOneSample()` добавлена посемпловая обработка и маршрутизация `mseg2` через матрицу модуляции.
2. **Улучшенный редактор MSEG (сетка, привязка, копирование):**
   - Файл: `SynthUI/Views/LFOView.swift`
   - Реализация:
     - В `MSEGPointEditor` добавлены переключатели выбора активной огибающей `[1]` и `[2]`.
     - Кнопка копирования `1→2` / `2→1` для быстрого дублирования формы огибающей между MSEG 1 и MSEG 2.
     - Режимы привязки к сетке (Snap Mode): `OFF`, `1/16`, `1/8`, `1/4`, `0.1`. При перемещении времени точки или добавлении новой точки время аккуратно привязывается к ближайшему делению.
     - Интерактивный мини-график с фоновыми направляющими сетки, отображающий сегменты и выделенную точку.
     - Сохранены все accessibility identifiers (`msegEditor`, `msegAdd`, `msegDelete`, `msegSync`, `msegSustain`, `msegLoop`) и добавлены новые (`msegSelect1`, `msegSelect2`, `msegCopy`, `msegSnap`).
3. **Lock-Free Ring Buffer и спектроанализатор:**
   - Файлы: `SynthCore/Audio/AtomicMeteringState.swift`, `SynthUI/Views/Components/OscilloscopeView.swift`, `SynthCore/Audio/AudioEngine+Render.swift`
   - Реализация:
     - `AtomicMeteringState` переведен на непрерывную плоскую память `UnsafeMutablePointer<Float>` на 4 слота кольцевого буфера. Запись из аудиотреда рендера происходит через сырое побайтовое копирование без единой аллокации, блокировки или ARC. Если читатель занят чтением следующего слота, фрейм мгновенно отбрасывается без ожидания.
     - В `OscilloscopeView` реализован класс `OutputSpectrumCalculator` на базе Accelerate (`vDSP_create_fftsetup`, `vDSP_fft_zip`, окно Ханна).
     - Реализован переключатель режимов `SCOPE` / `SPEC`. В режиме `SPEC` отображается логарифмический спектр частот (48 полос с градиентным заполнением под кривой).

- **Коммит:** `feat(visuals): Stage 4 - MSEG 2, enhanced editor, output scope and spectrum`
- **Тесты:** `Synt_swiftUITests/Stage10VisualsTests.swift` — все 6 тестов пройдены.

---

## Сводка по тестам и валидации
- `Stage10CriticalTests`: **PASSED**
- `Stage10OtherFixesTests`: **PASSED**
- `Stage10ModulationTests`: **PASSED**
- `Stage10VisualsTests`: **PASSED**
- `InitGoldenTests` (`0xd1b3635203a4799e`): **PASSED**
- `LayoutTests` (высота $\le 520\text{ pt}$): **PASSED**
- `Stage8MSEGTests`: **PASSED**
- `auval -v aumu Synt Nixr`: **AU VALIDATION SUCCEEDED**

---

## Отложено на SYNT_11
- Arp как отдельный AUv3 MIDI FX (`aumi`), предварительное прототипирование в Logic 11.
- Параллельная шина FX / send FX bus.
- Rotary speaker.
- MPE (MIDI Polyphonic Expression).
