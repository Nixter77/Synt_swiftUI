# GROK_BUILD_TASKS_2 — Synt_swiftUI: сменные скины

Задача: сделать у синтезатора три сменных скина. Это **Baseline** (светлый neumorphic, подчищенный текущий), **Dark Studio** (тёмный «железный», янтарный) и **Retro Analog** (кремовая панель, орех, стрелочные VU). Переключение идёт на лету, из шапки, без перезапуска.
Меняется только внешний вид. Раскладка, функции и звук остаются как есть.
Исходное состояние: ветка `feat/phaser-control-rate`, HEAD `bc8c357` (исправления CodeReviewer по аудиту), тесты зелёные. Сейчас тема одна и зашита в коде: `Synt_swiftUI/Views/Theme/AppleTheme.swift` (enum со static-цветами). Её используют ContentView и все файлы в `Views/` и `Views/Components/`.
Делай задачи по порядку, не спрашивая.

## Дизайн-источники (`docs/design/`)
- `THEMES_V2.md` — это **источник истины**: 49 общих токенов цвета (hex) на тему, радиусы, тени, шрифты, стиль ручек, слайдеров, тумблеров, сегментов, метров и клавиш, правило теней, раскладка. В нём описана и тема 4, Neon Synthwave. **Её НЕ делаем**, раздел игнорируй.
- `1_baseline_light_neumorphic*.png`, `2_dark_studio_hardware*.png`, `3_retro_analog*.png` — ИИ-макеты, 1000×700 pt @2x. Версия `_seq_shown` показывает раскрытый секвенсор. Надписи и значения на них приблизительные. «IAC Bus 1», паттерн секвенсора и Voices=1 — примерные данные.
- `CURRENT_UI.md` — инвентарь текущего UI: панели, контролы, размеры, цвета.
- **Важно:** на макетах ручки и клавиши нарисованы МЕНЬШЕ реальных. Реальные размеры сохраняются: ручки 50 pt, большие 70 pt, белые клавиши 140 pt в высоту, остальные размеры как в коде сейчас. С макетов берём только цвета и стиль.

## Правила
- Работай в текущей ветке `feat/phaser-control-rate`. Не мержи в `main`, не создавай новые ветки и репозитории.
- После КАЖДОЙ задачи: сборка и тесты зелёные, затем отдельный коммит (`feat(theme): …` / `test(theme): …` + номер задачи), затем `git push` в существующий `origin`. Только обычный push: без `--force`, без rebase и amend уже запушенного.
- **Не коммить `*_DUMP.txt`.** Тесты их перезаписывают; перед коммитом выполни `git checkout -- '*_DUMP.txt'` или добавляй файлы явно, без `git add -A`. Не трогай `*_NOTES.md` и `*_PLAN.md`.
- **Не менять раскладку, функции и звук.** Никаких правок в `Synt_swiftUI/Audio/**`, в пресетах, `SynthPreset` и MIDI. Init и фабричные пресеты должны звучать бит-в-бит как раньше. Не добавлять UI для фич, у которых его нет (арпеджиатор, pitch-bend range и т.д.).
- **Производительность:** не больше одного слоя тени на элемент. Без `.blur`, без `.ultraThinMaterial` и других материалов, без glow через радиус тени. Только плоские заливки и простые Linear/Radial-градиенты. Смена темы не должна добавлять перерисовок за кадр: метры и скоуп обновляются с той же частотой, что сейчас (см. `MeteringThrottleTests`).
- Если задача не получается, откати её изменения, запиши причину в раздел «Журнал» в конце файла и переходи к следующей.

## Команда сборки и тестов
```bash
cd /Users/nikolay/gemini_projekts/Synt_swiftUI
xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI \
  -destination 'platform=macOS' -derivedDataPath ~/.synt_dd \
  -only-testing:Synt_swiftUITests
```
Ожидается `** TEST SUCCEEDED **`.

---

## Задача 1 — Theme struct, 3 экземпляра, environment value
**Цель:** вместо статического `AppleTheme` сделать значение темы, которое можно подменять.
**Файлы:** новые `Synt_swiftUI/Views/Theme/Theme.swift` и `Synt_swiftUI/Views/Theme/Themes.swift`; `AppleTheme.swift`; тесты.
**Шаги:**
1. `struct Theme: Identifiable, Equatable` с `id: ThemeID` (`enum ThemeID: String, CaseIterable { case baseline, studio, retro }`) и `displayName`.
2. Поля — все 49 токенов цвета из `THEMES_V2.md`, с теми же именами: bg, panel, card, inset, border, text, textDim, textFaint, accent, accent2, logoA, logoB, aOsc, aEnv, aFilter, aLFO, aFx, aMod, aSeq, positive, destructive, knobTop…knobFill, meterLow/Mid/High/Off, scopeBg, scopeLine, key*, kbZone, kbZoneBorder, toggleOn/Off/Knob, sliderTrack, sliderFill, tile, tileSel. Плюс `rCard`, `rHeader`, `rSmall`, `accentBar`, `cardShadow` и `knobShadow` (struct: color, radius, y — один слой), шрифты (`titleFont`, `headerFont`, `labelFont`, `valueFont(size:)`, `uppercaseLabels: Bool`, `labelTracking`). Для Retro добавь `chrome` (wood cheeks 14 pt) и `meterStyle: .led / .needle`.
3. Хелпер `Color(hex:)` с поддержкой `#RRGGBB` и `rgba(r,g,b,a)`-значений из таблицы. Можно задавать как `Color(red:green:blue:opacity:)`.
4. `static let baseline / studio / retro` со значениями из таблиц `THEMES_V2.md`. `Theme.all = [baseline, studio, retro]`.
5. `EnvironmentKey` и `EnvironmentValues.theme` (по умолчанию `.baseline`).
6. Шрифты: если Inter, JetBrains Mono, Futura, Avenir Next, Courier или Cooper Black недоступны, нужен fallback на системные (Helvetica Neue / SF Mono / Georgia). Шрифты в бандл не добавлять.
**Тесты (`ThemeTests.swift`):** у каждой из 3 тем все токены заданы и отличаются от `.clear`. Проверить, что набор полей одинаков (через `Mirror`, число цветовых полей = 49, одинаково у всех тем). Проверить контрольные hex: baseline.bg = #F5F5F7, studio.accent = #FFB000, retro.scopeLine = #7FE0B0. `ThemeID.allCases.count == 3`.
**Приёмка:** тесты зелёные, UI пока не меняется.

## Задача 2 — Перевести все View с AppleTheme на `@Environment(\.theme)`
**Цель:** ни одного зашитого цвета темы во View.
**Файлы:** `ContentView.swift`, все `Views/*.swift` и `Views/Components/*.swift`, `AppleTheme.swift` (модификаторы `AppleCard3D`, `AppleInsetWell`, `ApplePillButton`, `AppleSectionHeader`).
**Шаги:**
1. Каждое обращение `AppleTheme.xxx` заменить на токен из `theme`. Соответствие: windowBackground→bg, cardSurface→card, surfaceSecondary→panel, surfaceInset→inset, textPrimary/Secondary/Tertiary→text/textDim/textFaint, accentBlue→accent, accentOscillator…accentSequencer→aOsc…aSeq, accentPositive/Destructive→positive/destructive, knob*→knob*, радиусы→rSmall/rCard/rHeader.
2. Модификаторы карточек, well, pill и section header должны читать тему из environment. Двойную тень (shadowLight + shadowDark) заменить одной `cardShadow`.
3. Цвет BPM → accent2, логотип SYNTH → градиент logoA→logoB.
4. После перевода `AppleTheme` либо удалить, либо оставить тонким `@available(*, deprecated)`-алиасом на `Theme.baseline`. В `Views/` и `ContentView` не должно остаться `AppleTheme.` (проверка: `rg "AppleTheme\." Synt_swiftUI/Views Synt_swiftUI/ContentView.swift` возвращает пусто).
5. Ввести тему в корень: `.environment(\.theme, Theme.baseline)` в `ContentView` или App.
**Тесты:** все существующие тесты зелёные. Добавить тест-грепалку необязательно; достаточно проверки командой `rg` в приёмке.
**Приёмка:** приложение выглядит как Baseline-макет (с одной тенью вместо двух), раскладка и размеры не изменились.

## Задача 3 — Выбор темы в шапке, сохранение в UserDefaults, живое переключение
**Цель:** пользователь переключает скин из шапки, и выбор переживает перезапуск.
**Файлы:** новый `Synt_swiftUI/Views/Theme/ThemeStore.swift`, `ContentView.swift` (header card), тесты.
**Шаги:**
1. `final class ThemeStore: ObservableObject` с `@Published var id: ThemeID`. Хранится в `UserDefaults` под ключом `"ui.theme"`; неизвестное значение → `.baseline`. Инициализатор принимает `UserDefaults` (для тестов — suite).
2. В шапке компактный `Menu` (иконка `paintpalette` + название темы) рядом с Export/Import, без сдвига остальной раскладки. Пункты: Baseline, Dark Studio, Retro Analog, у выбранного галочка.
3. Корень: `.environment(\.theme, Theme.all[store.id])`. Переключение мгновенное, без перезапуска и без пересоздания `AudioEngine` (store не должен лежать внутри объектов движка; движок не перезапускается, звук не прерывается).
4. Окно-фон (`bg`) и цвет схемы (`.preferredColorScheme(.dark)` для Studio, `.light` для двух других, чтобы системные Menu и Picker были читаемыми).
**Тесты (`ThemeStoreTests.swift`):** сохранение и чтение по suite UserDefaults; мусор в ключе → baseline; смена id публикует изменение.
**Приёмка:** тема меняется на лету; после перезапуска открывается последняя выбранная.

## Задача 4 — Рестайл контролов: ручки, слайдеры, тумблеры, сегменты, тайлы
**Цель:** контролы выглядят как в `THEMES_V2.md` для каждой темы.
**Файлы:** `Views/Components/KnobView.swift`, `WaveformPicker.swift`, слайдеры и тумблеры в `OscillatorView`, `FilterView`, `UnisonView`, `EffectsView`, `AdvancedEffectsView`, `LFOView`, `StepSequencerView`, `ContentView` (BPM, Master).
**Шаги:**
1. **Ручка:** диск с radial-градиентом knobTop→knobBottom, обод knobRing, линия-индикатор knobIndicator. **Дуга значения на ВСЕХ ручках** (раньше была только у Cutoff): трек knobTrack, заливка knobFill (в Retro — оранжевая, в Studio — янтарная). Одна тень `knobShadow`. Размеры 50 и 70 pt как сейчас. Жесты и чувствительность не трогать.
2. **Слайдер:** трек sliderTrack, заливка sliderFill, бегунок (в Baseline белый с одной мягкой тенью). Высота и hit-area как сейчас.
3. **Тумблер:** pill, toggleOn/toggleOff/toggleKnob.
4. **Сегменты и тайлы волн:** inset-трек; выбранный сегмент приподнят белым в Baseline, сплошной янтарный с тёмным текстом в Studio. Тайлы — tile/tileSel.
5. **Акцент панели:** Studio — всё янтарное (aOsc…aSeq одинаковые, так задано токенами). Retro — оранжевый/бирюзовый через токены панелей (OSC, Filter, FX, Seq — оранжевый; Env, LFO, Mod — бирюзовый).
6. Подписи: в Studio и Retro UPPERCASE с tracking (по флагу темы).
**Тесты:** существующие тесты зелёные. Чистая функция `knobArcFraction(value:range:)` (если появится) — юнит-тест на края и середину.
**Приёмка:** визуально совпадает с макетами по цвету и стилю, кроме размеров, которые остаются реальными.

## Задача 5 — Метры, скоуп, клавиатура, панели и хром
**Цель:** закончить скины.
**Файлы:** `Views/Components/VUMeterView.swift`, `OscilloscopeView.swift`, `PianoKeyView.swift`, `KeyboardView.swift`, `ContentView.swift`, модификаторы карточек; новый `Views/Components/NeedleVUMeterView.swift`.
**Шаги:**
1. **LED-метр** (Baseline, Studio): 12 сегментов на сторону, meterLow→Mid→High, неактивные meterOff, в inset-well.
2. **Retro:** на месте OUTPUT два маленьких стрелочных VU (L/R). Шкала #F4E3B0, чёрные риски, красная зона выше 0 dB. **Обе стрелки питаются тем же моно-уровнем**, что сейчас идёт в `StereoVUMeterView`; новых метрик в движке не делать. Без анимационных таймеров: стрелка = функция уровня (можно лёгкий `.animation(.linear(duration: 0.05))`). Частота обновления как сейчас. Габарит не больше текущего метра.
3. **Скоуп:** scopeBg и линия scopeLine, простой stroke без glow (вторую обводку-glow из `0d5e50a` убрать или сделать тем же цветом с низкой opacity; тень не использовать).
4. **Клавиши:** keyWhite с лёгким градиентом к keyWhiteEdge, чёрные keyBlack→keyBlackEnd, нажатая keyPressed, подписи keyLabel; зона Mac Keyboard kbZone с рамкой kbZoneBorder 2 pt. Высота 140 pt и логика нажатий без изменений.
5. **Панели:** card/panel/border/радиусы/accentBar из темы. Studio — 1 pt border #34343A. Retro — фон bg (орех) и деревянные «щёки» по 14 pt слева и справа (LinearGradient или тайловое изображение; ширину контента не уменьшать — щёки за пределами текущих карточек, в паддинге окна; если не помещаются, пиши в Журнал и делай тоньше).
6. Секвенсор: пэды, шаг, точки каждые 4, ячейки нот и velocity — на токенах (aSeq, inset, tile, accent).
**Тесты:** `NeedleVUMeterView` — чистая функция `needleAngle(level:)`: монотонна, 0 → левый упор, уровень > 0 dB → в красной зоне, NaN → левый упор. Существующий `MeteringThrottleTests` зелёный.
**Приёмка:** все три темы выглядят как макеты; FPS и CPU UI при игре не хуже, чем на Baseline до изменений.

## Задача 6 — Защита: звук не изменился, правила производительности
**Цель:** автоматически гарантировать, что работа со скинами не тронула аудио.
**Файлы:** новые `Synt_swiftUITests/ThemeNoAudioChangeTests.swift` и `ThemePerformanceRuleTests.swift`.
**Шаги и тесты:**
1. Офлайн-рендер Init и 3–4 фабричных пресетов (через тот же хук, что в `InitGoldenTests` / `AudioGoldenHarnessTests`) при каждой из 3 тем, выставленных в `ThemeStore`. Хеш или сумма сэмплов идентичны между темами и совпадают с существующими голденами. Голдены НЕ перегенерировать.
2. Существующие `InitGoldenTests` и `AudioGoldenHarnessTests` не изменены и зелёные.
3. Статическая проверка исходников (тест читает файлы `Synt_swiftUI/Views/**` через `#filePath`): нет `.blur(`, нет `Material`, `AppleTheme.` не встречается; в каждом View-файле не больше одного `.shadow(` на элемент (достаточно эвристики: нет двух `.shadow(` подряд в одной цепочке модификаторов).
4. `git diff bc8c357 -- Synt_swiftUI/Audio` пуст (проверить вручную и указать в сообщении коммита).
**Приёмка:** тесты зелёные.

## Задача 7 — Сверка с макетами (снапшоты или чек-лист)
**Цель:** зафиксировать, что вышло.
**Шаги:**
1. Если получится без новых зависимостей: тест рендерит `ContentView` через `ImageRenderer` 1000×700 при каждой теме и сохраняет PNG в `docs/design/screens/` (`baseline.png`, `studio.png`, `retro.png` и `*_seq.png`). Без сравнения пикселей, тест только проверяет, что изображение не пустое. Если `ImageRenderer` не тянет окно с движком, сделай скриншоты вручную (`screencapture -l`) и сохрани туда же.
2. Дополни `docs/design/CHECKLIST.md`, по пункту на тему, отметки [x]/[ ]: фон и карточки; шапка (лого-градиент, меню темы, BPM accent2, Master); ручки с дугой на всех; размеры 50/70/140 pt не изменились; слайдеры и тумблеры; тайлы волн; LED-метр / стрелки (Retro); скоуп без glow; клавиши и зона Mac Keyboard; секвенсор (`_seq_shown`); UPPERCASE-подписи (Studio, Retro); деревянные щёки (Retro); одна тень, без blur; читаемость системных меню (Studio).
3. Расхождения с макетами, сделанные специально (размеры, моно-стрелки), перечисли в конце CHECKLIST.
**Приёмка:** PNG и чек-лист закоммичены и запушены, тесты зелёные.

---

## Журнал
- Задача 7: `ImageRenderer` рисует только клавиатуру, панели в `ScrollView` остаются пустыми. PNG сняты с живого окна через `screencapture -l`. Тест проверяет, что файлы не пустые, и сам их не перезаписывает.
- Задача 7: у Studio и Retro строки SYNTH, BPM и Master сжимались шапкой и переносились посередине слова. У них `lineLimit(1)` и `fixedSize`. «Octave N» и «Drag Blue Zone» оставлены системным шрифтом.
