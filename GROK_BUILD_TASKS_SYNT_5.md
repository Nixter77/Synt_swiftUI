# GROK BUILD — SYNT_5: надёжность AUv3 в Logic, LFO, модуляция и голоса, микротюнинг + пользовательские пресеты

Источник: исследования Researchy (сравнение с Serum 2 / Vital / Pigments / Diva / Alchemy, практики Apple для AUv3) и Resercher (разбор `feat/auv3` @ `9a37b71`).
Ветка: `feat/auv3`, база `9a37b71` (сначала `git pull`). В main НЕ мержить и не пушить. Без force-push и без переписывания истории.
Этапов 4. Всё из «Не входит» — не начинать.

## Общие правила (нарушение = этап не принят)
- RT-поток: никаких аллокаций, локов, ARC, print, `DispatchQueue.main`. Только SPSC-очереди (`commandQueue` — производитель UI, `midiQueue` / `midiSchedule` — MIDI).
- Golden FNV-хэши рендера (`InitGoldenTests`, `0xd1b3635203a4799e`) совпадают бит в бит до и после каждого этапа. Константы голденов не править.
- Новые поля пресета — только в конец, через `decodeIfPresent` + `sanitize()`, с нейтральными дефолтами (старые пресеты звучат как раньше).
- В `SynthCore/` (Audio/Models/Input/Utils) не ссылаться на `Theme` и `@Environment`. Высота `SynthControlGrid` ≤ 520 pt во всех темах.
- Адреса `SynthParameterAddress` только дописываются в конец, старые не сдвигать.
- Перед каждым коммитом: `git restore GLASS_HORIZON_PROBE_DUMP.txt`.
- После каждого этапа: полный прогон `xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests` (ожидаемо: 2 skipped perf под `SYNT_RUN_PERF=1`, 1 известный expected failure `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`, 0 failed), отдельный коммит, обычный `git push` в `feat/auv3`. Для этапов, трогающих AU, — повторный `auval -v aumu Synt Nixr` (приложить хвост лога).
- Если что-то неясно — не угадывать, вписать в «Открытые вопросы». В отчёте честно перечислить, что НЕ сделано; не писать «всё зелёное», если это не так.
- Дополнительно: новые enum-кейсы (источники/цели матрицы, режимы) — только в конец; по умолчанию ничего не маршрутизируется, звук Init не меняется.
- Каждый пункт сопровождается тестом из описания ниже; тест должен падать до правки, если речь об ошибке.

## Этап 1 — Надёжность AUv3 в реальном времени (ПРИОРИТЕТ)
- R1 (HIGH): `musicalContextBlock` / `transportStateBlock` присваиваются и обнуляются на main (`SyntAudioUnit.swift` ~99-108), а читаются в рендере (~492-508) — гонка и ARC на RT-потоке. Захватывать их один раз в `allocateRenderResources` в неизменяемый контекст рендера; не обнулять, пока рендер активен.
- R3: `cachedFXOrder` пишется на main (`AudioEngine+Preset.swift:20`) при работающем рендере — передавать порядок FX только через снапшот `RTPresetBuffer`, рендер — единственный писатель.
- R5: `fullState` при загрузке проекта Logic применяет пресет асинхронно на main — первые буферы звучат старым патчем. Публиковать снапшот синхронно до возврата из сеттера.
- R2: убрать retain/release `self.engine` в каждом вызове рендера (захватить unowned/unmanaged в контексте).
- `.parameterRamp` сейчас прыгает сразу в конечное значение (`SyntAudioUnit.swift` ~511-544) — реализовать линейную рампу по кадрам. Тест: рампа 0→1 на 512 кадров даёт монотонный cutoff.
- Сообщать хосту `tailTime` (по хвостам delay/reverb) и `latency` = 0, `channelCapabilities` [0,2].
- Переключатель «Program Change» (вкл/выкл, по умолчанию ВЫКЛ) в UI настроек плагина для уже существующего `respondsToProgramChange`; сохраняется в `fullState`.
- Тесты: регрессия R5 (первый буфер после `fullState` звучит новым патчем), тест рампы, тест `tailTime` > 0 при включённом delay. Плюс оставить зелёными `AudibleOutputRegressionTests` и `PresetSurvivesTransportTests`.

## Этап 2 — LFO: триггер, фаза, синхронизация с Logic
- Режимы LFO: free / retrigger на ноту / one-shot; параметр стартовой фазы 0–360° (`LFO.swift` ~15-41, note-on в Render ~896). По умолчанию — нынешний free.
- Синхро-деления с точкой и триолью (1/4D, 1/8T и т.д.).
- Фазовая привязка к транспорту хоста через `musicalContextBlock` (beat position) для LFO, арпеджиатора и delay sync.
- Арп: latch/hold и порядок «как сыграно» (SequencerModels.swift ~8-28).
- Тесты: retrigger — две ноты с интервалом 333 мс дают одинаковые первые 100 сэмплов LFO; fake beat 4.5 → фаза = fract(beat·rate); 1/8T при 120 BPM = шаг 166.67 мс; latch — ноты продолжаются после note-off.

## Этап 3 — Модуляция и голоса
- Кривая velocity и глубина velocity→громкость вместо жёсткого `max(0.15, v)` (Render ~602). Дефолт повторяет текущую формулу бит в бит. Тест: amount=0 → vel 0.1 и 1.0 одинаково громкие.
- Третья огибающая MOD ENV как источник матрицы (в конец enum источников, `SynthPreset.swift` ~711). Тест: MOD ENV→pitch с D=50 мс устанавливается за 50 мс.
- Новые источники матрицы: pitch bend, случайное значение на ноту (per-voice xorshift, без `random()`), sample & hold. Тест: random→pan на 100 нотах даёт разброс, при фиксированном seed — детерминированно.
- Glide: режимы rate/time, только legato; приоритет нот в моно (last/low/high). Тест: в режиме rate октава скользит вдвое дольше, чем 6 полутонов.

## Этап 4 — Микротюнинг (.scl) и пользовательские пресеты в Logic
- Загрузка `.scl` (+ опционально `.kbm`) — таблица частот на ноту, считается вне RT, в рендер передаётся снапшотом. По умолчанию 12-TET (golden не меняется). Тесты на парсер (комментарии, центы, отношения, ошибки) и на частоты.
- AU user presets: `supportsUserPresets`, `userPresets`, `saveUserPreset`, `deleteUserPreset`; общий App Group между приложением и плагином, чтобы пресеты, сохранённые в приложении, были видны в Logic и наоборот (`SyntAudioUnit.swift` ~128-183, `PresetManager.swift` ~14-32). Тест: `saveUserPreset` → `presetState` round-trip.
- `AUParameterTree` разбить на группы (Osc/Filter/Env/LFO/FX), проставить единицы и флаги (DisplayLogarithmic для cutoff и т.п.); адреса не менять.

## Отчёт
`SYNT_5-REPORT.md`: по каждому пункту — коммит, файлы:строки, тест, результат; хвост `auval`; что НЕ сделано и почему; «Открытые вопросы».

## Не входит (SYNT_6)
- Drag-and-drop модуляции с кольцами на ручках + кривые remap на маршрут.
- Рисуемый LFO / MSEG.
- Пер-голосовая модуляция cutoff/resonance (сейчас берётся от самого громкого голоса).
- Два фильтра серийно/параллельно, filter FM; warp-режимы осцилляторов, noise.
- Режимы качества (draft/offline), MPE, собственный реверб, браузер пресетов с тегами и поиском, XY-pad.
