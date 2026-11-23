# Ночной аудит — `feat/swarm-code-review` @ `a651340`

**Дата:** 2026-11-23 (Asia/Jerusalem) · **Режим:** read-only; тесты и Instruments только из `git archive` → `/tmp`.
**Ветка:** `feat/swarm-code-review` (локальная, на `origin` не было). **База:** локальный `main` @ `bff3d99` (дерево = `origin/feat/auv3` @ `ebd9705`; `origin/main` = `06c40a6`).
**Диапазон:** `bff3d99..a651340`, 5 коммитов nixter (2026-11-21), 28 файлов, +2965/−462.
**Рабочее дерево:** грязный только `xcuserdata/…/xcschememanagement.plist` (Xcode, не трогаем).

## Что делает ветка
1. `28e2db0` audio-core: блокировка рекордера, стерео-скоуп (L/R ring + корреляция), микротюнинг в секвенсоре, hardening пресетов/истории/MIDI/Scala.
2. `fa012d5` MIDI/клавиатура/Arp: SyntArpAUv3 переписан на lock-free SPSC-кольцо + разбор render-событий (MIDI 1.0 / UMP), free-clock при стоящем транспорте, velocity по нотам.
3. `785db47` AUv3 bridge: `createAudioUnit` больше не трогает AppKit вне main, `chromeLock` для zoom/layout, tailTime учитывает send A/B.
4. `0d21845`, `a651340` UI: Shift-fine / Option-reset / double-click reset у ручек, vDSP-спектр, M/S-гониометр, swing в MIDI-экспорте.

## Baseline (`a651340`, Debug, serial, без UITests)
- Swift Testing: **824 теста, 1 FAIL** (`CompressorV2Tests.busGlueFlagWiresIntoRenderPath`, maxGR 0.022 < 0.1) + 1 known issue (ChordHiss near-clip, документированный).
- XCTest: **173/173**.
- `busGlueFlagWiresIntoRenderPath` красный и на `origin/feat/auv3` @ `ebd9705` → **не регрессия ветки** (Growl стал тише после перевойсинга фабрики в `c9fb618`).
- Init golden `0xd1b3635203a4799e` — зелёный; FactoryGolden — зелёный.
- gitleaks: 5 коммитов + дерево — **0 находок**.

## Instruments (Time Profiler, attach к test-host, render-нагрузка: Rhodes Warm / Supersaw Soft / Glass Horizon, педаль, до 32 голосов, блок 256)
- Реальное время: **0.65× realtime** (1 с звука считается ~1.5 с на одном ядре i7-8700B). Это та же Debug-сборка (`-O`, без WMO), которую `Tools/auval-reinstall.sh` ставит в `/Applications` → Logic.
- Горячие точки (self): `renderOneSample` 15 %, **сравнение enum'ов со String raw value через stdlib `RawRepresentable ==`** (`specialized ==` 6.1 % + `_stringCompare*` 3.5 % + `rawValue` getters ≈3 % + часть retain/release ≈10 %), **динамические проверки эксклюзивности** (`swift_beginAccess` + `AccessSet::insert` + TLS ≈ 15 %).

## Находки
| ID | Sev | Где | Суть |
|---|---|---|---|
| N-1 | **P2** | `AudioEngine+Voices.swift` `findFreeVoiceSlot` | Комментарий обещает «soft-steal 6 ms», код делает `deactivate()` жертвы на любом уровне → ступенька в миксе (щелчок). Замер: 8 удерживаемых синусов, 9-я нота → d2 на краже **0.0815** при фоне 0.0007. Сценарий педали на Rhodes Warm даёт 13 краж за 6 с. Кандидат на щелчки Key/Rhodes в Logic. |
| N-2 | **P2** | render-путь, все `enum X: String` | `==` на String-raw enum'ах идёт через stdlib `RawRepresentable ==` (сравнение строк + retain/release) — per-voice per-sample (`lfoTarget == .pan`, `filterType == .ladder`, `envelopeModel != .legacy`…). Микробенч: 11 нс против 0.8 нс. ≈15–20 % CPU рендера. При 0.65× realtime — прямой кандидат на треск (перегруз ядра) в Logic на Intel. |
| N-3 | P2 | рендер/класс `AudioEngine` | Runtime exclusivity checks ≈15 % CPU рендера. Снятие = смена build-флага (решение nixter, см. 07). |
| N-4 | P2 | `CompressorV2Tests.busGlueFlagWiresIntoRenderPath` | Красный и на `ebd9705`: одна нота Growl после `c9fb618` не доходит до порога −18 dB. Тест устарел (продукт ок, GR > 0). |
| N-5 | P3 | `Tools/auval-reinstall.sh` | Ставит **Debug** (`-O` без WMO, testability) в `/Applications`, а MODEL CONTRACT говорит «Release install». Для Logic — лишний CPU. |
| N-6 | P3 | `SyntArpAudioUnit` | События из render-списка и `scheduleMIDIEventBlock` применяются в начале блока, `eventSampleTime` игнорируется (джиттер ≤ 1 буфер). UMP MIDI 2.0 (тип 0x4) ноты игнорируются. |
| N-7 | P3 | `SyntArpAudioUnit.clearState()` | Сброс `ringHead/ringTail` не атомарен относительно продюсера, если хост шлёт MIDI во время allocate (теоретическая гонка, без краша). |
| N-8 | P3 | `PatchHistoryManager.shared` + `registerPresetProvider` в `.onAppear` | Синглтон на процесс: при двух инстансах AU в одном процессе undo-снимок drag'а берётся из последнего открытого окна. Было и раньше. |
| N-9 | P3 | `OscilloscopeView.spectrumBands` | `sampleRate` по умолчанию 44 100 — на 48/96 кГц полосы смещены (косметика). |
| N-10 | P3 | рендер | `var v = voices[i]` копирует `ActiveNote` (408 B) дважды на голос на сэмпл (`memmove` 1.9–2.6 %). Рефактор большой — не в этом раунде. |

**P0/P1: 0.** Init golden не тронут. AU-адреса не менялись (параметрическое дерево Synt/Arp — без сдвигов; Arp: адреса 0–4 как были).

## Что хорошо в ветке
- Recorder: tap больше не гоняется с `stopRecording` (lock + snapshot URL), запись в файл вне main.
- Arp: нет больше обработки MIDI на чужом потоке без синхронизации; CC120/123 чистят ноты; reset из non-RT через флаг.
- AUv3 VC: `AUParameterSurface` (@MainActor) создаётся только на main.
- Scala: CR/CRLF, пустое описание, `0.0` cents, non-finite → ошибка, таблица с fallback.
