# SYNT_3 — отчёт

Ветка `feat/auv3`, база `96ef444`. `main` остаётся предком (`merge-base --is-ancestor` успешен). В `main` не мержилось и не пушилось. Force-push не было.

Init не менялся. Голден `0xd1b3635203a4799e` держится: его проверяет `SyntAudioUnitStateTests` и `InitGoldenTests` в полном прогоне.

Последний полный прогон, уже с интерфейсом плагина:

`xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests`

Верхний уровень (`xcresult` Test-Synt_swiftUI-2026.10.20_06-01-05-+0300), `xcrun xcresulttool get test-results summary`:

| | |
|---|---:|
| result | Passed |
| totalTestCount | 382 |
| passedTests | 379 |
| skippedTests | 2 |
| expectedFailures | 1 |
| failedTests | 0 |

Пропуски: `benchmark32VoicesCPU` и `RenderBudgetTests` (оба под `SYNT_RUN_PERF=1`). Лимит RenderBudget 50% не поднимался. Ожидаемый провал: `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`. На устройстве x86_64 `passedTests` 480 — это повторы Swift Testing, в таблицу они не входят. Раннер один.

Прогоны этапов 1 и 2 в логах `/tmp/synt-auv3-test2.log` и `/tmp/synt-auv3-s2-test2.log` закончились `TEST SUCCEEDED`. Их xcresult с диска уже нет, верхние счётчики заново не снимались. Этап 3 добавил 5 тестов состояния; этап 4 новых тестов не добавил, итог остался 382 / 379.

## Этап 1. Фреймворк SynthCore

Коммит `5fb703e` `feat(engine): extract SynthCore and a sample-accurate render API`.

Публичный API: `prepare(sampleRate:maxFrames:)`, `render(frames:into:)`, `enqueueMIDI(_:sampleOffset:)`, `setParameter(id:value:)`. Пустой MIDI-план рендерит блок целиком. События с `sampleOffset` режут блок. Standalone по-прежнему линкует фреймворк.

## Этап 2. Расширение aumu

Коммит `cf021b3` `feat(auv3): embed a sandboxed instrument extension`.

Тип `aumu`, subtype `Synt` (`0x53796E74`), manufacturer `Nixr` (`0x4E697872`). Один стереовыход, входов нет. `internalRenderBlock` зовёт `SynthCore.render`. MIDI из `AURenderEvent` пишется в заранее выделенный `midiSchedule` с sample offset, не в `midiQueue`: у очереди нет смещения, и её забирают в начале буфера. Темп и транспорт арпа и LFO-sync берутся из `musicalContextBlock` / `transportStateBlock`. `preset.bpm` хост не пишет. Буферы рендера выделяются только в `allocateRenderResources` от `maximumFramesToRender`.

Сандбокс включён только у appex (`SyntAUv3.entitlements`). Приложение остаётся без сандбокса и без hardened runtime. `SynthCore.framework` вложен и в приложение, и внутрь appex.

`auval -v aumu Synt Nixr` на копии в `~/Applications/Synt_swiftUI.app`: лог `/tmp/synt-auv3-auval5.log`, конец `AU VALIDATION SUCCEEDED`. Предупреждения, которые не завалили прогон: `CurrentPreset property is deprectated. AU should implement PresentPreset` и `Can Initialize Unit to un-supported num channels: InputChan:0, OutputChan:1`.

## Этап 3. Параметры, пресеты, документ

Коммит `d4d4513` `feat(auv3): publish parameters, factory presets, and document state`.

Адреса — `SynthParameterAddress`, дописываются только в конец. `osc2WavetableIndex` добавлен как 19, старые номера не сдвигались. Дерево: osc, env, filter, lfo, fx, performance. Единицы те же, что у ручек (cutoff в герцах), не кривая MIDI CC.

Поток:

- Событие параметра на аудиопотоке вызывает `applyAddressedParameterRT` напрямую. В `commandQueue` со звукового потока ничего не кладётся: очередь однопроизводительская, производитель — UI.
- Наблюдатель дерева на главном потоке пишет поле пресета и затем `setParameter` в `commandQueue`. Повтор того же абсолютного значения идемпотентен.
- Индексы волновых таблиц с аудиопотока не применяются (`break`): загрузка таблицы может выделить память. С главного потока пишется поле пресета, и `didSet` вызывает `applyPreset`.
- `reverbMix` и `reverbRoomSize` с аудиопотока тоже `break`: Apple Reverb не стоит в `renderOneSample`. Главный поток обновляет юнит.
- Резонанс на аудиопотоке сбрасывает `ccResonanceRT` в −1 и пишет `filterL/R.resonance`. Cutoff пишет только `cachedFilterCutoff`. Глубина LFO пишет только `cachedLfoDepth`.

`fullState` / `fullStateForDocument`: версия 1, JSON текущего пресета, индекс `PresetBrowser.index(of:)`. Если ключ пресета есть, пресет — источник правды, `super.fullState` повторно не назначается. `factoryPresets` — плоский `PresetBrowser.list` с префиксом категории (`Bass: Clean Sub`). Init в список не входит. Двухуровневое меню в UI осталось.

`SyntAudioUnitStateTests`: восстановление Init даёт голден `0xd1b3635203a4799e`; cutoff с аудиопотока пресет не пишет; cutoff с главного пишет пресет и кэш.

## Этап 4. Окно плагина

Коммит `71872bb` `feat(auv3): host the control grid in the audio unit view`.

Точка расширения `com.apple.AudioUnit-UI`. Главный класс `SyntAUViewController` (`AUViewController` + `AUAudioUnitFactory`). Старый `SyntAUFactory` удалён. `preferredContentSize` задан явно: `AUPluginMetrics` 1000 × 520. Сетка сажается в `NSHostingView` на главном потоке: хост вызывает `createAudioUnit` из XPC-очереди, и создание `NSHostingView` там роняло процесс (`SIGILL` в SwiftUI).

`SynthUI` — одна синхронизированная группа и у приложения, и у appex. Из appex исключены `Views/KeyboardView.swift` и `Views/Components/MIDIStatusView.swift`: они ссылаются на `KeyboardHandler` и `MIDIHandler`, которые остались в приложении. `ThemePerformanceRuleTests` смотрит `SynthUI/Views`.

Плагин показывает только `SynthControlGrid`, тема `Theme.baseline`, ширина 1000, высота 520, выравнивание по верху. Шапки, клавиатуры, кнопки play и выбора MIDI-устройства нет: они ходят в `SynthRuntime` и `engine.start()`, а AU движок не стартует. Загрузка пользовательской волновой таблицы в плагине скрыта (`audioEngine == nil`).

Ручки с адресом идут в `parameter.setValue(_:originator:)` с токеном наблюдателя, чтобы Logic писал автоматизацию. Поля без адреса (матрица, арп, секвенсор и остальное) на главном потоке пишутся в `uiPreset`. Наблюдатель хоста, если он не на главном потоке, делает `DispatchQueue.main.async`. Это скачок интерфейса, не рендер-колбэк. Рендер по-прежнему зовёт `applyAddressedParameterRT` и на main не переходит.

Повторный `auval -v aumu Synt Nixr` после смены класса и точки расширения, чистая подписанная копия без xctest в `~/Applications/Synt_swiftUI.app`, лог `/tmp/synt-s4-auval2.log`: `AU VALIDATION SUCCEEDED`, код 0. Кэш AudioUnit не удалялся. Предупреждения, прогон при этом прошёл:

- `CurrentPreset property is deprectated. AU should implement PresentPreset` — осталось. Отдельного `presentPreset` в API нет, `currentPreset` на `AUAudioUnit` и есть мост к `kAudioUnitProperty_PresentPreset`.
- моно: `Can Initialize Unit to un-supported num channels: InputChan:0, OutputChan:1`.
- Reverb Mix и Reverb Room не удерживают min/max: аудиопоток их не пишет, провайдер возвращает кэш (0.2 и 0.5).
- Osc 1 Wavetable и Osc 2 Wavetable не удерживают максимум 5: аудиопоток таблицу не грузит, провайдер возвращает загруженный индекс 0.
- Phaser Feedback зажимается до ±0.85 при запрошенных ±0.9.

79 глобальных параметров, все `-parameter PASS`. Рендер 512 / 64 / 4096 кадров, в том числе 4096 при 192 кГц, Bad Max Frames, MIDI и рампы — PASS. Рампы прищёлкиваются к значению события, внутри буфера не интерполируются.

## Установка

1. Собрать приложение и положить копию в `/Applications` или `~/Applications`. DerivedData само по себе компонент не регистрирует. После тестов в `PlugIns` может остаться `Synt_swiftUITests.xctest` — такую копию ставить не нужно. Сейчас в `~/Applications/Synt_swiftUI.app` лежит чистая сборка без тестового бандла.
2. Запустить приложение один раз.
3. Logic Pro → Настройки → Плагины → Менеджер плагинов. Если Synt не появился: выбрать его и «Сбросить и повторить проверку».
4. Подпись — Apple Development, не нотариус. `spctl --assess` такую копию отвергает. Локальный `auval` её грузит.

## Не сделано

- Logic не открывался. Окно плагина в Logic не крутилось. Десять открытий и закрытий окна не делались. Видимость в списке инструментов Logic не проверялась.
- Критерий «автоматизация cutoff в Logic пишется и воспроизводится, проект сохраняет звук» закрыт юнит-тестом `fullState` и `auval` (параметры и рампы PASS), не сессией Logic.
- Плагин показывает сетку ручек, не всё окно standalone.
- Apple Delay и Reverb в рендер-колбэке AU не звучат: граф `AVAudioEngine` не стартует. Их параметры в пресете сохраняются.
- Хост не пишет `preset.bpm`. Apple Delay остаётся на темпе пресета. Если delay tempo-sync включён, автоматизация свободного времени перезаписывает длительность деления до следующего `applyPreset`. Та же схема, что у LFO, специально не чинилась.
- Program Change через `pendingProgram` ставит пресет без отдельного хука дерева. Индекс для сохранения считается по имени при чтении `fullState`. До следующего sync значения в дереве могут отставать.
- `maximumFramesToRender` сеттер не перекрыт. Запасной путь для interleaved stereo (`right = left.advanced(by:)`) для чередующихся данных неверен; `auval` шёл deinterleaved Float32.
- `internalRenderBlock` захватывает `self` как `unowned`. Если хост переживёт блок дольше объекта, это падение.
- Включение фейзера, EQ и дисторшна с аудиопотока зовёт `reset()` по уже выделенным массивам.
- Сумма огибающей фильтра и маршрут матрицы на cutoff хранятся и не слышны. Живые назначения матрицы: pitch, amp, pan.
- Пользовательские пресеты и отрицательные номера `currentPreset` не делались.
- Тема плагина всегда baseline: `UserDefaults` appex — другой набор, не скин приложения.
- Undo/Redo, A/B, порядок FX, микротюнинг, MPE и AU MIDI FX не входят в это задание и не делались.

Открытые вопросы из `GROK_BUILD_SYNT_2_REPORT.md` не закрывались догадкой: filter ADSR / wtMorph / lfoDepth / cutoff не в one-pole CC; внешний клок не пишет `preset.bpm`; Continue (`0xFB`) продолжает без сброса фазы; LFO после CC плывёт до следующего `applyPreset`; кнопка play секвенсора публикует `SequencerTransport`, а EXT идёт только когда клок бежит; ladder при drive 0 всё ещё проходит `fastTanh` на единичном усилении; pan в пресете не хранится; подпись категории остаётся сырой `Arp / Seq`.
