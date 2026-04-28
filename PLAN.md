# PLAN.md — D³ Phase 2: DEFINE

**Date**: 2026-04-28
**Status**: APPROVED — proceeding to DELIVER
**Bugs addressed**: 14 (from DISCOVER audit)

## Architecture Decision: Reuse Existing Infrastructure

The codebase already contains these battle-tested modules that are NOT wired up:
- `AudioCommandQueue.swift` — Lock-free SPSC queue (READY)
- `AtomicMeteringState.swift` — Atomic metering + triple-buffered scope (READY)
- `CachedBiquadFilter.swift` — Biquad with coefficient caching (READY)
- `VoiceManager` in `VoiceState.swift` — Pre-allocated flat voice pool (READY)
- `Compressor.swift` — Dynamics compressor with limiter mode (READY)

**Decision**: Wire these in instead of writing new code. Minimal new code needed.

---

## Phase 1: Thread Safety + Voice Architecture (BUG-01, 05, 10, 11, 13, 14)

**Goal**: Remove NSLock, Dictionary, DispatchQueue.main.async from audio thread.

### Changes:
1. `AudioEngine.swift` — Replace `notesLock` + `activeNotes: [Int: [ActiveNote]]` with `AudioCommandQueue` + `VoiceManager`
2. `AudioEngine.swift` — Replace `DispatchQueue.main.async` metering with `AtomicMeteringState` + UI polling timer
3. `AudioEngine.swift` — Add `AudioCommand` cases for preset parameter snapshots
4. `AudioEngine.swift` — Make `oscillator1/2`, `envelope`, `lfo` private (audio-thread-owned)
5. `AudioCommandQueue.swift` — Add snapshot command cases

### Thread ownership after fix:
- **UI thread**: pushes commands via `commandQueue.push()`
- **Audio thread**: pops commands in `prepareBlock()`, owns all DSP state

---

## Phase 2: Stereo Pipeline + Gain Staging (BUG-02, 03, 04, 06)

**Goal**: True stereo path, proper polyphony scaling, real limiter.

### Changes:
1. `AudioEngine.swift` — Replace `SynthFilter` (mono) with two `CachedBiquadFilter` instances (L/R)
2. `AudioEngine.swift` — Remove mono collapse `(mixedSampleL + mixedSampleR) * 0.7`
3. `AudioEngine.swift` — Add polyphony scaling: `1/√(activeVoiceCount)`
4. `AudioEngine.swift` — Add pre-limiter trim (0.9)
5. `AudioEngine.swift` — Replace hard clip with `Compressor` in limiter mode
6. `AudioEngine.swift` — Remove `* 1.414` from pan LFO
7. `AudioEngine.swift` — Add `mainMixerNode.outputVolume = 0.5` for reverb/delay headroom
8. `DSPChorus.swift` — Add stereo input method `process(inputL:inputR:)`

---

## Phase 3: Sample Rate + Filter Performance (BUG-07, 08)

**Goal**: Dynamic sample rate, cached filter coefficients.

### Changes:
1. `AudioEngine.swift` — Query hardware sample rate from `engine.outputNode`
2. `AudioEngine.swift` — Reinitialize DSP on configuration change
3. Filter already solved by `CachedBiquadFilter` (Phase 2)

---

## Phase 4: Sound Quality (BUG-09)

**Goal**: Natural-sounding envelopes.

### Changes:
1. `ADSREnvelope.swift` — Replace linear decay with exponential: `value *= exp(-5.0 * deltaTime / decayTime)`
2. `ADSREnvelope.swift` — Replace linear release with exponential

---

## Phase 5: Cleanup (BUG-12)

### Changes:
1. `AudioEngine.swift` — Remove duplicate `reverb.setRoomSize()` call

---

## Reviewer Debate Notes

**Reviewer attack**: "Phase 1 is too aggressive — you're rewriting the entire voice path."
**DSP Builder defense**: "We're not rewriting. VoiceManager already exists. We're replacing ~200 lines of Dictionary+NSLock code with ~30 lines of commandQueue.push() calls and a prepareBlock() function."

**Reviewer attack**: "Exponential ADSR in Phase 4 — won't it cause discontinuities?"
**DSP Builder defense**: "No. We use exp(-k*dt) per sample, which is inherently continuous. The transition from decay to sustain is smooth because exp approaches sustain asymptotically."

**Consensus**: All phases approved. Execute in order.

