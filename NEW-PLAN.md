# NEW-PLAN — Synt_swiftUI: улучшения для живой игры (Live Performance Pack)

Задание для исполнителя. После выполнения всех этапов результат проверяется автотестами и код-ревью.

---

## 🛡 Железные правила и архитектурные инварианты

1. **Ветка и Git-дисциплина**:
   - Ветка: `feat/phaser-control-rate`. В `main` ничего не мержить и не пушить. Без `force-push`.
   - Каждый этап (`Этап 1` … `Этап 4`) оформляется **отдельным атомарным коммитом**.
   - **Важно перед коммитом**: прогон тестов `GlassHorizonHangProbeTests` перезаписывает файл `GLASS_HORIZON_PROBE_DUMP.txt`. Перед каждым `git commit` проверяй `git status` и сбрасывай его:
     ```bash
     git restore GLASS_HORIZON_PROBE_DUMP.txt
     ```
2. **Зелёные тесты и эталонные хэши (`InitGoldenTests`)**:
   - После каждого этапа сборка и все тесты в `Synt_swiftUITests` должны быть на 100% зелёными.
   - Команда запуска тестов:
     ```bash
     xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests
     ```
   - Эталонный хэш `Init` (`0xd1b3635203a4799e`) и хэши всех 100 фабричных пресетов в `InitGoldenTests` проверяются **побитово (FNV-1a по `Float.bitPattern`)**. Все новые параметры в `SynthPreset` обязаны иметь нейтральные дефолтные значения, при которых математика `renderOneSample()` / `renderBlock()` для старых пресетов остаётся **100% bit-identical**.
   - Любое новое поле в `SynthPreset` декодируется через `decodeIfPresent`, проходит `sanitize()` в `SynthPreset+Sanitize.swift` и добавляется **в самый конец** параметров `init(...)`.
3. **Неприкосновенность Real-Time аудиопотока (`AVAudioSourceNode` / `renderOneSample` / `renderBlock`)**:
   - В аудиопотоке **ЗАПРЕЩЕНЫ**: выделение памяти в куче (`Array`, `Dictionary`, `String`, `Set`), `NSLock` / мьютексы, вызовы Swift ARC (`swift_retain` / `swift_release` / `[weak self]`), `print` / `os_log`, чтение `@Published var preset` напрямую и обращения к `DispatchQueue.main`.
   - **Строгое разделение SPSC-очередей**:
     - `commandQueue` — **только** для продюсера на `main` / UI-потоке.
     - `midiQueue` — **только** для продюсера на `CoreMIDI`-потоке (`MIDIHandler`). Никогда не пушь из `MIDIHandler` в `commandQueue` (два продюсера на одной SPSC-очереди приводят к data race)!
4. **Строгие ограничения UI и Тем (`LayoutTests`, `ThemeNoAudioChangeTests`, `ThemePerformanceRuleTests`)**:
   - Высота `SynthControlGrid` во всех 3 темах (`baseline`, `studio`, `retro`) **строго `<= 520 pt`** (сейчас `516 / 511 / 518 pt`, запас всего 2–9 pt!). Не добавляй новые вертикальные ряды в карточки — размещай новые кнопки/селекторы только в существующих шапках (`HStack`), `.menu` или `.popover`.
   - В папках `Audio/`, `Models/`, `Input/`, `Utils/` **ЗАПРЕЩЕНО** упоминать подстроки `"Theme"`, `".theme"`, `"@Environment"`, `"@EnvironmentObject"` (**даже в комментариях!** — проверяется тестом `ThemeNoAudioChangeTests`).
   - В папке `Views/` **ЗАПРЕЩЕНО** использовать `.blur(`, `Material`, `AppleTheme.` или два подряд `.shadow(` (проверяется тестом `ThemePerformanceRuleTests`).
5. **Открытые вопросы**:
   - Если в процессе реализации остаётся неоднозначность, не ломай существующее поведение: зафиксируй решение и впиши вопрос в раздел «Открытые вопросы» итогового отчёта `NEW-PLAN-REPORT.md`.

---

## ✅ Уже реализовано в кодовой базе (повторно не делать)
- **Синтез и голоса**: фиксированный пул на 32 голоса с мягким voice stealing (`beginFastRelease`), PolyBLEP и 11-уровневые FFT mip-maps для Wavetable (5 встроенных таблиц + слот `User` для импорта `.wav` 2048-sample), Sub-Oscillator, Linear FM (`Osc 2 → Osc 1`), Hard Sync, Ring Modulator (`Osc 1 × Osc 2`), цветной шум (`White / Pink / Brown`).
- **Фильтр и огибающие**: Per-voice Biquad фильтр, выделенная вторая огибающая `Env 2 (Filter)` (`filterEnvUseDedicatedADSR`), `filterKeyTracking`, чувствительность к силе нажатия клавиш (`velocityToCutoff`, `velocityToEnvAmount`), сглаживание cutoff / громкости / pitch bend.
- **Унисон и гармония**: до 5 партиалов на ноту, `unisonDetune`, равномощностная стерео-панорама `unisonSpread`, `analogDrift`, гармонический унисон `chordMode` (`Off`, `Octave`, `Fifth`, `Minor`, `Major`, `Sus4`), `portamento`.
- **Модуляция и секвенсор**: матрица модуляции `RTModMatrix` на 16 слотов (источники: `lfo1`, `env1`, `velocity`, `lfo2`, `modWheel`, `keyTrack`, `env2`), 2 LFO с BPM-синком (`TimeDivision`), Арпеджиатор с `arpGateLength` и `arpSwing`, 16-шаговый секвенсор с `Tie/Slide`, `Gate`, `Octave`, `Ratchet (1x–4x)` и `Probability (0–100%)`.
- **Эффекты и пресеты**: Distortion (с 2x FIR Oversampling), Parametric EQ, Phaser (control-rate), Stereo Chorus (`chorusStereo`), Ping-Pong Delay, Shimmer Reverb (`ShimmerProcessor`), 150 пресетов (100 Factory + 50 Expansion), поиск и `★ Favorites`, Program Change, 4 Performance Macros (`PerformanceMacros` в поповере `PresetView`), базовый `MIDICCLearnStore` (пока только для `ModDestination` с вызовом полного `preset = p`).

---

## 🎹 Этап 1. Aftertouch (Channel Pressure `0xD0` и Polyphonic Key Pressure `0xA0`)

### Что сделать:
1. **Декодирование MIDI 1.0 и UMP (`Input/MIDIMessageParser.swift`)**:
   - В `enum MIDIMessage` добавить:
     - `.channelPressure(Float, channel: UInt8)` — нормализованное давление `0…1` (`Float(d1) / 127.0`).
     - `.polyPressure(note: UInt8, pressure: Float, channel: UInt8)` — нота `0…127` (`d1`) и нормализованное давление `0…1` (`Float(d2) / 127.0`).
   - В `MIDIDecode.channelMessage(status:d1:d2:)` (около строки 69) обработать:
     - `case 0xD0: return .channelPressure(Float(d1) / 127, channel: channel)` (в `MIDIByteParser.feed` строка 123 уже знает, что `0xD0` имеет длину 1 байт данных `needed == 1`).
     - `case 0xA0: return .polyPressure(note: d1, pressure: Float(d2) / 127, channel: channel)`.
2. **Доставка в движок (`Input/MIDIHandler.swift`, `Audio/AudioCommandQueue.swift`, `Audio/AudioEngine.swift`)**:
   - В `AudioCommand` добавить:
     - `.setAftertouch(Float)` (`0…1`, non-critical)
     - `.setPolyAftertouch(midiNote: Int, pressure: Float)` (`0…1`, non-critical)
   - В `AudioEngine` добавить методы:
     - `func aftertouch(_ amount: Float)` (пушит в `commandQueue`) и `func midiAftertouch(_ amount: Float)` (пушит в `midiQueue`).
     - `func polyAftertouch(midiNote: Int, pressure: Float)` (пушит в `commandQueue`) и `func midiPolyAftertouch(midiNote: Int, pressure: Float)` (пушит в `midiQueue`).
   - В `MIDIHandler.dispatch(_:)` маршрутизировать `.channelPressure` → `audioEngine?.midiAftertouch(value)` и `.polyPressure` → `audioEngine?.midiPolyAftertouch(midiNote: Int(note), pressure: pressure)` + `activity.touch()`.
3. **Обработка, сглаживание и матрица модуляции (`Models/SynthPreset.swift`, `Models/Note.swift`, `Audio/AudioEngine+Render.swift`)**:
   - В `ModSource` (`SynthPreset.swift`) добавить `case aftertouch = "Aftertouch"`.
   - В `AudioEngine` добавить `var aftertouchTarget: Float = 0` и `var aftertouchSmoothed: Float = 0`.
   - В `ActiveNote` (`Note.swift`) добавить `var polyAftertouch: Float = 0` (сбрасывать в `0` в `activate()` и `deactivate()`). При получении `.setPolyAftertouch(midiNote, pressure)` обновлять `voices[i].polyAftertouch = pressure` у всех активных партиалов этой ноты, а также обновлять глобальный `aftertouchTarget` (например, как максимум или последнее значение, чтобы глобальные цели вроде `cutoff` / `lfoRate` тоже реагировали на poly pressure).
   - В `AudioEngine+Render.swift` добавить функцию `advanceAftertouch() -> Float` с one-pole сглаживанием ~5 мс (по образцу `advancePitchBend()`):
     - Если `aftertouchTarget == 0 && aftertouchSmoothed == 0`, мгновенно возвращать `0` без `exp()`, сохраняя 0 накладных расходов и 100% совпадение `InitGoldenTests`.
   - При `clearAll` и `applyMIDIResetRT()` сбрасывать `aftertouchTarget = 0`, `aftertouchSmoothed = 0`.
   - В `matrixSource(...)` передавать сглаженный aftertouch (для глобального прохода матрицы — `aftertouchSmoothed`, для голосового прохода — `max(aftertouchSmoothed, v.polyAftertouch)`).

### Тесты (`Synt_swiftUITests/LiveStep1AftertouchTests.swift`):
- Парсинг байтового потока (`MIDIByteParser`, включая running status) и UMP-слов (`MIDIDecode.ump`) для `0xD0` и `0xA0`.
- Маршрут модуляции `ModSource.aftertouch → .cutoff` (и per-voice цель, например `.vibrato` / `.pitch1` или `.amp` от `polyAftertouch`) заметно меняет спектр/уровень сигнала и плавно сглаживается без ступенек.
- Сохранение `InitGoldenTests`.

---

## 🎛 Этап 2. MIDI CC без перезагрузки пресета, расширенный Learn и шаблон «Samson Graphite 49»

### Проблема сейчас:
1. В `MIDIHandler.swift:305` входящий CC на CoreMIDI-потоке пушится в `engine.commandQueue` (нарушение SPSC, должно быть `engine.midiQueue`), а в `AudioEngine+Render.swift:773` `.controlChange` просто игнорируется (`break`).
2. На каждый тик CC вызывается `DispatchQueue.main.async`, где мутируется `engine.preset = p`, что триггерит полный `applyPreset()` (перезапись всех ~90 параметров, пересборку матрицы и фильтров).
3. `MIDICCLearnStore` умеет привязывать CC только к 13 целям `ModDestination`.

### Что сделать:
1. **Расширенный перечень параметров для MIDI Learn (`LearnableParameter` / расширение `MIDICCLearnStore`)**:
   - Сохранив обратную совместимость со старыми записями `ModDestination` в `UserDefaults`, расширить цели обучения (например, через `enum MIDIControlTarget: String, CaseIterable, Codable, Hashable` или расширенный маппинг), чтобы поддерживать:
     - Все 13 целей `ModDestination` (`cutoff`, `resonance`, `amp`, `pan`, `pitch1`, `pitch2`, `pwm1`, `pwm2`, `wtMorph1`, `wtMorph2`, `lfoRate`, `lfoDepth`, `mix`),
     - **ADSR (Amp & Filter)**: `attack`, `decay`, `sustain`, `release`, `filterAttack`, `filterDecay`, `filterSustain`, `filterRelease`, `filterEnvelopeAmount`,
     - **FX Mix & параметры**: `reverbMix`, `reverbRoomSize`, `reverbShimmer`, `delayMix`, `delayTime`, `delayFeedback`, `chorusMix`, `chorusRate`, `chorusDepth`, `distortionMix`, `distortionDrive`, `phaserMix`, `phaserRate`, `phaserDepth`,
     - **Синтез и Унисон**: `osc1Volume`, `osc2Volume`, `subOscVolume`, `fmAmount`, `ringModAmount`, `unisonDetune`, `unisonSpread`, `analogDrift`, `portamento`,
     - **4 Макроса**: `macro1`, `macro2`, `macro3`, `macro4`.
   - В `KnobView.swift` / `LargeKnobView.swift` автоматически разрешать `MIDIControlTarget` по `destination` или `label` (чтобы правый клик `Learn MIDI CC` работал на ручках ADSR, FX Mix, Drive, Shimmer, FM, Sub, Drift, Glide и Макросах).
2. **Прямая запись одного параметра в движок без вызова `applyPreset()`**:
   - Исправить `MIDIHandler.swift`: отправлять `.controlChange(cc: controller, value: value)` в `engine.midiQueue` (а не `commandQueue`).
   - В `AudioEngine` хранить lock-free таблицу привязок на 128 CC-контроллеров (например, `RTCCMap` с атомарным буфером или `UnsafeMutablePointer` на 128 слотов, обновляемым из `MIDICCLearnStore`).
   - В `AudioEngine+Render.swift` в `handleCommand(.controlChange(let cc, let value))` напрямую обновлять соответствующий параметр (`cachedFilterCutoff`, `filterL.resonance`, `envelope.attack`, `dspChorus.mix`, `distortion.mix`, `phaser.mix`, `cachedMacro1…4` и т.д.) за $O(1)$ в аудиопотоке **без вызова `applyPreset()`**.
   - На `main` потоке (для синхронизации UI-ручек и AU-эффектов `reverb`/`delay`, чьи AudioUnit-свойства обновляются на main) обновлять `preset` под флагом `isUpdatingSingleParamFromCC = true` (или через точечный метод `applySingleCCOnMain(target:normValue:)`), чтобы `preset.didSet` **не вызывал полный `applyPreset()`** (и счетчик вызовов `applyPreset` оставался неизменным).
3. **Аппаратный шаблон «Samson Graphite 49»**:
   - В `MIDICCLearnStore` добавить метод `applySamsonGraphite49Template()`, загружающий раскладку под MIDI-клавиатуру Samson Graphite 49:
     - **8 энкодеров (E1–E8, стандартный GM/Graphite банк CC 74, 71, 73, 75, 72, 91, 93, 94 или CC 20–27)**:
       - `CC 74` → Filter Cutoff (`cutoff`)
       - `CC 71` → Filter Resonance (`resonance`)
       - `CC 73` → Filter Env Amount (`filterEnvelopeAmount`)
       - `CC 75` → Wavetable Morph 1 (`wtMorph1`)
       - `CC 72` → FM Amount (`fmAmount`)
       - `CC 91` → Reverb Mix (`reverbMix`)
       - `CC 93` → Chorus Mix (`chorusMix`)
       - `CC 94` → Delay Mix (`delayMix`)
     - **Фейдеры (F1–F8: CC 20–27, Master F9: CC 7)**:
       - `CC 20..23` → Amp ADSR (`attack`, `decay`, `sustain`, `release`)
       - `CC 24..27` → Macros 1–4 (`macro1`, `macro2`, `macro3`, `macro4`)
       - `CC 7` → Master Volume (`amp`)
     - *(Если у пользователя на клавиатуре Samson Graphite 49 используется другой банк CC для фейдеров/энкодеров, вынести номера в константы `SamsonGraphite49CC` и упомянуть в «Открытых вопросах» отчёта).*
   - Добавить пункт меню для быстрой активации шаблона `Load Samson Graphite 49 Map` и `Clear All MIDI CC Mappings` (например, в меню MIDI-статуса или поповере `MACRO`, не увеличивая высоту сетки `<= 520 pt`).

### Тесты (`Synt_swiftUITests/LiveStep2CCAndTemplateTests.swift`):
- Приход сообщения `.controlChange` меняет целевой параметр в `AudioEngine` **без вызова полного `applyPreset()`** (проверить через счётчик `applyPresetCallCountForTesting`).
- MIDI CC Learn работает для параметров вне старого `ModDestination` (например, `reverbMix`, `attack`, `macro1`), корректно сохраняется и загружается из `UserDefaults`.
- Шаблон `Samson Graphite 49` корректно заполняет маппинги и управляет параметрами.

---

## 🎶 Этап 3. Режимы Poly / Mono / Legato и Макросы (`macro1…macro4`) как источники модуляции

### Что сделать:
1. **Режимы голосов `Poly / Mono / Legato`**:
   - В `SynthPreset.swift` добавить:
     ```swift
     enum VoiceMode: String, CaseIterable, Codable {
         case poly = "Poly"
         case mono = "Mono"
         case legato = "Legato"
     }
     ```
     и поле `var voiceMode: VoiceMode = .poly` (в конец `init`, `CodingKeys`, `decodeIfPresent`, санитизация в `SynthPreset+Sanitize.swift`). Старые и фабричные пресеты по умолчанию остаются `.poly`.
   - В `AudioEngine` добавить `var cachedVoiceMode: VoiceMode = .poly` и фиксированный стек удерживаемых нот для моно/легато без аллокаций в куче (`struct MonoNoteStack` со статическим буфером на 16 нот `(note: Int, velocity: Float)`).
   - **Логика `VoiceMode.mono` (Last-note priority, retrigger)**:
     - При `noteOn(N)`: нота `N` кладётся на вершину `monoNoteStack`. Все текущие активные голоса других нот переводятся в `beginFastRelease()` (6 мс анти-клик). Создаётся голос (или унисон-стек партиалов) для ноты `N` с перезапуском огибающих (`.attack`).
     - При `noteOff(N)`: нота `N` удаляется из `monoNoteStack` (с учётом педали сустейна, если нажата). Если отпущена звучащая верхняя нота, а в `monoNoteStack` ещё есть удерживаемая предыдущая нота `P`, движок автоматически возвращает ноту `P` с перезапуском огибающей! Если стек пуст — голос уходит в обычный `releaseHeldNote`.
   - **Логика `VoiceMode.legato` (Last-note priority, single-trigger & legato-only portamento)**:
     - Если стек `monoNoteStack` был пуст (первая нота фразы): нота `N` стартует как обычно с фазы `.attack`, причём `currentFrequency = targetFrequency` (портаменто **не** тянется от давно отпущенной ноты!).
     - Если в `monoNoteStack` уже удерживается нота `P` (связный переход легато к ноте `N`):
       - Нота `N` кладётся на вершину `monoNoteStack`.
       - Активные партиалы текущего звучащего голоса **НЕ переводятся в release и НЕ перезапускают огибающие** (`envelopePhase`, `envelopeValue`, `filterEnvelopePhase`, `filterEnvelopeValue` и фазы осцилляторов продолжают идти непрерывно!).
       - У активных партиалов обновляется `midiNote = N` и `targetFrequency` (с учётом расстройки унисона / аккорда). Если `cachedPortamento > 0.001`, `currentFrequency` плавно скользит к новой `targetFrequency`; если `cachedPortamento <= 0.001` — мгновенно переключается на `targetFrequency`.
     - При отпускании верхней ноты `N`, пока в `monoNoteStack` удерживается предыдущая нота `P`: активный голос **без ретриггера огибающей** плавно перестраивает `targetFrequency` обратно к ноте `P` (с портаменто, если `cachedPortamento > 0.001`).
   - В `UnisonView.swift` в верхней строке заголовка (`HStack`) добавить компактное меню выбора режима `POLY / MONO / LEGATO` (рядом с `CHORD` и `ARP`), соблюдая бюджет высоты `<= 520 pt`.
2. **Макросы `ModSource.macro1…macro4` в матрице модуляции**:
   - В `ModSource` (`SynthPreset.swift`) добавить:
     - `case macro1 = "Macro 1"`
     - `case macro2 = "Macro 2"`
     - `case macro3 = "Macro 3"`
     - `case macro4 = "Macro 4"`
   - В `SynthPreset` добавить поля `var macro1: Float = 0.0`, `var macro2: Float = 0.0`, `var macro3: Float = 0.0`, `var macro4: Float = 0.0` (диапазон `-1.0...1.0` или `0.0...1.0`, дефолт `0.0`, чтобы `InitGoldenTests` не менялся).
   - В `AudioEngine` добавить `cachedMacro1…cachedMacro4: Float = 0.0` и передавать их в `matrixSource(...)` (`AudioEngine+Render.swift`).
   - Связать ручки в `PerformanceMacrosPopover` (`PresetView.swift`) и MIDI CC (`macro1…macro4` из Этапа 2) с этими макросами, чтобы один макрос мог одновременно модулировать сколько угодно слотов в `ModMatrix` в реальном времени!

### Тесты (`Synt_swiftUITests/LiveStep3MonoLegatoMacrosTests.swift`):
- Стек нот в `mono`: нажать C4 → нажать E4 (звучит E4 с ретриггером) → отпустить E4 → автоматически возвращается C4.
- Режим `legato`: при связном переходе C4 → E4 огибающая не сбрасывается в 0 (фаза и уровень продолжают идти), а частота скользит по портаменто; при игре стаккато (отпустил C4, затем нажал E4) портаменто не скользит от старой ноты, а стартует сразу с E4.
- Один макрос (`ModSource.macro1`), назначенный в `modMatrix` на две цели сразу (например, `.cutoff` и `.pwm1` / `.pitch2`), синхронно двигает обе цели.

---

## ⚡ Этап 4. Оптимизация аудиопотока (Zero-ARC Callback & Block Render)

### Что сделать:
1. **Убрать `[weak self]` и `guard let self` из render callback (`Audio/AudioEngine.swift:244`)**:
   - Сейчас `AVAudioSourceNode` захватывает `[weak self]`, что на каждый аудио-буфер вызывает атомарный `swift_weakLoadStrong` / `swift_release` в real-time потоке.
   - Заменить на предварительный захват `let engineRef = Unmanaged.passUnretained(self)` перед созданием `AVAudioSourceNode`, а внутри рендер-блока получать ссылку через `let engine = engineRef.takeUnretainedValue()`.
   - В `deinit` гарантировать остановку `engine.stop()` до освобождения объекта.
2. **Блочный рендер (`renderBlock`) без изменения звука**:
   - В `AudioEngine.swift:253-265` сейчас указатели `ablPointer[0].mData?.assumingMemoryBound(to: Float.self)` вычисляются **на каждом сэмпле внутри цикла `for frame in 0..<frames`**.
   - Вынести получение `bufL` и `bufR` за пределы цикла по фреймам и реализовать метод `renderBlock(intoL: UnsafeMutablePointer<Float>, intoR: UnsafeMutablePointer<Float>?, frameCount: Int)`:
     - Вынести инварианты блока (чтение `rtModMatrix.snapshot()`, расчёт `samplesPerTick`, `glideRate`, флагов `perVoiceFilter`, формирование компактного списка индексов активных голосов `activeIndices`) на уровень блока/суб-блока там, где это не меняет побитовую точность, либо выполнять рендер фреймов в плотном цикле без лишних проверок буфера.
     - Использовать `renderBlock` также внутри `renderFramesMetricsForTesting` и `renderFramesDetailedForTesting` (через предвыделенный буфер в `AudioEngine`), чтобы ускорить как реальный `AVAudioSourceNode`, так и офлайн-рендер.
   - **Критическое требование к точности**: все 100 пресетов в `InitGoldenTests` должны остаться зелёными (либо совпасть 100% bit-identical, либо отличаться не более чем на `1e-6` с явным обоснованием).

### Тесты и бенчмарк (`Synt_swiftUITests/LiveStep4BlockRenderTests.swift`):
- Тест идентичности выхода `renderBlock` и по-сэмплового `renderOneSample()` (разница `<= 1e-6`, а для `InitGoldenTests` — зелёный статус).
- Бенчмарк 32 активных голосов (например, 200 буферов по 512 фреймов с замером `clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID)`): задокументировать время рендера в мс и % от 512-сэмплового буфера до и после оптимизации в `NEW-PLAN-REPORT.md`.

---

## 📋 Отчёт о выполнении (`NEW-PLAN-REPORT.md` в корне проекта)

По завершении всех 4 этапов создай файл `NEW-PLAN-REPORT.md` в корне репозитория со следующей структурой:
1. **По каждому этапу (Этапы 1–4)**:
   - Хэш коммита и сообщение коммита.
   - Список изменённых и созданных файлов (`file:line` и краткое описание).
   - Результаты прогона новых и существующих тестов.
   - Результаты бенчмарка 32 голосов (для Этапа 4: время до/после в мс и % от RT-бюджета).
2. **Открытые вопросы и архитектурные решения**:
   - Все принятые допущения (например, номера CC в шаблоне Samson Graphite 49, приоритет нот в Mono/Legato при зажатой педали сустейна и т.д.).
3. **Финальная верификация Git и тестов**:
   - Вывод `git log --oneline -6`.
   - Подтверждение, что ветка `main` не затронута, а рабочее дерево чистое (`git status`).

---

## 🔮 Следующий план (Этап 2 Live Pack — НЕ делать сейчас)
Фильтры ladder / notch / comb / formant / drive, синк с внешним MIDI clock (`0xF8` / `0xFA` / `0xFC`), перестановка порядка эффектов (FX Chain Reordering), Undo/Redo стек изменений пресета, расширенные теги в пресетах, AUv3 Audio Unit Extension для Logic Pro, микротюнинг (`.scl` / `.tun`), поддержка MPE.
