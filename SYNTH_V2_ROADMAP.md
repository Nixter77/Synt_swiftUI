# 🚀 SYNTH_V2_ROADMAP.md: План Следующего Поколения Улучшений Synt_swiftUI (v2.0)

> **СТАТУС ПРОЕКТА НА СТАРТЕ v2.0**:
> - Все 8 фаз из [`SYNTH_ROADMAP.md`](file:///Users/nikolay/gemini_projekts/Synt_swiftUI/SYNTH_ROADMAP.md) **полностью реализованы, протестированы и закоммичены**.
> - В проекте работают:
>   - **Фаза 1**: Per-Voice Filter Cutoff, `filterEnvelopeAmount` (`-1...+1`) и `filterKeyTracking` (`0...1`).
>   - **Фаза 2**: 5 таблиц Wavetable (`Basic`, `Analog`, `Digital`, `PWM`, `Formant`) + модуляция `WT Morph 1/2` через матрицу.
>   - **Фаза 3**: Sub-Oscillator (`-1`/`-2` oct, `sine`/`triangle`/`square`), Linear FM (`Osc 2 → Osc 1`) и Hard Sync.
>   - **Фаза 4**: Независимый `LFO 2`, Tempo Sync (`TimeDivision`) для LFO 1, LFO 2 и Delay, источники `LFO 2`, `Mod Wheel`, `Key Track` в матрице.
>   - **Фаза 5**: Step Sequencer Pro (`Tie/Slide` 303-style, индивидуальный `Gate` и `Octave` на шаг, двусторонняя синхронизация с `SynthPreset.sequencerData`) и Arpeggiator Pro (`arpRate`, `arpOctaves 1–3`, меню `ARP` в `UnisonView`).
>   - **Фаза 6**: 2x Oversampling с 11-tap half-band FIR в `Distortion` (`2X HQ`) и выделенный стерео `PingPongDelay` (`PONG`).
>   - **Фаза 7**: Sound Expansion Pack (`FactoryPresets+Expansion.swift`, +50 пресетов нового поколения) с навигацией в `PresetBrowser` (`E01 / 050`).
>   - **Фаза 8**: Smart Mutate (`🎲`), 4 Performance Macros (`MACRO`: Brightness, Timbre, Movement, Space), A/B Compare (`A/B`), запись звука в WAV (`● REC`) и экспорт секвенсора в MIDI (`MIDI` SMF Type 0).

---

## 🛡 ЗОЛОТЫЕ ПРАВИЛА АРХИТЕКТУРЫ (ОБЯЗАТЕЛЬНО ДЛЯ ВСЕХ МОДЕЛЕЙ)

1. **Неприкосновенность Real-Time потока (`renderOneSample()`)**:
   - **ЗАПРЕЩЕНЫ** `NSLock`, `DispatchQueue.main`, аллокации кучи (`Array`, `Dictionary`, `String`), чтение `@Published var preset` напрямую (только `cached...` поля в `AudioEngine`).
   - Любая тригонометрия в `renderOneSample()` на 32 голосах должна обновляться на control-rate (раз в 4 или 8 сэмплов) либо через быстрые аппроксимации/LUT.
2. **Сохранность эталонных тестов (`InitGoldenTests`)**:
   - Хэш `Init` (`0xd1b3635203a4799e`) и все 100 классических пресетов из `SynthPreset.factoryPresets` **ДОЛЖНЫ** оставаться 100% bit-identical!
   - Любой новый параметр в `SynthPreset` обязан иметь нейтральное дефолтное значение (при котором математика `renderOneSample()` не меняет старую ветку), декодироваться через `decodeIfPresent`, проходить `sanitize()` и добавляться **в самый конец** параметров `init(...)`.
3. **Строгие ограничения UI и Тем (`LayoutTests`, `ThemeNoAudioChangeTests`, `ThemePerformanceRuleTests`)**:
   - Высота `SynthControlGrid` во всех 3 темах (`baseline`, `studio`, `retro`) **НЕ ДОЛЖНА превышать `520 pt`**. Используйте вкладки (Segmented Pickers), компактные хедер-меню или `.popover`, чтобы не увеличивать высоту карточек!
   - В папках `Audio/`, `Models/`, `Input/`, `Utils/` **ЗАПРЕЩЕНО** упоминать слово `"Theme"`, `".theme"`, `"@Environment"` или `"@EnvironmentObject"` (даже в комментариях!).
   - В папке `Views/` **ЗАПРЕЩЕНО** использовать `.blur(`, `Material`, `AppleTheme.` или два подряд `.shadow(`.
4. **Протокол коммитов при лимитах**:
   - Выполняйте работу строго по фазам (`Phase V2.1` → `Phase V2.6`). После завершения каждой фазы запускайте тесты, отмечайте `[x]` в этом файле и делайте атомарный `git commit`.
   - Перед `git commit` проверяйте `git status`: если тест `GlassHorizonHangProbeTests` изменил `GLASS_HORIZON_PROBE_DUMP.txt`, сбрасывайте его через `git restore GLASS_HORIZON_PROBE_DUMP.txt`.

---

## 📊 Сводная Таблица Этапов v2.0 (Master Status)

| Фаза | Название этапа | Приоритет | Статус | Зависимости |
|------|----------------|-----------|--------|-------------|
| **Фаза V2.1** | Независимая ADSR-огибающая Фильтра (`Filter Envelope Env 2`) | P0 (Синтез) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.2** | Импорт пользовательских Wavetable из `.wav` (Serum / 2048-sample) | P1 (Синтез) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.3** | Стерео-панорама Унисона (`Unison Stereo Spread`) и Аналоговый Дрейф | P1 (Звук) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.4** | Расширенный секвенсор: Ratcheting (Дроби 2x/3x/4x) и Probability | P1 (Грув) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.5** | Поиск пресетов, Избранное (`★ Favorites`) и MIDI CC Learn | P2 (UX/Pro) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.6** | DSP Shimmer Reverb / Stereo Chorus Spread | P2 (DSP FX) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.7** | Ring Modulator (`Osc 1 × Osc 2`) & Цветной шум (`White/Pink/Brown`) | P1 (Синтез) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.8** | Arpeggiator Pro Groove: Gate Length (`0.1...1.0`) & Swing (`0...75%`) | P1 (Грув) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.9** | Динамика клавиш: Velocity-to-Cutoff & Velocity-to-Env Sensitivity | P1 (Экспрессия) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза V2.10** | Аккордовый унисон: Chord Memory (`Octave, Fifth, Minor, Major, Sus4`) | P2 (Гармония) | `[x]` Готово 2026-10-19 | Нет |

---

## 🔥 ФАЗА V2.1: Независимая ADSR-огибающая Фильтра (`Env 2`)

**Проблема сейчас**: В Фазе 1 `filterEnvelopeAmount` использует амплитудную огибающую голоса (`v.envelopeValue`). Однако в классических субтрактивных синтезаторах (Prophet, Jupiter, Serum) у фильтра есть **собственная независимая ADSR-огибающая (`Env 2`)**, позволяющая сделать короткий яркий щипок фильтра (`Filter Decay = 150 ms`, `Filter Sustain = 0`) поверх длинного певучего сустейна амплитуды (`Amp Sustain = 1.0`, `Amp Release = 2.0 s`).

### Шаг V2.1.1: Параметры `Filter ADSR` в `SynthPreset` и `AudioEngine`
- [x] **V2.1.1a**: В `SynthPreset.swift` добавить поля (в самый конец `init`, с `decodeIfPresent` и `sanitize()`):
  - `var filterEnvUseDedicatedADSR: Bool = false` (при `false` используется `v.envelopeValue`, сохраняя 100% совместимость со всеми 150 пресетами!)
  - `var filterAttack: Float = 0.01` (`0.001...5.0`)
  - `var filterDecay: Float = 0.3` (`0.01...10.0`)
  - `var filterSustain: Float = 0.0` (`0.0...1.0`)
  - `var filterRelease: Float = 0.3` (`0.01...10.0`)
- [x] **V2.1.1b**: В `ModSource` (`SynthPreset.swift`) добавить источник `.env2 = "Env 2 (Filter)"`.
- [x] **V2.1.1c**: В `ActiveNote` (`Note.swift`) добавить состояние второй огибающей: `var filterEnvelopeValue: Float = 0.0` и `var filterReleaseStartLevel: Float = 0.0`.
- [x] **V2.1.1d**: В `AudioEngine+Render.swift` обновлять `v.filterEnvelopeValue` аналогично амплитудной огибающей и использовать её для `filterEnvelopeAmount` (когда `cachedFilterEnvUseDedicatedADSR == true`) и для источника матрицы `.env2`.

### Шаг V2.1.2: Вкладки `AMP | FLT` в `EnvelopeView.swift`
- [x] **V2.1.2a**: В `ADSRView.swift` в заголовке карточки добавить компактный переключатель `AMP | FLT` (по образцу `LFO 1 | LFO 2` в `LFOView.swift`, не увеличивая высоту карточки!).
- [x] **V2.1.2b**: Написать unit-тест в `Synt_swiftUITests/PhaseV2FilterEnvelopeTests.swift`, проверяющий, что при `filterEnvUseDedicatedADSR = true`, `filterDecay = 0.05`, `filterSustain = 0.0` и `sustain = 1.0` фильтр закрывается быстро, тогда как амплитуда голоса продолжает звучать на полном уровне.

---

## 🌊 ФАЗА V2.2: Импорт Пользовательских Wavetable (`.wav` / Serum 2048-sample)

**Цель**: Позволить пользователю загружать собственные волновые таблицы (стандарт индустрии: моно/стерео `.wav` с длиной фрейма `2048` сэмплов, от 2 до 256 фреймов) в слот `User WT` (`index = 5`).

### Шаг V2.2.1: Парсер `.wav` таблиц в `WavetableOscillator.swift`
- [x] **V2.2.1a**: В `WavetableOscillator` добавить метод `loadFromAudioFile(url: URL) throws` (на main-потоке через `AVAudioFile`), который:
  - Читает float-сэмплы первого канала.
  - Нарезает их по `2048` сэмплов на фрейм (до 64 фреймов) с нормализацией каждого фрейма и автоматической генерацией mip-map уровней для подавления алиасинга.
- [x] **V2.2.1b**: В `OscillatorView.swift` добавить кнопку иконки папки `📂` рядом с выбором таблицы Wavetable для загрузки `.wav` файла через `NSOpenPanel`.
- [x] **V2.2.1c**: Написать unit-тест генерации временного `.wav` файла (например, 4 фрейма по 2048 сэмплов) и проверки его загрузки и чистого рендера в `WavetableOscillator`.

---

## 🎛 ФАЗА V2.3: Стерео-панорама Унисона (`Unison Stereo Spread`) и Аналоговый Дрейф (`Analog Drift`)

**Проблема сейчас**: Когда `unisonVoices > 1`, голоса унисона расстраиваются по частоте (`unisonDetune`), но все звучат в центре стереопанорамы, а их фазы стартуют синхронно.

### Шаг V2.3.1: `unisonSpread` и `analogDrift` в `SynthPreset` и `AudioEngine`
- [x] **V2.3.1a**: В `SynthPreset.swift` добавить поля:
  - `var unisonStereoSpread: Float = 0.0` (`0.0...1.0`, по умолчанию `0.0` для сохранения `InitGoldenTests`)
  - `var analogDrift: Float = 0.0` (`0.0...1.0` — микро-флуктуация высоты тона и среза фильтра каждого голоса до ±5 центов)
- [x] **V2.3.1b**: В `ActiveNote` добавить `var voicePan: Float = 0.0` и `var driftState: Float = 0.0`.
- [x] **V2.3.1c**: При спавне голосов унисона распределять `v.voicePan` равномерно слева направо (`-unisonStereoSpread ... +unisonStereoSpread`) и применять равномощностное стерео-панорамирование на выходе каждого голоса в `AudioEngine+Render.swift`.
- [x] **V2.3.1d**: В `UnisonView.swift` добавить компактную ручку `Spread` или `Drift`, уложившись в бюджет высоты `<= 520 pt`.
- [x] **V2.3.1e**: Написать unit-тест, подтверждающий, что при `unisonVoices = 4` и `unisonStereoSpread = 1.0` разница между левым и правым каналами (`abs(L - R)`) существенно больше нуля.

---

## 🎼 ФАЗА V2.4: Step Sequencer 2.0 — Ratcheting (Дроби 2x/3x/4x) и Probability

**Цель**: Сделать секвенсор способным на живые генеративные и IDM/Techno партии с вероятностью срабатывания шага и быстрыми повторами внутри одного шага (Ratchet).

### Шаг V2.4.1: Поля `ratchet` и `probability` в `SequencerStep`
- [x] **V2.4.1a**: В `SequencerStep` (`SequencerModels.swift`) добавить поля с `decodeIfPresent`:
  - `var ratchet: Int = 1` (`1...4` — количество суб-триггеров внутри одного 1/16 шага)
  - `var probability: Float = 1.0` (`0.0...1.0` — вероятность срабатывания шага, используя детерминированный/быстрый PRNG в RT-потоке без системных блокировок)
- [x] **V2.4.1b**: Расширить `SequencerStepRT` и `AudioEngine+Render.swift` для ретриггера ноты внутри шага при `ratchet > 1` и проверки вероятности при `probability < 1.0`.
- [x] **V2.4.1c**: Добавить выбор `Ratchet (1x, 2x, 3x, 4x)` и `Probability (25%, 50%, 75%, 100%)` в контекстное меню шага в `StepSequencerView.swift`.
- [x] **V2.4.1d**: Обновить `MIDIFileBuilder.swift`, чтобы при экспорте MIDI шаг с `ratchet = 3` экспортировался как 3 короткие ноты по `stepTicks / 3`.

---

## ⭐ ФАЗА V2.5: Поиск Пресетов, Избранное (`★ Favorites`) и MIDI CC Learn

**Цель**: Ускорить навигацию по 150+ пресетам и дать музыкантам привязку физических ручек MIDI-клавиатуры в два клика.

### Шаг V2.5.1: Поиск по названию и фильтр `★ Favorites` в `PresetView.swift`
- [x] **V2.5.1a**: Добавить хранение списка избранных имен пресетов (`Set<String>`) в `UserDefaults` (`"favoritePresetNames"`).
- [x] **V2.5.1b**: В попапе браузера пресетов (`PresetBrowserPopover` в `PresetView.swift`) добавить строку быстрого поиска (`TextField("Search presets...")`), фильтр `★ Favorites` и звездочку рядом с каждым пресетом.

### Шаг V2.5.2: MIDI CC Mapping & Learn
- [x] **V2.5.2a**: В `MIDIManager.swift` и `AudioCommandQueue.swift` добавить обработку произвольных MIDI Control Change (`0xB0`, `cc: UInt8`, `value: UInt8`).
- [x] **V2.5.2b**: Реализовать `MIDICCLearnStore` (сохраняемый в `UserDefaults` словарь `[UInt8: ModDestination]`), позволяющий правым кликом по ручке выбрать `Learn MIDI CC` и повернуть ручку на внешнем MIDI-контроллере.

---

## ✨ ФАЗА V2.6: Shimmer Reverb & Stereo Chorus Spread

**Цель**: Добавить кинематографический режим `Shimmer` (питч-шифт +12 полутонов в петле обратной связи/диффузии перед реверберацией) и полноценное стерео-разведение голосов хоруса.

### Шаг V2.6.1: Стерео-фаза в `DSPChorus` и октавный Shimmer
- [x] **V2.6.1a**: В `DSPChorus` добавить квадратурный сдвиг фазы LFO между левым и правым каналами ($\Delta\phi = 90^\circ$) при `chorusStereo: Bool = true` и синфазный моно-режим при `chorusStereo = false`, сохраняющий 100% bit-identical звучание классических пресетов.
- [x] **V2.6.1b**: Реализовать лёгкий real-time dual-grain октавный питч-шифтер (`ShimmerProcessor`) без аллокаций в памяти для подмешивания октавных гармоник в хвост реверберации при `reverbShimmer: Float > 0`.
- [x] **V2.6.1c**: Написать unit-тесты в `Synt_swiftUITests/PhaseV2EffectsTests.swift` и проверить неизменность `InitGoldenTests`.

---

## 🔔 ФАЗА V2.7: Ring Modulator (`Osc 1 × Osc 2`) & Цветной Шум (`White/Pink/Brown`)

**Цель**: Расширить палитру тембров аналоговым кольцевым модулятором для металлических колокольных/роботизированных звуков и генератором розового (-3dB/oct) и коричневого (-6dB/oct) шума.

### Шаг V2.7.1: Параметры `ringModAmount` и `noiseColor` в `SynthPreset` и `AudioEngine`
- [x] **V2.7.1a**: В `SynthPreset.swift` добавить поля с `decodeIfPresent`, санитизацией и дефолтами:
  - `var ringModAmount: Float = 0.0` (`0.0...1.0`, по умолчанию `0.0` для сохранения `InitGoldenTests`)
  - `enum NoiseColor: String, CaseIterable, Codable { case white = "White", pink = "Pink", brown = "Brown" }`
  - `var noiseColor: NoiseColor = .white` (по умолчанию `.white`)
- [x] **V2.7.1b**: В `Oscillator.swift` / `Note.swift` реализовать фильтрацию шума:
  - Pink noise: 3-полюсный IIR фильтр Кельвина (Paul Kellet's algorithm) с плотностью спектра $1/f$.
  - Brown noise: 1-полюсный интегратор с коэффициентом утечки $0.95$.
- [x] **V2.7.1c**: В `AudioEngine+Render.swift` добавить подмешивание кольцевой модуляции `(osc1 * osc2) * cachedRingModAmount` на уровне каждого активного голоса.
- [x] **V2.7.1d**: В `OscillatorView.swift` добавить компактную ручку `Ring` и переключатель цвета шума, уложившись в лимит высоты `<= 520 pt`.
- [x] **V2.7.1e**: Написать unit-тесты в `Synt_swiftUITests/PhaseV2RingModNoiseTests.swift`.

---

## 🎷 ФАЗА V2.8: Arpeggiator Pro Groove — Gate Length & Swing

**Цель**: Превратить арпеджиатор в выразительный грув-инструмент с регулировкой длины ноты (стаккато/легато) и аналоговым свингом (шаффлом).

### Шаг V2.8.1: `arpGateLength` и `arpSwing`
- [x] **V2.8.1a**: В `SynthPreset.swift` добавить:
  - `var arpGateLength: Float = 0.8` (`0.1...1.0`, дефолт `0.8`)
  - `var arpSwing: Float = 0.0` (`0.0...0.75`, дефолт `0.0`)
- [x] **V2.8.1b**: В `ArpeggiatorEngine.swift` и `AudioEngine+Render.swift` применять `arpGateLength` для отсечки длительности шага и сдвиг времени четных шагов тика на величину `arpSwing`.
- [x] **V2.8.1c**: В меню `ARP` в `UnisonView.swift` добавить компактные ручки `Gate` и `Swing`.
- [x] **V2.8.1d**: Написать unit-тесты в `Synt_swiftUITests/PhaseV2ArpGrooveTests.swift`.

---

## 🎹 ФАЗА V2.9: Динамика Клавиш (Velocity to Cutoff & Envelope)

**Цель**: Обеспечить естественную динамическую экспрессию при игре на MIDI-клавиатуре.

### Шаг V2.9.1: Velocity Routing
- [x] **V2.9.1a**: В `SynthPreset.swift` добавить:
  - `var velocityToCutoff: Float = 0.0` (`0.0...1.0`)
  - `var velocityToEnvAmount: Float = 0.0` (`-1.0...1.0`)
- [x] **V2.9.1b**: В `AudioEngine+Voices.swift` и `AudioEngine+Render.swift` масштабировать срез фильтра и глубину огибающей в зависимости от входящей скорости нажатия клавиши `v.velocity`.
- [x] **V2.9.1c**: В `FilterView.swift` добавить мини-ручку `Vel` рядом с `Env`.
- [x] **V2.9.1d**: Написать unit-тесты в `Synt_swiftUITests/PhaseV2VelocityTests.swift`.

---

## 🎶 ФАЗА V2.10: Chord Memory Unison (Гармонический унисон)

**Цель**: Позволить одним пальцем брать плотные полифонические аккорды (Octave, Fifth, Minor, Major, Sus4).

### Шаг V2.10.1: `chordMode` в унисоне
- [x] **V2.10.1a**: В `SynthPreset.swift` добавить:
  - `enum ChordMode: String, CaseIterable, Codable { case off = "Off", octave = "Octave", fifth = "Fifth", minor = "Minor", major = "Major", sus4 = "Sus4" }`
  - `var chordMode: ChordMode = .off`
- [x] **V2.10.1b**: В `AudioEngine+Voices.swift` при спавне голосов унисона транспонировать частоту каждого партиала в соответствии с выбранным аккордом.
- [x] **V2.10.1c**: В `UnisonView.swift` добавить меню выбора `Chord`.
- [x] **V2.10.1d**: Написать unit-тесты в `Synt_swiftUITests/PhaseV2ChordMemoryTests.swift`.

---

## 🧪 Команда Проверки Всех Тестов
```bash
cd /Users/nikolay/gemini_projekts/Synt_swiftUI
xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination "platform=macOS" -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests
```

---

## 📓 ЖУРНАЛ ВЫПОЛНЕНИЯ (v2.0 Handoff Log)

### Фаза V2.1 — 2026-10-19 ✅
- `SynthPreset.swift`: добавлены поля `filterEnvUseDedicatedADSR`, `filterAttack`, `filterDecay`, `filterSustain`, `filterRelease` (с безопасным `decodeIfPresent`, санитизацией и init-параметрами в конце).
- `ModSource`: добавлен источник модуляции `.env2 = "Env 2 (Filter)"`.
- `ActiveNote` (`Note.swift`): добавлены поля `filterEnvelopePhase`, `filterEnvelopeValue`, `filterEnvelopeTime`, `filterReleaseStartLevel`; обновлены методы `activate()`, `beginFastRelease()`, `accelerateRelease()`, `deactivate()`.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`: добавлен экземпляр `filterEnvelope: ADSREnvelope`, кеширование параметров фильтр-огибающей в `applyPreset()`.
- `AudioEngine+Render.swift`:
  - В `matrixSource()` подключен `.env2` с доставкой индивидуального значения фильтр-огибающей каждого голоса.
  - В `renderOneSample()` фильтр-огибающая вычисляется независимо (когда включена) и управляет срезом фильтра в `perVoiceFilter`.
- `ADSRView.swift`: добавлены вкладки `AMP | FLT` через `ThemeSegmented`, тумблер `ThemeToggle` для включения выделенной ADSR фильтра и 4 независимые ручки управления параметрами огибающей фильтра. Высота графа скорректирована до 54 pt, благодаря чему высота сетки строго соблюдена (`<= 520 pt` во всех 3 темах: `baseline: 516 pt`, `studio: 511 pt`, `retro: 518 pt`).
- `PresetMutator.swift`: поддержана мутация параметров выделенной огибающей фильтра.
- Тесты: `PhaseV2FilterEnvelopeTests.swift` (4 шт) проверяют значения по умолчанию, обратную совместимость, независимое закрытие фильтра при удерживаемом сустейне амплитуды, модуляцию от матрицы `.env2` и сохранение 100% bit-identical голденов `InitGoldenTests`. Все тесты проекта 100% зелёные.

### Фаза V2.2 — 2026-10-19 ✅
- `WavetableOscillator.swift`:
  - Добавлены `enum WavetableError: LocalizedError` и `import AVFoundation`.
  - Реализован парсер `static func parseAudioFile(url: URL, samplesPerFrame: Int = 2048, maxFrames: Int = 64) throws -> Wavetable` для Serum `.wav` формата (чтение float32 PCM, нарезка на 2048-сэмпловые фреймы, пик-нормализация каждого фрейма).
  - Реализован `loadFromAudioFile(url: URL) throws` с сохранением в `static var userWavetable: Wavetable?` и автоматической генерацией 11 октавных mip-map уровней через FFT.
  - В `loadBuiltin(index: Int)` добавлен слот 5 (`User`), который загружает пользовательскую таблицу или безопасно откатывается к базовой при её отсутствии.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`:
  - Добавлен метод `loadUserWavetable(url: URL, forOscillator: Int)` для загрузки файлов через UI и связки с пресетом.
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`:
  - Расширен допустимый диапазон `osc1WavetableIndex` и `osc2WavetableIndex` с `0...4` до `0...5` (где 5 = User).
- `OscillatorView.swift`:
  - В `ThemeSegmented` добавлена вкладка `User` (индекс 5).
  - В `HStack` рядом с переключателем добавлена кнопка `📂` (`NSOpenPanel` с фильтром `.wav/.audio`) для быстрого выбора файла таблицы.
- Тесты:
  - `PhaseV2WavetableImportTests.swift` (5 шт) тестирует парсер многофреймовых файлов, отбраковку некорректных размеров, чистоту генерации аудио без NaN/клиппинга и связку с `AudioEngine`.
  - `InitGoldenTests` и все тесты проекта (100%) зелёные.

### Фаза V2.3 — 2026-10-19 ✅
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`:
  - Добавлено вычисляемое свойство-алиас `unisonStereoSpread` для синхронизации со свойством `unisonSpread`.
  - Добавлено поле `analogDrift: Float = 0.0` (0.0...1.0 = микрофлуктуация высоты тона и среза фильтра до ±5 центов) с безопасным `decodeIfPresent` и санитизацией.
- `Note.swift` (`ActiveNote`):
  - Добавлены свойства `voicePan` (алиас для `pan`), `driftState`, `driftPhase`, `driftMul` и `driftCutoffMul`.
  - В `activate()` детерминированно инициализируется начальная фаза дрейфа голоса на основе ноты и индекса партиала унисона; в `deactivate()` состояние сбрасывается.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`:
  - Добавлено поле `cachedAnalogDrift`, обновляемое в `applyPreset()`.
- `AudioEngine+Voices.swift`:
  - Разрешен полный запрошенный размер унисона до 5 партиалов на ноту (`unisonCount = otherNotes >= 1 ? 1 : requested`) при одиночной удерживаемой ноте.
  - Сохранено симметричное равномощностное распределение панорамы `pan` каждого партиала от `-spreadAmount` до `+spreadAmount`.
- `AudioEngine+Render.swift`:
  - Добавлен расчет pitch drift (`osc1Freq *= v.driftMul`, `osc2Freq *= v.driftMul`) и cutoff drift на control-rate (каждые 8 сэмплов) при `cachedAnalogDrift > 0`.
  - При `cachedAnalogDrift == 0` блок полностью пропускается без каких-либо накладных расходов.
- `UnisonView.swift`:
  - Добавлена ручка `Drift` (`KnobView` с привязкой к `$preset.analogDrift`, формат `%.0f%%`) в строку унисона со `spacing: 6`. Высота карточки и всей сетки сохранена строго `<= 520 pt` (`baseline: 516 pt`, `studio: 511 pt`, `retro: 518 pt`).
- `PresetMutator.swift`:
  - Поддержана мутация параметров `unisonSpread` и `analogDrift`.
- Тесты:
  - `PhaseV2UnisonDriftTests.swift` (4 шт) проверяет значения по умолчанию, обратную совместимость, создание стерео-ширины при унисоне (разница L vs R > 0.05 при spread = 1.0 vs 0 при spread = 0), стабильность звука с аналоговым дрейфом и работу алиаса `unisonStereoSpread`.
  - `InitGoldenTests` и все тесты проекта (100%) зелёные.

### Фаза V2.4 — 2026-10-19 ✅
- `SequencerModels.swift` & `SynthPreset+Sanitize.swift`:
  - В `SequencerStep` добавлены поля `ratchet: Int = 1` (1...4) и `probability: Float = 1.0` (0.0...1.0) с безопасным `decodeIfPresent` и санитизацией (`s.ratchet = i(s.ratchet, 1, 4)`, `s.probability = f(s.probability, 0, 1, 1.0)`).
- `StepSequencer.swift`:
  - `SequencerStepRT` расширен полями `ratchet: UInt8` и `probability: Float`.
  - В `SequencerTransport.Mirror` добавлены поля `stepSkipped: Bool`, `ratchetIndex: Int` и `prngState: UInt32 = 0x12345678`.
- `AudioEngine+Render.swift`:
  - В RT-потоке реализован детерминированный lock-free xorshift32 PRNG для вероятностного гейта (`probability < 1.0` пропускает шаг без системных блокировок и без аллокаций).
  - Реализован суб-делитель шага для `ratchet > 1` (`triggerRatchetSubStep`): шаг делится на `R` равных интервалов, каждый из которых генерирует ретриггер ноты и пропорциональный гейт.
- `StepSequencerView.swift`:
  - В `SeqStepButton` и `SeqTieButton` добавлено контекстное меню для выбора `Ratchet (1x, 2x, 3x, 4x)` и `Probability (25%, 50%, 75%, 100%)`.
  - На кнопке шага отображается бейдж числа ратчетов (`step.ratchet > 1`).
- `MIDIFileBuilder.swift`:
  - При экспорте секвенсора в MIDI Standard File (SMF Type 0) шаги с `ratchet > 1` разбиваются на `rCount` отдельных нотных событий `Note-On`/`Note-Off` с корректной длительностью sub-gate.
- Тесты:
  - `PhaseV2SequencerTests.swift` (6 шт) тестирует значения по умолчанию, обратную совместимость декодирования legacy JSON, экспорт MIDI с 3 суб-нотами при `ratchet = 3`, пропуск шага при 0% вероятности, триггер при 100% вероятности, ретриггер субшагов в RT-рендере и сохранение эталонного хэша `InitGoldenTests`.
  - Все архитектурные тесты (`InitGoldenTests`, `LayoutTests`, `ThemeNoAudioChangeTests`, `ThemePerformanceRuleTests`) 100% зелёные.

### Фаза V2.5 — 2026-10-19 ✅
- `FavoritePresetsStore.swift`:
  - Создан менеджер избранных пресетов (`FavoritePresetsStore.shared`), сохраняющий `Set<String>` в `UserDefaults` под ключом `"favoritePresetNames"` с поддержкой `isFavorite`, `toggleFavorite`, `setFavorite`, `clearFavorites`.
- `MIDICCLearnStore.swift`:
  - Реализован менеджер MIDI CC Learn (`MIDICCLearnStore.shared`), сохраняющий маппинг `[UInt8: ModDestination]` в `UserDefaults` (`"midiCCMappings"`).
  - Поддерживает состояния обучения (`startLearning(for: destination)`), автоматический захват входящего CC, привязку и модуляцию целевого параметра пресета (`applyValue`).
- `AudioCommandQueue.swift` & `AudioEngine+Render.swift`:
  - В `AudioCommand` добавлена команда `.controlChange(cc: UInt8, value: UInt8)` (некритичная, lock-free SPSC в audio queue).
  - В `handleCommand` обеспечена безопасная обработка в RT-потоке.
- `MIDIHandler.swift`:
  - В `dispatch` при получении `.controlChange(controller, value, _)` команда пушится в `audioEngine.commandQueue`, а на main-потоке вызывается `MIDICCLearnStore.handleIncomingCC`, мгновенно обновляя пресет и UI ручки при наличии маппинга или в режиме обучения.
- `KnobView.swift`:
  - В `KnobView` и `LargeKnobView` добавлена привязка `destination: ModDestination?` (с автоматическим определением по названию ручки: Cutoff, Reso, Morph, PW, Detune, Mix, Rate, Depth).
  - Добавлено контекстное меню (правый клик) с кнопками `Learn MIDI CC` и `Unmap MIDI CC`.
- `PresetView.swift`:
  - В `PresetListView` добавлено компактное поле поиска (`TextField("Search presets...")`), кнопка-фильтр `★ Favorites` и кнопка-звездочка у каждого пресета в `PresetRow`.

### Фаза V2.6 — 2026-10-19 ✅
- `DSPChorus.swift`:
  - Добавлено свойство `stereo: Bool = true` и алиас `chorusStereo: Bool` с реактивным `didSet` для мгновенного плавного переключения квадратурного стерео-сдвига ($\Delta\phi = 90^\circ$) и синфазного моно-режима.
  - Побитовая математика LFO строго сохранена для `stereo == true`, что обеспечивает 100% сохранение эталонных золотых хэшей всех 100 фабричных пресетов.
- `ShimmerProcessor.swift`:
  - Реализован lock-free real-time dual-grain питч-шифтер (+12 полутонов / 1 октава вверх) без блокировок и без аллокаций памяти в render-потоке.
  - Используются два взаимно перекрывающихся зерна размером 1024 сэмпла (~23 мс) с треугольным оконным взвешиванием ($w_A + w_B = 1.0$) для кристально чистого звука без щелчков.
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`:
  - Добавлены поля `chorusStereo: Bool = true` и `reverbShimmer: Float = 0.0` (0.0...1.0) с безопасным декодированием `decodeIfPresent` и санитизацией диапазона.
- `AudioEngine.swift`, `AudioEngine+Preset.swift`, `AudioEngine+Render.swift`:
  - Добавлены `let shimmer = ShimmerProcessor()`, поля `cachedChorusStereo`, `cachedReverbShimmer`.
  - В `resetPatchStateRT()` поддержан `shimmer.reset()`.
  - В `renderOneSample()` при `cachedReverbShimmer > 0` октавный сигнал Shimmer подмешивается в мастер-поток перед реверберацией, обогащая хвост кинематографическими парящими гармониками.
- `EffectsView.swift`:
  - В заголовок карточки Chorus добавлена компактная кнопка `WIDE` для переключения стерео-панорамы хоруса.
  - В карточку Reverb добавлена компактная ручка `Shimmer` (`KnobView` с привязкой к `$preset.reverbShimmer`, формат `%.0f%%`). Высота блока и всей сетки сохранена строго `<= 520 pt` во всех темах.
- `PresetMutator.swift`:
  - Поддержана мутация параметра `reverbShimmer`.
- Тесты:
  - `PhaseV2EffectsTests.swift` (4 шт) проверяет дефолтные значения, декодирование legacy JSON, моно vs стерео-режим в `DSPChorus`, стабильность и октавный шифт в `ShimmerProcessor` и чистоту рендера в `AudioEngine`.
  - Все тесты проекта (`InitGoldenTests` 100/100, `LayoutTests`, `ThemeNoAudioChangeTests`, `ThemePerformanceRuleTests`, все Phase V2 тесты) 100% зелёные.

### Фаза V2.7 — 2026-10-19 ✅
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`:
  - Добавлены `var ringModAmount: Float = 0.0` (0.0...1.0) и `enum NoiseColor: String, CaseIterable, Codable { case white = "White", pink = "Pink", brown = "Brown" }`, `var noiseColor: NoiseColor = .white`.
  - Поддержаны безопасное декодирование `decodeIfPresent` и санитизация.
- `Note.swift` (`ActiveNote`):
  - Добавлены поля фильтров шума: `noiseB0, noiseB1, noiseB2` (для 3-полюсного IIR Кельвина Pink noise) и `noiseLastBrown` (для leaky integrator Brown noise).
  - Реализован метод `filterNoise(_ white: Float, color: NoiseColor) -> Float`. В `activate()` и `deactivate()` состояния сбрасываются в `0.0`.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`:
  - Добавлены поля `cachedRingModAmount` и `cachedNoiseColor`, синхронизируемые в `applyPreset()`.
- `AudioEngine+Render.swift`:
  - Генерация шума пропускается через `v.filterNoise(rawNoise, color: cachedNoiseColor)`.
  - При `cachedRingModAmount > 0` генерируется `s2` (если OSC 2 был выключен) и сигнал модулируется `(s1 * s2 * 2.0) * cachedRingModAmount`.
  - При `cachedRingModAmount == 0` и `noiseColor == .white` поведение математически 100% идентично предыдущему коду, что сохраняет эталонный хэш `InitGoldenTests`.
- `OscillatorView.swift`:
  - В блок OSC 2 добавлена ручка `Ring` (масштабирование `ringModAmount`).
  - При выборе формы волны `Noise` отображается селектор `Color: White | Pink | Brown`.
  - Сохранена высота панели `<= 520 pt` во всех темах.
- `PresetMutator.swift`:
  - Поддержана мутация `ringModAmount`.
- Тесты:
  - `PhaseV2RingModNoiseTests.swift` (4 шт) проверяет дефолты, обратную совместимость, спектральные свойства цветного шума, генерацию интермодуляционных частот в Ring Modulator и сохранение `InitGoldenTests`.
  - Все тесты проекта 100% зелёные.

### Фаза V2.8 — 2026-10-19 ✅
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`:
  - Добавлены поля `var arpGateLength: Float = 0.8` (диапазон `0.1...1.0`, дефолт `0.8`) и `var arpSwing: Float = 0.0` (диапазон `0.0...0.75`, дефолт `0.0`).
  - Поддержаны безопасное декодирование `decodeIfPresent` и санитизация.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`:
  - Добавлены кешированные поля `cachedArpGateLength` и `cachedArpSwing` (обновляются в `applyPreset()`).
  - Добавлены поля состояния аудио-потока `arpStepIndex: Int = 0` и `arpGateSamplesLeft: Int = 0`.
- `AudioEngine+Render.swift`:
  - Реализована функция `currentArpStepDuration() -> Double`, вычисляющая динамическую длительность тика со свингом: четные шаги (0, 2...) удлиняются на `swing * base * 0.5`, а нечетные шаги (1, 3...) укорачиваются на эту же величину, сохраняя неизменной общую длительность каждых двух шагов (`2.0 * base`).
  - В `handleArpTick(stepDuration:)` рассчитывается `arpGateSamplesLeft = max(1, Int((stepDuration * gateFrac).rounded(.down)))`.
  - В `renderOneSample()` по истечении `arpGateSamplesLeft` текущая нота переводится в `releaseHeldNote(n)` и `arp.currentNote = nil`, обеспечивая выразительное стаккато/легато.
- `UnisonView.swift`:
  - В меню `ARP` добавлены подменю `Gate` (25%, 50%, 75%, 80%, 90%, 100%) и `Swing` (0%, 15%, 30%, 50%, 66%, 75%).
  - В заголовке кнопки отображается бейдж активного свинга `S:XX%` и нестандартного гейта `G:XX%`.
  - Высота сетки сохранена строго `<= 520 pt` во всех темах (`LayoutTests` пройдены).
- `PresetMutator.swift`:
  - Поддержана мутация параметров `arpGateLength` и `arpSwing` при активном арпеджиаторе.
- Тесты:
  - `PhaseV2ArpGrooveTests.swift` (4 шт) проверяет дефолтные значения, санитизацию, декодирование legacy JSON, чередование длительностей шагов при свинге, отсечку гейта стаккато и сохранение эталонных золотых хэшей `InitGoldenTests`.
  - Все тесты проекта (`InitGoldenTests` 100/100, `LayoutTests`, `Theme...`, все фазы V2) 100% зелёные.

### Фаза V2.9 — 2026-10-19 ✅
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`:
  - Добавлены поля `var velocityToCutoff: Float = 0.0` (`0.0...1.0`, дефолт `0.0`) и `var velocityToEnvAmount: Float = 0.0` (`-1.0...1.0`, дефолт `0.0`).
  - Поддержаны безопасное декодирование `decodeIfPresent` и санитизация диапазонов.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`:
  - Добавлены кешированные поля `cachedVelocityToCutoff` и `cachedVelocityToEnvAmount`, синхронизируемые в `applyPreset()`.
- `AudioEngine+Render.swift`:
  - В флаг активации индивидуальной фильтрации на голос `perVoiceFilter` добавлена проверка `velToCutoff > 0 || velToEnvAmt != 0`.
  - В цикле фильтрации голоса срез фильтра динамически масштабируется от силы нажатия клавиши `c *= pow(2, (v.velocity - 1.0) * velToCutoff * 3.0)` (мягкое нажатие приглушает тембр, сильное раскрывает полный спектр).
  - Глубина огибающей масштабируется пропорционально скорости нажатия клавиши `envAmt *= max(0.0, 1.0 + (v.velocity - 1.0) * velToEnvAmt)`.
  - При значениях по умолчанию (0.0) математика рендера 100% bit-identical сохраняет эталонный хэш `InitGoldenTests`.
- `FilterView.swift`:
  - В строку регуляторов добавлена ручка `Vel` (управление `velocityToCutoff`, формат `%.0f%%`).
  - В заголовок карточки FILTER добавлено контекстное меню `Velocity -> Env` (Off, 25%, 50%, 75%, 100%, -50%, -100%) с компактным индикатором статуса.
  - Высота карточки и всей сетки сохранена строго `<= 520 pt` во всех темах (`LayoutTests` пройдены).
- `PresetMutator.swift`:
  - Поддержана интеллектуальная мутация параметров `velocityToCutoff` и `velocityToEnvAmount`.
- Тесты:
  - `PhaseV2VelocityTests.swift` (4 шт) проверяет дефолтные значения, санитизацию, декодирование legacy JSON, модуляцию энергии среза фильтра от силы удара, модуляцию пика огибающей и сохранение золотых хэшей `InitGoldenTests`.
  - Все тесты проекта 100% зелёные.

### Фаза V2.10 — 2026-10-19 ✅
- `SynthPreset.swift`:
  - Добавлен `enum ChordMode: String, CaseIterable, Codable { case off = "Off", octave = "Octave", fifth = "Fifth", minor = "Minor", major = "Major", sus4 = "Sus4" }`.
  - Реализован метод `semitoneOffset(for partialIndex: Int, totalPartials: Int) -> Float`, возвращающий интервалы (например, Octave: `[0, 12, 24, -12, 12]`, Fifth: `[0, 7, 12, 19, 7]`, Minor: `[0, 3, 7, 10, 12]`, Major: `[0, 4, 7, 11, 12]`, Sus4: `[0, 5, 7, 12, 17]`).
  - Добавлено поле `var chordMode: ChordMode = .off` (декодирование через `decodeIfPresent`, добавление в конец параметров `init`).
- `SynthPreset+Sanitize.swift`:
  - Добавлена санитизация `chordMode`.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`:
  - Добавлено кешированное поле `cachedChordMode`, синхронизируемое в `applyPreset()`.
- `AudioEngine+Voices.swift`:
  - В цикле генерации партиалов унисона частота каждого партиала рассчитывается с учетом гармонического сдвига: `let chordSemitones = cachedChordMode.semitoneOffset(for: u, totalPartials: unisonCount)`, `let totalCents = detuneCents + chordSemitones * 100.0`.
  - При `cachedChordMode != .off` минимальное количество партиалов автоматически повышается минимум до 3, гарантируя полноценное воспроизведение трезвучий даже при низком значении `unisonVoices`.
  - При `cachedChordMode == .off` поведение на 100% сохраняет оригинальную математику, обеспечивая идентичность золотого хэша `InitGoldenTests`.
- `UnisonView.swift`:
  - В заголовок карточки UNISON добавлено меню `Chord` с индикатором текущего строя (`Off`, `Octave`, `Fifth`, `Minor`, `Major`, `Sus4`).
  - Высота сетки сохранена строго `<= 520 pt` во всех темах (`LayoutTests` пройдены).
- `PresetMutator.swift`:
  - Поддержана мутация `chordMode`.
- Тесты:
  - `PhaseV2ChordMemoryTests.swift` (4 шт) проверяет дефолтные значения, санитизацию, декодирование legacy JSON, корректность полутоновых интервалов, транспонирование частот партиалов унисона в рендере и сохранение эталонных золотых хэшей `InitGoldenTests`.
  - Все тесты проекта (`InitGoldenTests` 100/100, `LayoutTests`, `Theme...`, все фазы V2) 100% зелёные.
