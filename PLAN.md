# 🎹 Прогресс и План Разработки Synt_swiftUI

## ✅ РЕАЛИЗОВАНО (Verified)
- **Звуковой движок**: 2 осциллятора, PolyBLEP (Saw/Square), ADSR (Экспоненциальные кривые), Filter (Cached Biquad), LFO.
- **Полифония**: Поддержка нескольких нот одновременно (сейчас через NSLock).
- **Эффекты**: Stereo Chorus, Reverb, Delay, Master Limiter.
- **Модуляция**: Unison (до 7 голосов), Modulation Matrix (6 слотов: LFO/Env/Vel -> Pitch/Amp/Pan/Cutoff).
- **Инструментарий**: Arpeggiator (Up/Down/Random), Step Sequencer (16 шагов, Pitch/Vel/Gate/Swing).
- **Интерфейс**: Apple-style Neumorphic Design, VU-метры, Осциллограф, FFT Спектрограмма.
- **Пресеты**: Система фабричных (20+) и пользовательских пресетов (UserDefaults).
- **Input**: QWERTY-клавиатура (macOS) и MIDI-контроллеры (CoreMIDI).

## ⚠️ В ОЖИДАНИИ ИНТЕГРАЦИИ (Modules Ready)
*Эти модули созданы, скомпилированы, но временно отключены или не подключены к `AudioEngine.swift` (после отката):*
- [ ] **Lock-Free Engine**: `AudioCommandQueue` & `VoiceManager` (готовы к замене NSLock).
- [ ] **Atomic Metering**: `AtomicMeteringState` (готов к замене DispatchQueue.main.async).
- [ ] **Wavetable Engine**: `WavetableOscillator` с поддержкой mip-mapping.
- [ ] **Advanced Effects**: `Distortion` (6 типов), `ParametricEQ` (3-band), `Phaser`.

## 🚀 СЛЕДУЮЩИЕ ШАГИ (Action Plan)

### Фаза 1: Thread Safety & Performance (P0)
- [x] **Удаление NSLock**: `AudioCommandQueue` UI → Audio Thread.
- [ ] **Оптимизация голосов**: `VoiceManager` — **откачено** (хрип); снова только после safe steal design.
- [x] **Thread-safe UI Update**: `AtomicMeteringState` + Timer 60Hz.
- [ ] **Dynamic Sample Rate**: Автоматически подстраивать DSP под частоту дискретизации оборудования.

### Фаза 2: Улучшение звукового тракта
- [x] **Stereo Gain Staging / Polyphony Scaling**: `1/√N` + linear −6 dB headroom (NEWPLAN Этап 1).
- [x] **True Stereo Filter**: filterL / filterR.

### Фаза 3: Новые возможности
- [x] **Wavetable Synthesis**: Stage 3 + UI morph; waveform picker.
- [x] **Effects Rack (Advanced)**: Distortion / EQ / Phaser + `AdvancedEffectsView` (default OFF).
- [ ] **Step Sequencer Pro**: Сохранение паттернов в пресеты и Tie-ноты.
- [ ] **Preset persistence for Advanced FX**: сохранять Distortion/EQ/Phaser в `SynthPreset`.

---
**Последнее обновление**: 2026-08-05
**Статус**: NEWPLAN 1/3/4/5 + UI. Этап 2 VoiceManager откачен.
