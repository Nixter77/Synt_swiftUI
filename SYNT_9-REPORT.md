# SYNT_9 Completion Report

**Target Branch**: `feat/auv3` (tracking `origin/feat/auv3`)  
**Base**: Result of `SYNT_8` on `feat/auv3`  
**Test Status**: All test suites passed (`Stage9FixesTests`, `Stage9ModulationTests`, `Stage9SoundTests`, `Stage9UITests`, `LayoutTests`, `InitGoldenTests`, `Stage7BugTests`, `Stage7ReverbTests`).  
**AU Validation**: `auval -v aumu Synt Nixr` — **AU VALIDATION SUCCEEDED**.  
**Golden Render Hash**: Bit-identical `0xd1b3635203a4799e` verified.  
**Layout Budget**: Control grid $\le 520\text{ pt}$ across all `ThemeID.allCases`.  

---

## 1. Stage 1: SYNT_7 / ROUND6 Fixes (R6-2 – R6-8)

- **R6-2 (.reverbMix / .reverbRoomSize AUv3 Automation & Knobs)**:
  - Addressed parameter handler and CC mapper in `AudioEngine+Parameters.swift` and `AudioEngine+Render.swift` now immediately update `cachedReverbMix`, `cachedReverbRoom`, `parameterReverbMix`, and `parameterReverbRoom`.
  - Added synchronization in `SyntAudioUnit.allocateRenderResources()` to ensure parameter store matches active preset state before first render.
- **R6-3 (Trance Gate Host Lock During Transport Stop)**:
  - When host transport is stopped, the trance gate locks initial step to host beat position and free-runs on internal clock so notes played from the keyboard are never muted.
  - While host transport is running, the gate locks tightly to host beat position across locates and loops.
- **R6-4 (Standalone Double Reverb Prevention)**:
  - When `preset.dspReverbEnabled == true`, the Apple `AVAudioUnitReverb` in standalone mode is explicitly bypassed (`reverb.reverb.bypass = true`, `wetDryMix = 0`), eliminating double reverb.
- **R6-5 (Reverb Buffer Reallocation Safe Swap on Device Change)**:
  - In `DSPReverb.allocate(sampleRate:)`, buffer reallocations are performed with safe allocation and atomic swap to prevent use-after-free when the audio device or sample rate changes.
- **R6-6 (Fixed OSC2 and FM Ratio Priority)**:
  - OSC2 fixed frequency (HZ) and FM ratio now have mutually exclusive priority in the UI and DSP. Fixed frequency takes priority over FM ratio, with mutual toggling and descriptive tooltips in `OscillatorView`.
- **R6-7 (MIDI Learn for Fine Pitch)**:
  - Mapped `.finePitch` target in `MIDICCLearnStore.swift` to its own distinct case, cleanly updating both `osc1Detune` and `osc2Detune` without conflating with `.pitch1`.
- **R6-8 (Chorus/Delay Mix Modulation Thread Safety)**:
  - Modulated values of `chorusMix` and `delayMix` are now computed locally in `render` (`chorusMixNow`, `delayMixNow`) rather than mutating main-thread object properties on `dspChorus` and `pingPongDelay`.
- **Tests**: `Synt_swiftUITests/Stage9FixesTests.swift` (7 unit tests, all passed).

---

## 2. Stage 2: Envelopes and Modulation

- **ADSR Curves per Segment**:
  - Added `attackCurve`, `decayCurve`, and `releaseCurve` (range `[-1.0, 1.0]`, neutral `0.0`) to `ADSREnvelope` and `SynthPreset`.
  - With curve = `0.0`, the envelope executes the original linear/standard formula bit-identically (preserving Init golden render hash `0xd1b3635203a4799e`).
  - Convex / concave warping applied smoothly when curve $\neq 0$.
- **Envelope Follower Modulation Source**:
  - Appended `ModSource.envelopeFollower = "Env Follower"` at the end of `ModSource` enum.
  - Implemented real-time audio level follower in `AudioEngine` tracking full-mix peak/RMS with zero allocations and zero locks. Off by default.
- **Stereo Modulation (L/R Phase Offset for LFOs)**:
  - Added `stereoPhaseOffsetDegrees` to `LFO` and `lfoStereoPhase` / `lfo2StereoPhase` to `SynthPreset` (default `0.0`).
  - LFO produces stereo signals (`nextStereoRawValue`) and modulates voice stereo pan/gain when offset $\neq 0$.
- **Tests**: `Synt_swiftUITests/Stage9ModulationTests.swift` (5 unit tests, all passed).

---

## 3. Stage 3: Sound

- **Frequency Shifter in FX**:
  - Implemented `DSPFrequencyShifter` with a 4-stage allpass Hilbert transform network producing analytic in-phase ($I$) and quadrature ($Q$) signals, complex carrier oscillator, feedback, and dry/wet mix.
  - Controlled by `frequencyShifterEnabled` (default `false`), `frequencyShifterShiftHz` (default `0.0`), `frequencyShifterMix`, and `frequencyShifterFeedback`.
- **Comb / Resonator Filter**:
  - Appended `FilterType.comb = "Comb"` at the end of `FilterType` enum.
  - Implemented `DSPCombFilter` with fractional delay (linear interpolation) and resonant feedback loop. Integrated into `AudioEngine` filter path and `DSPDualFilter`.
- **Character Warm / Bright**:
  - Implemented `DSPCharacterTone` with `.off` (default), `.warm` (low warmth boost, gentle high rolloff, subtle 2nd harmonic saturation), and `.bright` (air/presence shelving boost above 4 kHz).
- **Tests**: `Synt_swiftUITests/Stage9SoundTests.swift` (6 unit tests, all passed).

---

## 4. Stage 4: UI

- **Modulation Highlighting on Knobs**:
  - Added `modulationAmount: Float = 0.0` to `KnobView`, `KnobBody`, `LargeKnobView`, and `LargeKnobBody`.
  - In `KnobChrome`, rendered a modulation ring/arc using `theme.aMod` with 3.0 pt line width on `Circle().trim(from: modStart, to: modEnd)` when `modulationAmount != 0`.
  - Connected `modAmount(destination, in: preset.modMatrix)` to filter cutoff/resonance/vowel, LFO rate/depth, and oscillator volume knobs.
- **Preset Browser with Search and Tags**:
  - Enhanced `PresetListView` in `SynthUI/Views/PresetView.swift` with category and type filter pills: `["All", "Lead", "Bass", "Pad", "Keys", "Pluck", "Arp", "FX", "Wavetable", "FM"]`.
  - Added category tag badge on `PresetRow`.
  - Enhanced search to match both preset name and category name without modifying preset JSON or models.
- **Tests**: `Synt_swiftUITests/Stage9UITests.swift` (5 unit tests, all passed).

---

## 5. Constraints & Validations

1. **RT Safety**: Zero heap allocations, zero locks, zero ARC, zero print/logging on audio thread.
2. **Golden Render Hash**: `0xd1b3635203a4799e` bit-identical across `InitGoldenTests`.
3. **Layout Height**: Height $\le 520\text{ pt}$ across all themes (`LayoutTests` verified).
4. **AU Validation**: `auval -v aumu Synt Nixr` passes cleanly with `AU VALIDATION SUCCEEDED`.
5. **No Force Push / Clean History**: All commits pushed sequentially to `feat/auv3`.

---

## 6. Deferred Items
- **MIDI Output from Arp/Sequencer**: Deferred pending Logic Pro / AUv3 MIDI out compatibility review as specified in `GROK_BUILD_TASKS_SYNT_9.md`.
