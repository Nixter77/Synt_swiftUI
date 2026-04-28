# SYNTHESIZER IMPROVEMENT PLAN

**Дата создания**: 2026-01-27
**Последнее обновление**: 2026-01-27 04:09
**Автор**: Senior Synthesizer Developer
**Версия**: 1.3

---

## СТАТУС ВЫПОЛНЕНИЯ

### ОТКАЧЕНО (2026-01-27 04:07)

⚠️ **Изменения в AudioEngine.swift вызвали артефакты и искажения звука и были откачены к оригиналу.**

Следующие изменения были **откачены**:
- P0.1-P0.7 критические исправления в AudioEngine
- True stereo filter
- Lock-free command queue интеграция
- MIDI direct calls
- Hermite interpolation в Chorus

### СОЗДАННЫЕ МОДУЛИ (НЕ ИНТЕГРИРОВАНЫ)

Следующие файлы созданы и скомпилированы, но **НЕ подключены** к audio chain:

| Файл | Описание | Статус |
|------|----------|--------|
| `Audio/AudioCommandQueue.swift` | Lock-free SPSC очередь | ✅ Готово, не интегрировано |
| `Audio/AtomicMeteringState.swift` | Atomic level metering | ✅ Готово, не интегрировано |
| `Audio/CachedBiquadFilter.swift` | Cached Biquad filter | ✅ Готово, не интегрировано |
| `Audio/VoiceState.swift` | VoiceManager | ✅ Готово, не интегрировано |
| `Audio/WavetableOscillator.swift` | Wavetable с mip-mapping | ✅ Готово, не интегрировано |
| `Audio/Effects/Distortion.swift` | 6 типов дисторшна | ✅ Готово, не интегрировано |
| `Audio/Effects/ParametricEQ.swift` | 3-band EQ | ✅ Готово, не интегрировано |
| `Audio/Effects/Compressor.swift` | Компрессор/лимитер | ✅ Готово, не интегрировано |

---

### СЛЕДУЮЩИЕ ШАГИ

#### Рекомендуемый подход для интеграции

1. **Один модуль за раз** - интегрировать по одному модулю с тестированием после каждого
2. **Начать с простого** - сначала CachedBiquadFilter (замена SynthFilter)
3. **A/B тестирование** - сравнивать звук до и после каждого изменения
4. **Постепенная интеграция** - не менять несколько систем одновременно

#### Приоритет интеграции

1. [ ] `CachedBiquadFilter` - заменить SynthFilter (осторожно!)
2. [ ] `AudioCommandQueue` + `VoiceManager` - lock-free notes
3. [ ] `AtomicMeteringState` - thread-safe metering
4. [ ] `WavetableOscillator` - новый тип осциллятора
5. [ ] Effects chain (Distortion, EQ, Compressor)

---

### ПРЕДСТОИТ СДЕЛАТЬ

#### Фаза 2 - Новые движки синтеза
- [x] Wavetable Oscillator с mip-mapping ✅
- [ ] Интеграция Wavetable в AudioEngine и UI
- [ ] Granular Engine
- [ ] FM Synthesis (4-6 операторов)

#### Фаза 3 - Расширенная модуляция
- [ ] 4 LFO вместо 1
- [ ] 3 Envelope вместо 1
- [ ] Macro Controls (8 knobs)
- [ ] MPE Support

#### Фаза 4 - Эффекты
- [x] Distortion/Saturation (6 типов) ✅
- [x] 3-band Parametric EQ ✅
- [x] Compressor/Limiter ✅
- [x] Phaser/Flanger (6 режимов) ✅
- [ ] Интеграция эффектов в AudioEngine
- [ ] Effects Rack UI (4 слота)

#### Фаза 5 - UI/UX
- [x] Spectrum Analyzer (FFT) ✅
- [ ] Wavetable 3D View
- [ ] Improved Oscilloscope (trigger mode)
- [ ] Preset Browser с категориями

#### Фаза 6 - Продвинутые возможности
- [ ] Oversampling 2x/4x
- [x] Step Sequencer (engine + UI) ✅
- [x] Интеграция Step Sequencer в ContentView ✅
- [ ] Sample Import
- [ ] Undo/Redo System

---

## СОДЕРЖАНИЕ

1. [Executive Summary](#executive-summary)
2. [Code Review: Критические проблемы](#code-review-критические-проблемы)
3. [Анализ современных синтезаторов](#анализ-современных-синтезаторов)
4. [План улучшений по приоритетам](#план-улучшений-по-приоритетам)
5. [Детальная архитектура новых функций](#детальная-архитектура-новых-функций)
6. [Roadmap](#roadmap)

---

## EXECUTIVE SUMMARY

Synt_swiftUI — это полнофункциональный субтрактивный синтезатор с хорошей базовой архитектурой. Однако для достижения уровня современных профессиональных инструментов (Serum 2, Vital, Pigments) требуются существенные улучшения в следующих областях:

### Текущее состояние
- **Сильные стороны**: PolyBLEP anti-aliasing, Biquad фильтр, ADSR, Unison, Mod Matrix, 20 пресетов
- **Критические проблемы**: Thread-safety (NSLock в audio thread), data races с @Published, потеря стерео перед фильтром

### Ключевые направления улучшений
1. **Архитектура** — переход на lock-free audio thread
2. **Synthesis Engines** — Wavetable, Granular, FM
3. **Модуляция** — расширенная матрица, Envelope Follower, Macro Controls
4. **Эффекты** — Distortion, EQ, Compressor, Phaser, Flanger
5. **UI/UX** — визуализация спектра, drag-and-drop модуляции

---

## CODE REVIEW: КРИТИЧЕСКИЕ ПРОБЛЕМЫ

### P0 — БЛОКИРУЮЩИЕ - ИСПРАВЛЕНО

#### 1. NSLock в Real-Time Audio Thread - ИСПРАВЛЕНО
**Файл**: `AudioEngine.swift:147-148` (старый код удалён)

**Было**:
```swift
func generateSample() -> (Float, Float) {
    notesLock.lock()      // БЛОКИРУЮЩИЙ вызов в real-time thread!
    defer { notesLock.unlock() }
```

**Стало**: Lock-free SPSC очередь `AudioCommandQueue.swift`:
```swift
// UI thread
func noteOn(midiNote: Int, velocity: Float) {
    _ = commandQueue.push(.noteOn(midiNote: midiNote, velocity: velocity))
}

// Audio thread
private func processCommands() {
    while let command = commandQueue.pop() { ... }
}
```

#### 2. Data Race с @Published свойствами - ИСПРАВЛЕНО
**Файл**: `AudioEngine.swift:395-398, 411-412` (старый код удалён)

**Было**:
```swift
DispatchQueue.main.async { [weak self] in
    self?.outputLevel = level
    self?.peakLevel = peak
}
```

**Стало**: Atomic state + Timer polling:
```swift
// Audio thread - atomic write
meteringState.setOutputLevel(currentLevel)
meteringState.setPeakLevel(currentPeak)

// UI thread - Timer 60Hz polling
private func pollMeteringState() {
    outputLevel = meteringState.getOutputLevel()
    peakLevel = meteringState.getPeakLevel()
    scopeData = meteringState.readScopeBuffer()
}
```

#### 3. Пересчёт коэффициентов фильтра на каждый sample - ИСПРАВЛЕНО
**Файл**: `Filter.swift` заменён на `CachedBiquadFilter.swift`

**Было**:
```swift
func process(_ input: Float, sampleRate: Float) -> Float {
    let omega = 2.0 * Float.pi * normalizedCutoff
    let sinOmega = sin(omega)  // Тригонометрия на КАЖДЫЙ sample!
```

**Стало**: Dirty flag + кэширование:
```swift
@inline(__always)
func process(_ input: Float, sampleRate: Float) -> Float {
    // Пересчёт только когда isDirty
    if isDirty || abs(cachedSampleRate - sampleRate) > 0.1 {
        recalculateCoefficients(sampleRate: sampleRate)
        isDirty = false
    }
    // Быстрая обработка с кэшированными коэффициентами
    return b0 * input + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
}
```

### P1 — ВАЖНЫЕ

#### 4. Чтение preset напрямую в audio thread
**Файл**: `AudioEngine.swift:162, 168, 453, 533, 556, 635, 646`
```swift
let bpm = preset.bpm  // @Published свойство читается из audio thread
```
**Решение**: Кэшировать все параметры preset в thread-safe переменных.

#### 5. cachedOsc2Enabled не синхронизируется
**Файл**: `AudioEngine.swift:41`
```swift
private var cachedOsc2Enabled: Bool = true  // Никогда не обновляется в applyPreset()!
```

#### 6. MIDI latency через main queue
**Файл**: `MIDIHandler.swift:137-143`
```swift
DispatchQueue.main.async {
    self.audioEngine?.noteOn(...)
}
```
**Решение**: Вызывать noteOn напрямую из MIDI callback с lock-free note management.

### P2 — СРЕДНИЕ

#### 7. Потеря стерео перед фильтром
**Файл**: `AudioEngine.swift:352-356`
```swift
let monoMix = (mixedSampleL + mixedSampleR) * 0.7  // Stereo → Mono
let filteredSample = filter.process(monoMix)
```
**Решение**: Создать второй экземпляр фильтра для true stereo processing.

#### 8. Linear interpolation в Chorus
**Файл**: `DSPChorus.swift:77-86`
```swift
return s0 + (s1 - s0) * frac  // Linear interpolation
```
**Решение**: Использовать кубическую (Hermite) или all-pass интерполяцию для quality.

#### 9. Отсутствие denormal protection в Filter
**Файл**: `Filter.swift:69-75`
**Решение**: Добавить flush-to-zero или DC blocker.

### P3 — НЕЗНАЧИТЕЛЬНЫЕ

- Triangle wave без PolyBLEP (Oscillator.swift:51-55)
- Hardcoded modulation amounts в LFO (LFO.swift:59-72)
- Дублирование кода internalNoteOn/createVoiceNoLock
- UUID генерация для каждого ActiveNote

---

## АНАЛИЗ СОВРЕМЕННЫХ СИНТЕЗАТОРОВ

### Serum 2 (Xfer Records) — Industry Standard
**Ключевые инновации**:
- **3 осциллятора** вместо 2, каждый с 5 engines: Wavetable, Sample, Multi-sample, Granular, Spectral
- **Granular Oscillator** — real-time grain manipulation
- **Spectral Oscillator** — resynthesis на harmonic level
- **Smooth Wavetable Interpolation** — near-infinite frame positions
- **FM, PD, Ring Mod, Distortions** встроены в каждый осциллятор

### Vital (Matt Tytel) — Free/Open Architecture
**Ключевые инновации**:
- **Spectral Warping** — уникальная трансформация wavetables
  - Random Amplitude, Harmonic Stretch, Spectral Time Skew, Data Compress
- **Text-to-Wavetable** — генерация волн из текста
- **Visual Modulation** — drag-and-drop routing с real-time feedback
- **3-voice FM** — OSC3 модулирует OSC1 с pitch control
- **Free Core Engine** — монетизация через контент (пресеты, wavetables)

### Arturia Pigments 7
**Ключевые инновации**:
- **8 synthesis engines**: Wavetable, Virtual Analog, Additive, Sample/Granular, Harmonic, Utility Noise, Modal/Physical Modeling
- **Physical Modeling** — резонаторы и exciters
- **Comprehensive effects** — 17+ встроенных эффектов

### Тренды 2025-2026
1. **Hybrid Synthesis** — комбинирование разных engines в одном инструменте
2. **AI/ML Integration** — DDSP (Differentiable DSP), text-to-audio
3. **Visual Modulation** — интуитивный drag-and-drop для mod routing
4. **CPU Optimization** — SIMD, oversampling только где нужно
5. **Spectral Processing** — работа в frequency domain

---

## ПЛАН УЛУЧШЕНИЙ ПО ПРИОРИТЕТАМ

### ФАЗА 1: СТАБИЛЬНОСТЬ И ПРОИЗВОДИТЕЛЬНОСТЬ (P0)

#### 1.1 Lock-Free Audio Architecture
**Задачи**:
- [ ] Заменить NSLock на lock-free triple buffer для activeNotes
- [ ] Создать command ring buffer для Note On/Off/CC
- [ ] Использовать OSAtomicFloat для level metering
- [ ] Разделить AudioEngine на AudioCore (no Combine) и AudioEngineViewModel

**Новые файлы**:
```
Audio/
├── Core/
│   ├── LockFreeVoiceManager.swift   # Triple buffered voice state
│   ├── CommandRingBuffer.swift      # Note commands queue
│   └── AtomicFloat.swift            # Thread-safe float wrapper
├── AudioCore.swift                  # Pure real-time processing
└── AudioEngineViewModel.swift       # ObservableObject wrapper
```

#### 1.2 Filter Coefficient Caching
**Задачи**:
- [ ] Кэшировать Biquad коэффициенты (b0, b1, b2, a1, a2)
- [ ] Пересчитывать только при изменении cutoff/resonance
- [ ] Добавить smoothing для parameter changes
- [ ] Добавить denormal protection (flush-to-zero)

#### 1.3 True Stereo Filter
**Задачи**:
- [ ] Создать два независимых фильтра (L/R)
- [ ] Сохранить stereo panning до и после фильтра
- [ ] Опционально: stereo width control на фильтре

### ФАЗА 2: НОВЫЕ ДВИЖКИ СИНТЕЗА

#### 2.1 Wavetable Oscillator
**Архитектура**:
```swift
class WavetableOscillator {
    var wavetables: [[Float]]        // 256 frames x 2048 samples
    var framePosition: Float         // 0-255, morphing position
    var mipMaps: [[[Float]]]         // Per-octave band-limited versions

    func generateSample(phase: Double, frequency: Double) -> Float
    func morphTo(frame: Float, duration: Float)
    func loadWavetable(from url: URL)
}
```

**Задачи**:
- [ ] Реализовать Wavetable с mip-mapping (11 octaves)
- [ ] Wavetable morphing с smooth interpolation
- [ ] Импорт .wav файлов (single-cycle или multi-frame)
- [ ] Встроенные базовые wavetables (Basic Shapes, Analog, Digital)
- [ ] Spectral warping modes (Sync, Bend, PWM)

**UI**:
- [ ] WavetableView с 3D визуализацией
- [ ] Frame position knob с модуляцией
- [ ] Drag-and-drop импорт wavetables

#### 2.2 Granular Engine
**Архитектура**:
```swift
class GranularEngine {
    struct Grain {
        var startPosition: Double    // Sample position
        var duration: Float          // 10-100ms
        var pitch: Float             // Playback rate
        var pan: Float               // Stereo position
        var envelope: GrainEnvelope  // Parabolic/Raised Cosine
    }

    var sampleBuffer: [Float]        // Source audio
    var grainDensity: Float          // Grains per second
    var grainSize: Float             // Duration in ms
    var scatter: Float               // Position randomization
    var activeGrains: [Grain]

    func scheduleGrain()
    func processGrains() -> (Float, Float)
}
```

**Задачи**:
- [ ] Grain scheduling с density control
- [ ] Multiple envelope types (Parabolic, Trapezoidal, Raised Cosine)
- [ ] Position scrubbing с freeze mode
- [ ] Pitch shifting независимо от position
- [ ] Stereo scatter для spatial distribution

**UI**:
- [ ] GranularView с waveform display
- [ ] Position/Size/Density/Scatter knobs
- [ ] Freeze button
- [ ] Sample drag-and-drop

#### 2.3 FM Synthesis
**Архитектура**:
```swift
class FMOperator {
    var waveform: WaveformType
    var ratio: Float                 // Frequency ratio
    var level: Float                 // Modulation index
    var envelope: ADSREnvelope

    func modulate(_ carrier: Double, at sampleRate: Double) -> Double
}

class FMEngine {
    var operators: [FMOperator]      // 4-6 operators
    var algorithm: FMAlgorithm       // DX7-style routing

    func process(frequency: Double) -> Float
}
```

**Задачи**:
- [ ] 4-6 операторов с feedback
- [ ] 32 алгоритма (DX7-compatible)
- [ ] Ratio/Level/Envelope per operator
- [ ] Velocity scaling per operator

### ФАЗА 3: РАСШИРЕННАЯ МОДУЛЯЦИЯ

#### 3.1 Full Modulation Matrix
**Источники (Sources)**:
- [ ] LFO 1-4 (расширить до 4 LFO)
- [ ] Envelope 1-3 (добавить 2 дополнительных envelope)
- [ ] Velocity
- [ ] Aftertouch
- [ ] Mod Wheel (CC1)
- [ ] Note Number
- [ ] Random (per-note)
- [ ] Envelope Follower (audio input)

**Цели (Destinations)**:
- [ ] OSC 1/2/3 Pitch, Level, Pan, Wavetable Position
- [ ] Filter Cutoff, Resonance, Drive
- [ ] Amp Level, Pan
- [ ] LFO Rate, Depth
- [ ] Effect parameters (Chorus rate, Reverb size, etc.)
- [ ] Grain Size, Position, Density

**UI**:
- [ ] Drag-and-drop modulation (как Vital)
- [ ] Bipolar/Unipolar toggle per slot
- [ ] Amount visualization на каждом knob

#### 3.2 Macro Controls
**Задачи**:
- [ ] 8 Macro knobs (0-100%)
- [ ] Каждый Macro может управлять несколькими параметрами
- [ ] MIDI Learn для любого параметра
- [ ] Macro → Mod Matrix integration

#### 3.3 MPE Support
**Задачи**:
- [ ] Per-note pitch bend
- [ ] Per-note pressure (aftertouch)
- [ ] Per-note slide (CC74)
- [ ] MPE configuration (zone, pitch range)

### ФАЗА 4: ЭФФЕКТЫ

#### 4.1 Distortion/Saturation
**Типы**:
- [ ] Soft Clip
- [ ] Hard Clip
- [ ] Tube Saturation
- [ ] Tape Saturation
- [ ] Bitcrusher
- [ ] Wavefolder

**Параметры**: Drive, Tone, Mix

#### 4.2 EQ
**Типы**:
- [ ] 3-band parametric EQ
- [ ] Tilt EQ (one-knob)
- [ ] High/Low shelf

#### 4.3 Compressor/Limiter
**Параметры**: Threshold, Ratio, Attack, Release, Makeup Gain

#### 4.4 Phaser/Flanger
**Общие параметры**: Rate, Depth, Feedback, Mix
**Phaser**: 4/8/12 stages
**Flanger**: Delay time, Stereo width

#### 4.5 Effects Rack
- [ ] 4 слота эффектов с drag-and-drop
- [ ] Pre/Post filter routing
- [ ] Serial/Parallel режимы

### ФАЗА 5: УЛУЧШЕНИЯ UI/UX

#### 5.1 Spectrum Analyzer
**Задачи**:
- [ ] FFT-based спектральный анализ
- [ ] Pre/Post filter visualization
- [ ] Peak hold
- [ ] Logarithmic frequency scale

#### 5.2 Wavetable 3D View
**Задачи**:
- [ ] OpenGL/Metal для плавного рендеринга
- [ ] Rotation и zoom
- [ ] Current frame highlight

#### 5.3 Improved Oscilloscope
**Задачи**:
- [ ] Trigger mode (sync to waveform)
- [ ] Time scale adjustment
- [ ] Freeze mode

#### 5.4 Preset Browser
**Задачи**:
- [ ] Categories и tags
- [ ] Favorites
- [ ] Search
- [ ] Preview audio
- [ ] Import/Export (.syntp format)

### ФАЗА 6: ПРОДВИНУТЫЕ ВОЗМОЖНОСТИ

#### 6.1 Oversampling
**Задачи**:
- [ ] 2x/4x oversampling для осцилляторов
- [ ] Oversampling для distortion
- [ ] Bypass oversampling для CPU economy

#### 6.2 Step Sequencer (завершение)
**Задачи**:
- [ ] 16/32/64 шагов
- [ ] Note, Velocity, Gate per step
- [ ] Tie notes
- [ ] Pattern slots (A-H)
- [ ] MIDI clock sync

#### 6.3 Sample Import
**Задачи**:
- [ ] Drag-and-drop samples
- [ ] Auto-slice for granular
- [ ] Pitch detection
- [ ] Loop points editing

#### 6.4 Undo/Redo System
**Задачи**:
- [ ] Command pattern для всех изменений
- [ ] Undo stack (50+ levels)
- [ ] Redo support

---

## ДЕТАЛЬНАЯ АРХИТЕКТУРА НОВЫХ ФУНКЦИЙ

### Lock-Free Voice Manager

```swift
/// Triple-buffered voice state for lock-free audio/UI communication
final class LockFreeVoiceManager {
    private var buffers: [VoiceState] = [VoiceState(), VoiceState(), VoiceState()]
    private var readIndex: UnsafeAtomic<Int> = .create(0)
    private var writeIndex: UnsafeAtomic<Int> = .create(1)

    /// Called from audio thread (lock-free read)
    func getActiveVoices() -> [Voice] {
        return buffers[readIndex.load(ordering: .acquiring)].voices
    }

    /// Called from main thread (lock-free write)
    func updateVoices(_ voices: [Voice]) {
        let writeIdx = writeIndex.load(ordering: .acquiring)
        buffers[writeIdx].voices = voices

        // Swap read/write atomically
        let oldRead = readIndex.exchange(writeIdx, ordering: .releasing)
        writeIndex.store(oldRead, ordering: .releasing)
    }
}
```

### Command Ring Buffer

```swift
/// Lock-free command queue for Note On/Off/CC
struct AudioCommand {
    enum CommandType: UInt8 {
        case noteOn, noteOff, controlChange, pitchBend, allNotesOff
    }

    var type: CommandType
    var note: UInt8
    var velocity: UInt8
    var timestamp: UInt64
}

final class CommandRingBuffer {
    private let capacity: Int = 256
    private var buffer: UnsafeMutableBufferPointer<AudioCommand>
    private var head: UnsafeAtomic<Int> = .create(0)
    private var tail: UnsafeAtomic<Int> = .create(0)

    /// Called from MIDI/UI thread
    func push(_ command: AudioCommand) -> Bool { ... }

    /// Called from audio thread
    func pop() -> AudioCommand? { ... }
}
```

### Wavetable Mip-Mapping

```swift
/// Band-limited wavetable with mip-maps per octave
class BandLimitedWavetable {
    private var mipMaps: [[Float]]  // 11 octaves (C0-C10)
    private let tableSize: Int = 2048

    init(waveform: [Float]) {
        mipMaps = generateMipMaps(waveform)
    }

    private func generateMipMaps(_ source: [Float]) -> [[Float]] {
        var maps: [[Float]] = []
        var current = source

        for octave in 0..<11 {
            // FFT → Clear harmonics above Nyquist → IFFT
            let bandLimited = applyFFTBandLimit(current, maxHarmonic: 1 << (10 - octave))
            maps.append(bandLimited)
        }
        return maps
    }

    func sample(phase: Double, frequency: Double, sampleRate: Double) -> Float {
        // Select mip-map based on frequency
        let octave = max(0, min(10, Int(log2(frequency / 20.0))))
        return interpolateCubic(mipMaps[octave], at: phase)
    }
}
```

### Granular Scheduler

```swift
/// Real-time grain scheduling with overlap
class GrainScheduler {
    struct GrainParams {
        var position: Float      // 0-1 in sample
        var size: Float          // 10-200ms
        var pitch: Float         // 0.5-2.0
        var pan: Float           // -1 to 1
        var density: Float       // grains/sec
    }

    private var grains: [ActiveGrain] = []
    private var sampleBuffer: [Float] = []
    private var nextGrainTime: Double = 0

    func process(sampleRate: Double, params: GrainParams) -> (Float, Float) {
        // Schedule new grains based on density
        let interOnsetTime = 1.0 / Double(params.density)

        while nextGrainTime <= 0 {
            spawnGrain(params)
            nextGrainTime += interOnsetTime * (1 + scatter * randomBipolar())
        }
        nextGrainTime -= 1.0 / sampleRate

        // Process active grains
        var outputL: Float = 0
        var outputR: Float = 0

        grains.removeAll { $0.isFinished }

        for grain in grains {
            let sample = grain.process(sampleBuffer)
            let (gainL, gainR) = panGains(grain.pan)
            outputL += sample * gainL
            outputR += sample * gainR
        }

        return (outputL, outputR)
    }
}
```

---

## ROADMAP

### Q1 2026 — Stability & Core (v1.1)
- [ ] Lock-free audio architecture (P0 fixes)
- [ ] Filter coefficient caching
- [ ] True stereo filter
- [ ] Denormal protection
- [ ] Full MIDI CC support (Mod Wheel, Aftertouch)

### Q2 2026 — Wavetable Engine (v1.5)
- [ ] Wavetable oscillator с mip-mapping
- [ ] Wavetable morphing
- [ ] Basic wavetable library (50+ tables)
- [ ] Import custom wavetables
- [ ] 3D wavetable visualization

### Q3 2026 — Granular & Effects (v2.0)
- [ ] Granular synthesis engine
- [ ] Sample import
- [ ] Distortion effects (5 types)
- [ ] EQ и Compressor
- [ ] Effects rack (4 slots)

### Q4 2026 — FM & Modulation (v2.5)
- [ ] FM synthesis (4-6 operators)
- [ ] Extended modulation matrix
- [ ] 4 LFOs, 3 Envelopes
- [ ] Macro controls (8)
- [ ] MPE support

### Q1 2027 — Polish & Pro Features (v3.0)
- [ ] Oversampling (2x/4x)
- [ ] Spectrum analyzer
- [ ] Advanced preset browser
- [ ] Undo/Redo
- [ ] DAW integration (AU/VST wrapper)

---

## ИСТОЧНИКИ

### Исследование современных синтезаторов
- [Serum 2 vs Vital: Ultimate Comparison 2025](https://theproducerschool.com/blogs/music-production/serum-2-vs-vital-the-ultimate-wavetable-synth-comparison-2025)
- [Ultimate Soft Synth Showdown: Serum 2, Pigments 6, Phase Plant, Vital](https://www.musicradar.com/music-tech/the-ultimate-soft-synth-showdown-serum-2-pigments-6-phase-plant-vital-and-massive-x-but-which-is-best)
- [Serum 2 vs Pigments 7 vs Vital 2026](https://dawzone.com/serum-2-vs-pigments-6-vs-vital-which-soft-synth-is-the-best)
- [20 Best Sound Design VST Plugins 2026](https://pluginoise.com/20-best-sound-design-plugins/)

### DSP техники
- [Wavetable Synthesis Algorithm Explained](https://thewolfsound.com/sound-synthesis/wavetable-synthesis-algorithm/)
- [Alias-free Oscillators — Vaporizer2](https://www.vast-dynamics.com/?q=node/181)
- [Oscillator Antialiasing (BLEP, PolyBLEP)](https://www.kvraudio.com/forum/viewtopic.php?t=437116)
- [Granular Synthesis DSP Labs](https://lcav.gitbook.io/dsp-labs/granular-synthesis)
- [Modulation Matrix Design](https://dreyandersson.com/music-production-terms/modulation-matrix/)

### Архитектура
- [Designing Software Synthesizer Plugins in C++ — Will Pirkle](https://thewolfsound.com/designing-software-synthesizer-plugins-in-cpp-with-audio-dsp-by-will-pirkle-book-review/)
- [Polyphonic Synthesizer Architecture](https://www.perfectcircuit.com/signal/polyphonic-modular-synthesizer)
- [Voice Management Polyphony](https://www.patchandtweak.com/the-question-of-polyphony-an-introduction-to-the-synthesizer/)

---

## ЗАКЛЮЧЕНИЕ

Данный план превратит Synt_swiftUI из базового субтрактивного синтезатора в современный гибридный инструмент уровня Serum 2 / Vital. Ключевые приоритеты:

1. **Сначала — стабильность**: исправить thread-safety проблемы
2. **Затем — новые engines**: Wavetable → Granular → FM
3. **Параллельно — модуляция и эффекты**: расширить creative possibilities
4. **В конце — polish**: UI/UX, preset browser, DAW integration

Каждая фаза независима и может быть релизнута отдельно, обеспечивая постоянный прогресс и обратную связь от пользователей.
