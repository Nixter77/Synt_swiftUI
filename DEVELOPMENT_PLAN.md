# 🎹 План разработки синтезатора на SwiftUI

## Обзор проекта

Создание полнофункционального программного синтезатора с использованием SwiftUI для интерфейса и AVFoundation/AudioUnit для звукового движка.

---

## 📊 Текущий статус

**Дата последнего обновления**: 2026-01-26

### ✅ Реализовано:
- Базовый звуковой движок (AVAudioEngine + AVAudioSourceNode)
- 2 осциллятора с 4 формами волн (sine, sawtooth, square, triangle)
- ADSR-огибающая с визуализацией графика
- Фильтр с 3 режимами (Low-pass, High-pass, Band-pass)
- LFO с модуляцией pitch/filter/amplitude
- Эффекты: Reverb (AVAudioUnitReverb) + Delay (AVAudioUnitDelay)
- Виртуальная клавиатура пианино (2 октавы, мышь)
- QWERTY-клавиатура (A-L белые, W-E-T-Y-U-O-P чёрные, Z/X октавы)
- Система пресетов с 20 фабричными по категориям (Bass, Lead, Pad, Keys, Pluck, Strings/FX)
- Кастомные UI-компоненты (KnobView, WaveformPicker)
- Тёмная тема интерфейса
- VU-метры для отображения уровня сигнала в реальном времени

### 🔧 Известные проблемы / TODO:
- [x] ~~Добавить сохранение пользовательских пресетов (UserDefaults)~~ ✅
### 🔧 Известные проблемы / TODO:
- [x] ~~Добавить сохранение пользовательских пресетов (UserDefaults)~~ ✅
- [x] ~~Добавить Chorus эффект~~ ✅
- [x] ~~Добавить поддержку MIDI-контроллеров~~ ✅
- [x] ~~Улучшить визуализацию нажатых клавиш~~ ✅
- [x] ~~Оптимизировать производительность аудио-потока~~ ✅ (LCG Noise)
- [x] ~~Добавить выбор конкретного MIDI-устройства~~ ✅
- [x] ~~Добавить визуализацию осциллографа~~ ✅
- [x] ~~Добавить лимитер~~ ✅

### 🐛 Исправленные баги:
- [x] Исправлен порядок аргументов в пресете "Pluck" (delayTime, delayFeedback, delayMix)
- [x] Добавлена защита от повторных срабатываний клавиш при удержании (physicalKeysDown Set)
- [x] Убран системный звук macOS при нажатии клавиш (return nil для обработанных событий)

---

## 📋 Этапы разработки

### Этап 1: Базовый звуковой движок ✅ ГОТОВО
**Цель**: Проверить, что программа запускается и воспроизводит звук

#### Задачи:
- [x] Создать `AudioEngine.swift` - базовый класс для работы со звуком
- [x] Интегрировать AVAudioEngine для генерации звука
- [x] Создать простой синусоидальный осциллятор
- [x] Добавить кнопку "Play/Stop" в UI
- [x] Проверить воспроизведение звука

#### Файлы:
```
Synt_swiftUI/
├── Audio/
│   └── AudioEngine.swift
├── ContentView.swift (обновить)
└── Synt_swiftUIApp.swift
```

#### Технологии:
- `AVAudioEngine`
- `AVAudioSourceNode`
- `AVAudioSession` (для iOS) / Audio configuration (для macOS)

---

### Этап 2: Виртуальная клавиатура ✅ ГОТОВО
**Цель**: Создать визуальную клавиатуру и связать с генерацией звука

#### Задачи:
- [x] Создать `KeyboardView.swift` - компонент пианино
- [x] Реализовать белые и чёрные клавиши (2 октавы)
- [x] Связать нажатие клавиши с частотой ноты
- [x] Добавить визуальную обратную связь при нажатии
- [x] Поддержка полифонии (несколько нот одновременно)

#### Файлы:
```
Synt_swiftUI/
├── Views/
│   ├── KeyboardView.swift
│   └── Components/PianoKeyView.swift
├── Models/
│   └── Note.swift
```

---

### Этап 3: Поддержка QWERTY-клавиатуры ✅ ГОТОВО
**Цель**: Играть на синтезаторе с помощью клавиатуры компьютера

#### Задачи:
- [x] Создать `KeyboardHandler.swift` для обработки клавиш
- [x] Маппинг клавиш на ноты:
  - `A-S-D-F-G-H-J-K-L` → белые клавиши
  - `W-E-T-Y-U-O-P` → чёрные клавиши
- [x] Поддержка нажатия/отпускания (Note On/Off)
- [x] Визуальная индикация на виртуальной клавиатуре
- [x] Переключение октав (Z/X)
- [x] Защита от повторных срабатываний при удержании клавиши

#### Особенности реализации:
```swift
// Используется NSEvent для macOS + physicalKeysDown Set для защиты от repeats
eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
    if event.isARepeat || physicalKeysDown.contains(key) { return }
    // обработка нажатий
}
```

---

### Этап 4: Множественные осцилляторы ✅ ГОТОВО
**Цель**: Добавить выбор формы волны и микширование осцилляторов

#### Задачи:
- [x] Создать `Oscillator.swift` с разными формами волн:
  - Синусоида (Sine)
  - Пила (Sawtooth)
  - Квадрат (Square)
  - Треугольник (Triangle)
- [x] UI для выбора формы волны (WaveformPicker)
- [x] Добавить второй осциллятор (OSC 2)
- [x] Детюн (расстройка) между осцилляторами
- [x] Микширование громкости OSC 1 и OSC 2

#### Файлы:
```
Synt_swiftUI/
├── Audio/
│   ├── AudioEngine.swift
│   ├── Oscillator.swift
├── Models/
│   └── WaveformType.swift
├── Views/
│   ├── OscillatorView.swift
│   └── Components/WaveformPicker.swift
```

---

### Этап 5: ADSR Огибающая ✅ ГОТОВО
**Цель**: Контроль атаки, затухания, сустейна и релиза

#### Задачи:
- [x] Создать `ADSREnvelope.swift`
- [x] Параметры:
  - Attack (время нарастания)
  - Decay (время спада)
  - Sustain (уровень удержания)
  - Release (время затухания)
- [x] UI с 4 ручками (KnobView)
- [x] Визуализация кривой ADSR (ADSRGraph)
- [x] Применение огибающей к амплитуде

---

### Этап 6: Фильтр ✅ ГОТОВО
**Цель**: Добавить фильтрацию частот

#### Задачи:
- [x] Реализовать фильтры (Biquad):
  - Low-pass (низкие частоты)
  - High-pass (высокие частоты)
  - Band-pass (полосовой)
- [x] Параметры:
  - Cutoff (частота среза)
  - Resonance (резонанс)
- [x] UI с ручками для управления
- [x] Модуляция фильтра от LFO

---

### Этап 7: Эффекты ✅ ГОТОВО
**Цель**: Добавить пространственные эффекты

#### 7.1 Reverb (Реверберация) ✅
- [x] Интегрировать `AVAudioUnitReverb`
- [x] Параметры:
  - Room size (размер комнаты) - через preset
  - Wet/Dry mix (смешивание)
- [x] UI контролы

#### 7.2 Delay (Задержка) ✅
- [x] Интегрировать `AVAudioUnitDelay`
- [x] Параметры:
  - Delay time
  - Feedback
  - Mix

#### 7.3 Chorus ✅ РЕАЛИЗОВАНО
- [x] Две модулированные линии задержки (stereo chorus)
- [x] Параметры: Rate, Depth, Mix
- [x] UI контролы в EffectsView

---

### Этап 8: LFO (Низкочастотный осциллятор) ✅ ГОТОВО
**Цель**: Добавить модуляцию параметров

#### Задачи:
- [x] Создать `LFO.swift`
- [x] Параметры:
  - Rate (частота)
  - Depth (глубина)
  - Waveform (форма волны)
- [x] Routing (куда направить LFO):
  - На pitch (вибрато)
  - На filter cutoff
  - На amplitude (тремоло)

---

### Этап 9: Пресеты и сохранение ✅ ГОТОВО
**Цель**: Сохранение и загрузка настроек

#### Задачи:
- [x] Модель `SynthPreset` (Codable)
- [x] Сохранение в UserDefaults (PresetManager)
- [x] Список фабричных пресетов в UI (PresetView)
- [x] 20 фабричных пресетов по категориям:
  - **Bass (4)**: Sub Bass, Acid Bass, Funk Bass, Wobble Bass
  - **Lead (4)**: Classic Lead, Screaming Lead, Soft Lead, Trance Lead
  - **Pad (4)**: Warm Pad, Dark Pad, Bright Pad, Evolving Pad
  - **Keys (3)**: Electric Piano, Organ, Clav
  - **Pluck/Synth (3)**: Pluck, Bell, Arp Synth
  - **Strings/FX (2)**: Strings, SFX Riser

---

### Этап 10: Полировка UI ⚠️ ЧАСТИЧНО ГОТОВО
**Цель**: Современный, красивый интерфейс

#### Задачи:
- [x] Тёмная тема в стиле аналоговых синтезаторов
- [x] Кастомные ручки (knobs) в стиле hardware (KnobView, LargeKnobView)
- [ ] Анимации и визуальные эффекты
- [x] Индикаторы уровня (VU meters) - StereoVUMeterView, CompactVUMeterView
- [x] Поддержка разных размеров окна (minWidth: 900, minHeight: 650)

---

## 🏗️ Текущая архитектура проекта

```
Synt_swiftUI/
├── Synt_swiftUIApp.swift           // Точка входа
├── ContentView.swift               // Главный UI
├── Audio/
│   ├── AudioEngine.swift           // Основной движок (@unchecked Sendable)
│   ├── Oscillator.swift            // Генератор волн
│   ├── ADSREnvelope.swift          // Огибающая ADSR
│   ├── Filter.swift                // Biquad фильтр
│   ├── LFO.swift                   // Низкочастотный осциллятор
│   └── Effects/
│       ├── ReverbEffect.swift      // AVAudioUnitReverb wrapper
│       ├── DelayEffect.swift       // AVAudioUnitDelay wrapper
│       └── ChorusEffect.swift      // Stereo chorus с LFO модуляцией
├── Models/
│   ├── Note.swift                  // MIDI нота → частота
│   ├── SynthPreset.swift           // Пресет + фабричные пресеты
│   └── WaveformType.swift          // Enum форм волн
├── Views/
│   ├── KeyboardView.swift          // Клавиатура пианино
│   ├── OscillatorView.swift        // Контролы OSC 1/2
│   ├── ADSRView.swift              // Контролы ADSR + график
│   ├── FilterView.swift            // Контролы фильтра
│   ├── LFOView.swift               // Контролы LFO
│   ├── EffectsView.swift           // Контролы Reverb/Chorus/Delay
│   ├── PresetView.swift            // Выбор пресетов
│   └── Components/
│       ├── KnobView.swift          // Маленькая ручка
│       ├── PianoKeyView.swift      // Белая/чёрная клавиша
│       ├── WaveformPicker.swift    // Выбор формы волны
│       └── VUMeterView.swift       // VU-метры (Stereo, Compact)
├── Input/
│   └── KeyboardHandler.swift       // Обработка QWERTY (macOS)
└── Utils/
    ├── AudioMath.swift             // Математика (MIDI→freq, detune)
    ├── PresetManager.swift         // Сохранение пресетов (UserDefaults)
    └── MIDIHandler.swift           // Обработка MIDI (CoreMIDI)
```

---

## 📚 Технологии и ресурсы

### Основные фреймворки:
- **SwiftUI** - интерфейс
- **AVFoundation** - аудио движок
- **Combine** - реактивное связывание (@Published)

### Настройки проекта:
- **App Sandbox**: ОТКЛЮЧЕН (для работы с аудио)
- **Hardened Runtime**: ОТКЛЮЧЕН
- **Swift Strict Concurrency**: minimal (для совместимости с аудио-потоком)

---

## ⚠️ Важные замечания для разработчиков

1. **AudioEngine** использует `@unchecked Sendable` для работы с аудио-потоком
2. **notesLock (NSLock)** защищает activeNotes от race conditions
3. **cachedOsc2Enabled/cachedFilterCutoff/cachedMasterVolume** - копии значений для аудио-потока
4. **physicalKeysDown** в KeyboardHandler предотвращает повторные срабатывания клавиш
5. Аудио цепочка: SourceNode → Delay → Reverb → MainMixer
6. Частота дискретизации: 44100 Hz
7. **VU-метры**: обновляются каждые 2048 сэмплов через DispatchQueue.main.async
8. **Level metering**: levelDecay=0.95, peakDecay=0.9995 для плавной анимации

---

## 🚀 План улучшений (Improvements Plan)

### Этап 11: Улучшение качества звука (Sound Quality) 🎧 ✅ ГОТОВО
**Цель**: Профессиональное звучание без цифровых артефактов.

#### Задачи:
- [x] **Anti-Aliasing (Сглаживание)**: Внедрить PolyBLEP алгоритмы для осцилляторов (Sawtooth, Square).
- [x] **De-clicking**: Реализовать параметер-смузинг для Cutoff и Master Volume.
- [x] **Portamento / Glide**: Добавить эффект скольжения между нотами (Portamento).

### Этап 12: Продвинутая модуляция и Эффекты 🎛️ ✅ ГОТОВО
**Цель**: Более глубокий и живой звук.

#### Задачи:
- [x] **Улучшенный Chorus**: DSP Stereo Chorus с модуляцией в реальном времени.
- [x] **Улучшенный Reverb**: Больше контроля через пресеты.
- [x] **Расширенный LFO**: 
  - [x] Добавить формы волны: Sample & Hold (Noise/Random).
  - [x] Новые цели модуляции: PWM (ширина импульса), Pan (панорама).
- [ ] **Modulation Matrix**: Перенесено в будущие релизы (текущих целей LFO достаточно для MVP).

### Этап 14: Визуализация (Oscilloscope) 📈 ✅ ГОТОВО
**Цель**: Визуальная обратная связь в реальном времени.

#### Задачи:
- [x] **Data Capture**: Добавить буфер в AudioEngine для захвата сэмплов с выхода (post-effects).
- [x] **OscilloscopeView**: Создать View, рисующую path по этим сэмплам.
- [x] **Integration**: Встроить осциллограф на панель "EFFECTS" или "MASTER".
- [x] **Limiter**: Добавить лимитер на мастер-канале во избежание клиппинга.

### Этап 15: Unison & Modulation Matrix 🎛️ ✅ ГОТОВО
**Цель**: Жирный звук и сложная модуляция.

#### Задачи:
- [x] **Unison**: Реализовать наслоение голосов (до 7) с расстройкой (Detune) и стерео-расширением (Spread).
- [x] **Modulation Matrix**: Гибкая маршрутизация (LFO/Env/Vel -> Pitch/Amp/Pan/Cutoff).
- [x] **UI**: Добавить контролы UnisonView и ModMatrixView.

### Этап 16: Арпеджиатор и Секвенсор 🎹
**Цель**: Автоматическая генерация ритмических и мелодических паттернов.

#### Задачи:
- [x] **Clock Engine**: Создать метрономный движок 44100-sample-accurate для синхронизации.
- [x] **Arpeggiator**: Logic для преобразования аккорда в последовательность (Up/Down/Random).
- [ ] **Step Sequencer**: 16-шаговая сетка с параметрами Pitch и Velocity.
- [x] **UI**: Панель транспорта (BPM, Play/Stop) и редактора секвенсора.

