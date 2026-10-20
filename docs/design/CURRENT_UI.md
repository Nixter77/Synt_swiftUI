# Synt_swiftUI — CURRENT UI (as built, branch feat/phaser-control-rate)

Source of truth: SwiftUI code in `Synt_swiftUI/` + screenshot `current/01_main_window.png` (Debug build, preset "WT Orchestra" loaded, sequencer hidden, LFO/Distortion/EQ/Phaser off).
Only real, wired features are listed. Nothing here is invented.

## 1. Window
- One window (`Synt_swiftUIApp.swift`): `WindowGroup`, `.windowStyle(.hiddenTitleBar)` (only traffic lights, no title), default 1000×700 pt, min 900×650. No menu-bar menus, no Settings window, no tabs.
- Root (`ContentView.swift`): `VStack(spacing 0)`:
  1. **ScrollView** (padding 16, VStack spacing 16): Header card → Controls (3 columns) → Step Sequencer card (only when toggled on).
  2. **Keyboard** pinned at the bottom, outside the scroll view (so drags don't cancel note-off).
- Background: `AppleTheme.windowBackground`.

## 2. Header card (full width, `appleCard` radius 20) — left → right
| Element | Type | Details | Works |
|---|---|---|---|
| "SYNTH" | title | 28 pt black rounded, gradient coral→rose (accentOscillator→accentEffects) | – |
| "SwiftUI Synthesizer" | subtitle | 12 pt rounded, textSecondary | – |
| MIDI device menu | dropdown | Only appears if a MIDI device exists: green dot + "MIDI: <device>" + chevron, green 10% pill. Lists devices and selects one | yes |
| Preset button | button + popover | folder icon (amber) + preset name (14 pt medium) + chevron, raised rounded rect r10. Opens **Preset List popover** (§6) | yes |
| Save | icon button `square.and.arrow.down` (green) | Opens **Save Preset sheet** | yes |
| Reset | icon `arrow.counterclockwise` (grey) | Load default preset | yes |
| Export | icon `square.and.arrow.up` (blue) | NSSavePanel, `.synthpreset` file | yes |
| Import | icon `tray.and.arrow.down` (blue) | NSOpenPanel `.synthpreset` | yes |
| OUTPUT meter | stereo LED meter | "OUTPUT" label (green, 10 pt bold), two vertical segment bars L/R (segments 12×4, green → amber → red, red peak dot 8 pt), scale "-∞ -12 -6 0" (7 pt mono), inset well. NOTE: L and R are fed the same mono level | yes (mono) |
| Oscilloscope | display | 160×100 inset well, blue line with glow (`OscilloscopeView`) | yes |
| BPM | label + slider | "BPM" 10 pt + value 14 pt bold mono coral; Slider 40…240 step 1, width 80, coral tint. Drives the sequencer tempo | yes |
| Sequencer show/hide | icon button | `rectangle.expand.vertical` / `compress` (sky blue when shown) | yes |
| Sequencer play/stop | icon button | `play.circle.fill` blue / `stop.circle.fill` red | yes |
| Master | large knob 70 pt | 0…1, label "Master", value shown in blue | yes |
| Engine start/stop | round button | `play.fill`/`stop.fill` in a circle with green/red tinted ring (shown red stop = engine running) | yes |

## 3. Controls — 3 equal columns (HStack spacing 12, each column VStack spacing 12)
Each panel = white card (`appleCard`, radius 14) with a 3 pt colored accent line at top + section header (SF Symbol icon + 13 pt bold rounded title + thin accent rule).
Standard knob (`KnobView`): 50 pt neumorphic disc, dark indicator line, label 10 pt medium below, value 9 pt mono below that. Drag vertically to change.

### Column 1
**OSC 1** (`OscillatorView`, accent coral, icon `waveform`)
- "Wave": `WaveformPicker` — 6 tile buttons 38×30 with drawn icons: Sine, Saw, Square, Triangle, Noise, Wavetable (selected tile coral tint).
- Knob Volume 0…1 · Octave stepper "- n +" (−2…+2) · Knob Detune −50…+50 ct.
- Slider **PWM** 0.05…0.95 — only when wave = Square.
- Slider **Morph** 0…1 — only when wave = Wavetable.
**OSC 2** — same as OSC 1 plus an on/off switch in the header (`osc2Enabled`); body hidden when off.

### Column 2
**ENVELOPE** (`ADSRView`, teal, icon `chart.xyaxis.line`)
- ADSR graph 60 pt tall in inset well (teal→sky gradient line, soft fill) — live.
- Knobs: Attack 0.001–2 s, Decay 0.001–2 s, Sustain 0–1 (%), Release 0.001–3 s.
**FILTER** (`FilterView`, violet)
- Segmented picker Type: Low Pass / High Pass / Band Pass.
- Large knob Cutoff 20–20000 Hz (70 pt, blue arc + value) · Knob Resonance 0–1 · Knob Env Amt 0–1.
**UNISON / MASTER** (`UnisonView`, violet, icon `person.3.fill`; inner inset well)
- Menu picker Voices 1…7 · Knobs Detune 0–50, Spread 0–1, Glide (portamento) 0–1 s.

### Column 3
**LFO** (`LFOView`, sky blue) — header switch on/off; when on: WaveformPicker (same 6 waves), segmented Target: Pitch / Filter / Amplitude / Pan, knobs Rate 0.1–20 Hz, Depth 0–1.
**EFFECTS** (`EffectsView`, rose, icon `sparkles`) — three sub-blocks separated by dividers:
- Reverb: Mix 0–1, Room 0–1
- Chorus: Rate 0.1–5 Hz, Depth 0–1, Mix 0–1
- Delay: Time 0.01–1 s, Feedback 0–0.9, Mix 0–1
**ADVANCED FX** (`AdvancedEffectsView`, amber, icon `slider.horizontal.3`) — three rows, each with switch; controls appear only when on:
- Distortion: menu Type (Soft Clip, Hard Clip, Tube, Tape, Bitcrush, Wavefold); knobs Drive, Tone, Mix (0–1).
- Parametric EQ: menu Preset (Flat, Bass Boost, Bass Cut, Mid Scoop, Presence, Bright…); row 1 knobs Low/Mid/High gain −12…+12 dB; row 2 Lo F 40–400 Hz, Mid F 200–5000 Hz, Hi F 2000–16000 Hz.
- Phaser: menu Mode (Phaser 2/4/6/8, Flanger, Chorus); row 1 Rate 0.05–5 Hz, Depth, Mix; row 2 Fdbk −0.9…+0.9, Center 200–4000 Hz, Spread 0–1.
**MODULATION MATRIX** (`ModMatrixView`, amber, icon `arrow.triangle.branch`) — green "+" adds a row; scroll list 120 pt tall; "No patches" when empty. Each row (grey pill): Source menu (LFO 1, Env 1 (Amp), Velocity) → arrow → Destination menu (Pitch OSC1, Pitch OSC2, Filter Cutoff, Resonance, Amplitude, Pan, PWM OSC1, PWM OSC2, LFO Rate, LFO Depth, Osc Mix) · small knob Amt −1…+1 · red trash.

## 4. Step Sequencer card (hidden by default; `StepSequencerView`, indigo, full width under the columns)
- Header "STEP SEQUENCER" · "Root: C3" text · trash (Clear pattern) · dice (Randomize).
- Row 1: 16 step pads 35×35 (toggle on/off), each step its own color from a repeating 8-color rainbow of theme accents; current step = 2 pt dark outline; small dot above every 4th step.
- Row 2: 16 note cells (note name 9 pt mono + ▲▼ buttons, offset −24…+24 semitones).
- Row 3: 16 velocity bars (40 pt tall, drag to set 0–1, teal fill).
- Bottom: SWING small knob (40 pt, blue arc, 0–100%), ROOT stepper (MIDI 24–96, shows note name), LENGTH stepper 1–16.
- Tempo = header BPM; play = header play button. Clock runs on audio thread; playhead UI updated at 30 Hz. Works.

## 5. Keyboard (bottom, `KeyboardView` + `PianoKeyView`)
- Top bar: ◀ (`chevron.left.circle.fill`) "Octave 4" ▶ ; right: hint pill "✋ Drag Blue Zone | Z/X: Octave | A-L: Play".
- 4 octaves from C2 (MIDI 36), white keys 140 pt tall with note letters at the bottom (10 pt), black keys dark gradient (0.22→0.12 grey), pressed keys tint blue.
- Blue translucent "Mac Keyboard" zone (blue 15% fill, 2 pt blue border, label at top) shows which keys the computer keyboard plays; drag its small handle to move it by octaves.
- Mouse/touch play: yes. Computer keys: A W S E D F T G Y H U J K O L P ; (C to E+1), Z/X octave. MIDI input: yes.

## 6. Popovers / sheets (no other navigation exists)
- **Preset List popover** (`PresetListView`): scroll list; section "💾 My Presets" (user presets, trash on hover) then factory presets grouped by category Bass, Lead, Pad, Keys, Pluck, Strings, FX (≈38 factory presets, e.g. Clean Sub, Velvet Acid, Silk Lead, Cloud Bed, Glass Horizon, Soft EP, WT Orchestra, Deep Drone). Row: name 13 pt, blue checkmark + 10% blue background when selected, grey on hover.
- **Save Preset sheet**: "Save Preset" 18 pt bold, "Preset Name" caption, text field 250 wide, error "Preset name already exists" (red), Cancel / Save.
- System NSSavePanel/NSOpenPanel for export/import.
- Last session auto-restores on launch (saved 1 s after edits).

## 7. Not in the UI (exists in code/model only — don't design as working)
- Arpeggiator (`arpMode`, `arpRate` in preset, `ArpeggiatorEngine.swift`) — no UI controls.
- `pitchBendRange`, `eqMidQ` — no UI.
- `SpectrumAnalyzerView.swift`, `SequencerView.swift` — files exist but are not shown anywhere.
- `CompactVUMeterView` — unused.

## 8. Theme system (`Views/Theme/AppleTheme.swift`) — single fixed light neumorphic theme, no switching
Colors (sRGB 0–1 → hex):
- windowBackground #F5F5F7 · cardSurface #FFFFFF · surfaceSecondary #F2F2F5 · surfaceInset #EDEDF0
- textPrimary #1C1C1F · textSecondary #707075 · textTertiary #A3A3A8
- accentBlue #007AFF · accentOscillator (coral) #FF6147 · accentEnvelope (teal) #33C7A3 · accentFilter (violet) #9463E0 · accentLFO (sky) #52B3F5 · accentEffects (rose) #F06B8F · accentModulation (amber) #FAB833 · accentSequencer (indigo) #5957D6 · accentPositive (green) #38C759 · accentDestructive (red) #FF453B
- knobTop #F5F5F7 · knobBottom #DBDBE0 · knobIndicator #404047 · knobIndicatorActive #FF6147
- shadowLight white 70% · shadowDark #B3B3BA 45% · shadowDeep #9999A6 35%
Radii: small 8, medium 14, large 20, XL 28.
Modifiers: `appleCard` (white, dual shadow dark 10r x4 y6 + light 6r −3/−4, top-left white gradient stroke, optional 3 pt accent bar), `appleInset` (sunken well), `applePill`, `AppleSectionHeader`.
Fonts: all SF system — `.rounded` for labels/titles (10–14 pt, title 28 black), `.monospaced` for numeric values (9–14 pt). Icons: SF Symbols.
Panel accent mapping: OSC coral · Envelope teal · Filter & Unison violet · LFO sky · Effects rose · Advanced FX & Mod Matrix amber · Sequencer indigo.

## 9. View files
ContentView.swift (header, layout, EngineMetersView) · Views/OscillatorView · ADSRView (+ADSRGraph) · FilterView · UnisonView · LFOView · EffectsView · AdvancedEffectsView · ModMatrixView · StepSequencerView (SeqStepButton, SeqNoteCell, SeqVelocityBar, SeqKnob) · KeyboardView · PresetView (SavePresetSheet, PresetListView, PresetRow, SectionHeader) · Components/KnobView (KnobView 50 pt, LargeKnobView 70 pt) · VUMeterView (VUMeterView, StereoVUMeterView) · OscilloscopeView · WaveformPicker · PianoKeyView (WhiteKeyView, BlackKeyView) · Theme/AppleTheme.

## Screenshots
current/01_main_window.png (full window) · 02_header_detail · 03_panels_detail · 04_keyboard_detail (crops). Sequencer card, popover and sheet were NOT captured (macOS Accessibility not granted to osascript, so no UI automation) — they are described from code above.
