# GROK_BUILD_SYNT_2 — отчёт

Ветка `feat/phaser-control-rate`. `main` не мержился и не пушился.
База этапа — не ниже `09464df`. Init не менялся: `InitGoldenTests` зелёные на каждом этапе.

Полный прогон после этапа 4:

`xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests`

Верхний уровень (`xcresult` Test-Synt_swiftUI-2026.10.20_04-02-36-+0300):

| | baseline после FIX | сейчас |
|---|---:|---:|
| totalTestCount | 360 | 373 |
| passedTests | 357 | 370 |
| skippedTests | 2 | 2 |
| expectedFailures | 1 | 1 |
| failedTests | 0 | 0 |

Пропуски те же: `benchmark32VoicesCPU` и `RenderBudgetTests` (оба под `SYNT_RUN_PERF=1`). Ожидаемый провал тот же: `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`. Лимит RenderBudget 50% не поднимался. На устройстве `passedTests` 471 — это повторы, в таблицу выше они не входят. Новые тесты подняли итог на 13.

## Этап 1. Меню категорий

Коммит `d9a55d6` `feat(presets): add a category menu that keeps program numbers`.

- Меню: `Synt_swiftUI/Views/PresetView.swift:29` (категории, Expansion, ★ Favorites, Browse All…). Идентификатор `presetCategoryMenu` на строке 87.
- Группировка: `Synt_swiftUI/Utils/PresetBrowser.swift:22` `presets(in:)`.
- Подпись категории — сырое значение, у арпеджио это `Arp / Seq`.
- Стрелки и Program Change не трогались. Счётчик `NNN / 100` на месте (`presetCounter`, строка 71).

`PresetBrowserTests`: Bass 15, Lead 15, Pad 14, Keys 13, Pluck 13, Strings 11, Brass 5, Arp/Seq 4, FX 10. Выбор из подменю совпадает с пресетом по номеру программы. Голдены зелёные.

## Этап 2. Сглаживание CC и soft takeover

Коммит `7e121f9` `fix(midi): glide zipper CC and pick up knobs after a preset change`.

- One-pole ~8 мс: `Synt_swiftUI/Audio/AudioEngine+CCSmoothing.swift:144` `advanceCCSmoothers`. Вызов в начале `renderOneSample`. Pan, PWM, detune, mix, lfoRate и amp ADSR идут через цель. При `|Δ| < 1e-6` значение прищёлкивается, равные цель и живое значение не пишутся.
- Привязка к пресету: `snapCCTargetsFromLive` в `AudioEngine+Preset.swift:188`.
- Soft takeover: `ccTakeoverShouldApply` в `AudioEngine+CCSmoothing.swift:200`. Биты старта — все пойманы. Сброс только при реальной смене патча (`disarmCCTakeover`, строка 173). Первый `applyPreset` из `init` takeover не взводит.
- Резонанс: база пишется один раз на CC, `AudioEngine+Render.swift:1111` `ccResonanceBaseRT = filterL.resonance`. Пока база на месте, модуляция её не переназначает (`:353`).

`CCSmoothingTests`, обновлённые `LiveStep2` (attack ждёт оседания ~8000 кадров) и pan в `ModMatrixTests`, `InitGoldenTests` — зелёные.

## Этап 3. MIDI clock Logic

Коммит `8aa8bac` `feat(midi): follow Logic clock without leaving the audio thread`.

- Парсер: `Synt_swiftUI/Input/MIDIMessageParser.swift:128`. `0xF8/FA/FB/FC` возвращаются, не трогая running status, `dataCount` и `inSysEx`. `F9/FD/FE/FF` по-прежнему игнорируются.
- В аудиопоток: `MIDIHandler.swift:328` кладёт clock/start/continue/stop в `midiQueue`. `DispatchQueue.main` и `activity.touch()` на тик нет.
- Период: среднее 24 интервалов, `AudioEngine+MIDIClock.swift:25` `receiveMIDIClockRT`. Транспорт: `:56` `applyMIDITransportRT`.
- Поле в конце пресета на тот момент: `SynthPreset.swift:198` `syncSource`, дефолт `.internal`, `decodeIfPresent`.
- INT/EXT в существующей шапке BPM: `ContentView.swift:264` и кнопка `syncSourceToggle` на `:278`. `headerBPM` (`:190`) показывает `externalTempo`, только когда источник `.midiClock` и темп ≥ 20.
- Публикация темпа: `AudioEngine+Metering.swift:33`, порог 0.5. `preset.bpm` с аудиопотока не пишется.
- Clock и транспорт двигают арп, секвенсор и LFO только при `syncSource == .midiClock`. Внутренний путь — прежний код, поэтому `StepSequencerTimingTests` и голдены остались бит-в-бит.

`MIDIClockTests` (F8 внутри NoteOn, 120 BPM ± 0.5, Start/Stop/Continue), парсер, `StepSequencerTimingTests`, `InitGoldenTests` — зелёные.

Ручной шаг для nixter: Logic → File > Project Settings > Synchronization > MIDI, включить Clock для порта синтезатора. Переключатель на панели — EXT.

## Этап 4. Ladder, notch, drive

Коммит `fc423eb` `feat(filter): add a ladder, a notch and drive`.

- `FilterType`: `SynthPreset.swift:658` `.notch`, `:659` `.ladder` — в конце перечисления.
- `filterDrive` дефолт 0, после `syncSource`: `SynthPreset.swift:201`. `decodeIfPresent` и `SynthPreset+Sanitize.swift:160` (0…1, нейтраль 0).
- Notch, RBJ band-reject: `CachedBiquadFilter.swift:256`. Для `.ladder` коэффициенты — lowpass (`:264`), чтобы `a0` не был 0. Голосовой путь их не использует. Та же ветка в неиспользуемом `Filter.swift:64` и `:72`.
- Лестница: `Synt_swiftUI/Audio/LadderFilter.swift`. TPT Завалишина, `k` не выше 3.8. Вклад состояния в обратную связь умножен на `(1 − G)`. Вход и каждый полюс через `AudioMath.fastTanh` (`AudioMath.swift:34`). Состояние на `ActiveNote`, сброс в `activate`/`deactivate`.
- Голос: `AudioEngine+Render.swift:639`. При `.ladder` срез пересчитывается каждый сэмпл. При drive ≠ 0 и не ladder вход биквада идёт через tanh с усилением `1 + drive * 8`. При drive = 0 и LP/HP/BP вызов прежний: `v.filter.process(amplitude, coeffs: voiceCoeffs)`.
- Кэш drive: `AudioEngine.swift:122`, запись в `AudioEngine+Preset.swift:165`.
- Крутилка Drive — шестая в том же ряду: `FilterView.swift:70`. Нового ряда нет.

`LadderFilterTests`: notch гасит 1 кГц относительно 4 кГц; лестница −24 дБ/окт ± 3 дБ (4 кГц против 8 кГц при срезе 1 кГц); резонанс 1 и свип среза без NaN/Inf, пик < 8; 32 голоса, пик рендера < 1.5. `LayoutTests/controlsSectionFitsInitInEveryTheme` прошёл, высота сетки ≤ 520, крутилка Drive осталась. `InitGoldenTests` зелёные.

## Открытые вопросы

- В one-pole попали pan, PWM, detune, mix, lfoRate и amp ADSR. Filter ADSR, wtMorph и lfoDepth в тексте этапа не названы и не сглаживаются. Cutoff тоже остаётся мгновенным.
- Внешний clock не пишет `preset.bpm`. В режиме EXT шапка показывает темп clock, слайдер по-прежнему редактирует внутренний BPM и не заблокирован.
- Start сбрасывает фазу арпа, секвенсора и обоих LFO и запускает их. Stop останавливает и отпускает ноты, фазу не обнуляет. Continue продолжает без сброса фазы. В задании по имени разобраны Start и Stop; Continue прочитан как MIDI Real Time (0xFB).
- При tempo-sync LFO `applyPreset` прищёлкивает живую частоту к доле. Следующий CC ведёт уже свободную частоту до следующего `applyPreset` и не пересинхронизируется каждый сэмпл. Soft takeover сравнивает `preset.lfoRate` на main и синхронизированный `lfo.rate` на аудио, пока ручка не догонит.
- Кнопка play секвенсора по-прежнему публикует `SequencerTransport`. При EXT аудиопоток шагает, только когда clock запущен. Отдельной блокировки кнопки нет.
- CC громкости osc2 делит поле `oscillator2.volume` с mix, поэтому оба пишут одну цель и оба сглаживаются.
- При drive 0 лестница всё равно пропускает вход через `fastTanh` с усилением 1 и насыщает каждый полюс. Бит-в-бит обязательство относится к LP/HP/BP при drive 0. Крутизна мерилась синусом амплитуды 0.05, где аппроксимация почти линейна.
- Pan в пресет не сохраняется.

## git log --oneline -6

```
fc423eb feat(filter): add a ladder, a notch and drive
8aa8bac feat(midi): follow Logic clock without leaving the audio thread
7e121f9 fix(midi): glide zipper CC and pick up knobs after a preset change
d9a55d6 feat(presets): add a category menu that keeps program numbers
735bcfc docs: record Grok Build fix results in NEW-PLAN-REPORT.md
d8851d3 test: run RenderBudgetTests only when SYNT_RUN_PERF=1
```

Лог снят до коммита этого отчёта. `main` и `origin/main`: `e9c2eb520590efd8e16bd84cde37ba1324bdbbe8`. Это предок ветки. Force-push не было.
