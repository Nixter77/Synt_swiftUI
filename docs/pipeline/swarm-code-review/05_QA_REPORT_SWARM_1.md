# QA — CUT «SWARM-1» @ `768f72c` (`git archive` → `/tmp/synt_swarm1`, serial, без UITests)

| AC | Итог | Доказательство |
|---|---|---|
| AC-1 | **PASS** | `hardStealDecaysInsteadOfSteppingToZero` зелёный; на базе тот же сценарий d2 = 0.0815 (тест бы упал), после 0.0028 |
| AC-2 | **PASS** | `noStealLeavesResidualUntouched`, `clearAllVoicesDropsResidual`, `declickCoefficientTracksSampleRate` |
| AC-3 | **PASS** | `EnumCaseEqualityTests` — 29 enum'ов, все пары, 1 байт, Codable round-trip |
| AC-4 | **PASS** | `InitGoldenTests` зелёный (`0xd1b3635203a4799e`), `FactoryGoldenTests` зелёный, хеши не перезаписывались |
| AC-5 | **PASS** | Swift Testing **830** тестов (база 824 + 6 новых): 1 FAIL `busGlueFlagWiresIntoRenderPath` — тот же, что на `a651340` и `ebd9705`; 1 known issue (ChordHiss). XCTest **173/173** |
| AC-6 | **PASS** | см. 04: строковые сравнения ушли, RT 0.65× → 0.98×, 0 alloc/lock в render, утечек от CUT нет |
| AC-7 | см. 07 | auval после установки |
| AC-8 | **PASS** | `SynthParameterAddress.swift` и дерево параметров Arp в диффе отсутствуют |
| AC-9 | **DEFER** | Listen в Logic — nixter |

**Итог: PASS (BLOCK AC зелёные; AC-7 — в финальном CR).**
