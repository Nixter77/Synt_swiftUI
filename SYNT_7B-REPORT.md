# SYNT_7B Implementation Report (Parallel DSP Track)

## 1. Overview & Setup
- **Worktree**: `/Users/nikolay/gemini_projekts/Synt_swiftUI_7b`
- **Branch**: `feat/synt7b-dsp` (branched from `eb69415`, tracked on `origin/feat/synt7b-dsp`)
- **Isolation Guarantee**: The main project folder `/Users/nikolay/gemini_projekts/Synt_swiftUI` was completely untouched. No existing files were edited (`AudioEngine*`, `SynthPreset*`, mod matrix, UI, and `.pbxproj` are completely untouched).
- **DerivedData**: Dedicated `-derivedDataPath ~/.synt_dd_7b`.
- **Render Invariance**: Golden render hash `0xd1b3635203a4799e` verified via `InitGoldenTests` after every stage and bit-identical.

---

## 2. Commit Log

| Stage | Commit Hash | Message | Files Added |
|---|---|---|---|
| Baseline Worktree | `eb69415` | `fix(auv3): size and host the plugin view on main...` | - |
| **Stage 1 (Formant Filter)** | `38b6aef` | `feat(dsp): Step 1 - Formant filter with smooth morphing across A/E/I/O/U` | `SynthCore/DSP/Experimental/DSPFormantFilter.swift`<br>`Synt_swiftUITests/Experimental/DSPFormantFilterTests.swift` |
| **Stage 2 (MSEG Engine)** | `b2b2824` | `feat(dsp): Step 2 - MSEG engine with curve interpolation, loop, sustain, and sync` | `SynthCore/DSP/Experimental/DSPMSEG.swift`<br>`Synt_swiftUITests/Experimental/DSPMSEGTests.swift` |
| **Stage 3 (Dual Filter)** | `e84d281` | `feat(dsp): Step 3 - Dual filter standalone module with serial/parallel routing and balance` | `SynthCore/DSP/Experimental/DSPDualFilter.swift`<br>`Synt_swiftUITests/Experimental/DSPDualFilterTests.swift` |
| **Report** | `[Pending]` | `docs(dsp): SYNT_7B report with API description for SYNT_8 integration` | `SYNT_7B-REPORT.md` |

---

## 3. Test Suite Results

All unit test suites executed with Xcode testing (`platform=macOS`, `-derivedDataPath ~/.synt_dd_7b`):

### 1. `DSPFormantFilterTests` (5/5 Passed)
- `formantPeakInSpectrum()`: Verified formant resonance peaks at 800 Hz (F1 for vowel 'A') produce >3x higher energy than adjacent dips (200 Hz).
- `stableAtAllMorphValues()`: Continuous sweep from morph -0.5 to 4.5; verified bounded within rail and finite (`output.isFinite == true`).
- `finiteOutputWithWhiteNoiseFor10Seconds()`: 441,000 samples (10.0 s @ 44.1 kHz) of full-scale white noise with high resonance and dynamic morphing; strictly finite, 0 NaNs, 0 Infs, within safe rails.
- `stereoProcessingAndReset()`: Verified dual-channel discrete processing and state clearing on `reset()`.
- `blockProcessingMatchesSampleProcessing()`: Verified frame pointer buffer processing matches sample-by-sample output bit-for-bit.

### 2. `DSPMSEGTests` (6/6 Passed)
- `interpolationLinearConvexConcave()`: Verified linear ($c=0 \implies 0.5$), convex ($c>0 \implies <0.45$), concave ($c<0 \implies >0.55$).
- `loopRegionBetweenPoints()`: Verified phase wraps cleanly between loopStart and loopEnd without leaving bounds.
- `sustainPointHoldsUntilGateRelease()`: Verified phase and amplitude lock to sustain point while `gate == true`, and cleanly release past sustain when `gate == false`.
- `phaseAfterRetrigger()`: Verified `trigger()` restarts phase from 0.0 in `.retrigger` mode, and preserves phase in `.continuous` mode.
- `codableModelWithDecodeIfPresent()`: Verified JSON decoding with missing optional fields falls back to safe defaults; roundtrip encode/decode equality.
- `max32PointsClamped()`: Verified points array clamped to maximum 32 points.

### 3. `DSPDualFilterTests` (5/5 Passed)
- `frequencyResponseSerialVsParallel()`: Tested LP 500 Hz + HP 2000 Hz. In parallel with balance 0.5, passes 100 Hz and 8000 Hz; in serial with balance 1.0 (pure cascade), rejects both 100 Hz and 8000 Hz.
- `serialCascadingSteepness()`: Verified dual LP 1000 Hz cascade in serial gives steep 24 dB/oct slope with significantly higher stopband attenuation than single filter.
- `stabilityUnderContinuousParameterSweeps()`: 100,000 samples with simultaneous sweep of cutoff1, cutoff2, resonance1, resonance2, balance, and switching serial/parallel routing on the fly; 100% finite, no NaNs.
- `balanceCrossfadeParallel()`: Verified smooth crossfade between Filter 1 and Filter 2.
- `blockProcessingMatchesSampleProcessing()`: Verified block pointer buffer processing matches sample-by-sample processing bit-for-bit.

### 4. Golden Render Test
- `InitGoldenTests/initAndFactoryPresetsRenderBitIdenticalToGolden`: **PASSED**. Bit-identical FNV hash `0xd1b3635203a4799e` preserved.

---

## 4. API Guide for SYNT_8 Integration

### Module 1: `DSPFormantFilter`
Path: `SynthCore/DSP/Experimental/DSPFormantFilter.swift`

```swift
public final class DSPFormantFilter {
    /// 0.0 = 'A', 1.0 = 'E', 2.0 = 'I', 3.0 = 'O', 4.0 = 'U' with continuous morphing.
    public var vowel: Float // 0.0 ... 4.0
    public var q: Float     // Base Q (default 6.0)
    public var resonance: Float // 0.0 ... 1.0 (narrows peaks, increases ringing)
    public var mix: Float   // Dry/wet 0.0 ... 1.0

    public init(sampleRate: Double = 44100.0, maxFrames: Int = 512)
    public func prepare(sampleRate: Double, maxFrames: Int)
    public func reset()
    public func process(_ input: Float) -> Float
    public func process(inputL: Float, inputR: Float) -> (Float, Float)
    public func process(bufferL: UnsafeMutablePointer<Float>, bufferR: UnsafeMutablePointer<Float>, frameCount: Int)
}
```
**Wiring Tips for SYNT_8**:
- Can be added as a filter type (e.g. `FilterType.formant`) in `Filter.swift`, or as a voice post-filter insert, or as a master effect insert before/after EQ.
- Has zero allocations in `process()` and internal 5-band biquad parallel resonators using acoustic formant tables for vowels A/E/I/O/U.

---

### Module 2: `DSPMSEG` and `DSPMSEGModel`
Path: `SynthCore/DSP/Experimental/DSPMSEG.swift`

```swift
public struct DSPMSEGPoint: Codable, Equatable, Sendable {
    public var time: Float   // Normalized time 0.0 ... 1.0
    public var value: Float  // Amplitude -1.0 ... 1.0
    public var curve: Float  // Curvature: -1.0 (concave/log) ... 0.0 (linear) ... 1.0 (convex/exp)
}

public enum DSPMSEGSyncMode: String, Codable, Sendable, CaseIterable {
    case hz = "Hz"
    case beats = "Beats"
}

public enum DSPMSEGTriggerMode: String, Codable, Sendable, CaseIterable {
    case retrigger = "Retrigger"
    case continuous = "Continuous"
}

public struct DSPMSEGModel: Codable, Equatable, Sendable {
    public static let maxPoints: Int = 32
    public var points: [DSPMSEGPoint]
    public var isOneShot: Bool
    public var syncMode: DSPMSEGSyncMode
    public var rateHz: Float
    public var syncBeats: Float
    public var triggerMode: DSPMSEGTriggerMode
    public var loopStartIndex: Int?
    public var loopEndIndex: Int?
    public var sustainIndex: Int?
}

public final class DSPMSEG {
    public var model: DSPMSEGModel
    public private(set) var phase: Float
    public private(set) var currentValue: Float
    public private(set) var isRunning: Bool
    public private(set) var isSustaining: Bool

    public init(model: DSPMSEGModel = DSPMSEGModel(), sampleRate: Double = 44100.0)
    public func prepare(sampleRate: Double, maxFrames: Int = 512)
    public func reset()
    public func trigger()
    public func release()

    /// RT audio thread tick. Zero heap allocations, zero locks, zero ARC.
    @inline(__always)
    public func tick(gate: Bool = true, bpm: Double = 120.0) -> Float

    public func evaluate(at t: Float) -> Float
}
```
**Wiring Tips for SYNT_8**:
- `DSPMSEGModel` can be added to `SynthPreset` as an optional field:
  `public var mseg: DSPMSEGModel?` with `decodeIfPresent`.
- In `VoiceState.swift`, an instance of `DSPMSEG` can be held per voice (or globally for LFO-style MSEG) and ticked in `AudioEngine+Render.swift`.
- Added to `ModSource` as `.mseg` to modulate any parameter through `RTModMatrix`.

---

### Module 3: `DSPDualFilter`
Path: `SynthCore/DSP/Experimental/DSPDualFilter.swift`

```swift
public enum DualFilterRouting: String, Codable, Sendable, CaseIterable {
    case serial = "Serial"
    case parallel = "Parallel"
}

public final class DSPDualFilter {
    public var routing: DualFilterRouting = .serial
    public var balance: Float = 0.5 // 0.0 = Filter 1, 1.0 = Filter 2 / Cascade
    public var mix: Float = 1.0

    // Filter 1
    public var type1: FilterType
    public var cutoff1: Float
    public var resonance1: Float

    // Filter 2
    public var type2: FilterType
    public var cutoff2: Float
    public var resonance2: Float

    public init(sampleRate: Double = 44100.0, maxFrames: Int = 512)
    public func prepare(sampleRate: Double, maxFrames: Int = 512)
    public func reset()
    public func process(_ input: Float) -> Float
    public func process(inputL: Float, inputR: Float) -> (Float, Float)
    public func process(bufferL: UnsafeMutablePointer<Float>, bufferR: UnsafeMutablePointer<Float>, frameCount: Int)
}
```
**Wiring Tips for SYNT_8**:
- Replaces or augments the single filter in `VoiceState` / `AudioEngine+Voices.swift`.
- Reuses the existing `SynthFilter` without any breaking changes.
- Add `filter2Type`, `filter2Cutoff`, `filter2Resonance`, `filterRouting`, and `filterBalance` to `SynthParameterAddress` and `SynthPreset`.
