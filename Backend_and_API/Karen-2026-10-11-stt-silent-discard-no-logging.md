# Friday/Karen STT turns silently discarded with no logging

**Date:** 2026-10-11
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Medium
**Status:** Resolved

## Summary

Friday's voice pipeline discarded every non-speech Whisper result without writing any log line, so `friday.log` showed `Audio captured` followed by nothing — indistinguishable from a crashed or stalled transcription task. Stage-start, raw-result, discard-reason, and elapsed-time logging was added to `pipeline.rs` so the next test run produces a complete observable sequence.

## Symptoms

- User speaks; log shows `Speech started` / `Speech ended` / `Audio captured: 6-14s` / `mic capture stopped`, then nothing — no `heard:`, no STT error, no LLM/TTS entries.
- UI says "Friday is speaking…" at times with no audible output (separate, earlier symptom from when turns did reach TTS).
- Impossible to tell whether Whisper was slow, failing, or returning blank/noise markers.

## Environment Details

- **Server/Host:** garden (Linux, PipeWire 1.6.2, PulseAudio-compat)
- **Services Affected:** `karen-desktop` Tauri app — `audio.rs` (VAD), `pipeline.rs`, `stt.rs`, `tts/mod.rs`
- **Related Components:** Whisper `ggml-tiny.en.bin`, Piper local TTS, `pw-play`/`aplay` playback
- **Time First Observed:** 2026-10-11 (~07:06 log timestamps)

## Investigation Steps

### 1. Initial Diagnosis

Read `FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md` plus `audio.rs`, `pipeline.rs`, `stt.rs`, `tts/mod.rs`, `tts/manager.rs`, `lib.rs`, and both persisted logs (`friday.log`, `karen.log`).

### 2. Root Cause Analysis

Traced the `pipeline::run` control flow after `Audio captured`:

```rust
let transcript = match stt::transcribe(ctx, mono_16k).await {
    Ok(text) => match clean_transcript(&text) {
        Some(text) => text,
        None => { emit_if_current("idle", ...); return false; }  // <-- zero logging
    },
    ...
};
// STT duration + `heard:` logged only here — unreachable on the discard path
```

Verified against live evidence: captures were 6–14s of near-threshold audio (noise floor ~0.065 RMS, threshold ~0.09, speech peaks only 0.10–0.13), exactly the kind of input Whisper `tiny.en` transcribes as blank or `(water running)`-style markers — all of which take the silent `None` path.

Checked the output side independently so it would not be conflated:

```bash
echo "test one two three" | piper --model ... --output_file /tmp/test-piper.wav  # OK, 1.36s WAV
timeout 10 pw-play /tmp/test-piper.wav   # exit 0
timeout 10 aplay /tmp/test-piper.wav     # exit 0
pactl get-sink-mute @DEFAULT_SINK@       # no; volume 70%
pactl get-source-mute @DEFAULT_SOURCE@   # no; mic volume 35%
```

Playback backend, sink routing, and Piper synthesis all work, so the current no-audio reports are an input/STT problem, not a player problem.

### 3. Key Findings

- Microphone samples reach the app; revised VAD segments utterances.
- Long (6–14s) low-SNR captures are discarded by `clean_transcript` with no trace.
- `stt_started_at` timing and `heard:` logging sat below the discard early-return — unreachable.
- Output stack verified healthy in isolation (Piper synthesis + `pw-play`/`aplay` exit 0, sink unmuted at 70%).
- Mic input level is low (35%) against a high room noise floor (~0.065 RMS) — poor SNR worth a guided retest, not a code change yet.

## Root Cause

Observability gap, not a transcription crash: the STT discard path in `pipeline::run` returned before any logging, and all timing/result logs were placed after the transcript-cleaning gate. Every blank/noise transcription vanished silently.

## Prevention / Rule

**Guardrail:** every early-return in an async pipeline stage must log its input summary, reason, and elapsed time before returning — enforce via code-review checklist item for `pipeline.rs` ("no silent `return false`").

A discard with no log line is indistinguishable from a hang; the guardrail closes this exact gap by making each exit path self-describing.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/pipeline.rs` — restructured the STT section:

- Log STT start (16 kHz mono duration, sample count, source format).
- Log Whisper load elapsed (`Whisper ready in …` / failure with elapsed).
- Log raw Whisper transcript (`{:?}`) with inference elapsed on every success.
- Log discard with the raw text (`STT discarded: … raw=…`).
- Transcription errors now include elapsed time.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml  # pass (pre-existing warnings only)
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml pipeline::  # 5 passed
```

### Long-term Fix

- Guided retest in a quiet room with mic level raised; if discards persist with good SNR, consider a larger Whisper model or a max-capture-duration guard so 10s+ noise accumulations cannot reach STT.
- Revisit the optimistic `speaking` UI emit in `lib.rs` (shown before `tts::wait_all()` even when synthesis fails).

## Prevention

- [x] Code changes required (done — STT stage logging)
- [ ] Guided quiet-room retest with full log sequence
- [ ] Consider mic-gain adjustment (currently 35%) if SNR stays poor
- [ ] Documentation to update (`FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md` next steps 3–4 now unblocked)

## Related Issues

- `FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md` (working handoff in the Karen repo)
- Earlier Groq TTS 429 rate-limit with Piper fallback (2026-10-10 `karen.log`) — output-side, already falling back correctly

## References

- Files: `karen-desktop/src-tauri/src/pipeline.rs`, `stt.rs`, `audio.rs`, `tts/mod.rs`, `tts/manager.rs`, `lib.rs`
- Logs: `/home/shadowe/.local/share/com.tauri.dev/logs/friday.log`, `karen.log`

---

**Resolved By:** Muse Spark (OpenCode)
**Time to Resolution:** ~30 min investigation + fix
