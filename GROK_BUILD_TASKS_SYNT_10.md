# GROK_BUILD_TASKS_SYNT_10

Base: 44afb0f on feat/auv3 (the auval fix is done, `auval -v aumu Synt Nixr` = SUCCEEDED). Do not merge into main.
Rules: no allocations, locks or ARC on the render thread; golden hashes do not change, everything new is default-off; decodeIfPresent; enum cases at the end; main thread for UI/AU sizing; LayoutTests; every AU parameter has its default inside [min,max]; at the end of each stage `auval -v aumu Synt Nixr` = SUCCEEDED; restore GLASS_HORIZON_PROBE_DUMP.txt; one commit per stage.
Source: /workspace/tmp/synt_review/ROUND7.md on the bot's computer (lines as of 17110d7).

## Stage 1: Critical DSP fixes
- R7-1: DSPFrequencyShifter.swift:14-15,53. Rebuild the Hilbert network properly (Niemitalo allpass pairs with the correct section order plus a 1-sample delay in one branch). Test: shifting a sine by +100 Hz, the second sideband ≤ −40 dB.
- R7-3: Render.swift:965. Check isFinite BEFORE fastTanh; on NaN reset the filter and feedback (the reset on :972 must fire).
- R7-4: ADSREnvelope.swift:168. Release curve starts from the actual level, not 1.0.
- R7-5: ADSREnvelope.swift:87. Attack curve starts from the current level (retrigger/legato without dips).
- R7-2: Render.swift:872-877,1031-1042. Amp LFO with stereo phase applies once (no doubled tremolo).
- Tests: no clicks on short notes and retriggers with curves; no DC after a NaN; tremolo depth equals the setting.

## Stage 2: Other fixes
- R7-6: DSPMSEG.swift:240-266. Double-buffer with acknowledgement that render has read it (do not rewrite a bank render is using).
- R7-7: SyntAudioUnit.swift:437. Add Comb to the filter type parameter (at the end); old presets stay in range.
- R7-8: DSPCharacterTone.swift:54. Remove the DC in Warm; with Off, no tanh on the master (bit-exact).
- R7-9: AudioEngine.swift:686. Do not restart the engine if the sample rate has not changed.
- R7-10: LFO.swift:116-144. Right channel of the stereo LFO uses the same one-shot/start phase/wavetable.
- R7-11: Render.swift:912,917,1010. No ARC when reading the voiceFormant/Comb/Dual arrays (unowned/unsafe pointers prepared in allocate).
- R7-12: flush denormals in Comb and the shifter; lower Comb frequency is correct at 44.1–192 kHz.

## Stage 3: Modulation
- Live modulation highlighting on knobs (values from render through a lock-free snapshot at ~30 Hz).
- Attack/release settings for the envelope follower.
- Random phase on every note (an oscillator phase mode, at the end of the enum).

## Stage 4: MSEG 2 and visuals
- MSEG 2 (a second mod source) and a better editor (grid, snapping, copying between MSEGs).
- Oscilloscope and spectrum on the output (UI only; data through a lock-free ring buffer, render does not wait).

Report: SYNT_10-REPORT.md. Deferred to SYNT_11: arp as a separate AUv3 MIDI FX (aumi), prototype it in Logic 11 first (MIDI output from an aumu instrument in Logic most likely does not work); parallel/send FX bus; rotary speaker; MPE.
