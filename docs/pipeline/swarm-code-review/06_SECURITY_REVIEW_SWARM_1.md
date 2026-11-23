# Security — `bff3d99..` (ветка nixter) + CUT SWARM-1

**Вердикт: PASS с условиями.**

## Проверено
- gitleaks: 5 коммитов ветки + дерево — 0 находок; новые коммиты секретов не содержат.
- Недоверенный ввод: Scala `.scl` (non-finite/0/отрицательные → ошибка, `noteCount` проверяется до `reserveCapacity`); пользовательские пресеты из app-group UserDefaults проходят `sanitized()`; `fullState` chrome — `JSONDecoder` маленькой структуры с fallback; UMP: `max(1, wordCount)` против бесконечного цикла; Arp UMP-парсер ограничен 256 пакетами × 64 словами.
- Файлы: сохранение записи через staged-файл с UUID в папке назначения + `replaceItemAt`, temp удаляется в `defer`.
- Конкурентность: `PresetManager` под `NSLock`, `chromeLock`, recorder-lock (вне audio-потока), Arp SPSC-кольцо.
- Новый код CUT: `syntCaseTag` читает 1 байт через `withUnsafeBytes` — безопасно только для payload-free enum'ов ≥2 кейсов; тест держит `MemoryLayout.size == 1` для всех 29.

## Условия / находки
- S-1 (P3): `SyntAUv3.entitlements` содержит `com.apple.security.device.audio-input`, синту вход не нужен (было и раньше) — убрать при случае.
- S-2 (P3): Arp `clearState()` — неатомарный сброс кольца при параллельном продюсере (N-7), без порчи памяти за пределами кольца (маска индекса).
- S-3: `-enforce-exclusivity=unchecked` (если nixter выберет D-3) снимает рантайм-защиту от гонок доступа — включать только для SynthCore и только после зелёного прогона с проверками.
