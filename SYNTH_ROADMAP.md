# 🎹 SYNTH_ROADMAP.md: Поэтапный План Развития, Новых Возможностей и Звукового Дизайна Synt_swiftUI

> **ИНСТРУКЦИЯ ДЛЯ AI-АГЕНТОВ / ДРУГИХ МОДЕЛЕЙ (HANDOFF PROTOCOL)**:
> 1. **Атомарность этапов**: Каждый этап (`Phase X.Y`) спроектирован так, чтобы его можно было выполнить за 1 сессию.
> 2. **Сохранение прогресса при лимитах**: После завершения каждого подпункта **ОБЯЗАТЕЛЬНО** обновите чекбокс `[ ]` → `[x]` в этом файле, укажите дату и запустите `xcodebuild test` (или `build`), чтобы убедиться, что проект компилируется и тесты проходят.
> 3. **Золотое правило Real-Time Audio**:
>    - В `renderOneSample()` **ЗАПРЕЩЕНЫ** `NSLock`, `DispatchQueue.main`, аллокации памяти (`Array`, `Dictionary`), чтение напрямую из `@Published var preset` (используйте только `cached...` поля) и тяжелая тригонометрия без кеша/LUT.
>    - Любые новые параметры в `SynthPreset` должны иметь дефолтные значения и декодироваться через `decodeIfPresent`, чтобы не сломать существующие 100 фабричных пресетов и сохранённые пресеты пользователя!

---

## 📊 Сводная Таблица Прогресса (Master Status)

| Фаза | Название этапа | Приоритет | Статус | Зависимости |
|------|----------------|-----------|--------|-------------|
| **Фаза 1** | Фильтр-огибающая (Filter ADSR / Env Amount) и Per-Voice Filter | P0 (Звук) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза 2** | Полный Wavetable Синтез (Выбор из 5 таблиц + Модуляция Морфинга) | P0 (Звук) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза 3** | Расширение Синтеза: Sub-Oscillator, FM-модуляция и Hard Sync | P1 (Синтез) | `[x]` Готово 2026-10-19 | Фаза 1 |
| **Фаза 4** | LFO 2, Tempo Sync (привязка к BPM) и Расширенная Матрица | P1 (Модуляция) | `[x]` Готово 2026-10-19 | Фаза 2 |
| **Фаза 5** | Step Sequencer Pro (Tie/Slide, сохр. в пресет, Arp Rate) | P1 (Грув) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза 6** | Новые Эффекты и 2x Oversampling для Distortion | P2 (DSP FX) | `[x]` Готово 2026-10-19 | Нет |
| **Фаза 7** | Новые Звуки: Sound Expansion Pack (+50 пресетов нового поколения) | P1 (Звуки) | `[x]` Готово 2026-10-19 | Фазы 1–5 |
| **Фаза 8** | Performance & Workflow: 4 Макро-контроллера, A/B Compare, WAV/MIDI Export | P2 (UX/Pro) | `[x]` Готово 2026-10-19 | Фаза 7 |

---

## 🔥 ФАЗА 1: Оживление Фильтра — Filter Envelope Amount & Key Tracking
**Проблема сейчас**: В `SynthPreset` уже есть поле `filterEnvelopeAmount`, а в UI (`FilterView`) есть ручка `Env Amt`, но в `AudioEngine+Render.swift` она **не подключена к расчету частоты среза фильтра**! Кроме того, сейчас коэффициенты фильтра считаются один раз глобально на весь сэмпл (`filterL.currentCoefficients`), поэтому огибающая не может открывать фильтр индивидуально для каждой взятой ноты.

### Шаг 1.1: Подключение `filterEnvelopeAmount` и `filterKeyTracking` в модели и кеше
- [x] **1.1.1**: В `SynthPreset.swift` проверить наличие `filterEnvelopeAmount: Float = 0.0` и добавить `var filterKeyTracking: Float = 0.0` (от `0.0` до `1.0`, по умолчанию `0.0`, в `init(from decoder:)` через `decodeIfPresent`).
- [x] **1.1.2**: В `AudioEngine.swift` добавить кеш-поля:
  - `var cachedFilterEnvAmount: Float = 0.0`
  - `var cachedFilterKeyTracking: Float = 0.0`
- [x] **1.1.3**: В `AudioEngine+Preset.swift` в `applyPreset()` копировать `preset.filterEnvelopeAmount` и `preset.filterKeyTracking` в кеш.
- [x] **1.1.4**: **Чекпоинт**: Скомпилировать проект, убедиться в отсутствии ошибок.

### Шаг 1.2: Per-Voice Filter Cutoff в `renderOneSample()`
- [x] **1.2.1**: В `CachedBiquadFilter.swift` / `ActiveNote` добавить быстрый метод расчета коэффициентов фильтра или облегченное обновление частоты среза с децимацией (например, пересчет коэффициентов голоса раз в 8 сэмплов — `controlRateCounter & 7 == 0`, чтобы не нагружать CPU на 32 голосах).
- [x] **1.2.2**: В `AudioEngine+Render.swift` внутри цикла по активным голосам (`for i in 0..<AudioEngine.maxVoices`):
  - Вычислять модуляцию среза от огибающей голоса (`v.envelopeValue * cachedFilterEnvAmount`, где `1.0` = +4 октавы: `cutoff * exp2(envMod * 4.0)`).
  - Вычислять Key Tracking относительно ноты C4 (MIDI 60): `exp2(Float(v.midiNote - 60) / 12.0 * cachedFilterKeyTracking)`.
  - Применять к `v.filter` индивидуально для каждого голоса.
- [x] **1.2.3**: В `FilterView.swift` добавить ручку `Key Trk` (`0...100%`) рядом с `Env Amt`.
- [x] **1.2.4**: Написать unit-тест `filterEnvelopeAmountOpensVoiceCutoff`, проверяющий, что при `filterEnvelopeAmount > 0` яркость спектра на атаке выше, чем на сустейне.

---

## 🌊 ФАЗА 2: Полноценный Wavetable Синтез (5 таблиц + Модуляция Морфинга)
**Проблема сейчас**: В `WavetableOscillator.swift` уже написаны и сгенерированы **5 крутых волновых таблиц**:
1. `Basic Shapes` (Sine → Tri → Saw → Square)
2. `Analog` (Warm Saw → Fat Square → Pulse → Soft Tri)
3. `Digital` (FM-like → Metallic → Bell → Harsh)
4. `PWM` (10% → 90% Pulse Width sweep)
5. `Formant` (Гласные A → E → I → O → U)
Но `AudioEngine` всегда грузит только таблицу `0` (`Basic Shapes`), а в `SynthPreset` нет выбора индекса таблицы!

### Шаг 2.1: Выбор таблицы Wavetable в `SynthPreset` и `AudioEngine`
- [x] **2.1.1**: В `SynthPreset.swift` добавить поля (с `decodeIfPresent` для обратной совместимости):
  - `var osc1WavetableIndex: Int = 0` (`0...4`)
  - `var osc2WavetableIndex: Int = 0` (`0...4`)
- [x] **2.1.2**: В `AudioEngine.swift` добавить отслеживание текущей загруженной таблицы (`private var loadedWTIndex1: Int = 0`, `private var loadedWTIndex2: Int = 0`).
- [x] **2.1.3**: В `AudioEngine+Preset.swift` в `applyPreset()` проверять: если `preset.osc1WavetableIndex != loadedWTIndex1`, вызывать `wavetableEngine1.loadBuiltin(index: preset.osc1WavetableIndex)` и обновлять `loadedWTIndex1` (аналогично для Osc 2). *Важно: делать это только при смене индекса на main-потоке, не в рендер-потоке!*

### Шаг 2.2: Модуляция Wavetable Morph в Матрице Модуляции и UI
- [x] **2.2.1**: В `ModDestination` (`SynthPreset.swift`) добавить кейсы `.wtMorph1 = "WT Morph 1"` и `.wtMorph2 = "WT Morph 2"`.
- [x] **2.2.2**: В `AudioEngine+Render.swift` подключить модуляцию морфинга от матрицы (чтобы LFO или Envelope могли плавно двигать позицию `Morph` во времени — главный секрет живых современных тембров!).
- [x] **2.2.3**: В `OscillatorView.swift` (когда выбран `.wavetable`) добавить компактный `Picker` выбора таблицы (`Basic`, `Analog`, `Digital`, `PWM`, `Formant`) над слайдером `Morph`.
- [x] **2.2.4**: **Чекпоинт**: Проверить тестами переключение всех 5 таблиц и отсутствие щелчков при морфинге.

---

## ⚡ ФАЗА 3: Расширение Ядра Синтеза (Sub-Oscillator, FM, Hard Sync)
**Цель**: Дать синтезатору плотный аналоговый фундамент (Sub) и агрессивные/металлические/колокольные гармоники (FM и Sync).

### Шаг 3.1: Sub-Oscillator (Суб-осциллятор на каждый голос)
- [x] **3.1.1**: В `SynthPreset.swift` добавить:
  - `var subOscVolume: Float = 0.0` (`0.0...1.0`)
  - `var subOscOctave: Int = -1` (`-1` или `-2` октавы относительно Osc 1)
  - `var subOscWaveform: WaveformType = .sine` (`.sine`, `.triangle` или `.square`)
- [x] **3.1.2**: В `ActiveNote` (`Note.swift`) добавить `var subPhase: Double = 0.0`.
- [x] **3.1.3**: В `AudioEngine+Render.swift` генерировать чистый суб-тон на частоте `osc1Freq * (subOscOctave == -2 ? 0.25 : 0.5)` и подмешивать к сумме осцилляторов с защитой по headroom.
- [x] **3.1.4**: Добавить компактный блок `SUB OSC` в UI (в колонку осцилляторов).

### Шаг 3.2: Cross-Modulation (Linear FM: Osc 2 → Osc 1) и Hard Sync
- [x] **3.2.1**: В `SynthPreset.swift` добавить:
  - `var fmAmount: Float = 0.0` (`0.0...1.0` — фазовая модуляция Osc 1 сигналом Osc 2)
  - `var oscSyncEnabled: Bool = false` (сброс фазы `v.phase2 = 0` каждый раз, когда `v.phase` переходит через `2π`)
- [x] **3.2.2**: В `AudioEngine+Render.swift` реализовать:
  - Если `oscSyncEnabled == true`: при переполнении `v.phase >= twoPi` сбрасывать `v.phase2 = v.phase * (osc2Freq / osc1Freq)`.
  - Если `fmAmount > 0`: модулировать фазу Osc 1 выходом Osc 2 (`phase1 + s2 * fmAmount * Float.pi`).
- [x] **3.2.3**: Добавить ручку `FM` и кнопку `SYNC` в панель `Oscillator 2`.
- [x] **3.2.4**: **Чекпоинт**: Запустить тесты, проверить отсутствие `NaN` и перегруза при `fmAmount = 1.0`.

---

## 🌀 ФАЗА 4: Модуляция 2.0 (LFO 2, Tempo Sync, Filter ADSR)
**Цель**: Сделать звук живым, ритмичным и эволюционирующим во времени.

### Шаг 4.1: Привязка LFO и Delay к темпу проекта (BPM Sync)
- [x] **4.1.1**: В `SynthPreset.swift` добавить:
  - `var lfoTempoSync: Bool = false`
  - `var lfoSyncDivision: TimeDivision = .quarter`
  - `var delayTempoSync: Bool = false`
  - `var delaySyncDivision: TimeDivision = .eighth`
- [x] **4.1.2**: При включенном `lfoTempoSync` вычислять частоту LFO из `cachedBPM` и `lfoSyncDivision`. При включенном `delayTempoSync` вычислять `delayTime` (с ограничением `0.01...2.0` сек).
- [x] **4.1.3**: Добавить переключатель `Sync` в `LFOView.swift` и `EffectsView.swift`.

### Шаг 4.2: Второй независимый LFO (`LFO 2`)
- [x] **4.2.1**: В `SynthPreset.swift` добавить параметры `lfo2Enabled`, `lfo2Rate`, `lfo2Depth`, `lfo2Waveform`, `lfo2Target`.
- [x] **4.2.2**: В `ModSource` добавить кейс `.lfo2 = "LFO 2"`, а также `.modWheel = "Mod Wheel"` и `.keyTrack = "Key Track"`.
- [x] **4.2.3**: В `AudioEngine` создать `var lfo2 = LFO()` и подключить его в `renderOneSample()` и в `matrixSource()`.
- [x] **4.2.4**: В `LFOView.swift` добавить переключатель вкладок `LFO 1 | LFO 2`.

---

## 🎼 ФАЗА 5: Step Sequencer Pro & Arpeggiator Pro
**Проблема сейчас**:
1. Арпеджиатор в `AudioEngine+Render.swift` всегда делит бит на 4 (`samplesPerTick = samplesPerBeat / 4.0` — всегда 1/16), игнорируя `preset.arpRate` (`TimeDivision`)!
2. Шаговый секвенсор не умеет делать слитные ноты (`Tie` / `Slide`) и не имеет индивидуального `Gate` на шаг.

### Шаг 5.1: Исправление скорости Арпеджиатора (`arpRate`) + Режим `Chord` и `Octave Range`
- [x] **5.1.1**: В `AudioEngine` добавить `var cachedArpRate: TimeDivision = .sixteenth` и `var cachedArpOctaves: Int = 1` (`1...3`).
- [x] **5.1.2**: В `renderOneSample()` считать `samplesPerTick` на основе `cachedArpRate.denominator` (`samplesPerBeat * 4.0 / cachedArpRate.denominator`).
- [x] **5.1.3**: В `ArpeggiatorEngine.swift` добавить развертку удерживаемых нот на `1...3` октавы вверх.

### Шаг 5.2: Step Sequencer Pro (Tie, Per-Step Gate, Ratchet)
- [x] **5.2.1**: В `SequencerStep` (`SequencerModels.swift`) добавить поля (с `decodeIfPresent`):
  - `var tie: Bool = false` (если `true`, предыдущая нота не отпускается на границе шага, а плавно тянется или скользит по питчу!)
  - `var gate: Float = 0.8` (`0.1...1.0` — длительность конкретного шага)
- [x] **5.2.2**: В `AudioEngine+Render.swift` в `triggerSequencerStep()`: если следующий шаг имеет `tie == true`, не вызывать `releaseSequencerNote()`, а менять `targetFrequency` текущего голоса (эффект классического 303 Acid Slide!).
- [x] **5.2.3**: Обновить `StepSequencerView.swift` — добавить кнопку `Tie` (иконка лиги `🔗`) под каждым из 16 шагов.

---

## 🎛 ФАЗА 6: Улучшение DSP Эффектов (2x Oversampling & Shimmer/Stereo Delay)
**Цель**: Убрать цифровой алиасинг («песок» на высоких нотах) в Distortion и расширить пространственные эффекты.

### Шаг 6.1: 2x Oversampling в `Distortion.swift`
- [x] **6.1.1**: В `Distortion.swift` добавить опциональный 2x линейный/полифазный апсэмплинг перед нелинейным шейпером (`processWavefold`, `processHardClip`, `processTubeSaturation`) и полуполосный (half-band) фильтр даунсэмплинга.
- [x] **6.1.2**: Написать тест, проверяющий подавление алиасинга на частоте 5 кГц при высоком `Drive`.

### Шаг 6.2: Stereo Ping-Pong Delay
- [x] **6.2.1**: Добавить режим `delayPingPong: Bool = false` (перекрестная обратная связь L ↔ R для широкой стереокартины).

---

## 🎨 ФАЗА 7: НОВЫЕ ЗВУКИ — Sound Expansion Pack (+50 Пресетов)
**Цель**: Когда Фазы 1–5 реализованы, синтезатор обретает совершенно новую палитру (Filter Envelope, 5 таблиц Wavetable, Formant, FM, Sync, Sub-Osc, Acid Slide). Нужно создать файл `Synt_swiftUI/Models/FactoryPresets+Expansion.swift` с **50 новыми эталонными пресетами**.

### Шаг 7.1: Категория **Vocal & Formant (8 пресетов)** *(использует таблицу `Formant` + LFO → WT Morph)*
- [x] **7.1.1**: Создать пресеты:
  1. `Choir of Angels` (Wavetable Formant, плавный LFO на Morph, длинный Attack, широкий Reverb)
  2. `Cybernetic Talking Bass` (Formant WT + Env → WT Morph + Sub Osc -1 oct + Tube Drive)
  3. `Robotic Vowel Lead` (Formant WT + ModMatrix Velocity → Morph)
  4. `Throat Singing Drone` (Низкий басовый дрон C1 с медленным морфингом гласных О → У)
  5. `Glass Soprano` (Высокий регистр Formant + Triangle Osc 2 на +1 октаву)
  6. `Alien Transmission` (Sample & Hold LFO → Formant Morph + Delay)
  7. `Synth Choir Pad` (Мягкий фильтр 1.8 кГц + Chorus + Formant таблица)
  8. `Vocoder RiffSeq` (16-шаговый паттерн секвенсора с модуляцией гласных)

### Шаг 7.2: Категория **FM & Bell / Metallic (10 пресетов)** *(использует `fmAmount` + таблицу `Digital`)*
- [x] **7.2.1**: Создать пресеты:
  1. `DX Crystal EPiano` (Классическое FM-электропиано 80-х, Sine + FM + Velocity → Amp/Cutoff)
  2. `Tokyo Marimba` (Короткий Decay, высокий FM импульс на старте, деревянный тембр)
  3. `Ice Temple Bell` (Некратный детюн Osc 2 + FM + длинный хвост реверберации)
  4. `Tubular Cathedral` (Глубокие колокола с Sub-Osc и Digital Wavetable)
  5. `Kalimba Dream` (Перкуссионный плак с яркой атакой фильтр-огибающей)
  6. `Metallic Bass Pluck` (FM + Hard Clip Distortion на малом миксе для современного House баса)
  7. `Music Box Memory` (Высокие хрустальные ноты в октаве +1 с мягким дилеем)
  8. `Gamelan Gong` (Сложный металлический спектр + Phaser)
  9. `Digital Harp` (Арпеджиатор 1/16 Up/Down с FM-колокольчиками)
  10. `Neon Vibraphone` (Тремоло от LFO 1 + стеклянный FM-тон)

### Шаг 7.3: Категория **Analog Sync & Acid 303 (10 пресетов)** *(использует `Filter Env Amt`, `oscSyncEnabled`, `Sub-Osc`, `Tie`)*
- [x] **7.3.1**: Создать пресеты:
  1. `TB-303 Acid Squelch` (Saw, высокий Resonance 0.78, `filterEnvelopeAmount = 0.75`, секвенсор с `Tie/Slide`)
  2. `Hard Sync Screamer` (`oscSyncEnabled = true`, Envelope → Pitch 2 для фирменного прорезающего лида Prodigy/Cars)
  3. `Moog Sub Phatty` (Saw + Square + Sub-Osc -1 oct + Key Tracking + Filter Env)
  4. `Prophet Brass Swell` (Медленная атака Filter Env, теплый аналоговый брасс в стиле Blade Runner)
  5. `Cyberpunk Sync Bass` (Агрессивный Mid-Bass с Hard Sync и Tube Saturation)
  6. `Classic Funk Clavinet` (Узкий импульс PWM + резкая фильтр-огибающая)
  7. `Oberheim PolyJump` (Яркий полифонический стаб с Filter Env и легким хорусом)
  8. `Subquake 808 Pro` (Чистый Sub-Osc + быстрый питч-дроп через матрицу `Env1 → Pitch1`)
  9. `Retro Synthwave Arp` (Басовый арпеджиатор 1/16 с открывающимся фильтром от велосити)
  10. `Laser Zap FX` (Быстрая огибающая на питч и фильтр с самовозбуждением)

### Шаг 7.4: Категория **Cinematic & Evolving Pads (12 пресетов)** *(использует `Analog`/`PWM` таблицы + 2 LFO)*
- [x] **7.4.1**: Создать пресеты:
  1. `Interstellar Horizon` (Органный кинематографический пэд с Sub-Osc и медленным движением фильтра)
  2. `Solar Wind Sweep` (Noise + Analog Wavetable + Phaser 6-stage)
  3. `Aurora Borealis` (LFO 1 двигает WT Morph, LFO 2 двигает панораму и фильтр)
  4. `Deep Oceanwhale` (Резонансный фильтр + питч-глайд портаменто в низком регистре)
  5. `VHS Tape Nostalgia` (Медленный питч-дрейф LFO + теплый срез высоких частот в стиле Boards of Canada)
  6. `Floating Cathedral` (Квинтовый интервал Osc 2 `+7` полутонов через детюн/октаву + воздушный хорус)
  7. `PWM String Ensemble` (Таблица `PWM` с непрерывным движением ширины импульса)
  8. `Dark Dystopia Drone` (Низкий кинематографический браам/дрон с Wavefold дисторшном)
  9. `Starlight Pluck Pad` (Гибрид мягкого плака с длинным обволакивающим хвостом)
  10. `Celestial Harmonics` (Высокие обертоны таблицы `Digital` с мягким BandPass фильтром)
  11. `Analog Warmth Bed` (Нежный подкладочный пэд с идеальным хэдрумом для аккордов из 6 нот)
  12. `Time Warp Riser` (Длинная 4-секундная атака с подъемом питча и открытием фильтра)

### Шаг 7.5: Категория **Modern EDM & Future Keys (10 пресетов)**
- [x] **7.5.1**: Создать пресеты:
  1. `Future Bass SuperChord` (Яркий Saw + PWM с накачкой амплитуды и фильтра от синхронизированного LFO)
  2. `Pluck in the Rain` (Нежный прогрессив-хаус плак с Tempo-Synced Delay 1/8)
  3. `Lo-Fi Chill Keys` (Мягкое родес-пианино с легким Bitcrush/Warmth и вибрато)
  4. `Techno Rumble Sequence` (Темный техно-секвенсор с акцентами по велосити и фильтру)
  5. `Hyperpop Lead` (Яркий унисон с быстрым портаменто и широким стерео)
  6. `Deep House Organ Chord` (Классический хаус-орган с фильтрацией и коротким перкуссионным конвертом)
  7. `Trance Gate Runner` (Секвенсор 16 шагов с чередованием гейта и октав)
  8. `Crystal Pluck Bell` (Гибрид Wavetable + Triangle с мгновенной атакой)
  9. `Warm Vinyl Rhodes` (Теплые джазовые клавиши с реакцией фильтра на силу нажатия `Velocity → Cutoff`)
  10. `Galactic Funk Lead` (Соло-лид с авто-вау от огибающей и мягким фейзером)

- [x] **7.6**: Написать автотест `expansionPresetsRenderCleanlyAndWithinHeadroom`, который прогоняет все 50 новых пресетов через оффлайн-рендер (`renderFramesMetricsForTesting`), проверяя отсутствие `NaN`, клиппинга и тишины!

---

## 🚀 ФАЗА 8: Удобство Игры, Визуализация и Экспорт (Pro Workflow)

### Шаг 8.1: 4 Макро-ручки (Performance Macros) и кнопка `🎲 Randomize / Mutate`
- [x] **8.1.1**: Добавить кнопку **Smart Mutate (`🎲`)** в `PresetView.swift`, которая плавно варьирует параметры текущего пресета на ±15% (или генерирует гармоничный музыкальный патч в выбранной категории), не уводя громкость в перегруз.
- [x] **8.1.2**: Добавить кнопку **A/B Compare**, позволяющую временно сохранить слепок звука и в один клик сравнивать накрученный звук с исходным.

### Шаг 8.2: Аудио-рекордер (Запись игры в `.wav`) и MIDI Export
- [x] **8.2.1**: Добавить запись выходного сигнала синтезатора в `AVAudioFile` (16/24-bit WAV) по кнопке `● REC` в верхней панели с сохранением файла через `NSSavePanel`.
- [x] **8.2.2**: Добавить кнопку `Export MIDI` в `StepSequencerView.swift` для сохранения 16-шагового паттерна в стандартный `.mid` файл (SMF Type 0) для перетаскивания в Logic Pro / Ableton Live.

---

## ✅ Чек-лист завершения каждого этапа (Для AI-моделей)

Перед тем как завершить ответ или при приближении к лимиту контекста, выполните:
1. [x] Все изменённые файлы сохранены и проект собирается без ошибок (`xcodebuild build`).
2. [x] Все существующие и новые unit-тесты проходят (`xcodebuild test`).
3. [x] В `SynthPreset` все новые свойства имеют значения по умолчанию и используют `decodeIfPresent` в кастомном `init(from decoder:)`.
4. [x] В этом файле (`SYNTH_ROADMAP.md`) отмечены выполненные пункты `[x]` и обновлена сводная таблица наверху.


---

## 📓 ЖУРНАЛ ВЫПОЛНЕНИЯ (Handoff Log) — дописывать в конец после каждого этапа

**Команда сборки/тестов** (нужен BypassSandbox из-за DerivedData и .git):
```bash
cd /Users/nikolay/gemini_projekts/Synt_swiftUI
xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI -destination platform=macOS -derivedDataPath /Users/nikolay/.synt_dd -only-testing:Synt_swiftUITests
```
Ожидается `** TEST SUCCEEDED **` (~1 мин). Новые файлы в `Synt_swiftUITests/` и `Synt_swiftUI/` подхватываются автоматически (synchronized groups). Коммитим в текущую ветку (`feat/phaser-control-rate`), `git add`/`git commit` требуют BypassSandbox. Голдены (`InitGoldenTests`) должны оставаться bit-identical: все новые параметры по умолчанию = выключены/нейтральны. Новые поля `SynthPreset` добавлять: property + CodingKeys + `decodeIfPresent` + sanitize + init-параметр **в конец** списка параметров init.

### Фаза 1 — 2026-10-19 ✅
- `CachedBiquadFilter.coefficients(type:cutoff:resonance:sampleRate:)` — чистая static-функция; добавлены `smoothedCutoffValue`, `effectiveResonance`.
- `ActiveNote.voiceFilterCoeffs / filterControlTick`; пересчёт коэффициентов голоса каждые 4 сэмпла.
- `SynthPreset.filterKeyTracking` (+CodingKeys, decodeIfPresent, sanitize, init-параметр в конце).
- Кеши `cachedFilterEnvAmount / cachedFilterKeyTracking`; per-voice ветка только если хоть один != 0 (иначе путь идентичен прежнему).
- Env Amt теперь биполярный (-1…1; 1 = +4 окт. при полной огибающей Env1/Amp — отдельной filter-ADSR нет). UI: ручка Key Trk в `FilterView`.
- Тесты: `Phase1FilterTests` (6 шт). Полный набор зелёный.
- ЗАМЕЧАНИЕ: `Synt_swiftUITests.swift:586` требует `filterEnvelopeAmount == 0` у фабричных пресетов ("Env Amt is not live"). В Фазе 7 новые пресеты с Env Amt ≠ 0 лежат в отдельном файле Expansion — этот тест нужно сузить до старых списков/обновить.

### Фаза 2 — 2026-10-19 ✅
- `SynthPreset.osc1WavetableIndex / osc2WavetableIndex` (0...4, с `decodeIfPresent`, sanitize, init в конце).
- `AudioEngine.loadedWTIndex1 / loadedWTIndex2` для отслеживания загруженной таблицы; загрузка через `loadBuiltin(index:)` в `applyPreset()` только при смене индекса (main thread).
- `ModDestination.wtMorph1 / wtMorph2` — модуляция morph через матрицу модуляций (LFO, Env1, Velocity), поддержано форматирование `±%`.
- В `AudioEngine+Render.swift` модуляция morph суммируется с базовой позицией morph и сглаживается через один-полюс `advanceMorph()`.
- В `OscillatorView.swift` добавлен `ThemeSegmented` выбор таблицы (`Basic`, `Analog`, `Digital`, `PWM`, `Formant`) и индикатор модуляции морфинга от матрицы.
- В `ModMatrixView.swift` добавлены новые цели в секцию "Oscillator".
- Тесты: `Phase2WavetableTests` (5 шт) — проверка всех 5 таблиц, дефолтов, санитизации, модуляции и гладкости морфинга. Все 100 фабричных голденов bit-identical.

### Фаза 3 — 2026-10-19 ✅
- `SynthPreset`: добавлены `subOscVolume`, `subOscOctave`, `subOscWaveform`, `fmAmount`, `oscSyncEnabled` (с дефолтами, CodingKeys, decodeIfPresent, sanitize, init-параметры в конце).
- `ActiveNote.subPhase`: отдельный фазовый аккумулятор субосциллятора на каждом голосе, инициализируемый в `activate()`.
- Кеши в `AudioEngine`: `cachedSubOscVolume`, `cachedSubOscOctave`, `cachedSubOscWaveform`, `cachedFmAmount`, `cachedOscSyncEnabled`.
- Linear FM (Osc 2 → Osc 1): модуляция фазы Osc 1 выходом Osc 2 в `AudioEngine+Render.swift`.
- Hard Sync: при сбросе фазы Osc 1 сбрасывается фаза Osc 2 с учетом дробного суб-сэмплового овершута.
- Sub-Oscillator: чистый тон на 1 или 2 октавы ниже Osc 1 (`.sine`, `.triangle`, `.square`) с защитой headroom (`1.0 / (1.0 + subVol * 0.4)`).
- UI в `OscillatorView`: компактный блок Sub (ручка Sub в ряду ручек Osc 1, выбор октавы и волны в заголовке Osc 1); ручка FM в ряду Osc 2, кнопка SYNC в заголовке Osc 2. Бюджет высоты сетки (`<= 520 pt`) полностью соблюдён во всех 3 темах.
- Тесты: `Phase3SynthesisTests` (6 шт) проверяют дефолты, санитизацию, отсутствие клиппинга, тембральные различия форм волны sub, влияние FM и hard sync. Все 100 фабричных голденов bit-identical.

### Фаза 4 — 2026-10-19 ✅
- `SynthPreset`: добавлены поля `lfoTempoSync`, `lfoSyncDivision`, `delayTempoSync`, `delaySyncDivision`, `lfo2Enabled`, `lfo2Rate`, `lfo2Depth`, `lfo2Waveform`, `lfo2Target`, `lfo2TempoSync`, `lfo2SyncDivision` (с дефолтами, `decodeIfPresent`, sanitize и init-параметрами в конце).
- `TimeDivision`: добавлены методы `duration(bpm:)` и `frequency(bpm:)` для точного вычисления длительностей и частот синхронизации.
- `ModSource`: добавлены `.lfo2`, `.modWheel`, `.keyTrack`.
- `AudioEngine`: добавлен независимый `var lfo2 = LFO()`, кеш `cachedLfo2Depth`, `lastMatrixLFO2`.
- `AudioEngine+Preset.swift`: вычисление темпо-синхронизированных частот для LFO 1 / LFO 2 и времени Delay из `preset.bpm` и выбранных делений `TimeDivision`.
- `AudioEngine+Render.swift`:
  - `matrixSource()` расширен для поддержки всех 6 источников (`.lfo1`, `.env1`, `.velocity`, `.lfo2`, `.modWheel`, `.keyTrack`).
  - LFO 2 продвигается на сэмпл (если включен или востребован строками матрицы); применены прямые цели Pitch, Filter, Amplitude, Pan.
  - Per-voice модуляции pitch, amp, pan от LFO 2.
- UI:
  - `LFOView.swift`: переключатель вкладок `1 | 2` (`LFO 1` и `LFO 2`), кнопка `SYNC`, селектор `TimeDivision` для синхронизированного режима.
  - `EffectsView.swift`: кнопка `SYNC` в меню Delay, селектор `TimeDivision` вместо ручки Time при включенном темпо-синке.
  - `ModMatrixView.swift`: полная поддержка всех источников модуляции в подсказках `rowHelp()`.
- Тесты: `Phase4ModulationTests` (6 шт) проверяют вычисление темпо-синка LFO и Delay, прямое воздействие LFO 2 на фильтр, матричное воздействие LFO 2, ModWheel и KeyTrack, а также сохранение неизменности 100 фабричных голденов `InitGoldenTests`. Все тесты проекта зелёные (100%).
 
### Фаза 5 — 2026-10-19 ✅
- `SequencerModels.swift`: добавлены поля `tie: Bool = false` и `gate: Float = 0.8` (0.05...1.0) в `SequencerStep` с безопасным `decodeIfPresent` и полной обратной совместимостью.
- `StepSequencer.swift`: расширены `SequencerStepRT` и `SequencerTransport.publish` для доставки `tie` и `gate` в real-time рендер без блокировок.
- `SynthPreset.swift` & `SynthPreset+Sanitize.swift`: добавлен `arpOctaves: Int = 1` (1...3) с CodingKeys, дефолтом, санитизацией и декодированием.
- `ArpeggiatorEngine.swift`: добавлено поле `octaves: Int = 1`; `setHeldKeys()` автоматически разворачивает ноты на 1...3 октавы вверх (`baseMidi + oct * 12`), сохраняя кастомную сортировку и арпеджиацию.
- `AudioEngine.swift` & `AudioEngine+Preset.swift`: кеширование `cachedArpRate` и `cachedArpOctaves` в `applyPreset()`.
- `AudioEngine+Render.swift`:
  - Скорость арпеджиатора вычисляется строго из `cachedArpRate.denominator` (`samplesPerBeat * (4.0 / Double(denominator))`), теперь арпеджио следует за четвертями, восьмыми, триолями и шестнадцатыми.
  - В шаговом секвенсоре реализован режим **303 Acid Slide**: если следующий шаг `tie == true` и нота уже удерживается, старая нота не обрывается, а вызывается glide частоты (`targetFrequency = AudioMath.midiToFrequency(midi)`).
  - Поддержан индивидуальный `gate` на каждом шаге секвенсора.
- `StepSequencerView.swift`: добавлена компактная кнопка `Tie` (`🔗`) под каждым из 16 шагов с цветовой индикацией темы.
- Тесты: `Phase5SequencerArpTests` (5 шт) проверяют октавную развертку арпеджиатора, точный расчет тиков всех делителей `TimeDivision`, ACID tie/slide glide без ретриггера огибающей и дефолты декодирования. Все 100 голденов bit-identical, 100% тестов зелёные.
 
### Фаза 6 — 2026-10-19 ✅
- `Distortion.swift`:
  - Реализован 2x оверсэмплинг: линейный апсэмплинг входного сигнала до удвоенной частоты дискретизации ($2 \times F_s$) перед шейперами (`softClip`, `hardClip`, `tubeSaturation`, `tapeSaturation`, `bitcrusher`, `wavefolder`).
  - 11-точечный полуполосный (half-band) FIR фильтр децимации (`h = [0.01, 0, -0.06, 0, 0.30, 0.50, 0.30, 0, -0.06, 0, 0.01]`) с нулевыми четными коэффициентами, обеспечивающий zero-allocation, линейную фазу и эффективное подавление гармоник алиасинга.
  - По умолчанию `oversampling = false` — 100% сохранение прежнего звучания и всех фабричных голденов.
- `PingPongDelay.swift`:
  - Реализован выделенный real-time stereo Ping-Pong Delay с перекрестной обратной связью (L $\leftrightarrow$ R) и демпфирующим фильтром (~8 кГц) для устранения резких перегрузок.
  - При монофоническом или стерео сигнале первый эхо-отклик концентрируется в левом канале, а последующие отражения поочередно перескакивают из канала в канал с плавным затуханием.
- `SynthPreset.swift`: добавлены поля `distortionOversampling: Bool = false` и `delayPingPong: Bool = false` с поддержкой `decodeIfPresent` и безопасной обратной совместимостью.
- `AudioEngine.swift`, `AudioEngine+Preset.swift`, `AudioEngine+Render.swift`:
  - Подключены `pingPongDelay` и кеширование `cachedDelayPingPong`.
  - При `delayPingPong == true` нативный `AVAudioUnitDelay` мьютируется во избежание задвоения, а DSP-движок пинг-понга обрабатывает стерео эхо в `renderOneSample()`.
- UI:
  - `AdvancedEffectsView.swift`: добавлена кнопка `2X HQ` в заголовке карточки Distortion.
  - `EffectsView.swift`: добавлена кнопка `PONG` рядом с `SYNC` в заголовке карточки Delay.
- Тесты: `Phase6EffectsTests` (5 шт) проверяют математическое подавление алиасинга на частоте 5 кГц с 8-й гармоникой, чередование эхо-пиков между левым и правым каналами (L $\to$ R), стабильность затухания, применение в AudioEngine и bit-identical совпадение `InitGoldenTests`. Все тесты проекта 100% зелёные.

### Фаза 7 — 2026-10-19 ✅
- `FactoryPresets+Expansion.swift`:
  - Создан пакет **Sound Expansion Pack (+50 пресетов)** нового поколения, раскрывающих все возможности звукового движка (Filter Envelope, Wavetable морфинг 5 таблиц, Formant, FM, Hard Sync, Sub-Oscillator, Dual LFO, Acid Slide, Ping-Pong Delay, HQ Distortion).
  - Пресеты распределены по 5 ключевым категориям:
    1. **Vocal & Formant** (8 пресетов: `Choir of Angels`, `Cybernetic Talking Bass`, `Robotic Vowel Lead`, `Throat Singing Drone`, `Glass Soprano`, `Alien Transmission`, `Synth Choir Pad`, `Vocoder RiffSeq`).
    2. **FM & Bell / Metallic** (10 пресетов: `DX Crystal EPiano`, `Tokyo Marimba`, `Ice Temple Bell`, `Tubular Cathedral`, `Kalimba Dream`, `Metallic Bass Pluck`, `Music Box Memory`, `Gamelan Gong`, `Digital Harp`, `Neon Vibraphone`).
    3. **Analog Sync & Acid 303** (10 пресетов: `TB-303 Acid Squelch`, `Hard Sync Screamer`, `Moog Sub Phatty`, `Prophet Brass Swell`, `Cyberpunk Sync Bass`, `Classic Funk Clavinet`, `Oberheim PolyJump`, `Subquake 808 Pro`, `Retro Synthwave Arp`, `Laser Zap FX`).
    4. **Cinematic & Evolving Pads** (12 пресетов: `Interstellar Horizon`, `Solar Wind Sweep`, `Aurora Borealis`, `Deep Oceanwhale`, `VHS Tape Nostalgia`, `Floating Cathedral`, `PWM String Ensemble`, `Dark Dystopia Drone`, `Starlight Pluck Pad`, `Celestial Harmonics`, `Analog Warmth Bed`, `Time Warp Riser`).
    5. **Modern EDM & Future Keys** (10 пресетов: `Future Bass SuperChord`, `Pluck in the Rain`, `Lo-Fi Chill Keys`, `Techno Rumble Sequence`, `Hyperpop Lead`, `Deep House Organ Chord`, `Trance Gate Runner`, `Crystal Pluck Bell`, `Warm Vinyl Rhodes`, `Galactic Funk Lead`).
  - Все 50 пресетов сбалансированы по хэдруму, не дают перегруза и клиппинга при игре полифонией.
  - Сохранена инвариантность: 100 основных фабричных пресетов `SynthPreset.factoryPresets` остались нетронутыми для тестов `LibraryPresetTests` и `InitGoldenTests`.
- UI:
  - `PresetView.swift`: в браузере пресетов добавлен отдельный раздел `✨ Expansion Pack (+50)` с бейджем `EXP` и фильтрацией по категориям.
- Тесты:
  - `Phase7ExpansionTests` (5 шт) проверяют наличие ровно 50 уникальных пресетов, валидность категорий, корректность оффлайн-рендеринга без `NaN`, тишины и перегруза (`expansionPresetsRenderCleanlyAndWithinHeadroom`), а также сохранение 100% bit-identical голденов `InitGoldenTests` (`0xd1b3635203a4799e`).
  - Тест `FontNameCacheTests` изолирован от параллельного межпоточного влияния.
  - Все тесты проекта 100% зелёные.

### Фаза 8 — 2026-10-19 ✅
- `PresetMutator.swift`:
  - Реализована функция умной мутации **Smart Mutate (`🎲`)**: варьирует параметры текущего пресета на ±15% (осцилляторы, морфинг таблиц, фильтр, огибающие, LFO, хорус, дилей, ревер).
  - Громкость `masterVolume` строго зафиксирована (гарантирует отсутствие перегрузов и клиппинга).
  - Название мутированного патча помечается суффиксом ` *`.
  - Реализована структура **4 Performance Macros (`PerformanceMacros`)**: `Brightness` (срез фильтра ±2 октавы + Filter Env), `Timbre` (WT Morph 1/2 + FM Amount), `Movement` (глубина и скорость LFO 1/2), `Space` (Reverb/Delay/Chorus Mix).
- `PresetView.swift` & `PresetBrowser.swift`:
  - Добавлена кнопка **Smart Mutate (`🎲`)**, попап **4 Performance Macros (`MACRO`)** и кнопка **A/B Compare** (с контекстным меню сброса и автоматическим сбросом при смене пресета).
  - В `PresetBrowser` добавлена поддержка навигации (`‹` / `›`) и счётчика (`E01 / 050`) по пресетам Expansion Pack.
- `AudioEngine.swift` & `ContentView.swift`:
  - В `AudioEngine` реализован метод записи выходного микса в WAV (`startRecording` / `stopRecording`) через Apple realtime-safe tap на `mainMixerNode` с записью в `AVAudioFile` без влияния на `renderOneSample()` и автоматическим закрытием записи при `stop()` или смене частоты дискретизации.
  - В `ContentView` обеспечена двусторонняя синхронизация `preset.sequencerData` ↔ `stepSequencer.pattern.steps` при загрузке/редактировании пресетов.
  - В верхней панели `ContentView` добавлена кнопка `● REC` с красной пульсирующей индикацией при записи и диалогом `NSSavePanel`.
- `MIDIFileBuilder.swift`, `StepSequencerView.swift` & `UnisonView.swift`:
  - Реализован генератор стандартных MIDI файлов (SMF Type 0) с поддержкой смещения октав шага (`step.octave * 12`), длины паттерна `length`, гейта и легато/tie (`tie == true`).
  - В `StepSequencerView` добавлены кнопка `MIDI` и контекстное меню на кнопке `Tie` для выбора индивидуального `Gate` (`25%..100%`) и `Octave` (`-1..+1`) шага.
  - В `UnisonView` добавлено компактное меню `ARP` (выбор режима, скорости и диапазона октав `1–3`).
- Тесты:
  - `Phase8WorkflowTests` (7 шт) проверяют безопасную мутацию параметров, работу 4 Performance Macros, генерацию SMF Type 0 с учетом октавы и длины, навигацию `PresetBrowser` по Expansion Pack, запуск/остановку аудио-записи и 100% bit-identical сохранение голденов `InitGoldenTests` (`0xd1b3635203a4799e`).
  - Все тесты проекта 100% зелёные.




