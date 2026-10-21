# Отчёт по GROK BUILD — SYNT_7: баги SYNT_6, реверб в AUv3, звук, модуляция

**Ветка:** `feat/auv3`  
**Базовый коммит:** `eb69415`  
**Итоговый коммит кода:** `dac22fb`  
**Статус:** Все 4 этапа выполнены, протестированы и запушены в `origin/feat/auv3`. В `main` не вливалось. `main` не является предком `HEAD`.  
**Golden FNV Hash (Init):** `0xd1b3635203a4799e`. На полном прогоне этапа 4 прошли `InitGoldenTests` и `ModMatrixTests/initHashStaysTheGolden`. Init не переводился на DSP-реверб: у Init `reverbMix` равен 0.2, и включённый флаг сдвинул бы хэш.  
**Высота сетки:** компактный слот по-прежнему 1100×520. `LayoutTests` прошли на полном прогоне этапа 4. XY-пад стоит в UNISON, не в матрице. Бюджет прокрутки матрицы остаётся 260 pt, проверка высоты — не выше 340 pt.  
**Новые адреса AU-параметров:** не добавлялись. Последний адрес остаётся `monoPriority` = 134. Новые поля идут через `decodeIfPresent` и `sanitize()`, в RT попадают только через `RTPresetSnapshot`.

Номера строк ниже — итоговое дерево `dac22fb`. Счётчики — верхний уровень `xcrun xcresulttool get test-results summary`. Повторы Swift Testing на устройстве в это число не входят. Ожидаемый провал во всех четырёх прогонах один: `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`. Пропущены два теста, пока не задан `SYNT_RUN_PERF=1`: `RenderBudgetTests/renderBudgetForInitChordAndHeaviestFactory` и `LiveStep4PerfBenchmarks/benchmark32VoicesCPU`.

---

## Этап 1 — баги SYNT_6

1. **B1.** Ветка обратной связи фильтра без drive ограничена `AudioMath.fastTanh` (`AudioEngine+Render.swift:893`). `fb` остаётся в диапазоне sanitize −1…1. Нулевая ветка по-прежнему вызывает лестницу, drive и обычный `v.filter.process` (`AudioEngine+Render.swift:901`).
2. **B2.** NaN/Inf проверяется до записи состояния (`AudioEngine+Render.swift:895-899`). Неконечный выход обнуляет `filterFeedbackState` и возвращает сухой сигнал до фильтра. Поздняя проверка `if !amplitude.isFinite { amplitude = 0 }` перед trance остаётся.
3. **B3.** При `tranceHostLocked` шаг берётся из `tranceHostBeat` (`AudioEngine+Render.swift:177-191`). `adoptHostContext` ставит лок, когда у хоста есть `beatPosition`, и не пишет `preset.bpm` (`AudioEngine+RenderAPI.swift:172`). Без бита хоста курсор по-прежнему свободный.
4. **B4.** Haas. `lastHaasMs` стартует с −1 (`DSPStereoTool.swift:22`). Очистка буфера и кроссфейд около 5 мс выполняются только когда задержка поднимается с 0 (`DSPStereoTool.swift:62-67`). Старт уже с 10 мс по-прежнему находит импульс на индексе задержки.
5. **B5.** `RTModMatrix.lookup` линейно интерполирует соседние точки таблицы (`RTModMatrix.swift:90-96`). Линейная кривая по-прежнему считает `source * amount` и таблицу не читает (`AudioEngine+Render.swift:166-171`).

- **Коммит:** `6452221` (`fix(dsp): bound filter feedback, lock the trance gate, and de-click Haas`)
- **Тесты:** `Synt_swiftUITests/Stage7BugTests.swift`
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_03-42-02-+0300.xcresult`. Passed 465, failed 0, skipped 2, expectedFailures 1, total 468. Result: Passed.

---

## Этап 2 — реверб в AUv3

Свой Freeverb-подобный реверб. Один буфер выделяется в `allocate(sampleRate:)`, `process` на RT ничего не выделяет (`DSPReverb.swift:87`). Вызов allocate — из `AudioEngine.prepare`, `pushSampleRateToDSP` и `SyntAudioUnit.allocateRenderResources`.

Флаг `dspReverbEnabled` по умолчанию false (`SynthPreset.swift:261`). Старый JSON без ключа остаётся выключенным (`SynthPreset.swift:761`). При выключенном флаге слот `.reverb` делает только прежний shimmer. При включённом флаге wet смешивается по Mix, затем shimmer, если он больше нуля. Ручка Damping видна только при включённом флаге (`FXChainView.swift:535`, `EffectsView.swift:150`). Apple `AVAudioUnitReverb` остаётся в автономном графе и не является путём рендера AU.

- **Коммит:** `44f65bd` (`feat(fx): add a default-off DSP reverb for the Audio Unit`)
- **Тесты:** `Synt_swiftUITests/Stage7ReverbTests.swift`. Ключ отсутствует — рендер совпадает с явным false. В AU при Mix > 0 после note-off остаётся хвост.
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_03-48-24-+0300.xcresult`. Passed 467, failed 0, skipped 2, expectedFailures 1, total 470. Result: Passed.

---

## Этап 3 — звук

Всё по умолчанию выключено.

1. **Фиксированная частота OSC 2.** `osc2FixedFrequency` false, `osc2FrequencyHz` 440. Перезапись частоты стоит внутри `if cachedOsc2Fixed` и не трогает OSC 1. Кнопка HZ на шапке OSC 2, идентификатор `osc2FixedFrequency`. Ручка Hz видна только при включённом флаге.
2. **Scene HPF.** One-pole до цикла FX, только при `cachedSceneHPF` (`AudioEngine+Render.swift:963`). Карточка свёрнута, пока флаг выключен (`FXChainView.swift:22`, `sceneHPFCard` со строки 89). Сброс состояния на переходе включено→выключено и в `resetPatchStateRT`.
3. **Ensemble.** `ChorusMode.ensemble` добавлен в конец перечисления. `DSPChorus.process` уходит в ensemble только если флаг включён (`DSPChorus.swift:58`), иначе прежний путь фленджера и тела хоруса, включая ранний выход `mix <= 0.001`. Кнопка ENS, идентификатор `chorusEnsemble` (`FXChainView.swift:347`). ENS и FLNG взаимно исключают друг друга.

- **Коммит:** `ebbde71` (`feat(sound): add fixed OSC 2, a scene high-pass and chorus ensemble`)
- **Тесты:** `Synt_swiftUITests/Stage7SoundTests.swift`
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_03-54-12-+0300.xcresult`. Passed 470, failed 0, skipped 2, expectedFailures 1, total 473. Result: Passed.

---

## Этап 4 — модуляция и управление

Pan уже был среди 13 назначений. В конец `ModDestination` добавлены Fine Pitch, FM, Chorus Mix, Delay Mix, Reverb Mix (`SynthPreset.swift:998`). Сырые значения старых кейсов не сдвинуты. Пикер матрицы — явный список, не `allCases`: Fine и FM в секции Oscillator, FX — отдельная секция (`ModMatrixView.swift:112`). MIDI-цели переиспользуют существующие адреса (`finePitch` → pitch 1, `fm` → fm amount, миксы — свои CC). Новых адресов нет.

1. **Fine pitch.** На голос, только если сумма ряда не ноль (`AudioEngine+Render.swift:638`). Множитель `pow(2, clamp(fine)/12)` применяется после фиксированной частоты OSC 2 и до ограничения 20 Гц…0.45×rate.
2. **FM ratio.** `fmRatioEnabled` false, coarse 1, fine 0, маршрут OSC2→OSC1. При выключенном флаге и нулевом `fmMod` остаётся прежнее выражение `s2 * fmAmount * Float.pi` (`AudioEngine+Render.swift:707`). Ненулевой ряд FM меняет глубину и при выключенном ratio. При включённом ratio coarse+fine зажаты в 0.25…32. Маршрут OSC1→OSC2 сначала считает OSC 1 и модулирует фазу OSC 2. Кнопка RATIO на OSC 2, идентификатор `fmRatio`. Coarse, fine и маршрут `fmRoute` видны только при включённом флаге.
3. **Миксы FX.** Chorus, delay и reverb копятся в глобальном проходе, не на каждом голосе. Нулевой мод не пишет `dspChorus.mix` и `pingPongDelay.mix`. Ненулевой мод зажимает сумму в 0…1 на время слота и возвращает базу после цикла (`AudioEngine+Render.swift:976-984`, восстановление на строке 1051). Reverb читает локальный `reverbMixNow`, кэш пресета не переписывается.
4. **XY-пад.** Только UI. Пишет `macro1` и `macro2` в диапазоне −1…1 (`MacroXYPad.swift:9`, идентификатор `macroXYPad`). Стоит в `UnisonView` после ряда Poly. На аудиопотоке нового кода нет: макросы уже кэшируются прежним `applyPreset`.

Фабричные showcase-пресеты не перенастраивались. Тест покрытия исключает пять новых назначений вместе с wt morph, чтобы не менять их звук.

- **Коммит:** `dac22fb` (`feat(mod): add fine pitch, FM ratio and FX destinations`)
- **Тесты:** `Synt_swiftUITests/Stage7ModTests.swift` (старый JSON оставляет ratio выключенным и рендер совпадает; ratio и маршрут меняют ноту; fine с amount 0 совпадает с нотой без ряда; chorus mix открывает молчащий хорус; отображение XY). `ModMatrixTests/everyDestinationChangesTheSignal` и `allPairsStayFiniteUnderTheCeiling` покрывают новые назначения. Целевой прогон `Stage7ModTests` + `LayoutTests` + `ModMatrixTests` прошёл до полного набора (`/tmp/synt-s7-mod.log`, TEST SUCCEEDED).
- **Полный прогон:** `Test-Synt_swiftUI-2026.10.21_04-07-56-+0300.xcresult`. Passed 475, failed 0, skipped 2, expectedFailures 1, total 478. Result: Passed. На устройстве passedTests 576 — это повторы Swift Testing. `** TEST SUCCEEDED **`, EXIT:0 в `/tmp/synt-s7-full4.log`.

`project.pbxproj` после сборки чистый. В `membershipExceptions` таргета SyntAUv3 по-прежнему только `Info.plist`. `CODE_SIGN_ENTITLEMENTS = SyntAUv3/SyntAUv3.entitlements` на месте.

---

## Что не проверялось в Logic

- Logic не открывался. Окно плагина и наложения панелей этой сессией не смотрелись.
- `auval -v aumu Synt Nixr` для SYNT_7 не запускался.
- Приложение в `~/Applications` этой сборкой не обновлялось. Кэш Audio Unit не чистился.
- `spctl --assess` в этой сессии не запускался.

---

## Отложено на SYNT_8

Формантный фильтр и остальное из ROUND5. Параллельный трек SYNT_7B (формант, MSEG, второй фильтр) в это дерево не вносился и в `feat/auv3` не влит.
