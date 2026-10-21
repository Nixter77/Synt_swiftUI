# Отчёт по GROK BUILD — SYNT_8: второй фильтр, форманта, MSEG

**Ветка:** `feat/auv3`  
**Базовый коммит:** `896ef85`  
**Итоговый коммит кода:** `bf73ccb`  
**Статус:** Все 4 этапа, правка потолка фабрики и правка банков фильтра / MSEG выполнены, протестированы и запушены в `origin/feat/auv3`. В `main` не вливалось. `main` не является предком `HEAD` (`git merge-base --is-ancestor main HEAD` завершается с кодом 1).  
**Golden FNV Hash (Init):** `0xd1b3635203a4799e`. Старые ключи `InitGoldenTests` не менялись. К словарю добавлены три новых патча.  
**Высота сетки:** компактный слот по-прежнему 1100×520. `LayoutTests/controlsSectionFitsInitInEveryTheme` прошёл на полном прогоне. Замер всех трёх тем: 968×520 (baseline src 416 / shape 692 / mod 114 / fx 342, studio 412 / 686 / 113 / 341, retro 418 / 693 / 117 / 347). Вкладка FILTER 2 стоит внутри панели FILTER. Редактор MSEG стоит внутри LFO в колонке MOD и по умолчанию свёрнут.

Номера строк ниже — итоговое дерево `bf73ccb`. Счётчики — верхний уровень `xcrun xcresulttool get test-results summary` полного прогона схемы на этом дереве. Повторы Swift Testing на устройстве в это число не входят: на устройстве passedTests 617 при тех же failed 0, skipped 2, expectedFailures 1. Ожидаемый провал один: `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`. Пропущены два теста, пока не задан `SYNT_RUN_PERF=1`: `RenderBudgetTests/renderBudgetForInitChordAndHeaviestFactory` и `LiveStep4PerfBenchmarks/benchmark32VoicesCPU`.

Новые адреса AU: группа `filter2` последняя в дереве, после `performance`. Адреса `filter2Cutoff` = 135, `filter2Resonance` = 136, `filter2Type` = 137, `filter2Balance` = 138, `filter2Routing` = 139 (`SynthParameterAddress.swift:115-119`). У vowel и MSEG отдельных адресов нет. Поля пресета идут через `decodeIfPresent`.

---

## Этап 1 — второй фильтр в голосе

Поля `filter2Routing` / `filter2Type` / `filter2Cutoff` / `filter2Resonance` / `filter2Balance` имеют значения по умолчанию Off, low pass, 2000 Гц, 0.2, 0.5 (`SynthPreset.swift:282-286`). Старый JSON без ключей получает те же значения (`SynthPreset.swift:786-790`). Класс `DSPDualFilter` по-прежнему стартует с `.serial`; у пресета и у RT-снимка маршрут по умолчанию `.off`.

На рендере второй фильтр вызывается только при `cachedFilter2Routing != .off` (`AudioEngine+Render.swift:969-979`). Serial берёт уже отфильтрованный сигнал, Parallel — сухой до первого фильтра, затем смесь по balance. Off этот блок не входит, и рендер совпадает с прежним путём сэмпл в сэмпл. Буферы голоса готовятся в `prepare` / `allocateRenderResources`, не внутри `renderOneSample`. `DSPDualFilter` и `DSPFormantFilter` стоят рядом с пулом, не внутри `ActiveNote` (`AudioEngine.swift:150-152`): копия голоса в `renderOneSample` их не удерживает. У каждого слота свой экземпляр, пул собирается через `map`. `resetVoiceToneBanks` зовётся при включении и выключении слота.

Группа AU `filter2` создаётся последним ребёнком дерева (`SyntAudioUnit.swift:572-585`). Вкладка внутри `FilterView`: кнопка с идентификатором `filter2Tab` (`FilterView.swift:38`). При выключенной вкладке высота панели FILTER прежняя. Порядок маршрута в UI: Off, Serial, Parallel.

**R6-1.** Неконечный вход обратной связи принудительно становится NaN до фильтра (`AudioEngine+Render.swift:891-892`), потому что лестница, biquad и `fastTanh` сами приводят NaN к конечному числу. Ветка восстановления обнуляет `filterFeedbackState`, возвращает сухой сигнал и вызывает `v.filter.reset()` (`AudioEngine+Render.swift:927-932`). Конечный путь обратной связи прежний.

- **Коммит:** `79b0034` (`feat(filter): second voice filter, off by default, and feedback NaN reset`)
- **Тесты:** `Synt_swiftUITests/Stage8FilterTests.swift`. `offMatchesTheDefaultRender` сравнивает Off с рендером по умолчанию. `serialAndParallelChangeTheSpectrum` и `maxResonanceStaysFinite` гоняют `AudioEngine`. `nonFiniteFeedbackResetsTheVoiceFilter` травит состояние активного голоса и проверяет сброс biquad. `filter2GroupIsLastInTheParameterTree` читает живое дерево AU.

---

## Этап 2 — форманта

`FilterType.formant` добавлен в конец перечисления после ladder (`SynthPreset.swift:865`). Назначение `ModDestination.vowel` добавлено после `reverbMix` (`SynthPreset.swift:1029`). Поле `filterVowel` по умолчанию 0, диапазон sanitize 0…4. Максимум индекса типа фильтра и Filter 2 равен 5. Имена типов AU: Low Pass, High Pass, Band Pass, Notch, Ladder, Formant.

Голос при типе Formant обходит biquad, лестницу и обратную связь и зовёт `voiceFormant[i].process` (`AudioEngine+Render.swift:879-883`). `vowelNow` считается только когда Filter 1 или Filter 2 стоит в Formant: база плюс мод, умноженный на 4, зажатый в 0…4 (`AudioEngine+Render.swift:476-479`). Иначе гласная равна 0 и формантный `process` не вызывается. Filter 2 в режиме Formant пишет `voiceDual[i].vowel` и идёт через свой `DSPFormantFilter` (`AudioEngine+Render.swift:976-978`). MIDI-цель `.vowel` отображается на существующий cutoff и не расширяет перечисление CC.

- **Коммит:** `417413d` (`feat(filter): append formant and a vowel matrix destination`)
- **Тесты:** `Synt_swiftUITests/Stage8FormantTests.swift`. Тип, отличный от Formant, с ненулевой гласной совпадает с рендером по умолчанию. Свип гласной на пиле не даёт щелчка относительно соседней дельты. Шум через форманту конечен на 44100×10 сэмплах. Filter 2 Formant (serial, balance 1) отличается от Off и остаётся конечным.

---

## Этап 3 — MSEG как источник модуляции

`ModSource.mseg` = «MSEG 1» добавлен после `smoothRandom` (`SynthPreset.swift:978`). Поле пресета `mseg` по умолчанию пустое (`MSEGPreset`, `points: []`). Пустой пресет остаётся пустым: декодер `MSEGPreset` сортирует и зажимает точки и не подставляет двухточечный запасной контур (`DSPMSEG.swift:141`). Декодер `DSPMSEGModel` сортирует по времени, зажимает time 0…1, value и curve −1…1, обрезает до 32 точек и на пустом списке ставит две точки (`DSPMSEG.swift:89-101`). **R6-9.**

Движок держит один `DSPMSEG`. Инициализатор свойства сразу вызывает `publishEmpty()`, так что живой банк пуст, пока пресет не опубликует точки. `applyPreset` на главном потоке сначала публикует банк, затем ряд матрицы (`AudioEngine+Preset.swift:19-20`, тело `publishMSEG` на строке 53). Пустой список уходит в `publishEmpty()`, непустой — в `DSPMSEGModel`. Снимок аудиопотока массив точек не читает. `pushSampleRateToDSP` зовёт `mseg.prepare` (`AudioEngine.swift:694`), так что тик идёт с живой частотой, а не с 44100 из инициализатора.

**R6-11.** `publish` пишет времена, значения и кривые в простаивающий банк и только потом release-store индекса (`DSPMSEG.swift:235-255`). `tick` / `trigger` / `evaluate` читают банк по acquire-load. `publishEmpty` индекс банка меняет и поле `model` не трогает (`DSPMSEG.swift:259-266`). На рендер-потоке копии `[Float]` нет.

Тик стоит в `renderOneSample` и выполняется, когда ряд матрицы просит `.mseg` или у банка есть точки (`AudioEngine+Render.swift:293-300`). Gate — любой голос `isActive && !isReleasing`. Темп — `Double(cachedBPM)`. `handleNoteOn` первой строкой зовёт `mseg.trigger()` (`AudioEngine+Voices.swift:387`). `trigger` сбрасывает фазу при режиме retrigger или когда генератор ещё не идёт.

**R6-10.** После `phase >= 1` ветка петли уже не сработала: если кривая one-shot или у неё есть точка сустейна, фаза ставится в 1, `isRunning` становится false, возвращается последний сэмпл (`DSPMSEG.swift:340-345`). Дальнейшие тики держат это значение. Свободный прогон без сустейна и без one-shot по-прежнему заворачивается через `truncatingRemainder`. Пустой банк в `tick` обнуляет `currentValue` и возвращает 0 (`DSPMSEG.swift:300-303`), а не последний уровень.

Редактор в `LFOView`: кнопка `msegEditor` (`LFOView.swift:33`), по умолчанию свёрнут. Развёрнутый `MSEGPointEditor` пишет только `preset.mseg` (`LFOView.swift:186`). Идентификаторы чипов: `msegAdd`, `msegDelete`, `msegSync`, `msegSustain`, `msegLoop`. Подписи ручек Hz / Beats / T / V / C, чтобы «Rate» не учил CC LFO.

- **Коммит:** `ae4dfaa` (`feat(mseg): route MSEG 1 through an atomic bank`)
- **Тесты:** `Synt_swiftUITests/Stage8MSEGTests.swift`. Пустой пресет не тикает и совпадает с рендером по умолчанию. `presetSwapPublishesTheIdleBank` меняет банк и читает `evaluate`. `releaseWithoutLoopStopsAndHoldsTheLastValue` и `freeRunWrapsWhenThereIsNoSustain` идут через `AudioEngine`. Отдельные тесты покрывают retrigger, петлю, темп хоста без записи `preset.bpm`, пустой JSON и сортировку с зажимом при загрузке. `DSPMSEGTests` на этом дереве прошли вместе с `Stage8MSEGTests`.

---

## Этап 4 — модули и три демо

Модули перенесены из `Experimental` в рабочие папки. Живых копий под `Experimental` нет. `project.pbxproj` вручную не правился: файлы подхватывает синхронизированная группа.

- `SynthCore/DSP/Filters/DSPFormantFilter.swift`
- `SynthCore/DSP/Filters/DSPDualFilter.swift`
- `SynthCore/DSP/Modulation/DSPMSEG.swift`
- Тесты: `DSPFormantFilterTests.swift`, `DSPDualFilterTests.swift`, `DSPMSEGTests.swift`

Три новых фабричных пресета стоят в конце `libraryPresets` (`FactoryPresets+Library.swift:18`, `+ stage8Presets`). Срез showcase `all.count - libraryPresets.count - 20` из-за этого не сдвигается, и `ShowcasePresetTests` не редактировался. Тела старых пресетов и их хэши не трогались. Init не менялся.

`stage8Presets` (`FactoryPresets+Stage8.swift:11`):

| Имя | Категория | Что показывает | Хэш |
| --- | --- | --- | --- |
| Serial Glass Bass | bass | Filter 2 serial, band pass 1600 Гц, resonance 0.28, balance 0.62, master 0.38 | `0x1ea5c0b72c4da973` |
| Vowel Ah Lead | lead | `filterType` Formant, `filterVowel` 1.4, master 0.75 | `0xa56a54294ad9f208` |
| MSEG Drift | fx | треугольник, ряд MSEG → pitch 1 с amount 0.08, три точки, 0.7 Гц, retrigger, master 0.36 | `0xa58c55976732614f` |

Хэши дописаны в конец словаря `InitGoldenTests` (строки 119–121). Комментарий: «Stage 8 demos, captured when the three patches were added.»

Счётчики: фабрика 103, библиотека 45. Меню категорий: bass 16, lead 16, fx 11, остальные прежние (`LibraryPresetTests.swift:20-22`, `PresetBrowserTests.swift:67-69`). Программа 41 по-прежнему тот же пресет, счётчик строится от длины списка (`ProgramChangeTests.swift:25-26`), сейчас это `042 / 103`. Программа за концом библиотеки — `PresetBrowser.list.count` и 127 (`ProgramChangeTests.swift:36-37`).

- **Коммит:** `60bb2ad` (`feat(dsp): move wired modules out of Experimental and add three demos`)

Первый полный прогон схемы на `60bb2ad` остановился на трёх проверках: счётчик `042 / 100`, program change 100 загружал новый «Laser Zap», master Vowel Ah Lead 0.85 не проходил потолок `masterVolume <= 0.75` (`Synt_swiftUITests.swift:569`). Правка: master демо 0.75 (`FactoryPresets+Stage8.swift:45`), проверки program change смотрят на длину библиотеки. Хэш Vowel Ah Lead переснят в `0xa56a54294ad9f208`. Хэши Serial Glass Bass и MSEG Drift с первого снятия не менялись. Init остался `0xd1b3635203a4799e`.

- **Коммит:** `db0d440` (`fix(preset): keep the formant demo under the factory caps`)

---

## Поправка после проверки

Четыре места, которые полный прогон `db0d440` не ловил.

1. **Частота MSEG.** `pushSampleRateToDSP` готовит остальные блоки и зовёт `mseg.prepare(sampleRate:)` (`AudioEngine.swift:694`). Тик на 48 кГц больше не шагает фазу как при 44100.
2. **Копия голоса.** `dual` и `formant` убраны из `ActiveNote`. Банки лежат в `voiceDual` и `voiceFormant`. Рендер берёт их по индексу слота только когда тип Formant или маршрут Filter 2 не Off. Сброс — `resetVoiceToneBanks` на note-on, steal и конце огибающей.
3. **fullState с фонового потока.** `adoptPreset` публикует банк MSEG в том же синхронном блоке, что снимок и матрицу, и делает это до ряда `.mseg` (`SyntAudioUnit.swift:326-330`). Главный поток потом применяет пресет ещё раз. Буфер между этими шагами уже видит новую кривую.
4. **Пустой банк.** `tick` при `pointCount == 0` возвращает 0. Ряд матрицы после удаления всех точек не держит прошлый уровень.

- **Коммит:** `bf73ccb` (`fix(dsp): keep filter banks off the voice copy and publish MSEG in time`) — итоговый коммит кода.
- **Тесты:** `Stage8MSEGTests/beatsAt48kDoNotAdvanceAt44100` рендерит 4410 сэмплов при 48 кГц, 120 BPM и 4 долях и ждёт фазу 4410/96000, а не 4410/88200. `deleteAllPointsRendersZeroInsteadOfTheLastLevel` после `renderOneSample` ждёт `currentValue == 0`. `SyntAudioUnitStateTests/backgroundFullStatePublishesTheMSEGBankBeforeMain` ставит `fullState` с фонового потока и до хода на main рендерит кадр с кривой −1. `Stage8FilterTests/activeNoteCopyDoesNotRetainFilterBanks` проверяет, что у `ActiveNote` нет полей-классов, а банки слотов — отдельные экземпляры.

---

## Полный прогон схемы

Команда: `xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -only-testing:Synt_swiftUITests` на дереве, которое закоммичено как `bf73ccb`.

- **xcresult:** `Test-Synt_swiftUI-2026.10.21_07-06-12-+0300.xcresult`
- **Верхний уровень:** result Passed, passedTests 513, failedTests 0, skippedTests 2, expectedFailures 1, totalTestCount 516. `testFailures` пуст. Среда: Synt_swiftUI, сборка под macOS 15.7.4.
- В логе есть `** TEST SUCCEEDED **` и `EXIT:0`.
- `LayoutTests/controlsSectionFitsInitInEveryTheme` в этом прогоне прошёл.
- Прогон `db0d440` до этой правки: `Test-Synt_swiftUI-2026.10.21_06-26-47-+0300.xcresult`, passedTests 509, failedTests 0, skippedTests 2, expectedFailures 1, totalTestCount 512. Четыре новых теста в те цифры не входят.

`project.pbxproj` после сборки чистый. В `membershipExceptions` таргета SyntAUv3 (набор `B20000EX`) по-прежнему только `Info.plist`. Набор `C10000EX` по-прежнему исключает `Views/Components/MIDIStatusView.swift` и `Views/KeyboardView.swift`. `CODE_SIGN_ENTITLEMENTS = SyntAUv3/SyntAUv3.entitlements` на месте.

---

## Что не проверялось в Logic

- Logic не открывался. Окно плагина и наложения панелей этой сессией не смотрелись.
- `auval -v aumu Synt Nixr` для SYNT_8 не запускался.
- Приложение в `~/Applications` этой сборкой не обновлялось. Кэш Audio Unit не чистился.
- `spctl --assess` в этой сессии не запускался.
