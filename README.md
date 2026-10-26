# Synt

A polyphonic software synthesizer for macOS, written in Swift and SwiftUI.
Synt runs as a **standalone app** and as an **AUv3 instrument plugin** for Logic Pro and other Audio Unit hosts. Both share one engine, so presets and sound are identical in each.

> **Status:** work in progress. This is a personal project. Expect changes.

---

## Features

**Sound sources**
- Oscillators: sine, sawtooth, square, triangle, noise, wavetable
- Unison voices with detune
- ADSR envelopes, LFOs, and an MSEG modulator
- Modulation matrix

**Filters**
- Filter types include ladder and notch
- Dual filter with selectable routing
- Comb and formant filters

**Effects**
- Chorus, phaser, rotary, frequency shifter
- Delay, ping-pong delay, reverb, shimmer
- Distortion, character tone, transient shaper, compressor, parametric EQ, stereo tool
- Reorderable FX chain and FX presets

**Performance**
- Step sequencer and arpeggiator
- MIDI input, MIDI CC learn, MIDI clock sync, MPE
- Scala (`.scl`) tuning files

**Presets**
- Factory preset library
- User presets, favorites, patch history, and a preset mutator

## Audio Units

| Plugin | Type | Where it appears in Logic Pro |
| --- | --- | --- |
| **Synt** | Instrument (`aumu`) | AU Instruments › Nixr › Synt |
| **Synt Arp** | MIDI effect (`aumi`) | MIDI FX › Nixr › Synt Arp |

## Repository layout

```
Synt_swiftUI/            Standalone macOS app (SwiftUI)
SyntAUv3/                AUv3 instrument extension
SyntArpAUv3/             AUv3 MIDI arpeggiator extension
SynthCore/               Shared framework: audio engine, DSP, presets, MIDI
  Audio/                 Engine, voices, oscillators, envelopes, effects
  DSP/                   Additional filters, effects, modulation
  Models/                Presets, parameters, factory library
  Utils/                 Preset manager, Scala parser, helpers
SynthUI/                 Shared SwiftUI views (app and plugin)
Synt_swiftUITests/       Unit tests
Synt_swiftUIUITests/     UI tests
Tools/                   Small developer utilities
docs/design/             UI design notes and references
```

## Requirements

- macOS 15.6 or later
- Xcode with Swift 5 support

## Build and run

1. Clone the repository:

   ```bash
   git clone https://github.com/Nixter77/Synt_swiftUI.git
   cd Synt_swiftUI
   ```

2. Open the project in Xcode:

   ```bash
   open Synt_swiftUI.xcodeproj
   ```

3. Select the **Synt_swiftUI** scheme and run it (⌘R). This builds the app and embeds the AUv3 extensions.

To use the plugin in Logic Pro:

1. Build the app and copy `Synt_swiftUI.app` to `/Applications`.
2. Launch the app once, so macOS registers the extensions.
3. In Logic Pro, open a software instrument track and choose **AU Instruments › Nixr › Synt**.

If the plugin does not appear, run `auval -a` in Terminal to check the registration. Then rescan in Logic Pro's Plug-in Manager.

## Tests

```bash
xcodebuild test -project Synt_swiftUI.xcodeproj -scheme Synt_swiftUI
```
