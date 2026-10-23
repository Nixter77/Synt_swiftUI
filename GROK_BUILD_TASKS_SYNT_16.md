# GROK_BUILD_TASKS_SYNT_16 — по ROUND13 (база 98feb1a, ветка feat/auv3)

Исполнитель: Grok Bot (сам). Правила: golden 0xd1b3635203a4799e не меняется; новые фичи по умолчанию off; новые поля пресета — decodeIfPresent;
новые AU-адреса с 167; на render-потоке ни аллокаций, ни локов, ни exp/pow на сэмпл, ни ARC; пункт исправлен только с именованным тестом,
который упал бы на старом коде; старые тесты не ослаблять. Перед коммитом `git restore GLASS_HORIZON_PROBE_DUMP.txt CHORD_HISS_MATRIX_DUMP.txt`.
Весь набор зелёный → коммит → обычный push после каждого этапа. Без force, без merge в main.

## Stage 1 — R13-1: MPE-конфиг контроллера в AU
- AU (`coreOnly: true`) тоже забирает mailbox: таймер на main, принадлежащий AU, и/или drain на пути param/state (fullState, applyPreset snapshot).
- Снимок пресета (param/automation/preset change) не затирает заданные контроллером MPE-диапазоны: сначала drain mailbox, затем snapshot.
- Решить и задокументировать: сохраняется ли это в состоянии проекта.
- Закрыть гонку standalone 33 мс (тот же drain перед snapshot).
- Тест через реальный coreOnly-путь: RPN → смена параметра → диапазон сохранён. Без ручного вызова poll.

## Stage 2 — R13-2, R13-3, R13-9
- При MPE on MCM на ch1/ch16 принимается независимо от текущей зоны, так что зону можно переключить.
- MCM сбрасывает member bend на 48, master на 2.
- MCM при MPE off MPE не включает (off по умолчанию); задокументировать.
- master RPN range не сохраняется в user preset.

## Stage 3 — R13-4: wavetable LFO следует таблице осциллятора
- Указатель на кадр выбранной таблицы берётся снимком на блок. RT-safe: без ARC и аллокаций, morph осциллятора не трогается.

## Stage 4 — perf и мелочи
- Прогнать `SYNT_RUN_PERF=1` (RenderBudgetTests, LiveStep4BlockRenderTests), исправить регрессии, цифры в отчёт.
- CC 38 LSB; не хэшировать весь blob на main при каждом applyPreset, где это безопасно; mip-compile ветка недостижима с render.

## Отложено в SYNT_17
Арпеджиатор; R11-6..13; R12-10..15; ARC в `generateSample`.

## Отчёт
SYNT_16_REPORT.md: коммиты по этапам, итоги полного набора, perf-цифры, тест на каждый пункт, auval, `git merge-base --is-ancestor 98feb1a HEAD`.
