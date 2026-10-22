# GROK_BUILD_TASKS_SYNT_2 — меню пресетов, живые ручки, темп Logic, ladder-фильтр

Делать ПОСЛЕ `GROK_BUILD_TASKS_SYNT_FIX.md`.

## Правила
- Ветка `feat/phaser-control-rate` (`git pull`, база не ниже `09464df`). В `main` ничего не мержить и не пушить, без force-push.
- Каждый этап — отдельный коммит, после него обычный `git push`. Перед каждым коммитом: `git restore GLASS_HORIZON_PROBE_DUMP.txt`.
- Тесты: `xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests`. Результат не должен стать хуже текущего.
- `InitGoldenTests` должны совпадать бит в бит. Новые поля пресета добавлять в конец, через `decodeIfPresent` и `sanitize()`, с нейтральными дефолтами.
- В аудиопотоке нельзя: аллокации, локи, ARC, print, `DispatchQueue.main`. `midiQueue` — только из CoreMIDI, `commandQueue` — только из UI.
- UI: высота `SynthControlGrid` не больше 520 pt во всех трёх темах. В `Audio/ Models/ Input/ Utils/` не упоминать "Theme" и "@Environment".
- Если что-то неясно — не угадывай, впиши в «Открытые вопросы» отчёта.

## Этап 1. Двухуровневое меню пресетов
- В `PresetView` меню «Категория → пресеты»: Bass, Lead, Pad, Keys, Pluck, Strings, Brass, Arp/Seq, FX, Expansion, ★ Favorites. Используй готовые категории из `PresetBrowser` / `FactoryPresets+Library`.
- Стрелки вверх и вниз по-прежнему листают все пресеты по порядку. Program Change N → пресет N+1 и счётчик `NNN / 100` не меняются.
- Тест: в каждой категории правильное число пресетов (Bass 15, Lead 15, Pad 14, Keys 13, Pluck 13, Strings 11, Brass 5, Arp/Seq 4, FX 10). Выбор из подменю загружает тот же пресет, что и по номеру.

## Этап 2. Сглаживание CC и soft takeover
- Сейчас pan, PWM, detune, mix, lfoRate и ADSR меняются сырыми 7-битными ступеньками (`AudioEngine+Render.swift:1047-1074`), из-за этого zipper-шум. Добавь one-pole сглаживание (~5–10 мс) в `applySingleParameterRT` (около :1037), по образцу `smoothedFilterCutoff`. Инициализируй сглаживание значением из пресета, а при |Δ| < 1e-6 сразу ставь целевое значение (против денормалов).
- Soft takeover в `applyCCBatchFromMIDI` (`AudioEngine+Preset.swift:277`): после смены пресета ручка начинает действовать, только когда её значение «догонит» текущее значение параметра.
- Проверь `ccResonanceBaseRT` (Render:1044): база не должна плыть при модуляции. Нужен тест.
- Тесты: шаг CC 0→127 даёт плавный переход без ступенек; soft takeover не даёт скачка после смены пресета.

## Этап 3. Синхронизация с Logic по MIDI clock
- `MIDIMessageParser.swift:118`: разбирай 0xF8 (clock, 24 на четверть), 0xFA Start, 0xFB Continue, 0xFC Stop. Realtime-байты могут приходить посреди других сообщений и не должны сбивать running status.
- Дальше через `midiQueue` в аудиопоток. Период сглаживай скользящим средним по 24 тикам. По Start сбрасывай фазу арпеджиатора, секвенсора и LFO, по Stop останавливай их. Никаких `DispatchQueue.main` на каждый тик.
- Новое поле `syncSource: .internal / .midiClock` с дефолтом `.internal`. Переключатель INT/EXT разместить в существующей шапке, без нового ряда.
- Тесты: парсер (в том числе F8 посреди NoteOn), поток F8 со 120 BPM даёт `cachedBPM` ≈ 120 ± 0.5, Start/Stop работают, `StepSequencerTimingTests` и голден-тесты зелёные.
- Нужен ручной шаг для nixter, впиши его в отчёт: Logic → File > Project Settings > Synchronization > MIDI, включить Clock для порта синтезатора.

## Этап 4. Ladder 24 dB, drive и notch
- `case ladder` и `case notch` добавляй в КОНЕЦ `FilterType` (`SynthPreset.swift:634`). Ветка в `CachedBiquadFilter.swift:231`, ladder — отдельная ZDF/TPT-реализация (Zavalishin, «The Art of VA Filter Design») с tanh-насыщением по Huovilainen, tanh через быструю аппроксимацию.
- Новое поле `filterDrive` с дефолтом 0. При drive = 0 и для LP/HP/BP путь обработки должен остаться прежним, бит в бит.
- Ladder не должен взрываться на максимальном резонансе при быстрой модуляции cutoff. Учитывай нагрузку при 32 голосах.
- Тесты: notch гасит частоту среза, ladder −24 dB/окт ± 3 dB, устойчивость на максимальном резонансе (нет NaN/Inf), голден-тесты зелёные.

## Отчёт `GROK_BUILD_SYNT_2_REPORT.md`
По каждому этапу: коммит, file:line, результат тестов, открытые вопросы. В конце: `git log --oneline -6` и подтверждение, что `main` не тронут.

## Следующее задание (не делать сейчас)
Undo/Redo и A/B-сравнение патча, AUv3 для Logic, порядок эффектов, микротюнинг, MPE.
