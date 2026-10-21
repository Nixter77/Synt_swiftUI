# Отчёт по GROK BUILD — SYNT_11

Ветка `feat/auv3`. В `main` не вливал и не перебазировал. `git merge-base --is-ancestor main HEAD` остаётся с кодом 1. Автор коммитов: Nikolay Nikolaenko, niko.dr@gmail.com. Машина: Mac mini, x86_64, macOS 15.7.4. Logic Pro X 11.0.1 стоит в `/Applications/Logic Pro X.app`.

Золотой хеш Init `0xd1b3635203a4799e` не менялся. `FXSlotID` по-прежнему шесть слотов. Пресет «Fast Leslie» не редактировался. Приложение в `~/Applications` не перезаписывал.

## Коммиты

- `e9bcdd0` `fix(dsp): Stage 1 - ROUND8 LFO, MSEG, modulation, scope, and phase`
- `a1039b4` `feat(fx): Stage 2 - parallel send buses`
- `42f13c4` `feat(fx): Stage 3 - rotary Leslie off by default`
- `b261efb` `feat(auv3): Stage 4 - SyntArpAUv3 MIDI FX prototype`

## Этап 1 — ROUND8

LFO по стереоамплитуде, хвост one-shot, MSEG на трёх банках, подсветка только живых голосов, scope по эпохе, фаза `randomPerNote`, кэш коэффициентов character tone. Тема в ядро не попадала.

Прогон схемы: `~/.synt_dd/Logs/Test/Test-Synt_swiftUI-2026.10.22_00-51-19-+0300.xcresult`. Верхний итог: result Passed, passedTests 575, failedTests 0, skippedTests 2, expectedFailures 1, totalTestCount 578. Устройство My Mac: passedTests 681, failedTests 0, skippedTests 2, expectedFailures 1.

## Этап 2 — сенды

Send A (реверб) и Send B (дилей) идут параллельно цепочке вставок, с сухого сигнала после scene HPF. Свои `DSPReverb` и `PingPongDelay`, память берётся в `prepare` и при смене частоты, не в рендер-колбэке. При уровне 0 процессоры не вызываются. Адреса AU: `sendA` 142, `sendB` 143. Поля пресета через `decodeIfPresent`, по умолчанию 0. Ручки в свёрнутой карточке Sends, это не седьмой слот.

Прогон: `Test-Synt_swiftUI-2026.10.22_01-11-18-+0300.xcresult`. Верхний итог: Passed, passedTests 578, failedTests 0, skippedTests 2, expectedFailures 1, totalTestCount 581. Устройство: passedTests 684, failedTests 0, skippedTests 2, expectedFailures 1.

## Этап 3 — rotary

Leslie рядом с цепочкой, не седьмой `FXSlotID`. Выключен по умолчанию, тогда процессор не вызывается и выход остаётся бит-в-бит. Рупор и барабан со своими медленной и быстрой скоростями, разгон, drive и mix. Переключатель Slow/Fast — параметр AU `rotaryFast` (145). Остальные адреса 144 и 146–152. `exp` только при смене частоты, не на каждый семпл.

Прогон: `Test-Synt_swiftUI-2026.10.22_01-20-43-+0300.xcresult`. Верхний итог: Passed, passedTests 580, failedTests 0, skippedTests 2, expectedFailures 1, totalTestCount 583. Устройство: passedTests 686, failedTests 0, skippedTests 2, expectedFailures 1.

## Этап 4 — MIDI FX

Отдельный таргет `SyntArpAUv3`, тип `aumi`, производитель Nixr, subtype `Arp1`. Бандл `Home.Synt-swiftUI.SyntArpAUv3`. Синтезатор, `ArpeggiatorEngine` и рендер `aumu` не менялись. Режимы up, down, up-down, random. Доли 1/4…1/32 от темпа хоста, gate, октавы 1–4, hold. MIDI уходит в `MIDIOutputEventBlock`. Песочница расширения включена.

Прогон схемы после нового таргета: `Test-Synt_swiftUI-2026.10.22_01-29-57-+0300.xcresult`. Верхний итог: Passed, passedTests 580, failedTests 0, skippedTests 2, expectedFailures 1, totalTestCount 583. Устройство: passedTests 686, failedTests 0, skippedTests 2, expectedFailures 1. Числа те же, что после этапа 3: арпеджиатор не входит в тестовый бандл.

## Что пропущено и ожидаемый провал

На последнем прогоне схемы пропущены, пока нет `SYNT_RUN_PERF=1`:

- `RenderBudgetTests/renderBudgetForInitChordAndHeaviestFactory`
- `LiveStep4PerfBenchmarks/benchmark32VoicesCPU`

Ожидаемый провал, в `failedTests` его нет: `ChordHissMatrixTests/matrix_wetComplex_3note_documentNearClip`.

Лимит RenderBudget не поднимался.

## auval

`auval -v aumi Arp1 Nixr` на расширении из DerivedData (`~/.synt_dd/.../SyntArpAUv3.appex`): **AU VALIDATION SUCCEEDED**. Лог `/tmp/synt11-auval-aumi.log`, код 0.

`auval -v aumu Synt Nixr` на текущей сборке из DerivedData: **AU VALIDATION SUCCEEDED**. Лог `/tmp/synt11-auval-aumu-dd.log`, код 0. После этого регистрация `Home.Synt-swiftUI.SyntAUv3` возвращена на `~/Applications/Synt_swiftUI.app`.

Тот же `auval -v aumu Synt Nixr` по установленной копии в `~/Applications/Synt_swiftUI.app`: **AU VALIDATION FAILED**, код 255, лог `/tmp/synt11-auval-aumu.log`. Хвост: параметры не удержали значения после установки (`Parameter values are different since last set`). Предупреждения, которые сами по себе не были этим провалом: устаревший `CurrentPreset`, Phaser не удержал максимум, `Can Initialize Unit to un-supported num channels: InputChan:0, OutputChan:1`.

## Logic 11.0.1

Logic открылся и сам создал пустой `Project 1`. Через меню Track добавлен software instrument track. В дереве доступности окна дорожек слот MIDI FX и меню инструмента не подписаны, выбрать `Synt Arp` и довести ноту до инструмента Synt не удалось. На этом прототип не наращивался.

`aumi` зарегистрирован через `pluginkit` с пути DerivedData, не из `~/Applications`. Пока этот `.appex` на месте, хост может его найти. В установленное приложение копия не клалась.

## Отложено на SYNT_12

- MPE
- seed случайности в пресете
- sample → wavetable
- transient shaper
