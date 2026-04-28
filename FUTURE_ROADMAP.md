
## 🌟 План дальнейшего развития (Roadmap v3.0) 2026 Edition

На основе успешной реализации базового движка, унисона и арпеджиатора, а также анализа современных трендов (Wavetable, Granular, AI), предлагается следующий план развития.

### Фаза 1: Расширение Звуковой Палитры (Sound Design Powerhouse)
1.  **Wavetable Synthesis (Таблично-волновой синтез)**
    *   Замена статических волн (Saw/Square) на проигрывание таблиц (Wavetables).
    *   Интерполяция между кадрами таблицы (Morphing).
    *   Импорт пользовательских .wav таблиц (как в Serum/Pigments).

2.  **Granular Synthesis (Гранулярный синтез)**
    *   Режим "Grain" для осцилляторов: разбиение сэмпла на мелкие гранулы.
    *   Параметры: Grain Size, Density, Spray, Pan Random.
    *   Использование для создания атмосферных пэдов и текстур.

3.  **Noise Engine 2.0**
    *   Вместо простого White Noise — сэмплер шумов (Vinyl, Rain, Atmosphere).
    *   Фильтрация шума отдельно от основного сигнала.

### Фаза 2: Продвинутая Ритмика и Генеративность (Generative & Rhythmic)
4.  **Generative Sequencer**
    *   Вероятностные шаги (Probability steps): шанс срабатывания ноты (как в Electron/Korg).
    *   Polyrhythms: разная длина секвенции для разных дорожек/модуляций.
    *   Euclidean Rhythms: генератор евклидовых ритмов.

5.  **Motion Sequencer / MSEG (Multi-Stage Envelope Generator)**
    *   Рисуемые кривые модуляции.
    *   Использование как LFO со сложной формой.

### Фаза 3: Интеллектуальные функции (AI & Smart Features)
6.  **AI Patch Generator**
    *   Кнопка "Randomize Smart": генерация случайного пресета, но с музыкально осмысленными параметрами (не просто random noise).
    *   Морфинг между двумя пресетами (XY Pad Morphing).

7.  **Microtuning & MPE**
    *   Поддержка MPE (MIDI Polyphonic Expression) для управления тембром каждого голоса отдельно (Pressure, Slide).
    *   Загрузка .scl файлов для микротоновой музыки.

### Фаза 4: Профессиональная Экосистема
8.  **AUv3 Plugin**
    *   Портирование движка в Audio Unit Extension для работы в GarageBand/Logic Pro на iPad/Mac.
    
9.  **Preset Cloud**
    *   Обмен пресетами через iCloud.

---

### Текущий приоритет (Next Steps):
1.  **Step Sequencer Implementation**: Завершить логику секвенсора (сейчас только UI).
2.  **Audio Recording**: Добавить экспорт в WAV (быстрая победа).
3.  **Wavetable Basic**: Попробовать загрузку простых таблиц.
