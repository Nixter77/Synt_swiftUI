# GROK BUILD — SYNT_3: AUv3-плагин для Logic Pro

Выполнять ТОЛЬКО после GROK_BUILD_TASKS_SYNT_FIX.md и GROK_BUILD_TASKS_SYNT_2.md.
Ветка: создать `feat/auv3` от текущей `feat/phaser-control-rate`. В main НЕ мержить.
Цель: синтезатор загружается в Logic Pro (macOS) как AU-инструмент (aumu), standalone-приложение продолжает работать.

## Общие правила (нарушение = этап не принят)
- RT-поток: никаких аллокаций, локов, ARC, обращений к main. Только SPSC-очереди (commandQueue / midiQueue).
- Golden FNV-хэши рендера должны совпадать бит в бит до и после каждого этапа.
- Новые поля пресетов — только через decodeIfPresent + sanitize.
- В Audio/Models/Input/Utils не ссылаться на Theme.
- Перед коммитом: `git restore GLASS_HORIZON_PROBE_DUMP.txt`.
- После каждого этапа: полный прогон тестов (ожидаемо: 1 skipped perf, 1 известный ChordHiss), коммит, push в feat/auv3.
- В отчёте честно перечислить, что НЕ сделано. Не писать «всё зелёное», если это не так.

## Этап 1 — Общий движок во фреймворке `SynthCore`
- Новый target: macOS framework `SynthCore`. Перенести туда Audio/ (кроме обвязки AVAudioEngine), Models/, Input/ (парсер MIDI), Utils/.
- Отделить ядро рендера от AVAudioSourceNode: публичный API вида
  `prepare(sampleRate:maxFrames:)`, `render(frames:into:)` (без аллокаций), `enqueueMIDI(_ bytes:, sampleOffset:)`, `setParameter(id:value:)`.
- Довести block render: `renderBlock` (AudioEngine.swift ~279-291) сейчас в цикле зовёт renderOneSample — допустимо оставить, но без аллокаций и с поддержкой разбиения блока по sampleOffset MIDI-событий.
- Standalone-приложение линкует SynthCore и звучит идентично (golden-хэши).
- Критерий: сборка app + тесты зелёные, хэши совпадают.

## Этап 2 — Audio Unit Extension (aumu)
- Новый target: Audio Unit Extension (AUv3, macOS), встроенный в приложение. Тип `aumu`, subtype/manufacturer — 4-символьные коды (например `Synt` / `Nixr`), задать в Info.plist (AudioComponents).
- Класс на AUAudioUnit: 1 выходная шина стерео, 0 входных; `internalRenderBlock` вызывает SynthCore.render, MIDI из AURenderEvent (.MIDI) идут в midiQueue с учётом eventSampleTime.
- `musicalContextBlock` / `transportStateBlock` хоста → темп и транспорт для арпеджиатора/LFO-sync (вместо MIDI clock, когда работаем как плагин).
- `maximumFramesToRender`, `allocateRenderResources` — всё выделение памяти только здесь.
- Критерий: `auval -v aumu Synt Nixr` проходит без ошибок (приложить вывод). Плагин виден в Logic в списке AU-инструментов.

## Этап 3 — Параметры, автоматизация, состояние
- AUParameterTree: все ручки основного экрана (осцилляторы, фильтр cutoff/res/type/drive, огибающие, LFO, эффекты, макросы) с постоянными адресами (enum с фиксированными UInt64 — менять нельзя после релиза).
- Изменения из хоста → SynthCore через commandQueue; изменения из UI → `parameter.setValue(_, originator:)`, чтобы Logic писал автоматизацию.
- `fullState` / `fullStateForDocument`: сохранять и восстанавливать текущий пресет (тот же Codable, что пресеты) + индекс выбранного пресета.
- `factoryPresets` / `currentPreset`: отдать заводские пресеты (двухуровневое меню категорий остаётся в UI, хосту — плоский список с префиксом категории, например «Bass: …»).
- Критерий: в Logic — автоматизация cutoff пишется и воспроизводится; проект сохраняется, закрывается, открывается — звук и пресет те же. Unit-тест: fullState → restore → golden-хэш совпадает.

## Этап 4 — Интерфейс плагина
- AUViewController (NSViewController) хостит существующий SwiftUI-экран через NSHostingView; размер ≤ высоты 520 pt, preferredContentSize задать явно.
- UI плагина работает с AUParameterTree (наблюдение через parameter observer token), а не напрямую с движком.
- Standalone-приложение: оставить как есть (оно же служит контейнером расширения).
- Критерий: открыть плагин в Logic, крутить ручки — звук меняется, автоматизация двигает ручки в UI; нет зависаний/утечек при открытии-закрытии окна плагина 10 раз.

## Отчёт
SYNT_3-REPORT.md: что сделано по этапам, хэши коммитов, вывод auval, результаты тестов, список НЕсделанного и рисков.
Инструкция для nixter: как установить (запустить приложение один раз, затем в Logic: Настройки → Плагины → Менеджер плагинов, при необходимости «Сбросить и повторить проверку»).

## Не входит (следующие файлы)
Undo/Redo + A/B, порядок FX, микротюнинг, MPE, AU MIDI FX-вариант.
