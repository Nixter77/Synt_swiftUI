# Отчёт по GROK BUILD — SYNT_5: надёжность AUv3 в Logic, LFO, модуляция и голоса, микротюнинг + пользовательские пресеты

**Ветка:** `feat/auv3`  
**Базовый коммит:** `9a37b71`  
**Итоговый коммит:** `3236a49`  
**Статус:** Все 4 этапа полностью выполнены, протестированы и запушены в `origin/feat/auv3`.  
**Golden FNV Hash (Init):** `0xd1b3635203a4799e` сохранён бит-в-бит во всех тестах.  
**Высота сетки (Layout):** `SynthControlGrid` $\le 520\text{ pt}$ во всех темах (`ThemeID.allCases`).  
**AU Validation:** `AU VALIDATION SUCCEEDED` (`auval -v aumu Synt Nixr`).

---

## Этап 1 — Надёжность AUv3 в реальном времени (ПРИОРИТЕТ)

### Выполненные пункты:
1. **R1 (Elimination of ARC/Locks on Host Blocks):**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:120-136, 473-510`
   - Реализация: `musicalContextBlock` и `transportStateBlock` теперь захватываются единожды в `allocateRenderResources()` в `SyntRenderContext`. В `deallocateRenderResources()` они больше не обнуляются на лету во избежание гонок с завершающим рендером.
2. **R2 (Unmanaged / Unowned Audio Engine Dispatch):**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:138-149, 473-510`
   - Реализация: `internalRenderBlock` захватывает `SyntRenderContext` через `Unmanaged.passUnretained(renderContext)`. Контекст хранит `Unmanaged<AudioEngine>` и `Unmanaged<AddressedParameterStore>`, исключая retain/release ARC-счетчиков на аудиопотоке.
3. **R3 (Single-Writer Cached FX Order):**
   - Файлы:строки: `SynthCore/Audio/AudioEngine+Preset.swift:168`, `SynthCore/Audio/RTPresetBuffer.swift:107, 265`
   - Реализация: Главный поток больше не пишет напрямую в `cachedFXOrder` во время рендера. Порядок эффектов передается исключительно через двойной буфер `RTPresetBuffer`, а аудиопоток рендера является единственным писателем `cachedFXOrder`.
4. **R5 (Synchronous Preset Publication on fullState):**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:230-265`
   - Реализация: При установке `fullState` (например, при открытии проекта в Logic) снапшот пресета немедленно и синхронно публикуется через `rtPresetBuffer.publish(snapshot)`. Первые аудио-буферы звучат новым патчем без задержки на асинхронную диспетчеризацию `DispatchQueue.main`.
5. **Linear Parameter Ramping:**
   - Файлы:строки: `SynthCore/Audio/AudioEngine.swift:450-480`, `SynthCore/Audio/AudioEngine+Render.swift:160-205`
   - Реализация: Структура `ActiveParameterRamp` и метод `advanceParameterRampsRT()` выполняют посемпловую линейную интерполяцию для событий `.parameterRamp`.
6. **AU Properties:**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:20-55`
   - Реализация: `latency = 0`, `channelCapabilities = [0, 2]`, динамический `tailTime` (рассчитывается по времени delay и room size reverb).
7. **Program Change Toggle:**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:78-85, 237, 255`, `SynthUI/Views/HeaderView.swift:110-130`
   - Реализация: Состояние `respondsToProgramChange` (по умолчанию `false`) сохраняется в `fullState` и доступно для переключения в заголовке и меню настроек.

- **Коммит:** `3562431` (`feat(auv3): Step 1 - AUv3 real-time reliability and parameter ramping`)
- **Тесты:** `Synt_swiftUITests/AUv3ReliabilityTests.swift` (5 тестов: `r5RegressionFirstBufferAfterFullStateRendersNewPatchImmediately`, `parameterRampIsMonotonicOverFrames`, `tailTimeReportsCorrectlyForDelayAndReverb`, `latencyAndChannelCapabilities`, `respondsToProgramChangeRoundtripInFullState`). Все 5 passed.

---

## Этап 2 — LFO: триггер, фаза, синхронизация с Logic

### Выполненные пункты:
1. **LFO Modes & Start Phase:**
   - Файлы:строки: `SynthCore/Audio/LFO.swift:8-45`, `SynthCore/Models/SynthPreset.swift:209-214`, `SynthCore/Audio/AudioEngine+Voices.swift:328-335`
   - Реализация: Добавлены режимы `LFOMode` (`free`, `retrigger`, `oneShot`) и параметр начальной фазы `startPhaseDegrees` (0–360°). При ноте-он в режимах `retrigger` и `oneShot` вызывается `lfo.trigger()`.
2. **Синхро-деления с точкой и триолью:**
   - Файлы:строки: `SynthCore/Models/TimeDivision.swift:10-95`
   - Реализация: Добавлены все деления с точкой (`1/1D`...`1/32D`, множитель 1.5x) и триолью (`1/1T`...`1/32T`, множитель 2/3x) с точным расчетом `cyclesPerBeat`, `duration` и `frequency`.
3. **Фазовая привязка к транспорту хоста:**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:530-565`, `SynthCore/Audio/LFO.swift:44-50`, `SynthCore/Audio/AudioEngine+MIDIClock.swift:120-145`
   - Реализация: Хостовый блок `musicalContextBlock` считывает `currentBeatPosition`, передает в `adoptHostContext(...)`, который фазово выравнивает LFO через `syncPhase(beat:rateInCyclesPerBeat:)`.
4. **Арпеджиатор (Latch & AsPlayed):**
   - Файлы:строки: `SynthCore/Audio/ArpeggiatorEngine.swift:8-45`, `SynthCore/Audio/AudioEngine.swift:315-325`, `SynthCore/Audio/AudioEngine+Voices.swift:510-555`
   - Реализация: Добавлен режим `ArpeggiatorMode.asPlayed` с сохранением порядка нажатия клавиш `playedOrder` и флаг `arpLatch`. Аккорд удерживается после отпускания клавиш до нажатия нового аккорда.
5. **Публикация параметров:**
   - Файлы:строки: `SynthCore/Models/SynthParameterAddress.swift:99-104`, `SynthCore/Audio/SyntAudioUnit.swift:400-425, 460-465`
   - Реализация: Добавлены адреса 121..125 (`lfoMode`, `lfoStartPhase`, `lfo2Mode`, `lfo2StartPhase`, `arpLatch`) в дерево параметров AU.

- **Коммит:** `decfc97` (`feat(auv3): Step 2 - LFO trigger modes, phase sync, dotted/triplets, arp latch and asPlayed`)
- **Тесты:** `Synt_swiftUITests/LFOAndArpSyncTests.swift` (5 тестов: `retriggerModeResetsPhaseDeterministically`, `hostTransportBeatSyncAlignsPhase`, `dottedAndTripletTimeDivisionsCalculateExactIntervals`, `arpLatchHoldsNotesAfterNoteOff`, `arpAsPlayedPreservesExactKeyStrikeOrder`). Все 5 passed.

---

## Этап 3 — Модуляция и голоса

### Выполненные пункты:
1. **Кривая velocity и глубина velocity→громкость:**
   - Файлы:строки: `SynthCore/Models/SynthPreset.swift:775-785`, `SynthCore/Audio/AudioEngine+Render.swift:633-645`
   - Реализация: Добавлены `VelocityCurve` (`linear`, `exponential`, `logarithmic`) и параметр `velocityToVolume` (дефолт 1.0). Формула: `effectiveVel = 1.0 - velocityToVolume * (1.0 - curvedVel)`. При дефолтных значениях воспроизводит исходное выражение `max(0.15, min(1.0, velValue))` бит-в-бит. При `velocityToVolume == 0.0` громкость нот с любой силой нажатия одинакова (1.0).
2. **Третья огибающая MOD ENV (Env 3):**
   - Файлы:строки: `SynthCore/Models/SynthPreset.swift:765-775`, `SynthCore/Models/Note.swift:53-65`, `SynthCore/Audio/AudioEngine.swift:108`, `SynthCore/Audio/AudioEngine+Render.swift:440-455`
   - Реализация: В `SynthPreset` добавлены параметры огибающей (`modEnvAttack`, `modEnvDecay`, `modEnvSustain`, `modEnvRelease`). Каждый голос обрабатывает независимую огибающую `modEnvelope.process(...)`. Огибающая доступна в матрице как `ModSource.modEnv`.
3. **Новые источники матрицы модуляции:**
   - Файлы:строки: `SynthCore/Models/SynthPreset.swift:765-775`, `SynthCore/Audio/AudioEngine+Render.swift:125-150, 455-475`
   - Реализация: Добавлены `ModSource.pitchBend`, `ModSource.random` (per-voice xorshift32 без системного random), `ModSource.sampleAndHold` (дискретный stepped random из LFO).
4. **Режимы Glide и приоритет моно-нот:**
   - Файлы:строки: `SynthCore/Models/SynthPreset.swift:785-795`, `SynthCore/Audio/AudioEngine+Voices.swift:38-65, 170-205, 335-375`, `SynthCore/Audio/AudioEngine+Render.swift:400-415`
   - Реализация: Добавлен `GlideMode` (`time` и `rate`). В режиме `rate` время скольжения пропорционально интервалу (`semitones / 12.0`), октава скользит ровно вдвое дольше, чем тритон (6 полутонов). Реализован `glideLegatoOnly` (скольжение только при перекрытии нот). В `MonoNoteStack` добавлен выбор ноты `activeNote(priority:)` для `MonoPriority` (`last`, `low`, `high`).
5. **Публикация параметров адресов 126..134:**
   - Добавлены адреса в `SynthParameterAddress.swift`, `SynthPreset+ParameterValues.swift`, `AudioEngine+Parameters.swift`, `SyntAudioUnit.swift`.

- **Коммит:** `ad1e7be` (`feat(auv3): Step 3 - Velocity scaling, mod env 3, matrix sources, glide modes and mono priority`)
- **Тесты:** `Synt_swiftUITests/ModulationAndVoiceTests.swift` (6 тестов: `velocityToVolumeZeroGivesIdenticalLoudnessForDifferentVelocities`, `modEnvToPitchSettlesAfterDecayTime`, `randomToPanGivesSpreadAndIsDeterministicWithFixedSeed`, `rateGlideSlidesTwiceAsLongForOctaveThanSixSemitones`, `monoPrioritySelectsCorrectHeldNote`, `glideLegatoOnlyGlidesOnlyWhenOverlapping`). Все 6 passed.

---

## Этап 4 — Микротюнинг (.scl) и пользовательские пресеты в Logic

### Выполненные пункты:
1. **Парсер Scala (.scl) и таблица частот:**
   - Файлы:строки: `SynthCore/Utils/ScalaParser.swift:1-170`, `SynthCore/Audio/AudioEngine.swift:284-295`, `SynthCore/Audio/AudioEngine+Voices.swift:171, 337, 418`
   - Реализация: Создан `ScalaParser` для разбора формата Scala: фильтрация комментариев `!`, дескриптор, количество нот, поддержка центов (`100.0`, `1200.0`), дробей (`3/2`, `5/4`) и целых чисел (`2`). Метод `makeFrequencyTable` строит таблицу из 128 частот. `AudioEngine.customTuningTable` активирует кастомные частоты без аллокаций на RT-потоке. По умолчанию `customTuningTable == nil` (12-TET, сохранение golden хэша бит-в-бит).
2. **AU User Presets & App Group:**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:165-225`, `SynthCore/Utils/PresetManager.swift:12-40, 50-65`
   - Реализация: В `SyntAudioUnit` переопределены `supportsUserPresets = true`, `userPresets`, `saveUserPreset`, `deleteUserPreset`, `presetState(for:)`. `PresetManager` использует общую App Group `group.com.nixter.synt` (с безопасным фоллбэком на `.standard`), обеспечивая общий пул пользовательских пресетов между плагином и приложением.
3. **Группировка AUParameterTree и флаги:**
   - Файлы:строки: `SynthCore/Audio/SyntAudioUnit.swift:340-520`
   - Реализация: Параметры сгруппированы по секциям (`Oscillators`, `Envelopes`, `Filter`, `LFO`, `Effects`, `Performance`). Добавлены флаги `[.flag_DisplayLogarithmic]` и единицы измерения `.hertz`, `.seconds`, `.decibels`, `.cents`, `.pan` для частотных параметров (`filterCutoff`, `eqLowFreq`, `eqMidFreq`, `eqHighFreq`, `phaserCenterFrequency`).

- **Коммит:** `3236a49` (`feat(auv3): Step 4 - Microtuning scl parser, AU user presets and parameter tree grouping`)
- **Тесты:** `Synt_swiftUITests/MicrotuningAndUserPresetsTests.swift` (6 тестов: `scalaParserParsesCommentsDescriptionAndPitches`, `scalaParserParsesJustRatiosAndCents`, `scalaParserThrowsExpectedErrorsOnCorruptInputs`, `frequencyTableMatches12TETAndAltersPitchWhenApplied`, `auAudioUnitUserPresetsRoundTrip`, `parameterTreeHasLogarithmicFlagsOnFrequencies`). Все 6 passed.

---

## Итоговые результаты тестирования

### 1. `xcodebuild test`
```
Command: xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests

Executed all test suites in Synt_swiftUITests:
- InitGoldenTests: PASSED (hash 0xd1b3635203a4799e bit-identical)
- LayoutTests: PASSED (all themes <= 520 pt)
- AUv3ReliabilityTests: PASSED (5/5)
- LFOAndArpSyncTests: PASSED (5/5)
- ModulationAndVoiceTests: PASSED (6/6)
- MicrotuningAndUserPresetsTests: PASSED (6/6)
- SyntAudioUnitStateTests & RenderTests: PASSED
- Total: 0 failed (1 expected failure ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip recorded as expected).
Result: ** TEST SUCCEEDED **
```

### 2. Хвост вывода `auval -v aumu Synt Nixr`
```
FORMAT TESTS:

Reported Channel Capabilities (default config only):
      input:  0
      output: 2

* * PASS
--------------------------------------------------
RENDER TESTS:

Output Format: AudioStreamBasicDescription:  2 ch,  44100 Hz, Float32, deinterleaved
Render Test at 512 frames
Slicing Render Test at 64 frames
  PASS

Render Test at 64 frames, sample rate: 22050 Hz
Render Test at 137 frames, sample rate: 96000 Hz
Render Test at 4096 frames, sample rate: 48000 Hz
Render Test at 4096 frames, sample rate: 192000 Hz
Render Test at 4096 frames, sample rate: 11025 Hz
Render Test at 512 frames, sample rate: 44100 Hz
  PASS

Bad Max Frames - Render should fail
  PASS

Checking parameter setting
Using AudioUnitSetParameter
Using AudioUnitScheduleParameter
  PASS

Test MIDI
  PASS

* * PASS
--------------------------------------------------
AU VALIDATION SUCCEEDED.
--------------------------------------------------
```

---

## Что НЕ сделано (согласно разделу "Не входит (SYNT_6)")
Следующие пункты намеренно не реализовывались и отложены в соответствии со спецификацией задания:
- Drag-and-drop модуляции с визуальными кольцами на ручках и кривыми remap на маршрут.
- Рисуемый LFO / MSEG (многосегментный генератор огибающих).
- Пер-голосовая модуляция cutoff/resonance (сейчас фильтр общий, модулируется от ведущего голоса).
- Два фильтра серийно/параллельно, filter FM, warp-режимы осцилляторов, генератор шума как осциллятор.
- Режимы качества (draft/offline), полная поддержка MPE, кастомный алгоритмический ревербератор, теговый браузер пресетов, XY-pad.

---

## Открытые вопросы
1. **Файловый UI для импорта `.scl` в standalone / плагине**: Парсер и движок полностью поддерживают загрузку Scala и расчет 128-нотной таблицы. На этапе SYNT_6 можно добавить кнопку «Import Scala Tuning (.scl)» в UI вкладки настроек/Global.
2. **Поддержка кастомных файлов клавиатурных раскладок `.kbm`**: Сейчас парсер привязывается к стандарту Scala (нота 60 = C4 при 261.63 Hz или 69 = A4 при 440 Hz). При необходимости расширенной привязки белых/черных клавиш для произвольных микроинтервальных шкал (например, 19-EDO или 31-EDO) можно поддержать формат `.kbm`.
