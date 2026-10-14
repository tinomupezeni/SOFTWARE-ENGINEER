# VAD Classified Blank Audio as Speech During Startup Testing

**Date:** 2026-10-14
**Project:** Karen / Friday
**Environment:** Development
**Severity:** Medium
**Status:** Investigating

## Summary

During a full Tauri development run, the microphone VAD classified a
0.75-second capture as speech even though Whisper returned `[BLANK_AUDIO]`.
The pipeline correctly discarded the transcript, but the false speech
endpoint caused an unnecessary Whisper inference and indicates that the audio
detector can still arm on a short non-speech event after startup.

## Symptoms

- Audio capture began normally after startup speech playback.
- VAD logged `Speech started` and ended after the configured 350 ms silence.
- The captured utterance was only `0.75s`.
- Whisper returned `[BLANK_AUDIO]`.
- Pipeline discarded the transcript and stayed silent because the capture was
  shorter than the missed-voice reply threshold.
- No user-visible spoken response occurred, but CPU time was spent on a false
  turn.

## Environment Details

- **Server/Host:** Local Linux development workstation
- **Services Affected:** Tauri audio pipeline and Whisper STT
- **Related Components:** `audio.rs`, `pipeline.rs`, `stt.rs`, Piper playback
- **Time First Observed:** 2026-10-14 16:51:00 +02:00

## Investigation Steps

### 1. Initial Diagnosis

Started the complete application with:

```bash
cd karen-desktop
npm run tauri dev
```

Observed the live Tauri logs after startup greeting playback and microphone
re-arming.

### 2. Root Cause Analysis

The runtime logs were correlated across audio capture, pipeline, and Whisper:

```text
Audio captured: 0.75s (including VAD silence)
Speech started (rms=0.01298, floor=0.00028, threshold=0.01000)
Speech ended (350ms silence). Triggering pipeline.
STT_BENCHMARK model=ggml-tiny.en.bin audio_secs=0.748 audio_ctx=300 threads=4 inference_ms=852 realtime_factor=1.140
STT finished ... raw transcript="[BLANK_AUDIO]"
```

### 3. Key Findings

- Whisper model loading and startup succeeded.
- The VAD threshold was crossed at a low absolute signal level.
- The endpointing path accepted the capture before the minimum pipeline
  recording guard could reject it.
- Transcript cleanup correctly recognized `[BLANK_AUDIO]` as non-speech.
- The current guard prevents chatter but does not prevent wasted STT work.

## Root Cause

The audio VAD's adaptive threshold allowed a short low-level signal to satisfy
the speech-candidate and endpoint conditions. The later `MIN_RECORDING_SECS`
guard and non-speech transcript filter are downstream safeguards, so they
cannot stop the false capture from reaching Whisper.

## Prevention / Rule

**Guardrail:** Add a VAD acceptance test matrix that requires a minimum
speech-energy duration and verifies that low-level blank/noise captures do not
emit a pipeline trigger before Whisper.

This guardrail closes the gap at the endpoint boundary rather than relying on
Whisper to reject invalid audio after the expensive inference has already
started.

## Solution

### Immediate Fix

No behavior change was applied during this run. The pipeline safely discarded
the blank transcript and did not speak a false response.

### Long-term Fix

- Add deterministic audio-buffer tests for sub-second low-level noise after
  calibration.
- Revisit the speech-candidate duration and absolute threshold floor using
  recorded workstation audio.
- Preserve the existing `[BLANK_AUDIO]` filter as a second defense.

## Prevention

- [ ] Add low-level-noise VAD fixtures and endpoint assertions
- [ ] Measure false-trigger rate alongside STT realtime factor
- [x] Preserve structured `STT_BENCHMARK` telemetry
- [ ] Update the audio diagnostic handoff after tuning

## Related Issues

- `FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md`

## References

- `karen-desktop/src-tauri/src/audio.rs`
- `karen-desktop/src-tauri/src/pipeline.rs`
- `karen-desktop/src-tauri/src/stt.rs`
- Full-run shell session `28`

---

**Resolved By:** Copilot
**Time to Resolution:** Not resolved; investigation recorded
