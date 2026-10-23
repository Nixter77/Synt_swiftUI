# GROK_BUILD_TASKS_SYNT_15 — по ROUND12 (база 5537eea, ветка feat/auv3)

Исполнитель: Grok Bot (сам). Правила: golden 0xd1b3635203a4799e не меняется; новые фичи по умолчанию off;
новые поля пресета — decodeIfPresent; новые AU-адреса с 167; на render-потоке ни аллокаций, ни локов, ни exp/pow на сэмпл;
пункт считается исправленным только с именованным тестом, который упал бы на старом коде; RT-тесты гоняют render-путь не с main.
Перед коммитом `git restore GLASS_HORIZON_PROBE_DUMP.txt CHORD_HISS_MATRIX_DUMP.txt`. Весь набор зелёный → коммит → обычный push после каждого этапа.

## Stage 1 — RT-безопасность (R12-1, R12-8)
- R12-1: RPN/MCM в `handleRPN` на render-потоке трогает только `cached*` и пишет упакованное состояние MPE в lock-free mailbox (Atomic<UInt64>).
  Main забирает его в `pollMetering` (`pollMPEConfigMailbox()`) и обновляет `preset` через `updatePresetDisplayOnly` — без `applyPreset`, без @Published из render.
  Тест: RPN 0/6 из фонового потока → `applyPresetCallCountForTesting` не меняется, `preset` не меняется до poll; после poll — обновлён.
- R12-8: LFO `.wavetable` не вызывает `generateSample` осциллятора (не двигает morph/framePosition, не pull банка), нет подмены при `s == 0`,
  нет ARC на сэмпл: форма из собственного неизменяемого буфера (UnsafePointer). Тесты: framePosition/выход осциллятора не меняются от LFO; значение в нуле — по независимой интерполяции.

## Stage 2 — RPN-маршрутизация (R12-2, R12-4)
- R12-2: CC 6/38/100/101 → `.mpeControlChange` только при включённом MPE; иначе `.controlChange` (MIDI-learn как прежде). RPN 0 от DAW при MPE off не трогает пресет.
- R12-4: RPN 0 на master-канале зоны → master-диапазон (новое поле `mpeMasterPitchBendRange`, default 2, decodeIfPresent; применяется к bend master-канала при MPE on),
  на member-канале → member-диапазон; пересчёт `mpeChannelStates[].pitchBendMultiplier`. Исправить `testRPN0ChangesBendRange`, тест на типичную последовательность MCM→RPN0 member 48→RPN0 master 2.

## Stage 3 — зоны (R12-3) + standalone (R12-5)
- Общая функция «member/master канал» по зоне и числу каналов: lower master ch0, members 1…N; upper master ch15, members 15−N…14.
  Используется в `command(for:)`, в MIDI-путях standalone и в render. Канал вне зоны → обычный (глобальный) путь.
- Standalone MIDIHandler: CC 6/38/100/101 (при MPE on) → `.mpeControlChange` через тот же маршрутизатор; MCM работает в standalone.

## Stage 4 — средние + слабые тесты
- R12-6/R11-1: `loadBuiltin(5)` перекомпилирует user-таблицу под новый SR. R12-7/R11-4: убрать static fallback, экземпляры не делят таблицу.
- R12-9: хэш из заголовка WTZ1 проверяется (или пересчитывается); legacy-хэш кэшируется, без полной распаковки на каждый `applyPreset`.
- Усилить тесты: R9-2 с реальным сигналом в send; R11-1 через реальный путь `setSampleRate`→`loadBuiltin(5)`; R7-10 через движок; stereo-LFO против независимого эталона.

## Отложено в SYNT_16
Arpeggiator; R11-6..13; ARC retain/release в `generateSample`; R12-10…R12-15 (сглаживание MPE по SR, cancel очистки send, tuple вместо Array, сброс pressure, legacy-буфер, MPE-пресет id).

## Отчёт
SYNT_15_REPORT.md: коммиты по этапам, итог полного набора, тест на каждый пункт, auval, `git merge-base --is-ancestor 5537eea HEAD`.
