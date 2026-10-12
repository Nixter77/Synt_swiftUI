# Synt_swiftUI — Themes v2 (same layout, 4 skins)

These skins reuse the exact current layout and controls from `../CURRENT_UI.md`. Source: `synth_mockup.html`. One HTML file holds all themes as CSS-variable token sets. Open it with `?theme=baseline|studio|retro|synthwave` and add `&seq=1` to show the sequencer. Re-render with `./render.sh`, which uses headless Chrome at 2x.

Files: for each theme, `N_name.png` is 2000×1400 (1000×700 at 2x) with the sequencer hidden, which is the default state shown in 01_main_window. `N_name_seq_shown.png` is 2000×1870 (1000×935 at 2x), with the window made taller so the 16-step sequencer card and the keyboard both fit (in the app the content would scroll).

## Token → SwiftUI mapping
Every theme uses the same token names, so each one becomes a field on `struct Theme { let bg, panel, card, inset, border, text, textDim, textFaint, accent, accent2, logoA, logoB, aOsc, aEnv, aFilter, aLFO, aFx, aMod, aSeq, positive, destructive, knobTop, knobBottom, knobRing, knobIndicator, knobTrack, knobFill, meterLow, meterMid, meterHigh, meterOff, scopeBg, scopeLine, keyWhite, keyWhiteEdge, keyBlack, keyBlackEnd, keyPressed, keyLabel, kbZone, kbZoneBorder, toggleOn, toggleOff, toggleKnob, sliderTrack, sliderFill, tile, tileSel: Color; radii; shadow; fonts }`. The panel accents (aOsc…aSeq) replace the AppleTheme accent* colors one-for-one. `accent` maps to accentBlue (value text, scope, Master, play) and `accent2` to the BPM value colour.

**Performance rule for all themes:** at most one shadow layer per element, no `.blur`, no `.ultraThinMaterial` or other backdrop blur, and no glow made with a shadow radius. Use flat fills or simple Linear/RadialGradients. The scope keeps a plain stroke; drop the current glow.

## 1. Baseline — Light Neumorphic
Mockups: `1_baseline_light_neumorphic.png`, `1_baseline_light_neumorphic_seq_shown.png`

| token | value |
|---|---|
| bg | `#F5F5F7` |
| panel | `#F2F2F5` |
| card | `#FFFFFF` |
| inset | `#EDEDF0` |
| border | `#E3E3E8` |
| text | `#1C1C1F` |
| textDim | `#707075` |
| textFaint | `#A3A3A8` |
| accent | `#007AFF` |
| accent2 | `#FF6147` |
| logoA | `#FF6147` |
| logoB | `#F06B8F` |
| aOsc | `#FF6147` |
| aEnv | `#33C7A3` |
| aFilter | `#9463E0` |
| aLFO | `#52B3F5` |
| aFx | `#F06B8F` |
| aMod | `#FAB833` |
| aSeq | `#5957D6` |
| positive | `#38C759` |
| destructive | `#FF453B` |
| knobTop | `#F5F5F7` |
| knobBottom | `#DBDBE0` |
| knobRing | `#FFFFFF` |
| knobIndicator | `#404047` |
| knobTrack | `#E3E3E8` |
| knobFill | `#007AFF` |
| meterLow | `#38C759` |
| meterMid | `#FAB833` |
| meterHigh | `#FF453B` |
| meterOff | `#DCDCE0` |
| scopeBg | `#EDEDF0` |
| scopeLine | `#007AFF` |
| keyWhite | `#FFFFFF` |
| keyWhiteEdge | `#D8D8DD` |
| keyBlack | `#2E2E33` |
| keyBlackEnd | `#1F1F21` |
| keyPressed | `#7FB6FF` |
| keyLabel | `#8A8A90` |
| kbZone | `rgba(0,122,255,.15)` |
| kbZoneBorder | `#007AFF` |
| toggleOn | `#FF6147` |
| toggleOff | `#E3E3E8` |
| toggleKnob | `#FFFFFF` |
| sliderTrack | `#E3E3E8` |
| sliderFill | `#FF6147` |
| tile | `#EFEFF2` |
| tileSel | `rgba(255,97,71,.15)` |
| shadow | `0 4px 10px rgba(179,179,186,.45)` |
| knobShadow | `0 3px 6px rgba(153,153,166,.35)` |
| rCard | `14px` |
| rHeader | `20px` |
| rSmall | `8px` |
| accentBar | `3px` |

- **Fonts:** SF Pro Rounded for labels and titles (title 28 black, headers 13 bold, labels 10 medium); SF Mono for values (9–14). Same as the current AppleTheme.
- **Knobs:** neumorphic disc with a knobTop→knobBottom radial gradient, a 1.5 pt white rim, a dark indicator line, and a thin blue value arc around it (the arc is new: only the Cutoff knob had one before). Standard 50 pt, large 70 pt.
- **Sliders:** 4 pt coral track fill, white thumb with one soft shadow. **Toggles:** native-style pill, coral when on.
- **Segmented / tiles:** inset track with a raised white selected segment; waveform tiles turn coral (tileSel) when selected.
- **Meters:** stereo LED meter, 12 segments per side, green→amber→red, in an inset well. Scope: blue line on the inset color, no glow.
- **Keys:** white keys with a slight bottom gradient; black keys #2E2E33→#1F1F21; pressed = keyPressed blue. Mac Keyboard zone at 15% blue with a 2 pt blue border.
- **Shadow:** card `0 4 10 rgba(179,179,186,.45)` (one layer, instead of the current dark+light pair); knob `0 3 6 rgba(153,153,166,.35)`.

## 2. Dark Studio Hardware
Mockups: `2_dark_studio_hardware.png`, `2_dark_studio_hardware_seq_shown.png`

| token | value |
|---|---|
| bg | `#141416` |
| panel | `#1C1C1F` |
| card | `#232327` |
| inset | `#121214` |
| border | `#34343A` |
| text | `#E8E6E1` |
| textDim | `#9A978F` |
| textFaint | `#5E5C57` |
| accent | `#FFB000` |
| accent2 | `#FF7A1A` |
| logoA | `#FFB000` |
| logoB | `#FF7A1A` |
| aOsc | `#FFB000` |
| aEnv | `#FFB000` |
| aFilter | `#FFB000` |
| aLFO | `#FFB000` |
| aFx | `#FFB000` |
| aMod | `#FFB000` |
| aSeq | `#FFB000` |
| positive | `#7BD88F` |
| destructive | `#FF4D3D` |
| knobTop | `#3A3A40` |
| knobBottom | `#1E1E22` |
| knobRing | `#4A4A52` |
| knobIndicator | `#FFB000` |
| knobTrack | `#2E2E33` |
| knobFill | `#FFB000` |
| meterLow | `#7BD88F` |
| meterMid | `#FFB000` |
| meterHigh | `#FF4D3D` |
| meterOff | `#2A2A2E` |
| scopeBg | `#0B0B0C` |
| scopeLine | `#FFB000` |
| keyWhite | `#D9D6CF` |
| keyWhiteEdge | `#9C9890` |
| keyBlack | `#1A1A1C` |
| keyBlackEnd | `#0C0C0D` |
| keyPressed | `#FFB000` |
| keyLabel | `#55524C` |
| kbZone | `rgba(255,176,0,.14)` |
| kbZoneBorder | `#FFB000` |
| toggleOn | `#FFB000` |
| toggleOff | `#3A3A40` |
| toggleKnob | `#E8E6E1` |
| sliderTrack | `#2E2E33` |
| sliderFill | `#FFB000` |
| tile | `#1A1A1D` |
| tileSel | `rgba(255,176,0,.18)` |
| shadow | `0 2px 4px rgba(0,0,0,.5)` |
| knobShadow | `0 2px 3px rgba(0,0,0,.6)` |
| rCard | `6px` |
| rHeader | `8px` |
| rSmall | `4px` |
| accentBar | `2px` |

- **Fonts:** Inter / Helvetica Neue for labels, UPPERCASE with 0.5–1.2 pt tracking; JetBrains Mono (or SF Mono) for values. Logo in Helvetica Neue 800 with an amber gradient.
- **Knobs:** machined dark disc (#3A3A40→#1E1E22) with a grey rim, an amber indicator line and an amber value arc on a dark track. Every panel uses the same amber accent, like a real hardware unit.
- **Sliders:** dark track with amber fill and a light thumb. **Toggles:** amber when on, #3A3A40 when off.
- **Segmented:** the selected segment is filled solid amber with dark text.
- **Meters:** LED segments: green for low, amber for mid, red for peak; unlit segments #2A2A2E. Scope: amber trace on near-black #0B0B0C.
- **Keys:** aged-ivory whites #D9D6CF, black keys #1A1A1C, pressed keys amber; the zone is a 14% amber tint with an amber border.
- **Shadow:** `0 2 4 rgba(0,0,0,.5)` for cards, `0 2 3 rgba(0,0,0,.6)` for knobs. 1 pt #34343A borders do most of the separation.

## 3. Retro Analog
Mockups: `3_retro_analog.png`, `3_retro_analog_seq_shown.png`

| token | value |
|---|---|
| bg | `#3B2416` |
| panel | `#E9DFC7` |
| card | `#F3EAD3` |
| inset | `#E2D5B8` |
| border | `#C9B994` |
| text | `#2B2118` |
| textDim | `#6E5E49` |
| textFaint | `#A6967B` |
| accent | `#E2622B` |
| accent2 | `#1F8A86` |
| logoA | `#E2622B` |
| logoB | `#B4441A` |
| aOsc | `#E2622B` |
| aEnv | `#1F8A86` |
| aFilter | `#E2622B` |
| aLFO | `#1F8A86` |
| aFx | `#E2622B` |
| aMod | `#1F8A86` |
| aSeq | `#E2622B` |
| positive | `#4E8F3A` |
| destructive | `#C0392B` |
| knobTop | `#3A3430` |
| knobBottom | `#1C1916` |
| knobRing | `#C9B994` |
| knobIndicator | `#F3EAD3` |
| knobTrack | `#CDBE9C` |
| knobFill | `#E2622B` |
| meterLow | `#1F8A86` |
| meterMid | `#E2A72B` |
| meterHigh | `#C0392B` |
| meterOff | `#D8CCAE` |
| scopeBg | `#1E2A22` |
| scopeLine | `#7FE0B0` |
| keyWhite | `#F7F0DE` |
| keyWhiteEdge | `#C9B994` |
| keyBlack | `#2B2118` |
| keyBlackEnd | `#160F0A` |
| keyPressed | `#F2A07A` |
| keyLabel | `#8A7A60` |
| kbZone | `rgba(31,138,134,.16)` |
| kbZoneBorder | `#1F8A86` |
| toggleOn | `#E2622B` |
| toggleOff | `#CDBE9C` |
| toggleKnob | `#F7F0DE` |
| sliderTrack | `#CDBE9C` |
| sliderFill | `#E2622B` |
| tile | `#EAE0C8` |
| tileSel | `rgba(226,98,43,.2)` |
| shadow | `0 2px 3px rgba(60,40,20,.25)` |
| knobShadow | `0 2px 3px rgba(0,0,0,.35)` |
| rCard | `4px` |
| rHeader | `6px` |
| rSmall | `3px` |
| accentBar | `3px` |

- **Fonts:** Futura / Avenir Next UPPERCASE for labels; Courier for values; Cooper Black (Georgia as fallback) for the SYNTH logo.
- **Chrome:** cream faceplate cards on a dark walnut background, with 14 pt wood cheeks on the left and right. The wood is a repeating linear gradient; in SwiftUI use a tiled wood image or a LinearGradient.
- **Knobs:** black bakelite (#3A3430→#1C1916) with a cream rim, a cream indicator line and an orange value arc.
- **Accents:** orange #E2622B and teal #1F8A86 alternate by panel (OSC/Filter/FX/Seq orange; Env/LFO/Mod teal).
- **Sliders and toggles:** orange fill on a tan track.
- **OUTPUT meter:** the LED bars become two small VU needle meters (L/R), with a yellow #F4E3B0 face, a black scale and a red zone above 0 dB. Scope: phosphor green #7FE0B0 on #1E2A22.
- **Keys:** cream whites #F7F0DE, dark-brown black keys, pressed keys salmon #F2A07A; teal Mac Keyboard zone.
- **Shadow:** `0 2 3 rgba(60,40,20,.25)` for cards, `0 2 3 rgba(0,0,0,.35)` for knobs.

## 4. Neon Synthwave
Mockups: `4_neon_synthwave.png`, `4_neon_synthwave_seq_shown.png`

| token | value |
|---|---|
| bg | `#120A24` |
| panel | `#1A0F33` |
| card | `#1D1238` |
| inset | `#0E0820` |
| border | `#3A2470` |
| text | `#F3E9FF` |
| textDim | `#A994D6` |
| textFaint | `#6A5996` |
| accent | `#22E8FF` |
| accent2 | `#FF2BD6` |
| logoA | `#FF2BD6` |
| logoB | `#22E8FF` |
| aOsc | `#FF2BD6` |
| aEnv | `#22E8FF` |
| aFilter | `#B44DFF` |
| aLFO | `#22E8FF` |
| aFx | `#FF2BD6` |
| aMod | `#FFD23F` |
| aSeq | `#B44DFF` |
| positive | `#3DFFA8` |
| destructive | `#FF3860` |
| knobTop | `#2A1A52` |
| knobBottom | `#170D30` |
| knobRing | `#FF2BD6` |
| knobIndicator | `#22E8FF` |
| knobTrack | `#2E1D5C` |
| knobFill | `#FF2BD6` |
| meterLow | `#22E8FF` |
| meterMid | `#FF2BD6` |
| meterHigh | `#FFD23F` |
| meterOff | `#24164A` |
| scopeBg | `#0A0518` |
| scopeLine | `#22E8FF` |
| keyWhite | `#E9E0FF` |
| keyWhiteEdge | `#7A5CC2` |
| keyBlack | `#1A0F33` |
| keyBlackEnd | `#0A0518` |
| keyPressed | `#FF2BD6` |
| keyLabel | `#6A5996` |
| kbZone | `rgba(34,232,255,.12)` |
| kbZoneBorder | `#22E8FF` |
| toggleOn | `#FF2BD6` |
| toggleOff | `#2E1D5C` |
| toggleKnob | `#F3E9FF` |
| sliderTrack | `#2E1D5C` |
| sliderFill | `#FF2BD6` |
| tile | `#160C2E` |
| tileSel | `rgba(255,43,214,.18)` |
| shadow | `0 0 0 1px rgba(255,43,214,.35)` |
| knobShadow | `0 0 0 1px rgba(34,232,255,.5)` |
| rCard | `10px` |
| rHeader | `14px` |
| rSmall | `6px` |
| accentBar | `2px` |

- **Fonts:** Orbitron / Eurostile UPPERCASE for titles and labels; Share Tech Mono (or SF Mono) for values. The logo has a magenta→cyan gradient.
- **Knobs:** dark violet disc with a 1.5 pt magenta rim, a cyan indicator line and a magenta arc. The "glow" is only a thin 1 pt stroke: no blur and no shadow radius.
- **Panels:** headers are tinted with the panel accent (magenta for OSC/FX, cyan for Env/LFO, violet for Filter/Seq, yellow for Mod).
- **Sliders and toggles:** magenta fill on #2E1D5C. **Segmented:** the selected segment is filled with the panel accent.
- **Meters:** cyan for low, magenta for mid, yellow for peak; unlit segments #24164A. Scope: cyan line on #0A0518.
- **Keys:** lavender whites #E9E0FF; black keys have a 1 pt magenta outline; pressed keys are magenta. The zone is cyan at 12%.
- **Shadow:** none. The card "shadow" is a 1 pt magenta stroke at 35% (`0 0 0 1px`); knobs get a 1 pt cyan stroke at 50%.

## Layout (identical in all skins; checked against current/01_main_window.png)
- **Header card:** SYNTH and its subtitle · MIDI menu (drawn as an example, "MIDI: IAC Bus 1"; it only appears when a device exists) · preset button "WT Orchestra" · Save · Reset · Export · Import · OUTPUT L/R meter · scope · BPM 120 and its slider · seq show/hide · seq play · Master knob (0.44) · engine button (red stop = running).
- **Column 1:** OSC 1 (Wave: 6 tiles with Wavetable selected, Volume, Octave stepper, Detune, Morph slider) · OSC 2 (header switch on; Triangle selected, so no PWM/Morph slider).
- **Column 2:** Envelope (graph, Attack/Decay/Sustain/Release) · Filter (Type Low/High/Band Pass, large Cutoff 1700 Hz, Resonance, Env Amt) · Unison / Master (Voices menu, Detune, Spread, Glide in an inset well).
- **Column 3:** LFO (off, header only) · Effects (Reverb Mix/Room, Chorus Rate/Depth/Mix, Delay Time/Feedback/Mix) · Advanced FX (Distortion, Parametric EQ and Phaser switches, all off) · Modulation Matrix (+ button, "No patches").
- **Step Sequencer (`_seq_shown`):** header with Root: C3, Clear and Randomize · 16 pads (8-colour accent rainbow, current step outlined, a dot over every 4th step) · 16 note cells with ▲▼ · 16 velocity bars · Swing knob, Root stepper, Length stepper.
- **Keyboard:** ◀ Octave 4 ▶ · hint pill · 4 octaves from C2 · Mac Keyboard zone over C4–E5 (17 keys, A→;) with its drag handle; a pressed-key example is drawn at E4/F#4.
- **Not drawn (no UI in the app):** arpeggiator, pitch-bend range, EQ Mid Q, spectrum analyzer, compact VU.
