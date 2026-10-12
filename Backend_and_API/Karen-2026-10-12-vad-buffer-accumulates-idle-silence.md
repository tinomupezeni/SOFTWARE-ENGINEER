# Friday mic buffer recorded idle silence, starving real speech from STT

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** High
**Status:** Resolved

## Summary

Friday's capture loop in `audio.rs` appended every microphone frame to the
recording buffer unconditionally, from the moment listening started, not
just while the user was actually speaking. Any idle time waiting for the
user to talk was recorded into the same buffer as the eventual utterance.
This caused real speech to either be silently dropped once the 120s
recording cap was hit by pure silence, or to be buried in tens of seconds
of near-silence that Whisper mis-transcribed as `[BLANK_AUDIO]`/`[INAUDIBLE]`.
User-visible symptom: saying "hi" produced "transcribing" then "Sorry, I
didn't catch that" repeatedly.

## Symptoms

- User speaks a short phrase; HUD cycles `transcribing` → "Sorry, I didn't
  catch that" on effectively every turn.
- Log shows `Speech started` and `Speech ended (350ms silence)` within
  ~1 second of each other (correct, short VAD window), but the immediately
  following `Audio captured: NN.NNs` line reports a duration far longer
  than the actual utterance (120.00s in one case, 20.77s in another).
- STT (`whisper tiny.en`) then takes tens of seconds to over two minutes to
  return, often producing non-speech markers instead of the spoken words.

## Environment Details

- **Server/Host:** garden (Linux, PipeWire)
- **Services Affected:** `karen-desktop` Tauri app — `audio.rs` (CPAL
  capture + VAD)
- **Related Components:** `pipeline.rs` (consumes the drained buffer),
  `stt.rs` (Whisper transcription)
- **Time First Observed:** 2026-10-11, logged in `friday.log` (08:12–08:15
  timestamps); reported by user 2026-10-12

## Investigation Steps

### 1. Initial Diagnosis

User reported Friday fails to understand any voice command and loops
"Sorry, I didn't catch that." Read `friday.log` for the most recent
capture-to-transcript sequences rather than assuming a VAD threshold
problem (a threshold tweak was already applied in a prior session per
`FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md`).

### 2. Root Cause Analysis

Found two real captures in the log:

```text
08:12:22 Speech started (rms=0.05808, floor=0.02033, threshold=0.04000)
08:12:23 Speech ended (350ms silence). Triggering pipeline.
08:12:23 Audio captured: 120.00s (including VAD silence)
...
08:14:42 STT finished in 138.665992929s: raw transcript="[INAUDIBLE] [BLANK_AUDIO] [BLANK_AUDIO]"

08:15:06 Speech started (rms=0.04139, floor=0.02200, threshold=0.04000)
08:15:07 Speech ended (350ms silence). Triggering pipeline.
08:15:07 Audio captured: 20.77s
...
08:15:45 STT finished in 38.3530972s: raw transcript="[wind blowing] Is that it? Are you alright?"
```

Speech started and ended about one second apart in both cases (VAD itself
working correctly), yet the buffer handed to Whisper was 20–120 seconds
long. Traced this to `audio.rs`'s capture callback:

```rust
if guard.samples.len() < cap_len {
    guard.samples.extend_from_slice(data);
}
```

This ran on every audio frame regardless of `is_speaking`, so the buffer
accumulated the entire idle-listening window (silence while waiting for
the user to start talking), not just the speech segment. Two failure
modes followed directly:

1. If the user took long enough to speak, the buffer hit the 120s
   `MAX_RECORDING_SECS` cap on pure silence *before* real speech began —
   the `len() < cap_len` guard then blocked all further writes, so the
   actual utterance was never captured at all.
2. Even under the cap, Whisper had to transcribe a large near-silent
   buffer plus a few real words, which is both slow (matches the 38s/138s
   STT durations, scaling with captured duration) and prone to emitting
   non-speech markers instead of the spoken text.

### 3. Key Findings

- VAD onset/offset detection itself was correct and fast (~1s).
- The recording buffer was not scoped to the speech segment; it recorded
  from mic-listening-start, independent of `is_speaking`.
- STT duration correlated directly with `Audio captured` duration, not
  with actual speech length — confirming Whisper was processing mostly
  silence.
- The 120s cap (`MAX_RECORDING_SECS`), intended as a memory safety net for
  a forgotten push-to-talk key per its own comment, was actually starving
  real speech in VAD/open-mic mode.

## Root Cause

The capture buffer conflated "mic is listening" with "user is speaking."
It recorded continuously from `AudioCommand::Start` instead of only during
the VAD-detected speech window (plus its trailing end-silence grace
period), so idle silence consumed the recording cap and diluted what was
sent to STT.

## Prevention / Rule

**Guardrail:** any audio buffer fed to STT must be scoped to
`is_speaking` (plus a bounded pre-roll/grace window), never to the full
listening session — enforce via code-review checklist item for
`audio.rs`/`pipeline.rs` ("does this buffer gate writes on VAD state, or
just on stream-open state?").

This closes the exact gap above: a buffer that only ever grows while the
stream is open, rather than while speech is in progress, will eventually
reproduce this failure under any VAD design.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/audio.rs`:

- Added a bounded `preroll` buffer (300ms) to `SharedBuffer`, always
  trimmed to the last `PREROLL_MS` of idle audio.
- Main `samples` buffer is now only appended to while `guard.is_speaking`
  is true (which already correctly includes the 350ms trailing
  end-silence grace window used to detect end-of-utterance).
- On the idle→speaking transition, the pre-roll buffer is drained into
  `samples` first, so the onset of speech is never clipped.
- `preroll` is cleared alongside `samples` on `drain()`, on stream
  (re)start, and on the existing VAD "stuck" recovery path.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass (pre-existing warnings only)
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml audio::   # 7 passed
```

### Long-term Fix

- Guided live retest to confirm `Audio captured` durations now track
  actual speech length (roughly speech duration + 300ms preroll + 350ms
  trailing silence), and that STT returns real transcripts instead of
  non-speech markers.
- Consider whether `MAX_RECORDING_SECS`/`MAX_SPEECH_SECS` still need
  separate tuning now that idle time no longer counts against the cap.

## Prevention

- [x] Code changes required (done — gated buffer accumulation on
      `is_speaking`, added bounded pre-roll)
- [ ] Guided live retest with full log sequence
- [ ] Monitoring/alerts to add (none planned; log line already reports
      captured duration per turn)
- [ ] Documentation to update (`ARCHITECTURE.md` §5.1/§6 capture
      description could mention pre-roll + speech-gated recording)

## Related Issues

- `Karen-2026-10-11-stt-silent-discard-no-logging.md` — same file family
  (`audio.rs`/`pipeline.rs`); that entry made discards observable, which is
  what surfaced the `Audio captured` duration mismatch used to find this
  bug.
- `FRIDAY_AUDIO_DIAGNOSTIC_HANDOFF.md` — prior session's VAD threshold
  tuning; that fix was correct but insufficient on its own since the
  buffer-scoping bug sat downstream of VAD onset/offset detection.

## References

- Files: `karen-desktop/src-tauri/src/audio.rs`, `pipeline.rs`
- Logs: `/home/shadowe/.local/share/com.tauri.dev/logs/friday.log`

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~25 min investigation + fix
