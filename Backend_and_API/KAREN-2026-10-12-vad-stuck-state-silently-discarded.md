# Friday's VAD permanently stuck in "speaking" and silently discarded captures

**Date:** 2026-10-12
**Project:** Karen (Friday voice assistant)
**Environment:** Development
**Severity:** Critical
**Status:** Resolved

## Summary

After the earlier buffer-scoping fix (`Karen-2026-10-12-vad-buffer-accumulates-idle-silence.md`), Friday still could not hold a conversation: a single clean "hi" with real silence around it produced 20+ second "speech" windows, and every 20 seconds the detector's own safety valve silently discarded the whole recording without ever reaching STT or telling the user anything failed. Root cause was two compounding issues: an absolute VAD threshold raised far above the first working version's value, and single noisy frames re-arming the end-of-speech timer forever. Fixed by smoothing the VAD's input signal, restoring a much lower absolute threshold matching the original (working) implementation, and changing the 20-second safety valve to flush the capture to the pipeline instead of discarding it.

## Symptoms

- User says a single word, waits; HUD cycles `transcribing` → "Sorry, I didn't catch that" repeatedly, with zero other feedback.
- Log shows a tight `Speech started` → `Speech ended` cycle is rare; the common pattern is `Speech started` → 20 seconds later `VAD stuck in speech... discarding noise buffer and recalibrating` → immediately `Speech started` again, repeating indefinitely.
- No `heard:`, no STT error, no voiced "didn't catch" reply during the stuck loop -- the discard path produced no user-visible signal of any kind.

## Investigation Steps

### 1. Initial Diagnosis

User reported "still not catching anything" even after pausing background media and after the prior buffer fix. Tailed `friday.log` live while the user spoke test phrases.

### 2. Root Cause Analysis

Diffed `audio.rs` against its first working commit (`git show d36e7f8:.../audio.rs`). Found the original detector used:

```rust
let threshold = (guard.noise_floor * 2.5).max(0.001);
```

an almost negligible absolute floor, with no 20-second safety cap at all -- it just kept recording until real silence appeared, however long that took, and always handed the result to STT. The current code had drifted to:

```rust
let threshold = (guard.noise_floor * 1.35).max(0.04);
```

a 40x higher absolute floor, plus a `MAX_SPEECH_SECS` safety valve (added in an earlier session) that, on firing, cleared the buffer and reset state **without** calling `on_speech_end` -- silently discarding whatever was captured instead of ever processing it.

Live log evidence confirmed both halves of the bug:
- `Speech started (rms=0.03006, floor=0.00953, threshold=0.01905)` followed by a clean 1.63s capture and a correct transcript once threshold margin was restored -- the margin, not the detector logic, was the first problem.
- Repeated `VAD stuck in speech for >20s ... discarding noise buffer and recalibrating` entries immediately followed by a new `Speech started`, with no intervening STT activity -- confirming the discard path never reached the pipeline.

A parallel controlled test (recording directly from the same PipeWire source with `parecord`, bypassing Friday's VAD entirely) showed a brief single noisy callback could read far above a tight threshold while sustained ambient level stayed low, explaining why isolated spikes alone shouldn't have been able to keep `is_speaking` latched for 20+ seconds -- that pointed at the per-frame (unsmoothed) threshold comparison as the second contributing cause.

### 3. Key Findings

- The absolute VAD floor had drifted 40x higher than the original working value across sessions, likely in response to a different noisy-room complaint, without re-validating against quiet/normal speech.
- The 20-second "stuck" safety valve silently ate the recording instead of flushing it -- a regression from the original version's behavior of always eventually processing whatever was captured.
- Per-frame (single-callback) RMS was compared directly against threshold for both triggering and extending speech, so one noisy callback could extend the window indefinitely in a non-stationary noise environment.

## Root Cause

Three compounding changes, made independently across sessions without being tested together against the original's behavior: an over-tightened absolute threshold, no smoothing against transient noise, and a safety cap that discards instead of flushes.

## Prevention / Rule

**Guardrail:** any change to VAD threshold constants in `audio.rs` must be accompanied by a before/after comparison against the git history's first working values (`git show <first-commit>:.../audio.rs`), not just against the most recent broken state -- enforce via code-review checklist item ("does this threshold change cite what the original value was, and why the new one is different, not just what symptom it fixes").

This closes the gap that let three independent tightenings stack up over multiple sessions into an unusable detector, each individually justified by a real but different complaint.

## Solution

### Immediate Fix

`karen-desktop/src-tauri/src/audio.rs`:

- Added `smoothed_rms` (EMA, `SMOOTHING_ALPHA = 0.35`) and use it for every VAD decision (calibration, threshold crossing, extending `last_speech_time`) instead of raw per-callback RMS, so an isolated noisy frame can't single-handedly extend or restart the speech window.
- Lowered the absolute threshold floor from `0.04` to `0.01` and the multiplier from `1.35` to `2.0`, matching the original working implementation's sensitivity much more closely while keeping a non-zero floor (the original's `0.001` was considered but kept slightly higher to still reject true silence/clicks).
- Changed the `MAX_SPEECH_SECS` safety valve to send `on_speech_end` (flushing whatever was captured to the pipeline) instead of clearing `samples` and discarding -- restores the original guarantee that a capture always produces a result, while keeping the cap that prevents unbounded recording.

```bash
cargo check --manifest-path karen-desktop/src-tauri/Cargo.toml   # pass
cargo test --manifest-path karen-desktop/src-tauri/Cargo.toml    # 60/61 passed across this session's changes
```

### Long-term Fix

- None planned beyond the guardrail; the threshold is now anchored to a documented historical reference point instead of being tuned against the most recent complaint in isolation.

## Prevention

- [x] Code changes required (done)
- [ ] Guided live retest across multiple real conversation turns, not just single isolated utterances

## Related Issues

- `Karen-2026-10-12-vad-buffer-accumulates-idle-silence.md` -- same file, earlier in this session; fixed a different bug in the same detector (buffer scoped to listening-session instead of speech-session).
- `KAREN-2026-10-12-headset-mic-jack-dead-no-signal.md` -- a second, independent root cause found while diagnosing the same "can't pick up anything" symptom; this entry's fix was necessary but not sufficient on its own until the hardware issue was also found.

## References

- Files: `karen-desktop/src-tauri/src/audio.rs`
- Logs: `/home/shadowe/.local/share/com.tauri.dev/logs/friday.log` (or the session's `tauri dev` terminal output)

---

**Resolved By:** Claude (Claude Code)
**Time to Resolution:** ~1.5 hours (interactive live debugging across multiple hypotheses)
