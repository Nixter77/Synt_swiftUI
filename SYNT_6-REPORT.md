# Отчёт по GROK BUILD — SYNT_6: сетка плагина, стерео и голоса, модуляция, фленджер и обратная связь фильтра

**Ветка:** `feat/auv3`  
**Базовый коммит:** `3236a49`  
**Итоговый коммит кода:** `10efc9f`  
**Статус:** Все 4 этапа выполнены, протестированы и запушены в `origin/feat/auv3`. В `main` не вливалось. `main` не является предком `HEAD`.  
**Golden FNV Hash (Init):** `0xd1b3635203a4799e`. На полном прогоне этапа 4 прошли `InitGoldenTests/initAndFactoryPresetsRenderBitIdenticalToGolden` и остальные тесты, которые сверяют этот хэш.  
**Высота сетки:** компактный слот по-прежнему 1100×520. `LayoutTests` прошли на каждом полном прогоне.  
**Новые адреса AU-параметров:** не добавлялись. Последний адрес остаётся `monoPriority` = 134. Новые поля звука идут через `decodeIfPresent` и `sanitize()`, в RT попадают только через `RTPresetSnapshot`.

Счётчики ниже — верхний уровень `xcrun xcresulttool get test-results summary`. Повторные прогоны Swift Testing на устройстве в это число не входят. Ожидаемый провал во всех четырёх прогонах один: `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`. Пропущены два теста, пока не задан `SYNT_RUN_PERF=1`: `RenderBudgetTests/renderBudgetForInitChordAndHeaviestFactory` и `LiveStep4PerfBenchmarks/benchmark32VoicesCPU`.

---

## Этап 1 — сетка плагина без наложений (приоритет)

Панели больше не рисуются масштабом фиксированного холста 1100×520. Восемь панелей (`osc1`, `osc2`, `adsr`, `filter`, `unison`, `lfo`, `matrix`, `fx`) стоят в четырёх колонках.

1. **Раскладка.** `SynthUI/SynthControlGrid.swift:77` (`PluginColumnLayout`) и `SynthCore/Models/AUPluginMetrics.swift:90` (`frames`). Колонки: OSC1/OSC2, ADSR/FILTER/UNISON, LFO/MATRIX, FX. Пересечение уже 0.5 pt считается касанием края.
2. **Две конфигурации вида.** `SynthCore/Audio/SyntAudioUnit.swift:93-109`. `supportedViewConfigurations` возвращает все предложенные хостом конфигурации. `select(_:)` ставит `.extended`, если высота больше 520, иначе `.compact`, и шлёт `chromeDidChangeNotification` на главном потоке. Базовые размеры: компакт 1100×520, расширенный 1440×760 (`AUPluginMetrics.swift:70-87`).
3. **Зум 75/100/125/150/200.** `PluginZoom` в `AUPluginMetrics.swift:17-28`. Меню `pluginZoomMenu` в `SyntAUv3/SyntAUViewController.swift:237`. Зум меняет `preferredContentSize` (`SyntAUViewController.swift:23`), а не `scaleEffect`. В `fullState` ключ `syntUIChrome` (`SyntAudioUnit.swift:84`). Нет ключа — зум 100 и компактная раскладка. Версия состояния не повышалась.

- **Коммит:** `557ad35` (`feat(ui): tile plugin panels so they never overlap, with zoom and view configurations`)
- **Тесты:** `Synt_swiftUITests/PluginLayoutTests.swift` — `tiledFramesDoNotIntersectAtEachZoomAndLayout`, `hostedPanelsDoNotIntersectAtEachZoomAndLayout`, `compactPreferredHeightStaysWithinTheCap`, `chromeZoomRoundTripsThroughFullState`, `viewConfigurationsSelectCompactOrExtended`.
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_01-36-51-+0300.xcresult`. Passed 439, failed 0, skipped 2, expectedFailures 1, total 442. Result: Passed. На устройстве passedTests 540 — это повторы Swift Testing.

---

## Этап 2 — стерео и голоса

Всё по умолчанию выключено или совпадает с прежним поведением. При выключенном стерео `DSPStereoTool.process` не вызывается.

1. **Стерео в FX.** Width 0…2 (дефолт 1), Mid/Side −1…1 (дефолт 0), Haas 0–30 мс на правом канале, моно-бас ниже заданной частоты. Движок вызывает инструмент только при `cachedStereoEnabled` (`AudioEngine+Render.swift:909`). Буфер Haas на 8192 сэмпла выделяется в `init`. Сброс — на переходе включено→выключено и в `resetPatchStateRT`.
2. **Фаза осциллятора.** `OscPhaseMode` добавлен в конец: Reset / Free / Random, дефолт Reset (`SynthPreset.swift:758`). В `Note.swift:138-140` три присваивания Reset не менялись. Free возвращает фазы, снятые до них (`Note.swift:141-144`). Random перезаписывает их хешем ноты (`Note.swift:145-159`). Меню только на OSC 1, идентификатор `oscPhaseMode` (`OscillatorView.swift:67`).
3. **Полифония пресета.** `polyphonyLimit` 1…32, дефолт 32 (`SynthPreset.swift:237`). `sanitize` зажимает 0 в 1 (`SynthPreset+Sanitize.swift:182`). В `findFreeVoiceSlot` при лимите 32 или ≤ 0 верхняя граница остаётся `AudioEngine.maxVoices` (`AudioEngine+Voices.swift:287-303`). Степпер Poly в `UnisonView.swift:131`.

- **Коммит:** `dee05a8` (`feat(voice): add a default-off stereo tool, oscillator phase modes and a polyphony limit`)
- **Тесты:** `Synt_swiftUITests/Stage6VoiceTests.swift`, 10 тестов: `missingKeysDecodeToStereoOffResetPhaseAndFullPolyphony`, `sanitizeClampsStereoAndPolyphony`, `widthZeroCollapsesAStereoPair`, `haasDelaysTheRightChannel`, `monoBassCentersAConstantStereoOffset`, `resetPhaseMatchesVoiceStartPhases`, `freePhaseKeepsTheSlotAndRandomIsStable`, `defaultPolyphonyStillUsesLaterSlots`, `polyphonyLimitOfOneKeepsASingleSlot`, `stereoOffLeavesARepeatedRenderIdenticalAndWidthZeroCentersUnison`.
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_01-53-00-+0300.xcresult`. Passed 449, failed 0, skipped 2, expectedFailures 1, total 452. Result: Passed.

---

## Этап 3 — модуляция

1. **Trance Gate.** 16 шагов, деление темпа, depth, smoothing. Дефолт выключен (`tranceGateEnabled` в `SynthPreset.swift:240`). Шаг часов один раз до цикла голосов (`AudioEngine+Render.swift:447-449`, `advanceTranceGateRT` со строки 175). Умножение амплитуды стоит после фильтра (`AudioEngine+Render.swift:814-816`). Карточка FX «Trance Gate», шаги `tranceStep0`…`tranceStep15`. Это не новый `FXSlotID`.
2. **Smooth random (Perlin).** Источник `ModSource.smoothRandom` добавлен в конец перечисления (`SynthPreset.swift:916`). Генератор крутится только если какой-то слот матрицы его читает (`AudioEngine+Render.swift:262-270`). На Init слотов нет, `advanceCount` остаётся 0. Темп-синк пишет `cachedPerlinHz` из деления и не трогает `preset.bpm` (`AudioEngine+RenderAPI.swift:157-159`). Карточка «Smooth Random» свёрнута. В шапку матрицы ручка не ставилась: бюджет высоты матрицы ≤ 340 pt.
3. **Кривые маршрутов.** `ModCurve`: linear, exponential, logarithmic, sCurve, steps (`SynthPreset.swift:817`). Линейный маршрут остаётся `source * amount` без таблицы (`AudioEngine+Render.swift:164-171`). Остальные кривые читают банк 16×256, который заполняется вне аудиопотока и публикуется через atomic swap (`RTModMatrix.swift:30-80`).

- **Коммит:** `9dfc9cf` (`feat(mod): add a trance gate, smooth-random source and matrix remap curves`)
- **Тесты:** `Synt_swiftUITests/Stage6ModTests.swift`, 6 тестов: `legacyMatrixJSONDecodesLinearAndNewFieldsStayOff`, `linearCurveMatchesTheRawProductAndExponentialDoesNot`, `publishedCurveTableMatchesTheRemapAndLinearSkipsIt`, `tranceGateOffDoesNotAdvanceAndAnEmptyPatternGoesQuiet`, `smoothRandomIsDeterministicAndStaysIdleWithoutARoute`, `tempoSyncPublishesTheDivisionRate`.
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_02-03-31-+0300.xcresult`. Passed 455, failed 0, skipped 2, expectedFailures 1, total 458. Result: Passed.

---

## Этап 4 — фленджер и обратная связь фильтра

Оба параметра по умолчанию выключены: фленджер false, feedback 0, filter feedback 0.

1. **Фленджер поверх хоруса.** `DSPChorus.flanger` и `feedback` (`DSPChorus.swift:32-33`). Первая строка `process` уходит во фленджер только если флаг включён (`DSPChorus.swift:54`). Дальше прежние ранний выход `mix <= 0.001` и тело хоруса. Фленджер: центр около 3 мс, глубина до 2 мс, минимальная задержка 0.3 мс, feedback зажат в −0.95…0.95, в линию задержки пишется вход плюс задержанный сигнал (`DSPChorus.swift:96-120`). Синк подменяет `dspChorus.rate` только когда включены и фленджер, и sync (`AudioEngine+Preset.swift:130-134`, хостовый темп в `AudioEngine+RenderAPI.swift:160-162`). Кнопка FLNG на карточке хоруса, идентификатор `chorusFlanger` (`FXChainView.swift:314-327`). Ручка feedback и FREE/SYNC видны только при включённом фленджере. Новый слот FX не добавлялся.
2. **Filter → mixer feedback.** Дефолт 0. При нуле выполняются прежние вызовы лестницы, drive и `v.filter.process(amplitude, coeffs:)` (`AudioEngine+Render.swift:779-812`). Ненулевая ветка считает `fed = amplitude + filterFeedbackState * cachedFilterFeedback`, прогоняет фильтр и записывает выход в `filterFeedbackState` (`AudioEngine+Render.swift:742-778`). Состояние голоса обнуляется в `activate` (`Note.swift:89`, `Note.swift:193`). Ручка Feedback стоит второй строкой и не раздувает ряд из шести ручек (`FilterView.swift:73-76`). `sanitize`: chorus feedback −0.95…0.95, filter feedback −1…1, NaN → 0 (`SynthPreset+Sanitize.swift:188-190`).

- **Коммит:** `10efc9f` (`feat(fx): add a default-off chorus flanger and filter feedback`)
- **Тесты:** `Synt_swiftUITests/Stage6SoundTests.swift`, 4 теста: `missingKeysLeaveFlangerAndFeedbackOff`, `chorusBodyIsUnchangedUntilFlangerIsEnabled`, `syncSetsTheFlangerRateOnlyWhileFlangerIsOn`, `zeroFeedbackMatchesTheDefaultPathAndANonZeroValueChangesIt`. Целевой прогон этих тестов вместе с `LayoutTests` и `PhaseV2EffectsTests` прошёл до полного набора.
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_02-08-51-+0300.xcresult`. Passed 459, failed 0, skipped 2, expectedFailures 1, total 462. Result: Passed. На устройстве passedTests 560 — повторы Swift Testing. `** TEST SUCCEEDED **`, EXIT:0 в `/tmp/synt-s6-full4.log`.

`project.pbxproj` после сборки чистый. В `membershipExceptions` таргета SyntAUv3 по-прежнему только `Info.plist`. `CODE_SIGN_ENTITLEMENTS = SyntAUv3/SyntAUv3.entitlements` на месте.

---

## Что не проверялось в Logic

- Logic не открывался. Наложение OSC 2 / FILTER / LFO / UNISON при View 161% проверялось геометрией `PluginLayoutTests` на каждом зуме и обеих раскладках, а не окном Logic.
- `auval -v aumu Synt Nixr` для SYNT_6 не запускался. Последний успешный `AU VALIDATION SUCCEEDED` относится к сборкам до SYNT_6.
- Приложение в `~/Applications` этой сборкой не обновлялось. Кэш Audio Unit не чистился.
- `spctl --assess` в этой сессии не запускался.

---

## Отложено на SYNT_7

Остаток ROUND4 и прежний список SYNT_6: MSEG, MPE, два фильтра, браузер пресетов и соседние пункты. Undo/Redo, A/B, перестановка FX, микротюнинг сверх уже сделанного парсера `.scl` и AU MIDI FX в этот отчёт не входили.
