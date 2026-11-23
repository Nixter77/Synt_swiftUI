# CodeReviewer #1 — разбор находок аудита `a651340`

**Решение по ветке:** работать на `feat/swarm-code-review` (самая свежая работа nixter, поверх `feat/auv3` + merge-коммита `bff3d99`). `feat/auv3` и `main` не трогаем; `main` не пушим.

## Берём в CUT (безопасно, тестируемо, Init/factory бит-в-бит)
| Находка | Решение | Почему безопасно |
|---|---|---|
| N-1 жёсткая кража голоса | Steal de-click: у голоса хранится последний стерео-сэмпл (`lastOutL/R`), при краже он уходит в `stealDeclickL/R` и затухает (τ 0.7 мс, −60 dB за 5 мс). | Ветка `if stealDeclick != 0` пропускается без кражи → Init/factory goldens бит-в-бит (2 ноты, кражи нет). Меняется звук **только в момент кражи** (убираем щелчок) → Listen nixter. |
| N-2 String-сравнения enum'ов | `SynthCore/Utils/EnumCaseEquality.swift`: явный `==` по 1-байтному тегу кейса для 29 аудио-enum'ов. | Семантика та же (raw values уникальны) — тест сверяет `==` с `rawValue ==` для всех пар; Codable/rawValue не меняются; goldens бит-в-бит. |
| N-4 устаревший тест | Тест подаёт аккорд на full velocity вместо одной ноты. | Только тест; продуктовый код не трогается. |

## Не берём (решение nixter / отдельный раунд)
- N-3 runtime exclusivity off (`-enforce-exclusivity=unchecked` для SynthCore) — выигрыш измерен в 04, но это снятие защитной сетки → **решение nixter**.
- N-5 `auval-reinstall.sh` Debug → Release/WMO — меняет процесс установки; выигрыш измерен в 04 → **решение nixter**.
- N-6…N-10 — P3, записаны; N-10 (копия `ActiveNote`) — большой рефактор рендера, отдельный CUT.

## Ограничения на этот раунд
Не трогать: Init/Default/Template, factory-значения, AU-адреса, `main`, SyntHost. Без force-push. Listen = DEFER.
